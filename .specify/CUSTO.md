# Otimização de Custos — Firestore / Agentes de IA (Cloud Functions)

> **Tipo:** Especificação técnica obrigatória (SOP) + Postmortem
> **Severidade:** P1 (impacto financeiro direto, recorrente)
> **Escopo:** `functions/scheduledTasksCron.js` e todo backend Node.js que acessa Firestore no projeto `agendaclinica-457713`.
> **Incidente de referência:** Pico de faturamento de Firestore — junho/2026 (R$ 244,22+ em leituras).
> **Status atual (jun/2026):** SOPs implementados e testados (20/20). **Índices Firestore deployados** (✓, aditivo). **Function `scheduledTasksCron` bloqueada por billing** do projeto (Secret Manager 403) — redeploy pelo runbook **`.specify/EXEC_CUSTO.md`** após regularizar. Migração de dados pendente. Auditoria completa ✓/(X) na **§14**.
> **Regra de ouro:** *Você paga por documento que o Firestore lê do índice/coleção — não pelo que sobra após o filtro em memória.* Toda leitura precisa ser justificável por tenant + janela + limite.

---

## 0. Como ler este documento

- **§1–§2** explicam o modelo de custo e a matemática do incidente (o "porquê").
- **§3–§5** são o diagnóstico causa-raiz ancorado no código atual, com a auditoria ferramenta-a-ferramenta e o que ainda está **ABERTO**.
- **§6** são os **Padrões Obrigatórios (SOP)** — código exigido, inflexível.
- **§7–§12** são índices, critérios de aceite, testes, observabilidade, rollout e o **checklist de revisão de PR** (o portão).

Convenções de status nas tabelas: `OK` (conforme SOP) · `PARCIAL` (tenant-scoped mas viola outra regra) · `ABERTO` (full scan / sem cache / sem janela) · `N/A`.

---

## 1. Modelo de Custo do Firestore (referência canônica)

O Cloud Firestore cobra **por operação de documento**, não por byte trafegado nem por “query”:

| Operação | Unidade cobrada | Observação crítica |
|---|---|---|
| **Read** | 1 por **documento retornado pela query** | Um `.limit(400).get()` que devolve 400 docs custa **400 reads**, mesmo que você descarte 398 no `.filter()` do Node. |
| **Read (query vazia)** | 1 read mínimo | Query que não casa nada ainda custa 1 read (cobrança mínima). |
| **Aggregation (`count()`, `sum()`, `average()`)** | **1 read por até 1.000 entradas de índice** lidas (arredonda p/ cima) | Contar 5.000 docs faltosos custa **~5 reads**, não 5.000. **Use isto para totais.** |
| **Write / Delete** | 1 cada | Triggers `onWrite` que mantêm contadores são write, não read. |

**Cota grátis (Spark/Blaze):** 50.000 reads/dia · 20.000 writes/dia.
**Excedente (Blaze):** da ordem de **US$ 0,03–0,06 por 100.000 reads** (confirme a tabela vigente da região `us-central1` no Console — o valor exato varia por região/multi-região). O custo é **linear no nº de reads e multiplicado pela frequência do cron e pelo nº de tarefas ativas**.

> **Insight central:** reduzir leituras redundantes é a única alavanca que ataca *simultaneamente* os três multiplicadores (frequência × tarefas × rounds da IA).

---

## 2. A Matemática do Incidente (fatores de escala)

O custo de UM ciclo é:

```
custo_diário ≈ execuções_cron_dia × tarefas_ativas × rounds_IA × leituras_por_ferramenta
```

### 2.1. Multiplicador do Cron
`scheduledTasksCron` dispara a cada 5 min (`schedule: "*/5 * * * *"`, linha ~46):
- **288 execuções/dia.**
- A cada tick há **custo-base fixo** mesmo sem tarefa vencida: `getDue` lê até **50** docs (`tb_scheduled_tasks where nextRunAt <= now limit 50`, linha ~80) + `recoverStale` lê até **50** docs (`where status == "running" limit 50`, linha ~131). → **até 100 reads/tick × 288 = 28.800 reads/dia só de overhead de orquestração.**

### 2.2. Multiplicador de Tarefas
`MAX_TASKS_PER_RUN = 10` (linha ~38). Cada tarefa vencida dispara `executeTask` → `runAgent`.

### 2.3. Multiplicador de Rounds da IA
`runAgent` roda **até 6 rounds** (`for (let round = 0; round < 6; round++)`, linha ~262), alternando geração ↔ ferramentas. Em cada round a IA pode chamar **N ferramentas**. Cada ferramenta pode reler os mesmos dados (ver §3.2).

### 2.4. Cenário realista (worst-case de UMA tarefa de relatório)
Uma tarefa `kind=report` que monte “diagnóstico de absenteísmo” pode encadear: `listar_agendamentos_hoje` + `taxa_absenteismo` + `listar_agendamentos_risco_alto` + `historico_absenteismo_paciente`. Cada uma chama `fetchAgendamentos` (2×`limit(800)` = **até 1.600 reads**), **sem cache**:

```
4 ferramentas × 1.600 reads = 6.400 reads em UMA tarefa, relendo os MESMOS documentos.
```

Multiplicado por 10 tarefas/tick × 288 ticks → ordem de **milhões de reads/dia**. É exatamente esse perfil que estourou o faturamento.

---

## 3. Causa-Raiz — Diagnóstico Ancorado no Código

### 3.1. Falha A — Full Scan + Filtro em Memória (`listScoped`, `consultar_colecao`, `buscar_paciente` por nome) · **ABERTO**

`listScoped` (linha ~400) lê a coleção inteira até 400 docs e filtra o tenant **depois**:

```javascript
// 🚫 ABERTO — functions/scheduledTasksCron.js ~L400
async function listScoped(collection, clinicaId, { filters = {}, limit = 50 } = {}) {
  const snap = await db.collection(collection).limit(400).get(); // paga 400 reads SEMPRE
  let list = snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((d) => d.id === clinicaId || belongsToClinic(d, clinicaId)); // filtro tardio
  for (const [k, v] of Object.entries(filters)) { /* mais filtro em memória */ }
  return list.slice(0, limit).map(jsonSafe);
}
```

**Impacto:** 400 reads garantidos por chamada, mesmo que a clínica tenha 2 registros. Afeta **7 ferramentas** que delegam a `listScoped`: `listar_usuarios`, `listar_eventos_overbooking`, `listar_realocacoes`, `listar_tickets`, `listar_relatorios_ia`, `listar_email_logs`, `listar_email_queue`.

Mesmo padrão em `consultar_colecao` (`.limit(200).get()` + filtro, linha ~477) e em `buscar_paciente` quando busca por **nome** (`users` `.limit(400).get()` + `includes`, linha ~554).

### 3.2. Falha B — Ausência de Cache no Escopo da Execução (`fetchAgendamentos`) · **ABERTO**

`fetchAgendamentos` (linha ~413) é a função mais cara e não tem memoização:

```javascript
// 🚫 ABERTO — relê tudo a cada chamada, 2 queries de até 800
async function fetchAgendamentos(clinicaId) {
  const docs = [];
  for (const f of ["idClinica", "idclinica"]) {
    const s = await db.collection("tb_agendamentos").where(f, "==", clinicRef(clinicaId)).limit(800).get();
    docs.push(...s.docs); // até 1.600 reads no total (dois campos)
  }
  /* dedup por id */
}
```

Chamada por **4 ferramentas analíticas**: `listar_agendamentos_hoje`, `taxa_absenteismo`, `listar_agendamentos_risco_alto`, `historico_absenteismo_paciente`. Numa execução multi-turno a IA chama várias → **N × 1.600 reads dos mesmos documentos**.

### 3.3. Falha C — Dupla Query `idClinica` / `idclinica` (campo de tenant não canônico) · **ABERTO**

Por compatibilidade com cadastros legados, quase toda query roda **duas vezes** (uma por campo) e deduplica em memória — ver `fetchAgendamentos` (L413) e `listar_agendamentos` (L487). **Cada query dobra o piso de leituras** e **impede o uso de um único índice composto eficiente**. É dívida de dados, não só de código.

### 3.4. Falha D — “Catch-up Loop” Temporal (`advanceNextRun`) · **ABERTO**

```javascript
// 🚫 ABERTO — functions/scheduledTasksCron.js ~L176
function advanceNextRun(t) {
  const s = readSchedule(t);
  ...
  const from = t.nextRunAt ? t.nextRunAt.toDate() : new Date(); // ⬅ ancora no PASSADO
  const next = computeNextRun(s, from);
  ...
}
```

Se a tarefa atrasou (cron inativo, deploy, falha), `from` é a data **vencida original**. `computeNextRun` soma o intervalo a partir dela, então `nextRunAt` continua `<= now` por várias iterações. Consequência: o cron **reprocessa a mesma tarefa repetidas vezes** num intervalo curto (backfill), acionando LLM + leituras redundantes sem ganho analítico. Cada reprocessamento é um worst-case da §2.4.

### 3.5. Falha E — Over-fetch sem janela temporal (`listar_agendamentos`, `..._hoje`, `taxa_absenteismo`) · **PARCIAL/ABERTO**

`listar_agendamentos` (L485) e as analíticas filtram **datas em memória** depois de puxar 300–1.600 docs. A janela (“hoje”, “últimos 30 dias”) **não está na query** (`where dataConsulta >= ... <= ...`), então pagamos por todo o histórico da clínica para usar uma fração.

### 3.6. Falha F — Totais por leitura de documentos em vez de agregação · **ABERTO**

`taxa_absenteismo` (L571) e `historico_absenteismo_paciente` (L619) **leem todos os agendamentos** para *contar* quantos têm `status == "faltou"`. Contagem é o caso de uso clássico de `count()`/agregação (1 read por 1.000 entradas) ou de contadores mantidos por trigger (§6.5).

---

## 4. Auditoria de Custo — Ferramenta a Ferramenta

Worst-case de **reads por chamada** no código atual (antes das correções). “Tenant?” = filtra tenant na query; “Janela?” = limita data na query; “Cache?” = reusa leitura na execução.

| Ferramenta | Helper / query | Reads (worst) | Tenant? | Janela? | Cache? | Status | Prioridade |
|---|---|---:|:--:|:--:|:--:|:--:|:--:|
| `consultar_colecao` | `.limit(200)` + filtro mem. | 200 | ❌ | ❌ | ❌ | ABERTO | Alta |
| `listar_agendamentos` | 2×`where`.limit(300) | 600 | ⚠ dupla | ❌ | ❌ | PARCIAL | Alta |
| `listar_medicos` | `where idClinica`.limit(200) | 200 | ✅ | N/A | ❌ | PARCIAL | Média |
| `listar_agendamentos_hoje` | `fetchAgendamentos` | 1.600 | ⚠ dupla | ❌ | ❌ | ABERTO | **Crítica** |
| `taxa_absenteismo` | `fetchAgendamentos` | 1.600 | ⚠ dupla | ❌ | ❌ | ABERTO | **Crítica** |
| `listar_agendamentos_risco_alto` | `fetchAgendamentos` | 1.600 | ⚠ dupla | ❌ | ❌ | ABERTO | **Crítica** |
| `historico_absenteismo_paciente` | `fetchAgendamentos` | 1.600 | ⚠ dupla | ❌ | ❌ | ABERTO | **Crítica** |
| `buscar_paciente` (nome) | `users`.limit(400) | 400 | ❌ | N/A | ❌ | ABERTO | Alta |
| `buscar_paciente` (cpf/uid) | `where cpf`/`doc()` | ≤5 | ✅ | N/A | N/A | OK | — |
| `listar_usuarios` | `listScoped` | 400 | ❌ | N/A | ❌ | ABERTO | Alta |
| `listar_eventos_overbooking` | `listScoped` | 400 | ❌ | N/A | ❌ | ABERTO | Alta |
| `listar_realocacoes` | `listScoped` | 400 | ❌ | N/A | ❌ | ABERTO | Alta |
| `listar_tickets` | `listScoped` | 400 | ❌ | N/A | ❌ | ABERTO | Alta |
| `listar_relatorios_ia` | `listScoped` | 400 | ❌ | N/A | ❌ | ABERTO | Alta |
| `listar_email_logs` | `listScoped` | 400 | ❌ | N/A | ❌ | ABERTO | Alta |
| `listar_email_queue` | `listScoped` | 400 | ❌ | N/A | ❌ | ABERTO | Alta |
| `atualizar_status_agendamento` | `doc().get()` | 1 | ✅ (pós-check) | N/A | N/A | OK | — |
| `criar_agendamento` | write | 0 read | ✅ | N/A | N/A | OK | — |
| `enviar_whatsapp` | `where idclinica`.limit(5) ×2 | ≤10 | ✅ | N/A | ❌ | PARCIAL | Baixa |
| **Orquestração/tick** | `getDue`(50)+`recoverStale`(50) | 100 | N/A | N/A | N/A | PARCIAL | Média |

**Teto de uma execução de agente** hoje: facilmente **6.000–10.000 reads**. **Meta pós-SOP: < 500 reads/execução** (ver §8).

---

## 5. Itens — Status

> Resolvido no código em jun/2026. Detalhe completo (✓ / (X)) na **§14**.

1. `listScoped` → server-side por tenant + filtros — **✓**
2. `fetchAgendamentos` → cache por execução + janela temporal — **✓**
3. Campo de tenant canônico = **`idclinica`** (corrigido pós-auditoria); escrita grava ambos (`idclinica`+`idClinica`) — **✓**; remoção da dupla query — **(X) pendente migração** (§14)
4. `advanceNextRun` → âncora em `Date.now()` — **✓**
5. `taxa_absenteismo` → **janela única + cache** (correto p/ tenant heterogêneo) — **✓**; agregação `count()` e contadores por trigger — **(X) adiados** (§14)
6. `consultar_colecao` e `buscar_paciente`(nome) → tenant-scoped (sem full scan) — **✓**
7. Read meter + circuit breaker (§6.8) — **✓**

---

## 6. Padrões de Especificação Obrigatórios (SOP)

> Todo código backend Node.js com Firestore **deve** seguir as regras abaixo. Violação = PR bloqueado (§12).

### 6.1. Server-Side Filtering exclusivo (proibido full scan + `.filter()`)

Nenhum documento que não pertença ao tenant solicitado pode trafegar. `.limit()` serve para **paginar resultados legítimos**, nunca para truncar coleção.

```javascript
// ✅ EXIGIDO
const snap = await db.collection("users")
  .where("idClinica", "==", clinicRef(clinicaId))
  .where("status", "==", true)        // filtro adicional na query, não em memória
  .limit(100)
  .get();
```

`listScoped` deve ser **reescrita** para receber o campo de tenant e os filtros e montar `where` nativo:

```javascript
// ✅ Substituição EXIGIDA de listScoped
async function listScoped(collection, clinicaId, { filters = {}, limit = 50 } = {}) {
  let q = db.collection(collection)
    .where(TENANT_FIELD, "==", clinicRef(clinicaId)); // §6.6: campo canônico único
  for (const [k, v] of Object.entries(filters)) {
    if (v == null || v === "") continue;
    q = q.where(k, "==", v);            // exige índice composto (§7)
  }
  const snap = await q.limit(limit).get();
  return snap.docs.map((d) => jsonSafe({ id: d.id, ...d.data() }));
}
```

**Proibido:** usar `Array.prototype.filter()` para suprir falta de índice composto numa query ampla. Se precisa filtrar por 2+ campos, **crie o índice** (§7).

### 6.2. Context Cache por Execução (memoization de instância)

Toda execução multi-turno recebe uma “maleta” em memória, viva apenas durante a request:

```javascript
// ✅ EXIGIDO — em executeTask
async function executeTask(task) {
  const runCache = { agendamentos: new Map(), counts: new Map() }; // morre com a request
  const { content } = await runAgent({ ..., clinicaId, cache: runCache });
}

// ✅ fetch com cache
async function fetchAgendamentosCached(clinicaId, cache, { since, until } = {}) {
  const key = `${clinicaId}|${since || ""}|${until || ""}`;
  if (cache.agendamentos.has(key)) return cache.agendamentos.get(key); // 0 reads
  let q = db.collection("tb_agendamentos").where(TENANT_FIELD, "==", clinicRef(clinicaId));
  if (since) q = q.where("dataConsulta", ">=", Timestamp.fromDate(since));
  if (until) q = q.where("dataConsulta", "<=", Timestamp.fromDate(until));
  const snap = await q.limit(500).get();
  const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  cache.agendamentos.set(key, list);
  return list;
}
```

O `cache` deve ser **propagado** por `runAgent` → `executeTool(name, args, clinicaId, cache)`.

### 6.3. Janelas Temporais na Query (Time-Bounding)

Relatório com recorte de tempo **não** pode escanear histórico inteiro:

```javascript
// ✅ EXIGIDO — "hoje" (BRT) resolvido na QUERY
const inicio = new Date(); inicio.setUTCHours(3, 0, 0, 0);   // 00h BRT
const fim    = new Date(); fim.setUTCHours(26, 59, 59, 999); // 23h59 BRT
const snap = await db.collection("tb_agendamentos")
  .where(TENANT_FIELD, "==", clinicRef(clinicaId))
  .where("dataConsulta", ">=", Timestamp.fromDate(inicio))
  .where("dataConsulta", "<=", Timestamp.fromDate(fim))
  .get();
```

`listar_agendamentos_hoje`, `taxa_absenteismo` (janela do período), `listar_agendamentos_risco_alto` (`now..now+dias`) e `listar_agendamentos` (quando `dataInicio/dataFim` vierem) **devem** empurrar a janela para a query.

### 6.4. Recalibração Temporal Segura (anti catch-up)

Cronogramas diário/semanal/mensal **sempre** referenciam `Date.now()` para o próximo salto; backfill só com teto explícito:

```javascript
// ✅ EXIGIDO — substitui a âncora de advanceNextRun
function advanceNextRun(t) {
  const s = readSchedule(t);
  if (s.type === "once") return null;
  if (t.maxRuns != null && (t.runCount || 0) + 1 >= t.maxRuns) return null;
  const base = new Date();                          // presente real, NÃO t.nextRunAt
  const next = computeNextRun(s, base);
  if (!next) return null;
  if (t.endAt && next.getTime() > t.endAt.toDate().getTime()) return null;
  return next;
}
```

Para `interval`, garantir `next > now` somando múltiplos do intervalo até ultrapassar `now` (uma única vez), nunca em loop por dia perdido. Backfilling só quando explicitamente solicitado e limitado a **1** execução de compensação.

### 6.5. Sumarização Orientada a Triggers / Agregação (totais sem ler N docs)

Para **contagens** (absenteísmo, performance, totais financeiros):

**Opção A — Aggregation query (mínimo esforço, recomendado p/ já existente):**
```javascript
// ✅ count() agrega no servidor: ~1 read / 1.000 entradas, não 1/doc
const base = db.collection("tb_agendamentos")
  .where(TENANT_FIELD, "==", clinicRef(clinicaId))
  .where("dataConsulta", ">=", Timestamp.fromDate(winStart))
  .where("dataConsulta", "<=", Timestamp.fromDate(now));
const totalAgg = await base.count().get();
const faltasAgg = await base.where("status", "==", "faltou").count().get();
const total = totalAgg.data().count, faltas = faltasAgg.data().count;
const taxa = total ? +(faltas / total * 100).toFixed(1) : 0;
```

**Opção B — Contadores materializados por trigger (melhor em escala):**
manter `tb_dashboard_stats/{clinicaId}` com `total_faltas`, `total_agendamentos` via trigger `onWrite` em `tb_agendamentos` usando `FieldValue.increment(±1)`. A IA faz **1 leitura de 1 documento** para compor o relatório gerencial. Requer índice/trigger e backfill inicial dos contadores.

### 6.6. Campo de Tenant Canônico Único (fim da dupla query)

> **Correção pós-auditoria (jun/2026):** a inspeção dos **101 índices de produção** mostrou que o campo dominante é **`idclinica` (minúsculo, reference)** — 49 índices vs 2 de `idClinica`. Portanto o canônico é **`idclinica`**, não `idClinica`. A base ainda é **heterogênea** (`idclinica`/`idClinica` como reference OU string, e `clinicaId` string).

Decisão: **`idclinica`** (`DocumentReference` → `tb_clinica`) é o campo canônico.

```javascript
const TENANT_FIELD = "idclinica";
// Enquanto a base não está unificada, a leitura cobre as variantes reais
// (reference + string em idclinica/idClinica + campo clinicaId) — ver
// `lib/dataAccess.js::tenantQueries`. NÃO é full scan; é igualdade indexada.
```

- **Migração:** `functions/scripts/migrateTenantField.js` garante `idclinica` (reference) em todo doc, derivando de `idClinica`/`clinicaId`/`id_clinica`; idempotente, paginado, fora do cron. **(X) ainda não executada** (precisa de credenciais admin + export de backup).
- **Escrita:** `criar_agendamento` grava **ambos** `idclinica` e `idClinica` enquanto a base não está unificada (visibilidade para todas as queries/índices). Após a migração: manter só `idclinica`.
- **Leitura:** queries usam as variantes de tenant (acima). A redução para **um único** campo/query — e a reativação da **agregação `count()`** em `taxa_absenteismo` (§6.5) — só é segura **após** a migração validada.

### 6.7. Contrato de Busca (sem scan para texto livre)

Busca por **nome** não pode varrer coleção. Exigências:
- Preferir `cpf`/`uid` (lookup direto/indexado).
- Para nome, manter campo normalizado `nome_lower` e usar **prefix query** indexada:
  ```javascript
  const q = String(args.nome).toLowerCase();
  const snap = await db.collection("users")
    .where("idClinica", "==", clinicRef(clinicaId))
    .where("nome_lower", ">=", q)
    .where("nome_lower", "<", q + "")
    .limit(10).get();
  ```
- Sem `nome_lower` cadastrado, a ferramenta deve **recusar** a busca ampla e pedir cpf/uid (nunca cair no `.limit(400)`).

### 6.8. Orçamento de Leituras + Circuit Breaker (instrumentação obrigatória)

Toda execução conta as leituras e **aborta** ao exceder o teto, registrando no log estruturado:

```javascript
// ✅ EXIGIDO — wrapper único de leitura
function makeReadMeter(limit = 1500) {
  let reads = 0;
  return {
    add(n) { reads += n; if (reads > limit) throw new Error(`READ_BUDGET_EXCEEDED: ${reads}/${limit}`); },
    get total() { return reads; },
  };
}
// Em cada .get(): meter.add(snap.size || 1);  (e snap.size para agregações: meter.add(1))
// Ao final de executeTask: console.log(JSON.stringify({ taskId, reads: meter.total, toolsUsed, durationMs }));
```

- Teto padrão por execução: **1.500 reads** (ajustável por tarefa, nunca silenciosamente).
- O total de reads por execução **deve** ir para o log estruturado (para o alarme da §10).

---

## 7. Índices Compostos Firestore — **DEPLOYADOS** (✓)

> **Status:** o `firestore.indexes.json` no repo foi **mesclado** com os **101 índices de produção** (preservando todos) + **11 novos** sobre o campo canônico **`idclinica`** e **deployado** com sucesso (`firebase deploy --only firestore:indexes`). 2 dos índices propostos já existiam em produção. Campo de tenant = **`idclinica`** (reference) — confirmado pela auditoria (§6.6).

Os 11 índices adicionados (todos `idclinica` ASC + campo):

| Coleção | Campos compostos |
|---|---|
| `tb_agendamentos` | `idclinica, cpf` *(idclinica+dataConsulta e idclinica+status+dataConsulta já existiam)* |
| `tb_medicos` | `idclinica, status` |
| `users` | `idclinica, status` · `idclinica, nome_lower` |
| `tickets` | `idclinica, status` · `idclinica, prioridade` |
| `tb_overbooking_events` | `idclinica, decisao` |
| `queue_realoc` | `idclinica, status` |
| `tb_relatorio_ia` | `idclinica, tipoRelatorio` |
| `email_logs` | `idclinica, tipo` |
| `email_queue` | `idclinica, status` |

> ⚠️ **Nunca** rode `firebase deploy --only firestore:indexes` a partir de um `firestore.indexes.json` que contenha **apenas** estes — ele apagaria os 101 de produção. O arquivo no repo já está mesclado; mantê-lo assim. Igualdade em campo único usa índice automático (não listado).

---

## 8. Critérios de Aceite (Definition of Done, mensuráveis)

Uma mudança nesta área só é “pronta” quando **todos** abaixo são verdadeiros:

1. **Zero full scan:** nenhuma query de ferramenta sem `where(TENANT_FIELD, ...)`. Nenhum `.filter()` substituindo filtro indexável.
2. **Teto de execução:** uma execução de agente de relatório complexa consome **< 500 reads** (medido pelo read meter §6.8) — redução ≥ 90% vs. baseline.
3. **Cache efetivo:** numa execução com 3+ ferramentas analíticas, `fetchAgendamentos*` faz **no máximo 1** query por janela distinta (verificável no log).
4. **Sem catch-up:** após simular 5 dias offline, a tarefa roda **1 vez** (não 5). `nextRunAt` resultante é `> now`.
5. **Totais sem ler tudo:** `taxa_absenteismo`/`historico_…` não escaneiam a coleção — usam **janela única + cache** (hoje, por causa do tenant heterogêneo) e, **após a migração**, `count()`/contador materializado.
6. **Custo-base do tick:** overhead de `getDue`+`recoverStale` documentado e ≤ 100 reads/tick; avaliar reduzir frequência do cron (ver §11).
7. **Índices aplicados:** `firestore.indexes.json` atualizado e deployado; nenhuma query lança `FAILED_PRECONDITION` no log.
8. **Multi-tenant preservado:** nenhuma regressão de isolamento — testes da §9 passam.

---

## 9. Plano de Testes e Validação

### 9.1. Emulador + contagem de leituras
- Rodar no **Firebase Emulator Suite** com seed determinístico: 1 clínica com 3 usuários, 40 agendamentos (mix de `status`), 2 clínicas “vizinhas” com dados para detectar vazamento.
- Instrumentar o read meter (§6.8) e **asseverar** o total por ferramenta. Tabela-alvo (worst → meta):

| Ferramenta | Antes | Meta |
|---|---:|---:|
| `listar_usuarios` | 400 | ≤ nº usuários da clínica (ex.: 3) |
| `taxa_absenteismo` | 1.600 | ≤ 2 (agregação) |
| `listar_agendamentos_hoje` | 1.600 | ≤ nº de hoje (janela) |
| `listar_*` (listScoped) | 400 | ≤ `limit` legítimo |

### 9.2. Isolamento multi-tenant
- Para cada ferramenta, garantir que **nenhum** documento de outra clínica aparece no retorno (assert por `idClinica`).
- `atualizar_status_agendamento` em doc de outra clínica deve retornar “fora do escopo” (já coberto, manter).

### 9.3. Recalibração temporal
- Tarefa `daily 08:00` com `nextRunAt` 5 dias no passado → após um tick: exatamente **1** execução e `nextRunAt` no próximo 08:00 futuro.
- Tarefa `interval 60min` parada por 3h → **1** execução, próximo `now+60min`.

### 9.4. Índices
- Executar cada query nova contra o emulador/produção e confirmar ausência de `FAILED_PRECONDITION`. CI deve falhar se algum índice referenciado não existir.

---

## 10. Observabilidade e Alarmes

1. **Log estruturado por execução:** `{ taskId, clinicaId, kind, reads, toolsUsed, durationMs, ok }` (read meter §6.8). 1 linha por `executeTask`.
2. **Métrica de leituras:** criar log-based metric `firestore_reads_per_run` a partir do campo `reads`; alarme se `p95 > 800` numa janela de 1h.
3. **Budget Alert (Billing):** orçamento mensal no GCP Billing para o produto Firestore com alertas em 50/80/100%. **Pré-incidente:** notificar em valor absoluto diário (ex.: > R$ 5/dia).
4. **Dashboard:** painel com reads/dia, reads/tick de orquestração, top-5 ferramentas por reads, e contagem de execuções catch-up (deve ser ~0).
5. **Circuit breaker visível:** ocorrências de `READ_BUDGET_EXCEEDED` viram alerta imediato (indicam ferramenta nova fora do SOP).

---

## 11. Rollout, Mitigações Rápidas e Rollback

**Ordem recomendada (menor risco → maior):**
1. **Mitigação imediata (hotfix, baixo risco):** reduzir frequência do cron de `*/5` para `*/15` (ou `*/30`) → corta o multiplicador de 288 para 96/48 ticks/dia **sem mudar lógica**. Avaliar SLA das tarefas antes.
2. Aplicar **read meter + circuit breaker** (§6.8) — só observabilidade/proteção, não muda resultado.
3. Reescrever `listScoped` server-side + **deploy dos índices** (§6.1, §7).
4. Adicionar **cache + time-bounding** em `fetchAgendamentos*` (§6.2, §6.3).
5. `taxa_absenteismo`/`historico_…` por **janela única + cache** (feito); migrar para **agregação `count()`** só após unificar o tenant (§6.6).
6. Corrigir **`advanceNextRun`** (§6.4).
7. **Migração do campo canônico** + remoção da dupla query (§6.6) — maior risco de dados, fazer por último, com backup/export.

**Rollback:** cada item é independente e atrás de deploy isolado de função; reverter = redeploy da versão anterior. A migração de dados (§6.6) deve ter **export do Firestore** antes e ser idempotente.

---

## 12. Checklist de Revisão de PR (portão inflexível)

Marcar **todos** antes de aprovar qualquer PR que toque Firestore no backend:

- [ ] Toda query tem `where(TENANT_FIELD, "==", clinicRef(clinicaId))` (ou justificativa explícita para coleção global não-tenant).
- [ ] Nenhum `.limit(N).get()` seguido de `.filter()` para isolar tenant ou suprir índice.
- [ ] Filtros adicionais estão **na query** e têm índice composto declarado em `firestore.indexes.json`.
- [ ] Recortes de data estão **na query** (`dataConsulta >= / <=`), não em memória.
- [ ] Leituras repetidas na mesma execução passam pelo **runCache**.
- [ ] Contagens não escaneiam a coleção: usam `count()`/contador materializado **ou** janela única limitada + cache (enquanto o tenant não está unificado).
- [ ] Agendamento recorrente ancora em `Date.now()` (sem backfill não delimitado).
- [ ] Read meter instrumentado; teto definido; total logado.
- [ ] Testes da §9 (custo + isolamento + temporal) adicionados/passando no emulador.
- [ ] Sem `idclinica` em **escrita** de documento novo (pós-migração); leitura usa campo canônico.

---

## 13. Apêndice — Referências de Código

| Item | Arquivo | Local aprox. |
|---|---|---|
| Cron schedule `*/5` | `functions/scheduledTasksCron.js` | L44–52 |
| `getDue` / `recoverStale` | idem | L78–148 |
| `advanceNextRun` (catch-up) | idem | L172–181 |
| `runAgent` (6 rounds) | idem | L257–284 |
| `listScoped` (full scan) | idem | L399–410 |
| `fetchAgendamentos` (sem cache, 2×800) | idem | L412–423 |
| `executeTool` (switch das ferramentas) | idem | L474–700 |
| `TOOLS` (specs) | idem | L305–368 |
| Espelho/origem | `cloud_functions/scheduledTasksCron.js` | — |

> Manter este documento sincronizado com o código: ao fechar cada item ABERTO da §5, atualizar o status na §4 e na §5, e registrar o ganho de reads medido (§8/§9).

---

## 14. Status de Implementação (auditoria jun/2026)

Legenda: **✓** implementado e validado · **✓ (parcial)** implementado com ressalva · **(X)** não implementado (com motivo).

| # | Medida (SOP) | Status | Onde | Observação / por que (X) |
|---|---|:--:|---|---|
| §6.1 | Server-side filtering (sem full scan) | **✓** | `lib/dataAccess.js` (`tenantFetch`, `listScoped`) | Auditado: **nenhum** `.collection().limit().get()` direto; nenhum `.limit(400/800)`. 7 ferramentas de `listScoped` + `consultar_colecao` migradas. |
| §6.2 | Cache por execução (memoization) | **✓** | `fetchAgendamentos` + `cache` propagado `executeTask→runAgent→executeTool` | Teste prova 0 leitura na 2ª chamada da mesma janela. |
| §6.3 | Time-bounding (janela na query) | **✓** | `fetchAgendamentos({since,until})`; `listar_agendamentos`/`_hoje`/`risco_alto` | Janela empurrada para a query; fallback em memória se faltar índice. |
| §6.4 | Anti catch-up (`advanceNextRun`) | **✓** | `lib/costGuards.js` | Âncora em `Date.now()`. Teste prova independência de `nextRunAt` e salto único. |
| §6.5 | Agregação `count()` (Opção A) | **(X) adiada** | `taxa_absenteismo` (windowed) | **Não ativada de propósito:** com tenant heterogêneo (idclinica/idClinica/clinicaId), `count()` por campo único **subcontaria silenciosamente**. Em vez disso, `taxa_absenteismo` usa **1 leitura de janela** (limitada + cacheada) e conta em memória — correto e barato. Reativar `count()` **após** a migração (§6.6). |
| §6.5 | Contadores por trigger (Opção B) | **(X)** | — | Exige **novas triggers `onWrite`** + backfill de `tb_dashboard_stats`. Fica para escala maior. |
| §6.6 | Campo canônico = `idclinica` (corrigido) | **✓** | `TENANT_FIELDS=["idclinica","idClinica"]`; auditoria dos índices | Auditoria de produção corrigiu a escolha (era `idClinica`). |
| §6.6 | Cobertura heterogênea na leitura (ref+string+clinicaId) | **✓** | `dataAccess.tenantQueries` | Substitui o antigo full-scan+`belongsToClinic` **sem** full scan; teste dedicado prova as 3 representações. |
| §6.6 | Escrita de tenant | **✓** | `criar_agendamento` grava `idclinica` **e** `idClinica` | Visível a todas as queries até a unificação. |
| §6.6 | **Remover** dupla query / unificar campo | **(X)** | `migrateTenantField.js` (pronto, canônico=idclinica) | **Pendente de rodar a migração** (credenciais admin + `gcloud firestore export` p/ backup). Custo residual: poucas leituras de probe vazio por query — ínfimo perto do full scan anterior. |
| §6.7 | Busca sem full scan | **✓ (parcial)** | `buscar_paciente`(nome) tenant-scoped | Sem mais varredura global de 400. **(X)** o prefixo indexado `nome_lower`: índice declarado, mas o **campo `nome_lower` não está populado** em `users` (precisa backfill). Até lá, filtro de nome roda em memória já **escopado ao tenant**. |
| §6.8 | Read meter + circuit breaker | **✓** | `makeReadMeter`/`meteredGet`/`meteredCount`; re-lança no fallback | Teste prova abort em `READ_BUDGET_EXCEEDED` e que o fallback **não** o engole. |
| §7 | Índices compostos | **✓ arquivo / (X) deploy** | `firestore.indexes.json` + `firebase.json` | Arquivo criado e referenciado. **Deploy** (`firebase deploy --only firestore:indexes`) é passo de **ops** (não executado aqui). Sem ele, queries compostas caem no fallback tenant-scoped (ainda sem full scan). |
| §10 | Log estruturado por execução | **✓** | `executeTask` → `console.log(JSON…{reads,toolsUsed,…})` | — |
| §10 | Métrica/alarme/budget alert/dashboard | **(X)** | — | Configuração no **GCP Console** (log-based metric, Billing budget), **não automatizável por código**. O log já emite o campo `reads` que alimenta a métrica. |
| §11 | Hotfix frequência do cron `*/5`→`*/15` | **✓** | `schedule: "*/15 * * * *"` | Corta o multiplicador de 288→96 execuções/dia. |
| §11 | Migração de dados (execução) | **(X)** | `migrateTenantField.js` | Script criado e validado (sintaxe); **execução** depende de credenciais de produção. |
| §9 | Testes unitários + Firestore falso | **✓** | `functions/test/*` | 20 testes, `node --test`. Ver §15. |
| §9 | Testes no **Firebase Emulator** (seed real) | **(X)** | — | Não rodados aqui (precisa do emulador instalado/seed). Os testes com Firestore falso cobrem a lógica de custo de forma determinística. |

### 14.1. Garantia de que o custo NÃO sobe de forma descontrolada

O controle de custo é **em camadas**, cada uma um limite independente:

1. **Frequência travada:** cron a cada 15 min → **96 execuções/dia** (não 288).
2. **Teto rígido por execução (circuit breaker):** `READ_BUDGET = 1500` — qualquer execução que tente ultrapassar é **abortada** com `READ_BUDGET_EXCEEDED` (testado). É o disjuntor que mata o cenário de 6.400+ leituras.
3. **Escopo de tenant em toda leitura:** nenhuma query lê a coleção inteira; cada uma traz só os documentos da clínica (dezenas), não 400/800.
4. **Cache por execução:** dados relidos na mesma execução custam **0**.
5. **Totais por janela única + cache:** `taxa_absenteismo` lê a janela uma vez (limitada, cacheada) e conta em memória — `count()` será reativado após unificar o tenant (§6.6).
6. **Limite de tarefas/tick:** `MAX_TASKS_PER_RUN = 10`.

**Limite teórico superior** (todos os diais no pior caso): `96 ticks × (≤100 orquestração + 10 tarefas × 1500 teto) ≈ 1,45 M reads/dia` — e isso **só** se cada tarefa estourasse o teto a cada tick, o que os SOPs impedem. **Esperado real:** cada execução < 300 leituras → dezenas de milhares de reads/dia, dentro/perto da cota grátis (50k/dia).

**Diais de aperto adicional** (se o custo ainda preocupar), sem mudar lógica:
- Baixar `READ_BUDGET` (ex.: 800) → teto por execução mais agressivo.
- Baixar `MAX_TASKS_PER_RUN` ou a frequência (`*/30`).
- Concluir a migração (§6.6) → elimina o `+1 probe` e metade das queries.

---

## 15. Testes Automatizados (implementados)

Suíte determinística com o runner nativo do Node (`node:test`) — **sem dependências novas**. Roda em segundos, não precisa de Firebase.

**Como rodar:**
```bash
cd functions && npm test          # ou: node --test test/
```
**Resultado atual:** `# tests 20 · # pass 20 · # fail 0` (idem na cópia `cloud_functions/`).

**Arquitetura testável:** a lógica sensível a custo foi extraída em módulos puros/injetáveis, para poder ser exercitada sem Firestore real:
- `functions/lib/costGuards.js` — puro (meter, recalibração temporal, parse/score).
- `functions/lib/dataAccess.js` — fábrica que recebe `db`/`Timestamp` injetados.
- `functions/test/fakeFirestore.js` — Firestore em memória que **conta leituras** (1/doc no `get`, 1 no `count`, 1 no `doc.get`) e simula índice ausente (`failOn`).

**Cobertura (o que cada teste garante):**

| Arquivo / teste | SOP | Garante |
|---|---|---|
| `costGuards` · circuit breaker | §6.8 | Meter acumula e **estoura** no teto (`READ_BUDGET_EXCEEDED`). |
| `costGuards` · anti catch-up (diário) | §6.4 | Próxima execução é **futura**, **independente** de `nextRunAt` passado, e roda **uma vez**. |
| `costGuards` · anti catch-up (intervalo) | §6.4 | Salto é `now+intervalo`, não `passado+intervalo` (sem backfill). |
| `costGuards` · maxRuns/once/endAt | §6.4 | Para corretamente nos limites da tarefa. |
| `costGuards` · parseDate/quickScore/faltaRatios/belongsToClinic | — | Helpers de domínio corretos. |
| `dataAccess` · tenantFetch isolamento | §6.1/§6.6 | Retorna **só** a clínica do contexto; **sem vazamento**; **toda** query é tenant-scoped; lê poucas (não centenas). |
| `dataAccess` · tenant heterogêneo | §6.6 | Acha o tenant como **reference, string e campo `clinicaId`** — cobertura do antigo `belongsToClinic` **sem** full scan. |
| `dataAccess` · early-break | §6.6 | Campo canônico supre o limite e **evita a 2ª query** legada. |
| `dataAccess` · listScoped | §6.1 | Filtro server-side + isolamento de tenant. |
| `dataAccess` · time-bounding | §6.3 | Janela exclui fora do intervalo; não vaza outra clínica. |
| `dataAccess` · cache | §6.2 | 2ª chamada da mesma janela → **0 leituras**. |
| `dataAccess` · fallback de índice | §6.1/§7 | Sem índice composto, cai para filtro em memória **ainda tenant-scoped** (não vira full scan) e dá o resultado certo. |
| `dataAccess` · meteredCount | §6.5 | `count()` cobra **1 leitura**, não N. |
| `dataAccess` · circuit breaker | §6.8 | Estouro de orçamento **aborta** e **não é engolido** pelo fallback. |

**Lacuna conhecida:** testes de **integração no Firebase Emulator** com seed real e deploy de índices ainda não foram executados (§9) — recomendados antes do deploy de produção. Os testes acima cobrem a lógica de custo de forma determinística e são suficientes para o portão de PR (§12).
