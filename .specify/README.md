# Especificações do Vitta

Índice dos documentos desta pasta. Comece pelo que você precisa fazer, não pelo
nome do arquivo.

> **O Vitta é um app Flutter** (+ Cloud Functions do Firebase). Se um documento
> mencionar Next.js, `src/app/api/`, Vercel ou `/dashboard/*`, ele veio do
> projeto irmão `app_company` e está errado para este repositório — ver
> "Manutenção" no fim.

---

## Vou mexer em…

| O quê | Leia antes |
|---|---|
| Qualquer coisa (contexto geral) | [`AGENTS.md`](AGENTS.md) — módulos, responsabilidades, design system |
| Uma tela nova | [`AGENTS.md`](AGENTS.md) + a spec do módulo · [`Designer/`](Designer/) para o visual |
| A plataforma de I.A. (visão geral) | [`AgentAI.md`](AgentAI.md) — o que existe, o que é proposta, e o backlog |
| Ferramentas do agente de IA | [`MCP.md`](MCP.md) — §3.1 tem as regras de isolamento multi-tenant |
| O ciclo diário da IA | [`VIGIA.md`](VIGIA.md) |
| Tarefas agendadas / rotinas | [`TAREFAS_AGENDADAS.md`](TAREFAS_AGENDADAS.md) — §3.1 para o fluxo de aprovação da IA |
| Simulador / planejador por I.A. | [`SIMULADOR.md`](SIMULADOR.md) — a I.A. interpreta, nunca calcula nem aplica |
| Evidência científica / PubMed | [`EVIDENCIAS.md`](EVIDENCIAS.md) — §3.1 explica por que esta function exige login |
| O Cérebro (notas, grafo, busca) | [`obsidian/obsidian.md`](obsidian/obsidian.md) — 3.000 linhas, mas §13 é obrigatória antes de tocar no índice |
| Qualquer query nova no Firestore | [`CUSTO.md`](CUSTO.md) — SOPs obrigatórios · [`database.md`](database.md) para o schema |
| Cloud Functions | [`CLOUD_FUNCTION.md`](CLOUD_FUNCTION.md) — **leia a §2 antes de qualquer deploy** |
| WhatsApp | [`ZAPI.md`](ZAPI.md) |
| Totem / autoatendimento | [`update_data.md`](update_data.md) · [`NEW_FEATURE.md`](NEW_FEATURE.md) |

---

## Preciso saber…

| Pergunta | Documento |
|---|---|
| O que está pendente ou merece atenção? | [`ATENCAO.md`](ATENCAO.md) — **radar único**, mantido a cada sessão |
| Como está o banco? | [`database.md`](database.md) — parte automática + coleções do app Flutter no fim |
| Quais Cloud Functions existem? | [`cloud_functions.md`](cloud_functions.md) — inventário do projeto inteiro |
| Como publicar uma function? | [`CLOUD_FUNCTION.md`](CLOUD_FUNCTION.md) |
| Onde ficam as chaves de API? | [`AI_chaves.md`](AI_chaves.md) — **gitignored**; §1 diz quem lê cada segredo |
| Quais ferramentas o agente tem? | [`MCP.md`](MCP.md) §6 — 79 tools, com a coleção de cada uma |
| O que já foi auditado? | [`VARREDURA_QA_2026-07.md`](VARREDURA_QA_2026-07.md) · [`ANALISE_E_MELHORIAS.md`](ANALISE_E_MELHORIAS.md) |
| Como aplicar a otimização de custo? | [`EXEC_CUSTO.md`](EXEC_CUSTO.md) — runbook com comandos prontos |

---

## Regras que valem para o projeto inteiro

Quatro invariantes que aparecem em mais de uma spec porque quebrar qualquer uma
delas causa dano silencioso — o código roda, e o estrago só aparece depois:

**1. A clínica ativa vem de `clinicaResolvidaProvider`, nunca de
`selectedClinicIdProvider`.** Este último vale o placeholder de `MockData`
(`'c1'`) durante o boot; usá-lo como chave de dados grava documentos numa
clínica que não existe. Ver `MCP.md` §3.1.

**2. A IA nunca executa automação sozinha.** Rotinas propostas nascem
`suggested` e só rodam após aprovação humana. Ver `VIGIA.md` §2 e
`TAREFAS_AGENDADAS.md` §3.1.

**3. Deploy de Cloud Function é sempre direcionado.**
`firebase deploy --only functions` (sem nome) **apaga** as functions dos outros
codebases do projeto. Ver `CLOUD_FUNCTION.md` §2.

**4. Nenhum segredo de produção entra em arquivo versionado.** Segredo de
function vive no Secret Manager; segredo de build entra por `--dart-define`.
`AI_chaves.md` é gitignored justamente por isso. Ver `AI_chaves.md` §0.

---

## Manutenção destes documentos

- **Achou um risco?** Registre em [`ATENCAO.md`](ATENCAO.md) *antes* de
  corrigir — mesmo que a correção seja no mesmo turno. O valor do radar é
  listar o que existe, não só o que já foi resolvido.

- **Mudou comportamento?** Atualize a spec no mesmo commit. Uma spec que
  descreve o sistema errado é pior que spec nenhuma: alguém vai "consertar" o
  código para bater com ela. Já aconteceu duas vezes:
  - `MCP.md` documentava o fallback de clínica como correto depois de ele ter
    sido removido por ser furo de isolamento;
  - `TAREFAS_AGENDADAS.md` documentava `DEFAULT_CLINICA = JuhdNt7NG3GYOFKOKOXP`
    — **o mesmo valor removido** — como constante viva, contradizendo `MCP.md`
    na mesma pasta.

- **Trouxe doc de `app_company`?** Reescreva contra o código deste repositório
  **antes** de commitar, ou marque explicitamente que é spec de outro projeto.
  Em 2026-09-01, quatro documentos da plataforma de I.A. descreviam rotas
  Next.js que nunca existiram aqui. Cada um ganhou uma §0 de portabilidade
  mapeando "o que a spec antiga dizia → o que existe" — mantenha esse padrão.

- **Escrevendo sobre ferramenta ou requisito?** Marque o estado. `obsidian.md`
  listava 14 tools do Cérebro como registradas quando só 5 existiam; `AgentAI.md`
  listava RFs sem dizer quais viraram código. Ferramenta planejada documentada
  como pronta faz o agente gastar rodada pedindo tool inexistente.

- **`database.md` tem duas origens.** A maior parte é gerada automaticamente do
  Firestore; a seção final é escrita à mão a partir do código. Ao regerar,
  preserve a seção final.
