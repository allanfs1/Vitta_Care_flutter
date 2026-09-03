# Cloud Functions — Especificação de Deploy

Procedimento de publicação das Cloud Functions mantidas **neste repositório**.

> **Projeto Firebase**: `agendaclinica-457713`
> **Codebase**: `ia` (definido em `firebase.json`)
> **Runtime**: `nodejs20` · **Região**: `us-central1`
> **Fuso das agendadas**: `America/Sao_Paulo` (BRT)

Para o inventário de **todas** as functions do projeto — inclusive as de outros
repositórios — veja [`cloud_functions.md`](cloud_functions.md). Este documento
cobre só o que sai daqui, e como colocar no ar sem derrubar o resto.

---

## 1. Escopo: o que este repositório publica

O projeto Firebase hospeda funções de **mais de uma origem**. As de `functions/`
deste repo vivem num *codebase* isolado (`ia`) justamente para que o deploy daqui
não toque nas outras.

| Function | Trigger | Agenda | Memória | Timeout | Secrets |
|---|---|---|---|---|---|
| `chatProxy` | https | — | 256 MiB | 120 s | `AZURE_AI_KEY` |
| `anthropicProxy` | https | — | 256 MiB | 120 s | `ANTHROPIC_API_KEY` |
| `analyzeDocument` | https | — | 256 MiB | 120 s | `AZURE_DOCINTEL_KEY` |
| `emailProxy` | https | — | 256 MiB | 60 s | `SENDGRID_API_KEY` |
| `sendConfirmationEmail` | https | — | 256 MiB | 60 s | `SENDGRID_API_KEY` |
| `whatsappProxy` | https | — | 256 MiB | 60 s | — |
| `scheduledTasksCron` | scheduled | `*/15 * * * *` | 512 MiB | 540 s | `AZURE_AI_KEY`, `SENDGRID_API_KEY` |
| **`vigiaCron`** | scheduled | `0 6 * * *` | 512 MiB | 540 s | `AZURE_AI_KEY` |
| **`publicAgendaProxy`** | https | — | 256 MiB | 30 s | — |
| **`publicAgendaSolicitar`** | https | — | 256 MiB | 30 s | — |
| **`pubmedProxy`** | https | — | 256 MiB | 60 s | `NCBI_API_KEY` (opcional) |

**Status atual:** todas publicadas, **exceto `vigiaCron`, `publicAgendaProxy`,
`publicAgendaSolicitar` e `pubmedProxy`** — escritas, testadas (`functions/test/publicAgenda.test.js`)
e aguardando deploy: `firebase deploy --only functions:publicAgendaProxy,functions:publicAgendaSolicitar`.
Backend da agenda pública do médico (`/agenda-publica/:id`); ver
`.specify/ATENCAO.md`.

**`pubmedProxy`** é o backend do módulo de Evidências
([`EVIDENCIAS.md`](EVIDENCIAS.md)). Antes do deploy, configure as variáveis de
ambiente `NCBI_TOOL` e `NCBI_EMAIL` — o NCBI exige as duas em toda chamada, e
sem elas a função responde 503 de propósito. `NCBI_API_KEY` é opcional (eleva o
teto de ~3 para 10 req/s):

```bash
firebase functions:secrets:set NCBI_API_KEY    # opcional
firebase deploy --only functions:pubmedProxy
```

É a **única function deste repositório que exige login** (`verifyIdToken`). Não
remova essa checagem para "facilitar teste": o limite do NCBI é por IP, e um
proxy aberto faria o NCBI barrar o tráfego de todas as clínicas de uma vez.

---

## 2. A regra que não pode ser quebrada

```bash
# ❌ NUNCA — remove as Cloud Functions dos outros codebases do projeto
firebase deploy --only functions

# ✅ SEMPRE — deploy direcionado, função por função
firebase deploy --only functions:vigiaCron
```

O Firebase interpreta `--only functions` como *"o estado desejado do projeto é o
que está neste codebase"* e **apaga o que não encontra**. Como este repo é um de
vários publicando no mesmo projeto, um deploy amplo apagaria dezenas de funções
de produção listadas em `cloud_functions.md`.

O aviso está repetido no cabeçalho de `functions/index.js`. Ele existe porque o
erro é silencioso: o comando roda, reporta sucesso, e o estrago só aparece quando
alguém abre uma tela que dependia de uma função que sumiu.

Para publicar várias de uma vez, liste-as:

```bash
firebase deploy --only functions:chatProxy,functions:emailProxy,functions:vigiaCron
```

---

## 3. Pré-requisitos

### 3.1 Ferramentas

```bash
firebase --version     # 15.x
node --version         # 20.x (o runtime é nodejs20; ver functions/package.json)
firebase login:list    # precisa listar a conta com acesso ao projeto
```

### 3.2 Secrets

Os secrets vivem no **Secret Manager**, não no repositório. Verifique antes de
publicar — uma função agendada com secret faltando falha em silêncio na primeira
execução, e você só descobre no dia seguinte:

```bash
firebase functions:secrets:access AZURE_AI_KEY --project agendaclinica-457713
```

Para criar ou rotacionar:

```bash
firebase functions:secrets:set AZURE_AI_KEY --project agendaclinica-457713
```

Depois de rotacionar um secret é **obrigatório republicar** as funções que o
usam — elas carregam a versão do secret que existia no momento do deploy.

### 3.3 Índices do Firestore

**Índices primeiro, função depois.** Uma query sem índice falha com
`failed-precondition`, e numa função agendada isso vira erro recorrente.

```bash
firebase deploy --only firestore:indexes
```

As queries de `vigiaCron` são **todas de igualdade** (`where clinicaId ==`,
`where idclinica ==`), servidas pelos índices automáticos de campo único.
**Nenhum índice composto novo é necessário para ela.**

---

## 4. Testes antes do deploy

```bash
cd functions
npm test          # 37 testes — parser, dedupe, agendamento, custo
```

O que os testes cobrem e por que importam no deploy:

- **`vigiaCron.test.js`** — fixa a chave de deduplicação em valor literal
  (`action|auditoria de faltas`). O ciclo do Vigia roda em dois lugares (Dart no
  cliente, Node aqui) e os dois precisam gerar a mesma chave; se divergirem, cada
  lado repropõe o que o outro já sugeriu. Este teste quebra antes de a divergência
  chegar em produção.
- **`costGuards.test.js`** — read meter e circuit breaker (§6.8 de `CUSTO.md`).
- **`dataAccess.test.js`** — escopo por tenant e cache por execução.

Um teste vermelho aqui é motivo para **não** publicar.

---

## 5. `vigiaCron` — o deploy pendente

### 5.1 O que ela faz

Uma vez por dia, às **06:00 BRT**, para cada clínica ativa:

1. Lê a operação (agendamentos, faltas, filas) pelas ferramentas MCP e o Cérebro.
2. Escreve **um relatório** em `tb_relatorio_ia` → aparece em `/relatorios`.
3. Propõe **até 3 rotinas de prevenção** em `tb_scheduled_tasks` com
   `status: "suggested"` → aparecem em `/tarefas-agendadas` aguardando aprovação.

### 5.2 A garantia: ela nunca executa nada

Uma rotina proposta **não roda**. São três travas independentes:

| # | Trava | Onde |
|---|---|---|
| 1 | A sugestão é gravada **sem `nextRunAt`** — não há horário para vencer | `vigiaCron.js` › `gravarSugestoes` |
| 2 | `scheduledTasksCron` só pega `status === "active"` | `scheduledTasksCron.js:118,132` |
| 3 | O cliente Dart filtra o mesmo status | `getDue` / `claimDue` |

Ativar uma rotina exige uma pessoa aprovando na tela — e é só na aprovação que o
primeiro `nextRunAt` é calculado.

### 5.3 Coleções que ela toca

| Coleção | Acesso | Observação |
|---|---|---|
| `tb_clinica` | leitura | lista as clínicas ativas (até 50) |
| `tb_cerebro_notas` | leitura | amostra de até 400 notas para o contexto |
| `tb_scheduled_tasks` | leitura + **escrita** | grava sugestões (`status: "suggested"`) |
| `tb_relatorio_ia` | **escrita** | o relatório do dia |
| `tb_vigia_ciclos` | leitura + **escrita** | trava diária; criada sozinha no 1º ciclo |

### 5.4 Trava contra ciclo duplo

O ciclo também roda no cliente (`lib/features/ia/vigia/`) quando alguém abre o
app. Os dois compartilham a mesma trava: um documento em `tb_vigia_ciclos` com id
`{clinicaId}_{YYYY-MM-DD}`, marcado em transação. **Quem chegar primeiro faz o
ciclo do dia**; o outro encontra `executou: true` e não faz nada.

Consequência prática: publicar `vigiaCron` **não** duplica análises nem gasto de
IA. O cron passa a ser a garantia de que o ciclo acontece mesmo num dia em que
ninguém abre o app.

### 5.5 Custo por execução

Por clínica, por dia: até 6 rodadas de LLM com ferramentas (o loop de
`runAgent`), limitadas pelo mesmo `READ_BUDGET = 1500` leituras do
`scheduledTasksCron`. Máximo de 8 clínicas por execução (`MAX_CLINICAS`).

Para uma instalação com 1 clínica: **1 ciclo/dia**, ordem de grandeza semelhante
a uma tarefa agendada de relatório. Ver `CUSTO.md` §6 para os SOPs de custo.

### 5.6 Publicar

```bash
# 1. índices (não muda nada para esta função, mas é a ordem correta do SOP)
firebase deploy --only firestore:indexes

# 2. testes
cd functions && npm test && cd ..

# 3. a função
firebase deploy --only functions:vigiaCron
```

---

## 6. Verificação pós-deploy

```bash
# a função aparece na lista?
firebase functions:list --project agendaclinica-457713 | grep vigia

# logs da primeira execução (só depois das 06:00 BRT)
firebase functions:log --only vigiaCron --project agendaclinica-457713
```

O log de um ciclo saudável tem uma linha por clínica:

```
vigiaCron[<clinicaId>]: relatório=sim · 2 sugerida(s) · 1 descartada(s)
vigiaCron: 1/1 clínica(s) analisada(s).
```

Para forçar uma execução sem esperar as 06:00, use o botão **✨** no topo de
`/tarefas-agendadas` no app — ele roda o ciclo do lado do cliente, que usa a
mesma trava e grava nas mesmas coleções. É o jeito mais rápido de validar o
resultado ponta a ponta.

### Sinais de problema

| Sintoma | Causa provável |
|---|---|
| `o modelo não devolveu JSON utilizável` | Prompt ou modelo mudou; ver `sistema()` em `vigiaCron.js` |
| Nenhuma sugestão em vários dias seguidos | Normal se a operação está estável; confira `sugestoesDescartadas` em `tb_vigia_ciclos` |
| `READ_BUDGET_EXCEEDED` | Vault ou base grande demais; ajustar limites em `scheduledTasksCron.js` |
| Sugestões duplicadas | Dedupe divergiu entre Dart e Node — rodar `npm test` |

---

## 7. Rollback

Cloud Functions não têm "desfazer". Para tirar do ar:

```bash
firebase functions:delete vigiaCron --project agendaclinica-457713 --region us-central1
```

Isso interrompe os ciclos futuros. **Não** remove o que já foi gravado —
relatórios e sugestões pendentes continuam nas telas, o que é o comportamento
desejado (nada executou; são leituras e propostas aguardando decisão).

Para uma pausa temporária sem apagar a função, desative o job no Cloud
Scheduler. Confirme o nome antes — o Firebase costuma usar o padrão
`firebase-schedule-<função>-<região>`, mas vale listar:

```bash
gcloud scheduler jobs list --project agendaclinica-457713 --location us-central1
gcloud scheduler jobs pause <nome-do-job> --project agendaclinica-457713 --location us-central1
```

---

## 8. Checklist

Antes de publicar qualquer função deste repositório:

- [ ] `npm test` em `functions/` está verde
- [ ] Índices publicados (`firebase deploy --only firestore:indexes`)
- [ ] Secrets usados pela função existem e estão atualizados
- [ ] O comando é **direcionado** (`--only functions:<nome>`), nunca `--only functions`
- [ ] Depois: `firebase functions:list` confirma a função no ar
- [ ] Depois: `firebase functions:log` na primeira execução esperada

---

## 9. Referências

| Documento | Assunto |
|---|---|
| [`cloud_functions.md`](cloud_functions.md) | Inventário de todas as functions do projeto |
| [`CUSTO.md`](CUSTO.md) | SOPs de custo: read meter, circuit breaker, escopo por tenant |
| [`TAREFAS_AGENDADAS.md`](TAREFAS_AGENDADAS.md) | Contrato de `tb_scheduled_tasks`, lock e execução |
| [`MCP.md`](MCP.md) | Servidor MCP e as ferramentas que o agente usa |
| [`obsidian/obsidian.md`](obsidian/obsidian.md) | O Cérebro — modelo, índice e grafo |
