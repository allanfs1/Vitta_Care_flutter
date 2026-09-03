# Vigia — Análise Diária e Rotinas de Prevenção

Especificação do ciclo que, uma vez por dia, lê o estado da clínica, escreve um
relatório para os gestores e **propõe** rotinas de prevenção que esperam
aprovação humana.

> **Coleções**: `tb_vigia_ciclos` (auditoria) · `tb_relatorio_ia` (saída) ·
> `tb_scheduled_tasks` (propostas) · `tb_cerebro_notas` (memória)
> **Telas**: `/relatorios` · `/tarefas-agendadas`
> **Fuso**: `America/Sao_Paulo` (BRT)

---

## 1. O problema que resolve

Uma clínica gera sinais o tempo todo — faltas concentradas num turno, uma fila
que cresce às quintas, um médico com overbooking recorrente. Esses sinais estão
todos no banco, e ninguém tem tempo de procurá-los todo dia.

O Vigia procura. E vai além de relatar: quando vê um padrão que **se repete**,
propõe uma rotina que ataca a causa. Mas propor não é agir — a decisão de ligar
uma automação continua sendo de uma pessoa.

---

## 2. A propriedade central

> **Uma rotina proposta pela IA nunca executa sozinha.**

Isto não é uma convenção de código nem uma checagem na UI. São **três travas
independentes**, cada uma suficiente sozinha:

| # | Trava | Onde |
|---|---|---|
| 1 | A sugestão é gravada **sem `nextRunAt`** — não existe horário para vencer | `ScheduledTasksService.criarSugestao` · `vigiaCron.js › gravarSugestoes` |
| 2 | `getDue` e `claimDue` só devolvem `status === "active"` | `scheduled_tasks_service.dart` |
| 3 | O cron do servidor filtra o mesmo status | `functions/scheduledTasksCron.js:118,132` |

E uma quarta defesa contra caminho lateral: **`setStatus` recusa promover uma
sugestão**. Ativar só por `aprovar()` — transacional, calcula o `nextRunAt` no
momento da decisão e grava `decididaPor`/`decididaEm`.

Coberto por `test/features/vigia_sugestoes_test.dart` e
`test/security/mcp_isolamento_clinica_test.dart`.

---

## 3. Arquitetura — o ciclo roda dos dois lados

```
    ┌──────────────── cliente (Dart) ────────────────┐
    │ AppShell agenda 20 s após o app abrir          │
    │ lib/features/ia/vigia/                         │
    └───────────────────────┬────────────────────────┘
                            │
              ┌─────────────▼─────────────┐
              │   tb_vigia_ciclos         │   trava diária compartilhada
              │   {clinicaId}_{YYYY-MM-DD}│   quem chegar primeiro faz
              └─────────────▲─────────────┘
                            │
    ┌───────────────────────┴────────────────────────┐
    │ onSchedule "0 6 * * *" (BRT)                   │
    │ functions/vigiaCron.js                         │
    └────────────────────────────────────────────────┘
```

**Por que dois lados.** O cliente cobre o uso normal (alguém abre o app todo
dia); o cron garante que um dia sem ninguém abrindo ainda tenha análise. A
trava em `tb_vigia_ciclos` — marcada em transação pelo cron, verificada pelo
cliente — impede ciclo duplo mesmo com vários dispositivos.

**O custo dessa escolha:** prompt, parser e dedupe existem em Dart **e** em
Node. Quando divergirem, **o Dart é a referência** — é onde a UI de aprovação
é desenvolvida. `functions/test/vigiaCron.test.js` fixa a chave de dedupe em
valor literal para a divergência quebrar o build.

---

## 4. O que o ciclo faz

### 4.1 Coleta

Antes de concluir qualquer coisa, o Vigia investiga com as **75** ferramentas MCP
(agendamentos, absenteísmo, overbooking, filas, pacientes de risco, equipe) e
**consulta o Cérebro** (`cerebro_buscar`, `cerebro_ler`).

O prompt instrui explicitamente a ler o Cérebro **antes** de propor: pode já
haver uma análise do mesmo padrão, uma decisão registrada que explica por que
algo é do jeito que é, ou uma rotina que já foi tentada e falhou. Repropor algo
que o Cérebro registra como fracassado é o pior erro possível.

Um retrato do Cérebro (contagens, notas mais referenciadas, notas recentes) vai
pronto no contexto, para o modelo não gastar chamadas de ferramenta
descobrindo o óbvio.

### 4.2 Saídas

| Saída | Onde | Observação |
|---|---|---|
| Relatório do dia | `tb_relatorio_ia` → `/relatorios` | Markdown + métricas rotuladas |
| Rotinas propostas | `tb_scheduled_tasks` (`suggested`) → `/tarefas-agendadas` | Máximo 3 por ciclo |
| Nota do ciclo | `tb_cerebro_notas` (`agente/vigia/YYYY-MM-DD.md`) | Memória para o ciclo seguinte |
| Notificação | feed de notificações | Só se houve relatório ou sugestão |

### 4.3 Contrato de saída do modelo

```jsonc
{
  "relatorio": {
    "titulo": "...", "periodo": "Últimas 24 horas",
    "corpo": "markdown",
    "metricas": [{ "label": "Absenteísmo", "valor": "18%" }]
  },
  "rotinas": [{
    "titulo": "...", "descricao": "...",
    "prompt": "instrução operacional que o agente executará",
    "kind": "action" | "report",
    "schedule": { "type": "daily", "time": "07:30" },
    "problemaDetectado": "...", "impactoEstimado": "...",
    "evidencias": ["...", "..."], "confianca": 0.82
  }],
  "notaCerebro": { "titulo": "...", "conteudo": "markdown com [[wikilinks]]" }
}
```

**O parser é defensivo de propósito.** Proposta sem título, sem prompt ou com
agendamento inválido é **descartada**, não exibida pela metade — o gestor
precisa poder confiar que todo card tem o necessário para decidir. Weekdays
inválidos são filtrados; confiança fora de `0..1` é contida, não rejeitada.

---

## 5. Anti-ruído

Rotina demais faz o gestor ignorar a seção inteira. Cinco limites — e nem
todos valem dos dois lados:

| Limite | Valor | Dart (cliente) | Node (cron) |
|---|---|---|---|
| Rotinas por ciclo | 3 | ✅ `tetoRotinas` | ✅ `TETO_ROTINAS` |
| Confiança mínima | 0.6 | ✅ `confiancaMinima` | ✅ `CONFIANCA_MINIMA` |
| Clínicas por execução | 8 | — (1 clínica por ciclo) | ✅ `MAX_CLINICAS` |
| Timeout do ciclo | 5 min / 540 s | ✅ `.timeout(5 min)` | ✅ `timeoutSeconds` |
| Leituras por ciclo | 1500 | ❌ **sem medidor** | ✅ `READ_BUDGET` via `cron._makeReadMeter()` |

> ⚠️ **O teto de leituras existe só no servidor.** `vigiaCron.js` reutiliza o
> medidor do `scheduledTasksCron` (`makeReadMeter`, `CUSTO.md` §6.8), que
> aborta com `READ_BUDGET_EXCEEDED` ao passar de 1500 leituras. O ciclo em
> Dart chama `servidor.callTool` **sem medidor e sem circuit breaker** — o
> único limite é o timeout de 5 min e as 6 rodadas do loop do agente.
>
> Na prática: um ciclo que o cron abortaria por custo roda até o fim no
> cliente. Registrado em [`ATENCAO.md`](ATENCAO.md).

Dedupe contra **ativas, pausadas, pendentes e recusadas**. O prompt diz
explicitamente que **lista vazia é resultado legítimo** — um dia sem sugestão
sinaliza estabilidade, não falha.

---

## 6. O ciclo de aprendizado

```
   propõe ──▶ humano recusa com motivo ──▶ motivo entra no contexto
      ▲                                              │
      └──────────────────────────────────────────────┘
              o ciclo seguinte não repropõe
```

Recusar **exige o motivo** na UI, e o texto não é burocracia: a lista de
recusadas com motivos vai no prompt do ciclo seguinte. É o que transforma uma
recusa em aprendizado em vez de atrito repetido.

A nota escrita no Cérebro fecha o outro lado: o ciclo de amanhã lê o que o de
hoje concluiu.

---

## 7. Auditoria — `tb_vigia_ciclos`

Documento por clínica/dia (`{clinicaId}_{YYYY-MM-DD}`):

```jsonc
{
  "executou": true,
  "motivo": "relatório=sim · 2 sugerida(s) · 1 descartada(s)",
  "relatorioId": "rel_vigia_...",
  "sugestoesCriadas": 2,
  "sugestoesDescartadas": 1,   // filtros locais: dedupe, confiança, malformada
  "notaCerebroId": "nt_...",
  "duracaoMs": 48210,
  "origem": "cron" | (cliente),
  "em": Timestamp
}
```

`sugestoesDescartadas` é sinal de calibração, não de erro: um Vigia que
descarta quase tudo está mal calibrado (ou o vault está saturado de rotinas).

**Falha não marca `executou: true`** — o próximo boot tenta de novo, para um dia
não ficar sem análise por causa de uma rede ruim.

---

## 8. Estrutura de arquivos

| Arquivo | Papel |
|---|---|
| `lib/features/ia/vigia/vigia_service.dart` | Orquestra o ciclo (cliente) |
| `lib/features/ia/vigia/vigia_prompt.dart` | System prompt + contrato JSON |
| `lib/features/ia/vigia/vigia_models.dart` | Parser defensivo das propostas |
| `lib/features/ia/vigia/vigia_providers.dart` | Estado e disparo |
| `lib/navigation/app_shell.dart` | Agenda o ciclo (`State` com `dispose` garantido) |
| `lib/features/tarefas_agendadas/widgets/card_sugestao_ia.dart` | UI de aprovação |
| `functions/vigiaCron.js` | Ciclo no servidor |
| `functions/test/vigiaCron.test.js` | 18 testes do parser/dedupe |
| `test/features/vigia_sugestoes_test.dart` | 13 testes das travas |

---

## 9. Armadilhas conhecidas

**Não agende o ciclo no construtor de um provider.** Um `Timer` criado ali
sobrevive ao fim da árvore de widgets (em teste vira "A Timer is still
pending"; em produção fica sem dono). O agendamento vive no `AppShell`, que é
um `State` com `dispose` garantido pelo Flutter.

**Clínica: use `clinicaResolvidaProvider`.** `selectedClinicIdProvider` vale o
placeholder de `MockData` (`'c1'`) durante o boot. O Vigia grava relatório e
sugestões com o **mesmo** `clinicaId` que a tela de tarefas lê
(`tarefasClinicaIdProvider`) — gravar numa e ler de outra faria a sugestão
simplesmente não aparecer.

**Não crie caminho lateral para `status: "active"`.** Ver §2.

---

## 10. Referências

| Documento | Assunto |
|---|---|
| [`TAREFAS_AGENDADAS.md`](TAREFAS_AGENDADAS.md) §3.1 | Schema da proposta e fluxo de aprovação |
| [`CLOUD_FUNCTION.md`](CLOUD_FUNCTION.md) §5 | Deploy do `vigiaCron` |
| [`MCP.md`](MCP.md) | As ferramentas que o Vigia usa |
| [`CUSTO.md`](CUSTO.md) §6 | Read budget e circuit breaker |
| [`obsidian/obsidian.md`](obsidian/obsidian.md) | O Cérebro |
| [`ATENCAO.md`](ATENCAO.md) | Estado do deploy e riscos abertos |
