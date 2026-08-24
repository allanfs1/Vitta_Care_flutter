# 🧠 CÉREBRO VITTA — Segundo Cérebro (Obsidian Engine)

> **Especificação Técnica Ultra-Detalhada · v1.0**
> **Módulo**: `lib/features/cerebro/` · **Rota**: `/cerebro` · **Superfície**: `IaView.cerebro` dentro do dashboard `features/ia/`
> **Data**: 2026-08-19 · **Autor**: Agente Líder · **Status**: Especificação aprovada para implementação
> **Documentos relacionados**: [`AGENTS.md`](../AGENTS.md) · [`AgentAI.md`](../AgentAI.md) · [`MCP.md`](../MCP.md) · [`database.md`](../database.md) · [`AI_chaves.md`](../AI_chaves.md) · [`update_data.md`](../update_data.md)
> **Referências visuais**: `.specify/obsidian/img/{Sem título,2,3,4,5}.jpg`

---

## 📑 SUMÁRIO

| # | Seção | Conteúdo |
|---|-------|----------|
| 0 | [TL;DR](#0-tldr--o-que-estamos-construindo) | Resumo executivo |
| 1 | [Visão e Princípios](#1-visão-princípios-e-não-objetivos) | Por que, para quem, o que NÃO é |
| 2 | [Glossário](#2-glossário-canônico) | Vocabulário obrigatório do módulo |
| 3 | [Arquitetura Macro](#3-arquitetura-macro) | 7 camadas, fluxo de dados |
| 4 | [Modelo de Dados](#4-modelo-de-dados) | Firestore, índices, rules, cache |
| 5 | [VFM — Linguagem de Marcação](#5-vfm--vitta-flavored-markdown) | Gramática EBNF completa |
| 6 | [Motor de Parsing](#6-motor-de-parsing-e-indexação) | Tokenizer → AST → 6 índices |
| 7 | [Motor de Grafo](#7-motor-de-grafo) | Barnes-Hut, PageRank, Louvain, render |
| 8 | [Camada Semântica](#8-camada-semântica-ia) | Embeddings, vetores, sugestões |
| 9 | [Integração com o Agente](#9-integração-com-o-agente-mcp) | 14 tools, políticas, ciclo autônomo |
| 10 | [UI/UX e Layout](#10-uiux--especificação-de-interface) | Wireframes derivados das 5 imagens |
| 11 | [Estrutura de Arquivos](#11-estrutura-de-arquivos-flutter) | Árvore completa de arquivos |
| 12 | [Providers Riverpod](#12-mapa-de-estado-riverpod) | Grafo de dependência de estado |
| 13 | [Performance](#13-orçamentos-de-performance) | Budgets, estratégias, benchmarks |
| 14 | [Segurança e LGPD](#14-segurança-multi-tenant-e-lgpd) | Isolamento, redação, esquecimento |
| 15 | [Telemetria](#15-telemetria-e-métricas-de-produto) | Eventos, KPIs, north star |
| 16 | [Roadmap](#16-plano-de-implementação-por-fases) | 6 fases, backlog de tarefas |
| 17 | [Critérios de Aceite](#17-critérios-de-aceite-gherkin) | Gherkin PT-BR |
| 18 | [Plano de Testes](#18-plano-de-testes) | Unit/widget/golden/integration/perf |
| 19 | [Riscos](#19-riscos-e-mitigações) | Matriz risco × mitigação |
| 20 | [Anexos](#20-anexos) | Seeds, mapeamento imagem→tela, exemplos |

---

## 0. TL;DR — O que estamos construindo

Estamos transformando o **chat de IA** (`features/ia/`) em um **Segundo Cérebro navegável**: um *vault* de conhecimento no estilo Obsidian, onde **notas markdown** e **entidades operacionais da clínica** (pacientes, médicos, agendamentos, alertas, relatórios) vivem no **mesmo grafo**, ligados por wikilinks explícitos e por proximidade semântica calculada por IA.

O salto conceitual:

| | Hoje (`features/ia/`) | Cérebro Vitta |
|---|---|---|
| **Memória** | Histórico linear de chat (`tb_ia_chats`) | Grafo persistente, versionado, navegável |
| **Contexto** | Recuperado por tool call a cada pergunta | Pré-indexado, com backlinks e vizinhança semântica |
| **Saída da IA** | Texto efêmero na conversa | Nota permanente, linkada, que vira contexto futuro |
| **Descoberta** | Zero — o usuário precisa saber o que perguntar | O grafo revela conexões que ninguém procurou |
| **Aprendizado** | Nenhum entre sessões | Consolidação noturna: o cérebro fica mais denso a cada dia |

**Regra de ouro do módulo:** *toda saída relevante do agente vira nó do grafo; todo nó do grafo é contexto recuperável pelo agente.* O ciclo se fecha — é isso que leva a inteligência a outro nível.

**Não é** um app de notas pessoais. É a **memória institucional viva da clínica**, editável por humanos e por agentes, com auditoria completa e conformidade LGPD.

---

## 1. Visão, Princípios e Não-Objetivos

### 1.1 Visão

> Em 12 meses, quando um gestor perguntar *"por que o absenteísmo da Dra. Helena subiu em março?"*, o Cérebro Vitta não vai **calcular** a resposta — ele vai **lembrar** dela: a nota de análise que o agente escreveu em 12/03, ligada ao alerta de overbooking de 08/03, ligada ao MOC "Absenteísmo · Q1", ligada às 14 consultas afetadas e à mudança de horário registrada no perfil da médica.

### 1.2 Princípios de Design (invioláveis)

| # | Princípio | Consequência prática |
|---|-----------|----------------------|
| **P1** | **Markdown é a fonte da verdade** | Nenhuma feature pode exigir formato proprietário. Um vault exportado como `.md` + `.json` deve reabrir no Obsidian real com alta fidelidade. |
| **P2** | **Links são baratos, hierarquia é cara** | Priorizar wikilinks e tags sobre pastas. Pastas existem, mas são organização secundária. |
| **P3** | **O grafo é a interface, não o enfeite** | O grafo precisa ser *usável* para navegar (clicar, focar, filtrar), não só bonito. |
| **P4** | **Entidades operacionais são cidadãs de primeira classe** | `[[@paciente:pac_123]]` é tão nó quanto `[[Protocolo de Confirmação]]`. |
| **P5** | **Escrita do agente é auditável e reversível** | Toda escrita da IA grava evento em `tb_cerebro_eventos` + versão anterior. Desfazer funciona contra a IA. |
| **P6** | **Local-first no runtime** | Índices (backlinks, tags, trigramas) vivem em memória. Firestore é sincronização, não caminho crítico de leitura. |
| **P7** | **Dado sensível nunca é copiado, é referenciado** | Nome/CPF de paciente jamais é materializado no corpo da nota. Só o `entityRef`, resolvido em render com checagem de permissão. |
| **P8** | **Degradação graciosa** | Sem embeddings → busca textual. Sem grafo → lista. Sem rede → cache local read-only. Nunca tela branca. |

### 1.3 Não-Objetivos (v1.0)

- ❌ Sincronização com vault Obsidian real via filesystem (só import/export manual `.zip`).
- ❌ Plugins de terceiros / sandbox de execução de JS.
- ❌ Edição colaborativa simultânea em tempo real (CRDT). v1 usa *last-write-wins* com detecção de conflito e merge assistido.
- ❌ Publicação pública de notas (equivalente a Obsidian Publish).
- ❌ Canvas com vídeo/áudio embutido.
- ❌ Anotação de PDF.

---

## 2. Glossário Canônico

> Todo código, comentário e commit **deve** usar estes termos. Divergência = revisão rejeitada.

| Termo | Definição | Classe Dart |
|-------|-----------|-------------|
| **Vault** | Conjunto de todas as notas de uma clínica (`clinicaId`). Unidade de isolamento multi-tenant. | `Vault` |
| **Nota** | Documento markdown com frontmatter. Unidade atômica de conhecimento. | `Nota` |
| **Nota Virtual** | Nó do grafo projetado de dado operacional (paciente/médico/consulta). Não existe em `tb_cerebro_notas`. | `NotaVirtual` |
| **Path** | Identificador humano da nota, único no vault: `mocs/absenteismo.md`. | `String` |
| **Wikilink** | Referência `[[destino]]`. Aresta explícita do grafo. | `WikiLink` |
| **Entity-link** | Wikilink para entidade operacional: `[[@medico:med_44]]`. | `EntityLink` |
| **Backlink** | Aresta inversa: notas que apontam para esta. | `Backlink` |
| **Menção não-vinculada** | Ocorrência textual do título/alias sem `[[ ]]`. Candidata a link. | `MencaoNaoVinculada` |
| **Vizinho semântico** | Nota próxima no espaço vetorial, sem link explícito. | `VizinhoSemantico` |
| **MOC** | *Map of Content* — nota-índice curadora de um domínio. Nó-hub do grafo. | `NotaTipo.moc` |
| **Nota Diária** | Nota automática `diario/2026-08-19.md`. Âncora temporal do vault. | `NotaTipo.diario` |
| **Órfã** | Nota com `inDegree == 0 && outDegree == 0`. | — |
| **Ilha** | Componente conexo desconectado do componente gigante. | `Ilha` |
| **Cluster** | Comunidade detectada por Louvain. Define cor no grafo. | `Cluster` |
| **Grafo Local** | Subgrafo em raio *N* saltos a partir de um nó focal. | `GrafoLocal` |
| **Grafo Global** | Vault inteiro (com filtros). | `GrafoGlobal` |
| **Grupo** | Regra `query → cor` de colorização manual (estilo Obsidian *Groups*). | `GrupoGrafo` |
| **Canvas** | Quadro infinito com cartões e setas. | `CanvasBoard` |
| **Consolidação** | Rotina noturna que sintetiza eventos do dia em notas. | `ConsolidacaoService` |
| **VFM** | *Vitta-Flavored Markdown* — dialeto definido na §5. | — |

---

## 3. Arquitetura Macro

### 3.1 As 7 camadas

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  L7 · APRESENTAÇÃO            features/cerebro/ui/                            │
│      Explorer · Editor · Grafo · Analítico · Backlinks · Canvas · Palette     │
├──────────────────────────────────────────────────────────────────────────────┤
│  L6 · ESTADO (Riverpod)       features/cerebro/providers/                     │
│      vaultProvider · notaProvider · grafoProvider · buscaProvider · …         │
├──────────────────────────────────────────────────────────────────────────────┤
│  L5 · AGENTE                  features/cerebro/agent/                         │
│      14 tools MCP · políticas de escrita · ciclo autônomo · consolidação      │
├──────────────────────────────────────────────────────────────────────────────┤
│  L4 · SEMÂNTICA               features/cerebro/semantic/                      │
│      chunking · embeddings · vector store · KNN · sugestões · RAG             │
├──────────────────────────────────────────────────────────────────────────────┤
│  L3 · GRAFO                   features/cerebro/graph/                         │
│      força (Barnes-Hut) · PageRank · Louvain · LOD · painter · hit-test       │
├──────────────────────────────────────────────────────────────────────────────┤
│  L2 · ÍNDICE                  features/cerebro/index/                         │
│      parser VFM · AST · forward/backlink · tags · trigram · alias · headings  │
├──────────────────────────────────────────────────────────────────────────────┤
│  L1 · PERSISTÊNCIA            features/cerebro/data/                          │
│      Firestore repos · cache local · sync · versionamento · conflitos         │
└──────────────────────────────────────────────────────────────────────────────┘
                                     ↕
      ┌──────────────────────────────────────────────────────────────┐
      │  PONTE OPERACIONAL  ·  features/cerebro/bridge/               │
      │  Projeta tb_agendamentos / tb_medicos / tb_pacientes /        │
      │  tb_absenteismo_scores / tb_overbooking_events em NotaVirtual │
      └──────────────────────────────────────────────────────────────┘
```

**Regra de dependência:** camada `Ln` só pode importar de `Ln-1` ou inferior. `L7` nunca importa `L1` direto — sempre via `L6`. Violação quebra o teste `test/cerebro/arquitetura_test.dart`.

### 3.2 Fluxo de dados — do teclado ao grafo

```
  Usuário digita "[[Prot"
        │
        ▼
  ┌──────────────────┐   debounce 120ms
  │ EditorController │──────────────────┐
  └────────┬─────────┘                  │
           │ texto completo             ▼
           │ (debounce 400ms)   ┌────────────────────┐
           ▼                    │ AutocompleteEngine │──▶ popup [[…]]
  ┌──────────────────┐          │ (alias map+trigram)│    (≤16ms)
  │  ParserVFM       │          └────────────────────┘
  │  texto → AST     │
  └────────┬─────────┘
           │ AST
           ▼
  ┌──────────────────┐   diff de arestas
  │  IndexadorVault  │──────────────────┐
  │  atualiza 6 índ. │                  ▼
  └────────┬─────────┘        ┌──────────────────────┐
           │                  │  GrafoEngine         │
           │                  │  patch incremental   │
           │                  │  + reaquece α=0.3    │
           │                  └──────────┬───────────┘
           │                             │ 60fps
           │                             ▼
           │                  ┌──────────────────────┐
           │                  │  GrafoPainter        │
           │                  └──────────────────────┘
           │
           │ (autosave 2s idle | 10s máx)
           ▼
  ┌──────────────────┐        ┌──────────────────────┐
  │  NotaRepository  │───────▶│  Firestore           │
  │  (otimista+fila) │        │  tb_cerebro_notas    │
  └────────┬─────────┘        └──────────────────────┘
           │
           │ (fila background, ≤5min)
           ▼
  ┌──────────────────┐        ┌──────────────────────┐
  │ EmbeddingQueue   │───────▶│ CF: embedText        │
  └──────────────────┘        │ tb_cerebro_vetores   │
                              └──────────────────────┘
```

**Latências alvo** (P95, desktop, vault de 2.000 notas):

| Etapa | Budget |
|-------|--------|
| Keystroke → caractere na tela | ≤ 16 ms |
| Keystroke → popup de autocomplete | ≤ 60 ms |
| Salvar → AST + índices atualizados | ≤ 45 ms |
| Índices → grafo repintado | ≤ 16 ms |
| Abrir nota (cache quente) | ≤ 80 ms |
| Abrir nota (cache frio, Firestore) | ≤ 400 ms |
| Busca textual (trigrama) | ≤ 30 ms |
| Busca semântica (KNN k=20) | ≤ 900 ms |
| Grafo global 2.000 nós — 1º layout estável | ≤ 2,5 s |

### 3.3 Contrato com os módulos existentes

| Módulo existente | Relação com o Cérebro | Direção |
|---|---|---|
| `features/ia/` | Hospeda o Cérebro como `IaView.cerebro`; compartilha `AiAgentService`, sidebars e tema | bidirecional |
| `core/modules/mcp/` | Registra as tools `cerebro_*` no `McpServer` | Cérebro → MCP |
| `features/absenteismo/` | Scores viram `NotaVirtual` tipo `risco`; alertas geram notas | leitura |
| `features/overbooking/` | Eventos de realocação viram entradas na nota diária | leitura |
| `features/agendamentos/` | Consultas viram `NotaVirtual` tipo `consulta` | leitura |
| `features/equipe_medica/` | Médicos viram `NotaVirtual` tipo `medico` | leitura |
| `features/relatorios/` | Relatório salvo pode ser "fixado" como nota permanente | escrita |
| `features/notificacoes_centro/` | Sugestões do cérebro viram notificações | escrita |
| `core/widgets/command_palette.dart` | Reutilizado e estendido com comandos do cérebro | extensão |

---

## 4. Modelo de Dados

### 4.1 Coleções Firestore

Todas seguem o padrão do projeto (`tb_` + snake_case, ver [`database.md`](../database.md)).

| Coleção | Propósito | Volume esperado (clínica média/ano) |
|---|---|---|
| `tb_cerebro_notas` | Notas (documento markdown + metadados) | 3.000–15.000 |
| `tb_cerebro_notas/{id}/versoes` | Histórico de versões (subcoleção) | 10× notas |
| `tb_cerebro_links` | Índice de arestas desnormalizado | 5× notas |
| `tb_cerebro_tags` | Agregados por tag | 100–800 |
| `tb_cerebro_vetores` | Chunks + embeddings | 4× notas |
| `tb_cerebro_canvas` | Quadros de canvas | 20–200 |
| `tb_cerebro_eventos` | Log de auditoria (escritas do agente) | 20.000+ |
| `tb_cerebro_sugestoes` | Sugestões pendentes de link/tag/merge | 500–3.000 |
| `tb_cerebro_config` | Configuração do vault por clínica | 1 por clínica |
| `tb_cerebro_snapshots` | Layout e métricas de grafo pré-computados | 1 por clínica/dia |

### 4.2 `tb_cerebro_notas` — documento canônico

```jsonc
{
  // ── Identidade ────────────────────────────────────────────────────────────
  "id": "nt_7f3a91c2",                  // doc id, prefixo nt_
  "clinicaId": "cl_001",                // 🔒 chave de isolamento multi-tenant
  "path": "mocs/absenteismo.md",        // único por clínica; case-insensitive
  "titulo": "Absenteísmo — MOC",        // H1 ou derivado do filename
  "aliases": ["Faltas", "No-show MOC"], // resolvem [[Faltas]] para esta nota

  // ── Classificação ─────────────────────────────────────────────────────────
  "tipo": "moc",                        // ver enum NotaTipo §4.3
  "tags": ["moc", "operacao/absenteismo", "q1"],  // hierárquicas com "/"
  "icone": "hub",                       // nome de Icons.* (Material)
  "cor": "#F43F5E",                     // sobrescreve cor do cluster no grafo

  // ── Conteúdo ──────────────────────────────────────────────────────────────
  "conteudo": "# Absenteísmo — MOC\n\nlinks: [[Operação]]…",  // markdown bruto
  "conteudoRef": null,                  // se > 900KB: gs:// path no Storage
  "frontmatter": {                      // YAML parseado (chaves livres)
    "status": "vivo",
    "revisar_em": "2026-09-01",
    "responsavel": "med_44"
  },

  // ── Índice derivado (gravado pelo cliente ao salvar; recalculável) ─────────
  "outLinks": ["nt_a1", "nt_b2", "@medico:med_44"],   // destinos resolvidos
  "outLinksNaoResolvidos": ["Protocolo X"],            // links quebrados
  "entityRefs": [                                      // ponte operacional
    { "tipo": "medico",  "id": "med_44" },
    { "tipo": "paciente","id": "pac_812" }
  ],
  "headings": [
    { "nivel": 1, "texto": "Absenteísmo — MOC", "slug": "absenteismo-moc", "linha": 1 },
    { "nivel": 2, "texto": "Diagnóstico",       "slug": "diagnostico",     "linha": 14 }
  ],
  "blocos": { "^resumo-q1": 22, "^decisao-mar": 47 },  // blockId → linha
  "wordCount": 842,
  "charCount": 5219,
  "tempoLeituraSeg": 202,               // wordCount / 250 wpm * 60

  // ── Métricas de grafo (escritas pela rotina noturna) ──────────────────────
  "metrics": {
    "inDegree": 27, "outDegree": 12,
    "pagerank": 0.0184,                 // normalizado, soma 1.0 no vault
    "cluster": 3,                       // id da comunidade Louvain
    "centralidadeIntermediacao": 0.0072,
    "orfa": false
  },

  // ── Estado e proveniência ─────────────────────────────────────────────────
  "origem": "agente",                   // humano | agente | sistema | importado
  "agenteId": "agt_absenteismo",        // null se origem == humano
  "confianca": 0.86,                    // 0..1, só para origem == agente
  "revisadoPor": "usr_12",              // null enquanto não revisado
  "revisadoEm": "2026-08-19T14:02:00Z",
  "estado": "publicada",                // rascunho | publicada | arquivada
  "sensivel": false,                    // 🔒 §14: exclui de export/embedding
  "fixada": true,                       // pin no explorer
  "favorita": false,

  // ── Versionamento e sync ──────────────────────────────────────────────────
  "versao": 14,
  "hash": "sha1:9f2c…",                 // do campo conteudo; detecta conflito
  "embeddingVersao": 3,                 // se < versao → reindexar vetores
  "createdAt":  "2026-03-12T09:14:00Z",
  "createdBy":  "agt_absenteismo",
  "updatedAt":  "2026-08-19T14:02:00Z",
  "updatedBy":  "usr_12",
  "deletedAt":  null                    // soft delete; purga em 30d
}
```

**Limite de 1 MB do Firestore.** Notas com `conteudo` acima de **900.000 bytes** têm o corpo movido para Cloud Storage (`gs://.../cerebro/{clinicaId}/{id}.md`) e o campo `conteudo` vira `null` com `conteudoRef` preenchido. O `NotaRepository` faz isso de forma transparente. Limite duro de UI: aviso amarelo a partir de 400 KB.

### 4.3 Enums

```dart
enum NotaTipo {
  nota,        // padrão
  moc,         // Map of Content — hub curatorial
  diario,      // diario/YYYY-MM-DD.md
  conceito,    // definição atômica (zettel)
  protocolo,   // procedimento operacional da clínica
  analise,     // saída analítica do agente
  relatorio,   // relatório fixado de features/relatorios
  reuniao,     // ata
  decisao,     // registro de decisão (ADR clínico)
  pessoa,      // nota sobre pessoa da equipe (não-paciente)
  fonte,       // referência externa (artigo, norma, RN ANS)
  template,    // modelo reutilizável
  canvas,      // ponteiro para tb_cerebro_canvas
  memoria,     // memória consolidada do agente
}

enum EntidadeTipo {
  paciente, medico, agendamento, clinica, alerta,
  score, overbookingEvent, tarefa, conversa, avaliacao,
}

enum NotaOrigem { humano, agente, sistema, importado }
enum NotaEstado { rascunho, publicada, arquivada }
enum LinkTipo { wiki, embed, entidade, tag, semantico, hierarquico }
```

### 4.4 `tb_cerebro_links` — índice de arestas

Desnormalizado para permitir *backlinks* por query direta sem varrer o vault inteiro (essencial acima de ~2.000 notas, quando o índice em memória deixa de caber confortavelmente no cliente web).

```jsonc
{
  "id": "lk_...",
  "clinicaId": "cl_001",
  "de":   "nt_7f3a91c2",         // origem (sempre nota real)
  "para": "nt_a1b2c3d4",         // destino: nt_* | @tipo:id | tag:nome
  "tipo": "wiki",                // LinkTipo
  "alias": "as faltas de março", // texto exibido, se houver |
  "ancora": "diagnostico",       // #heading
  "bloco": null,                 // ^blockId
  "linha": 34,                   // posição na origem, p/ preview do backlink
  "contexto": "…impacto direto sobre [[Absenteísmo]] em março…", // ±120 chars
  "peso": 1.0,                   // n de ocorrências; embeds valem 2.0
  "criadoEm": "2026-08-19T14:02:00Z"
}
```

**Consistência:** ao salvar uma nota, o cliente calcula o *diff* de arestas (`adicionadas`, `removidas`) e aplica em `WriteBatch` junto com o documento da nota. Batch máximo de 500 operações — notas com mais de ~480 links novos são divididas em lotes sequenciais.

### 4.5 `tb_cerebro_vetores` — chunks semânticos

```jsonc
{
  "id": "vc_...",
  "clinicaId": "cl_001",
  "notaId": "nt_7f3a91c2",
  "chunkIndex": 2,
  "texto": "…trecho de até 512 tokens…",
  "headingPath": ["Absenteísmo — MOC", "Diagnóstico", "Segundas-feiras"],
  "linhaInicio": 30, "linhaFim": 58,
  "embedding": [0.0123, -0.0456, /* … 768 floats … */],   // Firestore VectorValue
  "modelo": "text-embedding-3-large@768",
  "versao": 3,
  "tokens": 487,
  "criadoEm": "2026-08-19T14:05:00Z"
}
```

**Dimensionalidade.** `text-embedding-3-large` produz 3072 dims. Usamos truncamento *Matryoshka* para **768 dims** + renormalização L2 — perda de recall < 2%, redução de 4× em custo de storage e de latência de KNN. Constante única em `SemanticConfig.dims = 768`.

**Índice vetorial** (criar uma vez por projeto):

```bash
gcloud firestore indexes composite create \
  --collection-group=tb_cerebro_vetores \
  --query-scope=COLLECTION \
  --field-config=field-path=clinicaId,order=ASCENDING \
  --field-config=field-path=embedding,vector-config='{"dimension":768,"flat":{}}'
```

Consulta (cloud_firestore ≥ 5.5):

```dart
final snap = await FirebaseFirestore.instance
    .collection('tb_cerebro_vetores')
    .where('clinicaId', isEqualTo: clinicaId)
    .findNearest(
      vectorField: 'embedding',
      queryVector: VectorValue(consulta),
      limit: k,
      distanceMeasure: DistanceMeasure.cosine,
      distanceResultField: 'dist',
    )
    .get();
```

**Fallback obrigatório** (se o índice vetorial não existir ou a query falhar): `VectorStoreLocal` mantém em memória os vetores quantizados em `Int8List` (escala por chunk) e faz cosseno por força bruta. Para 8.000 chunks × 768 dims int8 = ~6 MB de RAM e ~12 ms de varredura — perfeitamente viável.

### 4.6 Demais coleções (resumo de campos)

```jsonc
// tb_cerebro_tags — agregado mantido por Cloud Function onWrite
{ "id":"tg_operacao_absenteismo", "clinicaId":"cl_001",
  "nome":"operacao/absenteismo", "pai":"operacao",
  "contagem":42, "cor":"#C77700", "descricao":"…", "atualizadoEm":"…" }

// tb_cerebro_sugestoes — fila de curadoria (§8.3)
{ "id":"sg_…", "clinicaId":"cl_001",
  "tipo":"link|tag|merge|mocSplit|orfa|desatualizada",
  "origem":"nt_a", "destino":"nt_b",
  "score":0.87, "justificativa":"Ambas descrevem o protocolo de confirmação 48h.",
  "trechoOrigem":"…", "trechoDestino":"…",
  "estado":"pendente|aceita|rejeitada|expirada",
  "decididoPor":null, "decididoEm":null,
  "criadoEm":"…", "expiraEm":"…" }   // TTL 30 dias

// tb_cerebro_eventos — auditoria imutável (§14.4)
{ "id":"ev_…", "clinicaId":"cl_001", "notaId":"nt_…",
  "acao":"criar|editar|mover|arquivar|excluir|linkar|reverter",
  "ator":"agt_absenteismo|usr_12|sistema", "atorTipo":"agente|humano|sistema",
  "versaoAntes":13, "versaoDepois":14,
  "diff":"@@ -12,3 +12,7 @@…",       // unified diff, máx 20KB
  "motivo":"Consolidação noturna 2026-08-19",
  "toolCallId":"call_abc",           // rastreia até a chamada MCP
  "criadoEm":"…" }

// tb_cerebro_canvas
{ "id":"cv_…", "clinicaId":"cl_001", "titulo":"Plano Q4",
  "nos":[ {"id":"n1","tipo":"nota|texto|grupo|entidade|imagem",
           "ref":"nt_…","x":120,"y":80,"w":320,"h":180,
           "cor":"#7C3AED","texto":"…","colapsado":false} ],
  "arestas":[ {"id":"e1","de":"n1","ladoDe":"direita",
               "para":"n2","ladoPara":"esquerda",
               "rotulo":"causa","estilo":"solida|tracejada","cor":"#F43F5E"} ],
  "viewport":{"x":0,"y":0,"zoom":1.0},
  "criadoEm":"…","atualizadoEm":"…" }

// tb_cerebro_config — 1 doc por clínica
{ "id":"cl_001", "clinicaId":"cl_001",
  "pastaDiario":"diario", "formatoDiario":"yyyy-MM-dd",
  "pastaTemplates":"templates", "pastaAnexos":"anexos",
  "pastaAgente":"agente",
  "gruposGrafo":[ {"query":"tag:#moc","cor":"#F43F5E","nome":"MOCs"} ],
  "autoLinkLimiar":0.82, "autoTagLimiar":0.78,
  "consolidacaoAtiva":true, "consolidacaoHora":"02:30",
  "escritaAgenteRequerAprovacao":true,
  "embeddingsAtivos":true, "maxNotasGrafo":3000 }

// tb_cerebro_snapshots — layout/métricas pré-computados (§7.6)
{ "id":"sn_cl_001_2026-08-19", "clinicaId":"cl_001",
  "posicoes":"<base64 Float32List: [id_idx,x,y]*>",
  "idsOrdenados":["nt_a","nt_b", "…"],
  "clusters":{"nt_a":3,"nt_b":1},
  "pagerank":{"nt_a":0.018},
  "nNos":2140,"nArestas":8921,"componentes":7,
  "geradoEm":"2026-08-19T02:52:00Z" }
```

### 4.7 Índices compostos necessários

| Coleção | Campos | Uso |
|---|---|---|
| `tb_cerebro_notas` | `clinicaId ASC, deletedAt ASC, updatedAt DESC` | Explorer "recentes" |
| `tb_cerebro_notas` | `clinicaId ASC, tipo ASC, updatedAt DESC` | Filtro por tipo |
| `tb_cerebro_notas` | `clinicaId ASC, tags ARRAY, updatedAt DESC` | Painel de tags |
| `tb_cerebro_notas` | `clinicaId ASC, path ASC` | Resolução de link por path |
| `tb_cerebro_notas` | `clinicaId ASC, estado ASC, origem ASC` | Fila de revisão da IA |
| `tb_cerebro_links` | `clinicaId ASC, para ASC, criadoEm DESC` | **Backlinks** (crítico) |
| `tb_cerebro_links` | `clinicaId ASC, de ASC` | Forward links / limpeza |
| `tb_cerebro_vetores` | `clinicaId ASC, embedding VECTOR<768>` | KNN |
| `tb_cerebro_vetores` | `clinicaId ASC, notaId ASC, chunkIndex ASC` | Reindexação |
| `tb_cerebro_sugestoes` | `clinicaId ASC, estado ASC, score DESC` | Fila de curadoria |
| `tb_cerebro_eventos` | `clinicaId ASC, notaId ASC, criadoEm DESC` | Histórico da nota |

### 4.8 Regras de segurança (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {

    function auth_()      { return request.auth; }
    function uid()        { return request.auth.uid; }
    function claims()     { return request.auth.token; }
    function minhaClinica(c) { return auth_() != null && claims().clinicaId == c; }
    function papel()      { return claims().papel; }  // admin|gestor|recepcao|medico
    function podeEscrever() { return papel() in ['admin','gestor']; }
    function podeLerSensivel() { return papel() in ['admin','gestor','medico']; }

    match /tb_cerebro_notas/{notaId} {
      allow read: if minhaClinica(resource.data.clinicaId)
                  && (resource.data.sensivel != true || podeLerSensivel());

      allow create: if minhaClinica(request.resource.data.clinicaId)
                    && podeEscrever()
                    && request.resource.data.versao == 1
                    && request.resource.data.path is string
                    && request.resource.data.path.size() <= 240
                    && request.resource.data.conteudo.size() < 900000;

      allow update: if minhaClinica(resource.data.clinicaId)
                    && podeEscrever()
                    // versão é monotônica: bloqueia sobrescrita cega
                    && request.resource.data.versao == resource.data.versao + 1
                    // clinicaId e createdAt são imutáveis
                    && request.resource.data.clinicaId == resource.data.clinicaId
                    && request.resource.data.createdAt == resource.data.createdAt;

      // Exclusão real só via Cloud Function (purga LGPD). Cliente só faz soft delete.
      allow delete: if false;

      match /versoes/{v} {
        allow read:   if minhaClinica(get(/databases/$(db)/documents/tb_cerebro_notas/$(notaId)).data.clinicaId);
        allow write:  if false;      // escrito só por Cloud Function
      }
    }

    match /tb_cerebro_links/{linkId} {
      allow read:  if minhaClinica(resource.data.clinicaId);
      allow write: if minhaClinica(request.resource.data.clinicaId) && podeEscrever();
    }

    match /tb_cerebro_vetores/{vecId} {
      allow read:  if minhaClinica(resource.data.clinicaId);
      allow write: if false;         // só Cloud Function (custo de embedding)
    }

    match /tb_cerebro_eventos/{evId} {
      allow read:   if minhaClinica(resource.data.clinicaId) && papel() in ['admin','gestor'];
      allow create: if minhaClinica(request.resource.data.clinicaId);
      allow update, delete: if false;   // 🔒 auditoria imutável
    }

    match /tb_cerebro_sugestoes/{sgId} {
      allow read:   if minhaClinica(resource.data.clinicaId);
      allow update: if minhaClinica(resource.data.clinicaId) && podeEscrever()
                    && request.resource.data.diff(resource.data).affectedKeys()
                       .hasOnly(['estado','decididoPor','decididoEm']);
      allow create, delete: if false;   // só Cloud Function
    }

    match /tb_cerebro_config/{clinicaId} {
      allow read:  if minhaClinica(clinicaId);
      allow write: if minhaClinica(clinicaId) && papel() == 'admin';
    }

    match /tb_cerebro_canvas/{cvId} {
      allow read:  if minhaClinica(resource.data.clinicaId);
      allow write: if minhaClinica(request.resource.data.clinicaId) && podeEscrever();
    }

    match /tb_cerebro_snapshots/{snId} {
      allow read:  if minhaClinica(resource.data.clinicaId);
      allow write: if false;
    }
  }
}
```

> ⚠️ A regra `versao == resource.data.versao + 1` é o mecanismo de **detecção de conflito no servidor**. Duas abas salvando a mesma nota: a segunda escrita falha com `permission-denied`, o cliente recarrega e entra no fluxo de merge (§4.10).

### 4.9 Cache local e offline

```dart
/// Cache em três níveis.
///  N1  memória     — LRU de 300 Notas parseadas (AST incluso). ~40 MB máx.
///  N2  persistente — Firestore offline persistence (IndexedDB no web,
///                    SQLite no desktop/mobile) — ligado em main.dart.
///  N3  índice      — 6 índices reconstruídos no boot a partir de N2,
///                    em isolate (mobile/desktop) ou em fatias de 8ms (web).
```

**Boot do vault** (`VaultBootstrapper`):

1. `t=0ms` — Renderiza *shell* (explorer skeleton, editor vazio). **Nunca** bloqueia a UI.
2. `t≈50ms` — Lê snapshot mais recente de `tb_cerebro_snapshots` (posições + clusters) → grafo já aparece "montado", sem simulação.
3. `t≈120ms` — Query paginada em `tb_cerebro_notas` (`limit 500`, ordenado por `updatedAt DESC`), campos projetados **sem** `conteudo` (usa `select()` via REST ou documentos leves espelhados — ver nota abaixo).
4. `t≈400ms` — Índices de link/tag/alias prontos (usam só metadados). Backlinks funcionais.
5. `t≈1.2s` — Trigramas construídos sob demanda: só ao primeiro uso da busca textual.
6. Lazy — `conteudo` carregado apenas quando a nota é aberta ou precisa de preview.

> **Nota de implementação:** o SDK `cloud_firestore` não expõe *field masks*. Para evitar baixar 15 MB de markdown no boot, mantemos o espelho leve `tb_cerebro_notas_meta/{id}` (mesmos campos **exceto** `conteudo`/`frontmatter` completos), escrito pela mesma Cloud Function `onWrite`. O boot lê o espelho; o corpo vem sob demanda do documento principal.

### 4.10 Conflitos e versionamento

**Detecção:** `versao` monotônica (regra de segurança) + `hash` SHA-1 do conteúdo.

**Resolução** (`ConflitoResolver`):

| Caso | Estratégia |
|---|---|
| Edições em **parágrafos distintos** | *Auto-merge* por diff de 3 vias (base = última versão comum). Silencioso, com toast "mesclado automaticamente". |
| Edições na **mesma linha** | Abre `ConflitoDialog` com 3 painéis (Seu / Base / Deles) + botão "Mesclar com IA". |
| Conflito **humano × agente** | **Humano sempre vence.** A versão do agente vira sugestão em `tb_cerebro_sugestoes` (tipo `merge`). |
| Conflito **agente × agente** | Vence maior `confianca`; empate → maior `versao`; persiste empate → rascunho para revisão. |

**Retenção de versões:** todas as versões dos últimos 30 dias + 1 por dia nos 12 meses seguintes + 1 por mês para sempre (política *tiered*, aplicada por Cloud Function semanal).

---

## 5. VFM — Vitta-Flavored Markdown

Superconjunto de CommonMark + GFM, compatível com Obsidian, mais 4 extensões proprietárias (entity-links, queries, callouts clínicos, transclusão de dados).

### 5.1 Gramática (EBNF)

```ebnf
documento     = [ frontmatter ] , { bloco } ;
frontmatter   = "---" , NL , yaml , NL , "---" , NL ;

bloco         = heading | paragrafo | lista | tabela | codigo
              | callout | queryBlock | separador | canvasEmbed ;

(* ── Inline ────────────────────────────────────────────────────────────── *)
inline        = { texto | wikilink | entitylink | embed | tag | blockRef
                | enfase | codigoInline | linkMd | imagemMd | citacaoBloco } ;

(* ── Wikilinks ─────────────────────────────────────────────────────────── *)
wikilink      = "[[" , alvo , [ "#" , ancora ] , [ "^" , blocoId ]
                                , [ "|" , textoExibido ] , "]]" ;
alvo          = pathOuTitulo | aliasConhecido ;
ancora        = { CHAR - ("]" | "|" | "^" | "#") } ;
blocoId       = LETRA , { LETRA | DIGITO | "-" } ;
embed         = "!" , wikilink ;

(* ── Entity-links (extensão Vitta) ─────────────────────────────────────── *)
entitylink    = "[[@" , entidadeTipo , ":" , entidadeId
                       , [ "|" , textoExibido ] , "]]" ;
entidadeTipo  = "paciente" | "medico" | "agendamento" | "clinica"
              | "alerta" | "score" | "overbooking" | "tarefa"
              | "conversa" | "avaliacao" ;
entidadeId    = { LETRA | DIGITO | "_" | "-" } ;

(* ── Tags hierárquicas ─────────────────────────────────────────────────── *)
tag           = "#" , segmento , { "/" , segmento } ;
segmento      = LETRA , { LETRA | DIGITO | "-" | "_" } ;

(* ── Âncora de bloco ───────────────────────────────────────────────────── *)
blockAnchor   = fimDeLinha , " ^" , blocoId ;

(* ── Callouts (Obsidian-compatível + tipos clínicos) ───────────────────── *)
callout       = ">" , "[!" , calloutTipo , "]" , [ "+" | "-" ]
                     , [ " " , titulo ] , NL , { ">" , inline , NL } ;
calloutTipo   = "note" | "tip" | "warning" | "danger" | "info" | "success"
              | "question" | "quote" | "example" | "bug" | "todo"
              (* extensões clínicas *)
              | "risco" | "protocolo" | "insight" | "decisao"
              | "acao-agente" | "lgpd" ;

(* ── Query blocks (extensão Vitta) ─────────────────────────────────────── *)
queryBlock    = "```vitta-query" , NL , queryDSL , NL , "```" ;
queryDSL      = fonte , { NL , clausula } ;
fonte         = ( "TABELA" | "LISTA" | "CARTOES" | "GRAFICO" | "GRAFO"
                | "CALENDARIO" | "TIMELINE" | "KANBAN" ) , [ campos ] ;
clausula      = ( "DE" , escopo ) | ( "ONDE" , expr ) | ( "ORDENAR" , campo , [ "DESC" ] )
              | ( "LIMITE" , NUM ) | ( "AGRUPAR" , campo ) | ( "JUNTAR" , colecao ) ;
escopo        = 'pasta("' , path , '")' | 'tag(#' , tag , ')'
              | 'links([[' , alvo , ']])' | 'backlinks([[' , alvo , ']])'
              | '@' , entidadeTipo | 'semelhante([[' , alvo , ']],' , NUM , ')' ;

(* ── Transclusão de dados operacionais ─────────────────────────────────── *)
canvasEmbed   = "![[canvas:" , canvasId , "]]" ;
```

### 5.2 Semântica de resolução de `[[alvo]]`

Ordem determinística — o **primeiro** que casar vence:

1. **Path exato** (case-sensitive): `mocs/absenteismo.md`
2. **Path exato sem extensão**: `mocs/absenteismo`
3. **Path case-insensitive**
4. **Alias exato** (campo `aliases`)
5. **Título exato**
6. **Título case-insensitive**
7. **Nome de arquivo único no vault** (`absenteismo` casa `mocs/absenteismo.md` se não houver ambiguidade)
8. **Ambíguo** → renderiza em âmbar com badge `⚠ 3` e tooltip listando candidatos; clique abre desambiguador.
9. **Não encontrado** → link *quebrado*, renderizado em vermelho tracejado; clique oferece **"Criar nota `X`"** (Obsidian-style *unresolved link*), e o nó aparece no grafo como círculo vazado (opção "mostrar links não resolvidos").

Entity-links (`@tipo:id`) pulam esse pipeline e vão direto ao `BridgeResolver`.

### 5.3 Exemplo canônico de nota

````markdown
---
aliases: [Faltas, No-show MOC]
tipo: moc
tags: [moc, operacao/absenteismo]
status: vivo
revisar_em: 2026-09-01
responsavel: med_44
cor: "#F43F5E"
---

# Absenteísmo — MOC

links: [[Operação Clínica]] · [[Indicadores Q3]] · [[@clinica:cl_001]]

> [!insight] Descoberta de 12/03
> Segundas-feiras às 7h concentram **34%** das faltas, contra 11% esperados.
> Correlacionado com [[Protocolo de Confirmação 48h]] não aplicado nesse turno. ^insight-seg

## Diagnóstico

- [[Padrão · Faltas de Segunda]] — o achado central ^resumo-q1
- [[@medico:med_44|Dra. Helena]] concentra 3 dos 5 piores slots
- Consultas afetadas em março: `12` — ver [[@agendamento:ag_9912]]

## Ações em curso

- [x] Ativar lembrete reforçado 48h → [[Protocolo de Confirmação 48h]]
- [ ] Testar overbooking controlado em 2 slots → [[@overbooking:ob_2201]]
- [ ] Revisar com a equipe em [[Reunião 2026-09-02]]

## Notas relacionadas

```vitta-query
TABELA titulo, metrics.pagerank AS "relevância", updatedAt AS "atualizado"
DE tag(#operacao/absenteismo)
ONDE tipo != "diario" E updatedAt > hoje-90d
ORDENAR metrics.pagerank DESC
LIMITE 15
```

## Pacientes de risco crítico agora

```vitta-query
CARTOES
DE @score
ONDE riskLevel = "critico" E clinicaId = clinicaAtual()
ORDENAR riskScore DESC
LIMITE 8
```

![[Padrão · Faltas de Segunda#Gráfico semanal]]
````

### 5.4 Renderização — mapeamento token → widget

| Construção | Widget | Comportamento |
|---|---|---|
| `[[nota]]` resolvido | `WikiLinkSpan` (azul `primary`, sem sublinhado) | Clique abre; `Ctrl`+clique abre em painel novo; hover ≥ 500 ms → *hover preview* |
| `[[nota]]` ambíguo | `WikiLinkSpan` âmbar + badge contador | Clique abre `DesambiguadorSheet` |
| `[[nota]]` quebrado | `WikiLinkSpan` vermelho tracejado | Clique abre `CriarNotaDialog` pré-preenchido |
| `[[@paciente:id]]` | `EntityChip` (avatar + nome, cor por tipo) | Clique abre `EntityDrawer`; sem permissão → chip cinza "restrito" |
| `![[nota]]` | `EmbedCard` (borda esquerda 3px) | Renderiza conteúdo inline, colapsável, com link "abrir" |
| `![[nota#sec]]` | `EmbedCard` só da seção | — |
| `#tag/sub` | `TagChip` | Clique filtra explorer; `Ctrl`+clique adiciona ao filtro do grafo |
| `> [!risco]` | `CalloutBox` | Ícone + cor por tipo; `+/-` controla estado inicial colapsado |
| ` ```vitta-query ` | `QueryBlockView` | Executa e renderiza; botão ⟳ e "editar query" |
| `- [ ]` / `- [x]` | `TaskItem` | Checkbox real; marcar reescreve o markdown |
| `^blockId` | invisível em leitura | Visível em edição (cinza 40%); botão "copiar ref do bloco" |
| `$$latex$$` | `MathBlock` (v1.1) | Fora do escopo v1.0 — renderiza como código |

### 5.5 Extensões de parser (flutter_markdown)

O projeto já depende de `flutter_markdown ^0.7.7+1`. Estendemos com `md.InlineSyntax`:

```dart
/// [[alvo#ancora^bloco|alias]]  e  ![[…]]
class WikiLinkSyntax extends md.InlineSyntax {
  WikiLinkSyntax() : super(
    r'(!?)\[\[([^\[\]|#^]+?)(?:#([^\[\]|^]+?))?(?:\^([^\[\]|]+?))?(?:\|([^\[\]]+?))?\]\]',
  );

  @override
  bool onMatch(md.InlineParser parser, Match m) {
    final el = md.Element.empty(m[1] == '!' ? 'vittaEmbed' : 'vittaWikiLink')
      ..attributes['alvo']   = m[2]!.trim()
      ..attributes['ancora'] = m[3]?.trim() ?? ''
      ..attributes['bloco']  = m[4]?.trim() ?? ''
      ..attributes['alias']  = m[5]?.trim() ?? '';
    parser.addNode(el);
    return true;
  }
}

/// [[@tipo:id|alias]] — precisa ser registrado ANTES de WikiLinkSyntax
class EntityLinkSyntax extends md.InlineSyntax {
  EntityLinkSyntax() : super(
    r'\[\[@(paciente|medico|agendamento|clinica|alerta|score|overbooking|tarefa|conversa|avaliacao):([A-Za-z0-9_-]+)(?:\|([^\[\]]+?))?\]\]',
  );
  // → Element 'vittaEntity' com attributes tipo/id/alias
}

/// #tag/hierarquica — exige que não esteja dentro de código ou de heading ATX
class TagSyntax extends md.InlineSyntax {
  TagSyntax() : super(r'(?<![\w/#])#([A-Za-zÀ-ÿ][\w\-À-ÿ]*(?:/[\w\-À-ÿ]+)*)');
}
```

**Ordem de registro (importa):** `EntityLinkSyntax` → `WikiLinkSyntax` → `BlockRefSyntax` → `TagSyntax` → `HighlightSyntax` (`==destaque==`) → padrões nativos.

**Zonas de exclusão:** o `ParserVFM` pré-computa intervalos de código (fences, inline `` ` ``, blocos indentados) e URLs; nenhum syntax proprietário casa dentro deles. Isso evita que `#hashtag` em uma URL (`https://x.com/a#b`) vire tag — bug clássico.

---

## 6. Motor de Parsing e Indexação

### 6.1 Pipeline

```
texto markdown
   │
   ├─▶ [1] FrontmatterSplitter   → (yamlMap, corpo, offsetLinha)
   │
   ├─▶ [2] MascaraDeCodigo       → List<Intervalo> zonas proibidas
   │
   ├─▶ [3] Tokenizer             → List<Token>  (single-pass, O(n))
   │
   ├─▶ [4] AstBuilder            → NotaAst
   │
   ├─▶ [5] Extrator              → LinkSet, TagSet, HeadingList, BlockMap, Stats
   │
   └─▶ [6] IndexadorVault        → aplica diff nos 6 índices globais
```

**Complexidade alvo:** `O(n)` no tamanho do texto para 1–5; `O(Δ)` no número de arestas alteradas para 6. Nota de 50 KB deve parsear em ≤ 8 ms em desktop, ≤ 25 ms em mobile.

### 6.2 Os 6 índices globais

```dart
class VaultIndex {
  /// 1. Forward: notaId → arestas de saída
  final Map<String, List<Aresta>> forward = {};

  /// 2. Backlinks: alvo (notaId | @tipo:id | tag:x) → arestas de entrada
  final Map<String, List<Aresta>> back = {};

  /// 3. Alias: chave normalizada (lowercase, sem acento) → notaId
  ///    Popula path, path sem .md, título, cada alias, nome de arquivo.
  ///    Valor é List<String> para detectar ambiguidade.
  final Map<String, List<String>> alias = {};

  /// 4. Tags: tag completa e cada prefixo hierárquico → Set<notaId>
  ///    "operacao/absenteismo" popula "operacao" E "operacao/absenteismo".
  final Map<String, Set<String>> tags = {};

  /// 5. Trigramas: "abs" → Set<notaId>  (busca textual difusa)
  ///    Construído sob demanda (lazy) no 1º uso da busca.
  final Map<String, Set<String>> trigram = {};

  /// 6. Headings/Blocos: notaId → estrutura, p/ resolver [[nota#sec]] e ^bloco
  final Map<String, EstruturaNota> estrutura = {};

  /// Metadados leves de todas as notas (sem conteúdo) — fonte do explorer/grafo.
  final Map<String, NotaMeta> metas = {};
}
```

**Custo de memória** (vault de 5.000 notas, ~40 links/nota):

| Índice | Estimativa |
|---|---|
| forward + back | 200.000 arestas × ~120 B = **24 MB** |
| alias | 20.000 chaves × ~60 B = 1,2 MB |
| tags | 800 tags × média 60 ids = 0,3 MB |
| trigram (lazy) | ~180.000 trigramas × ~90 B = **16 MB** |
| estrutura | 5.000 × ~400 B = 2 MB |
| metas | 5.000 × ~700 B = 3,5 MB |
| **Total** | **≈ 47 MB** (aceitável; teto de alerta em 120 MB) |

> Acima de `maxNotasGrafo` (padrão 3.000) o cliente entra em **modo servidor**: backlinks passam a vir de query em `tb_cerebro_links`, trigramas são desativados e a busca usa só o servidor. Alternância automática, sinalizada por um ícone na status bar.

### 6.3 Tokenizer — pseudocódigo

```
função tokenizar(corpo, zonasProibidas):
  tokens ← []
  i ← 0
  enquanto i < corpo.length:
    se dentroDeZonaProibida(i, zonasProibidas):
      i ← fimDaZona(i);  continuar

    c ← corpo[i]

    // ![[ ou [[
    se c == '!' e corpo.startsWith('[[', i+1) OU corpo.startsWith('[[', i):
      ehEmbed ← (c == '!')
      j ← corpo.indexOf(']]', i)
      se j == -1: tokens.add(Texto(c)); i++; continuar     // não fecha: literal
      bruto ← corpo.substring(i + (ehEmbed ? 3 : 2), j)
      se bruto.startsWith('@'):
        tokens.add(parseEntityLink(bruto, linha(i), ehEmbed))
      senão:
        tokens.add(parseWikiLink(bruto, linha(i), ehEmbed))
      i ← j + 2;  continuar

    // #tag — exige fronteira à esquerda e 1ª letra alfabética
    se c == '#' e ehFronteiraEsquerda(corpo, i) e ehLetra(corpo[i+1]):
      m ← REGEX_TAG.matchAt(corpo, i)
      se m != null:
        tokens.add(Tag(m.group(1), linha(i)));  i ← m.end;  continuar

    // ^blockId no fim da linha
    se c == '^' e ehFimDeLinha(corpo, i):
      m ← REGEX_BLOCK.matchAt(corpo, i)
      se m != null: tokens.add(AncoraBloco(m.group(1), linha(i))); i ← m.end; continuar

    // heading ATX no início da linha
    se c == '#' e ehInicioDeLinha(i):
      m ← REGEX_HEADING.matchAt(corpo, i)
      se m != null: tokens.add(Heading(nivel, texto, linha(i))); i ← m.end; continuar

    tokens.add(Texto(c));  i++
  retornar tokens
```

**Casos-limite obrigatórios em teste** (`test/cerebro/parser_test.dart`):

| # | Entrada | Esperado |
|---|---|---|
| 1 | `[[a]] [[a]]` | 1 aresta com `peso = 2` |
| 2 | `[[a\|b\|c]]` | alvo `a`, alias `b\|c` (só o 1º pipe separa) |
| 3 | `[[]]` | texto literal, sem aresta |
| 4 | `[[ a ]]` | alvo `a` (trim) |
| 5 | `` `[[a]]` `` | literal, sem aresta |
| 6 | ```` ```\n[[a]]\n``` ```` | literal, sem aresta |
| 7 | `https://x.com/p#frag` | sem tag |
| 8 | `#1` / `#123` | sem tag (1º char precisa ser letra) |
| 9 | `#pai/filho` | tags `pai` **e** `pai/filho` |
| 10 | `[[nota#sec\|texto]]` | alvo `nota`, âncora `sec`, alias `texto` |
| 11 | `![[nota#^bloco]]` | embed de bloco |
| 12 | `[[@paciente:pac_1]]` | entity-link, **não** wikilink |
| 13 | `[[@invalido:x]]` | wikilink normal para título literal `@invalido:x` (tipo desconhecido) |
| 14 | `[[a]]` dentro de `> [!note]` | aresta contada normalmente |
| 15 | Frontmatter com `aliases: [x, y]` | 2 chaves no índice alias |
| 16 | Nota referenciando a si própria | aresta ignorada (self-loop não entra no grafo) |
| 17 | `[[A]]` e alias `A` em 2 notas | ambíguo → `LinkEstado.ambiguo` |
| 18 | Texto de 1 MB sem links | parse ≤ 120 ms, sem OOM |
| 19 | `[[nota\.md]]` com escape | alvo literal |
| 20 | Emoji + acentos no alvo | resolve por normalização NFC + casefold |

### 6.4 Atualização incremental

```dart
/// Chamado a cada salvamento. NUNCA reconstrói o índice inteiro.
void atualizarNota(String notaId, NotaAst novoAst) {
  final antigas = forward[notaId] ?? const [];
  final novas   = novoAst.arestas;

  final removidas = antigas.toSet().difference(novas.toSet());
  final add       = novas.toSet().difference(antigas.toSet());

  for (final a in removidas) { back[a.para]!.remove(a); }
  for (final a in add)       { back.putIfAbsent(a.para, () => []).add(a); }

  forward[notaId] = novas;
  _atualizarTags(notaId, novoAst.tags);
  _atualizarAlias(notaId, novoAst.meta);
  estrutura[notaId] = novoAst.estrutura;
  if (trigram.isNotEmpty) _atualizarTrigramas(notaId, novoAst.textoPlano);

  // Notifica o grafo com o delta — não com o vault inteiro.
  _grafoBus.emit(GrafoDelta(no: notaId, adicionadas: add, removidas: removidas));
}
```

**Renomear/mover uma nota** (`cerebro_mover`) dispara reescrita em cascata:

1. Busca `back[notaId]` → todas as notas que apontam para ela.
2. Para cada uma, reescreve o texto do wikilink preservando alias/âncora/bloco.
3. `WriteBatch` de até 500 notas por lote, com barra de progresso e possibilidade de cancelar.
4. Registra um único evento `mover` em `tb_cerebro_eventos` com a lista de notas afetadas (permite reverter tudo de uma vez).
5. Se houver > 200 notas afetadas, exige confirmação explícita no diálogo.

### 6.5 Busca textual

**Ranking híbrido** (`BuscaService.buscarTexto`):

```
score(nota, consulta) =
    3.0 · casaTitulo(exato)
  + 2.0 · casaAlias(exato)
  + 1.5 · casaTitulo(prefixo)
  + 1.2 · casaTag
  + 1.0 · bm25(corpo, consulta)
  + 0.6 · log(1 + inDegree)          // notas centrais sobem
  + 0.4 · recencia(updatedAt)        // exp(-Δdias / 45)
  + 0.3 · (fixada ? 1 : 0)
  − 2.0 · (arquivada ? 1 : 0)
```

**Fuzzy:** trigramas com limiar Jaccard ≥ 0,35, seguido de reordenação por distância de Levenshtein normalizada. Digitar `absentesimo` (erro de digitação) precisa encontrar `Absenteísmo`.

**Operadores da barra de busca** (compatíveis com Obsidian):

| Operador | Significado |
|---|---|
| `tag:#operacao` | Notas com a tag (inclui filhas) |
| `path:mocs/` | Notas na pasta |
| `file:absent` | Nome de arquivo contém |
| `line:(a b)` | `a` e `b` na mesma linha |
| `block:(a b)` | No mesmo bloco |
| `section:(a b)` | Na mesma seção |
| `"frase exata"` | Correspondência literal |
| `-termo` | Exclusão |
| `a OR b` / `a b` | Ou / E (padrão) |
| `tipo:moc` | Filtra por `NotaTipo` |
| `origem:agente` | Só notas escritas pela IA |
| `estado:rascunho` | Fila de revisão |
| `entidade:@medico:med_44` | Notas que referenciam a entidade |
| `orfa:true` | Sem links de entrada nem saída |
| `criada:>2026-07-01` | Filtro temporal (`criada`/`editada`, `>`, `<`, `..`) |
| `semelhante:[[nota]]` | 🆕 KNN semântico (§8) |
| `caminho:[[a]]..[[b]]` | 🆕 Notas no menor caminho entre duas notas |

---

## 7. Motor de Grafo

> As imagens `Sem título.jpg`, `2.jpg`, `3.jpg` e `5.jpg` definem a linguagem visual desta seção. Ver §10.5 e §10.6 para a UI; aqui está a engine.

### 7.1 Modelo

```dart
class GrafoNo {
  final String id;            // nt_… | @tipo:id | tag:nome
  final String rotulo;
  final NoTipo tipo;          // nota | moc | diario | entidade | tag | naoResolvido
  final EntidadeTipo? entidade;

  // Estado da simulação (mutável, alinhado em Float32List na prática)
  double x, y, vx, vy;
  bool fixado;                // arrastado pelo usuário → posição travada

  // Derivados
  int inDegree, outDegree;
  double pagerank;            // 0..1
  int cluster;                // Louvain
  double raio;                // calculado de pagerank/degree — §7.5
  Color cor;                  // de grupo > cor manual > tipo > cluster
  double opacidade;           // 1.0 normal; 0.18 fora do filtro/foco
}

class GrafoAresta {
  final String de, para;
  final LinkTipo tipo;
  final double peso;          // ocorrências; embed = 2.0; semântico = similaridade
  double opacidade;
  bool destacada;             // no caminho do nó em foco
}
```

**Layout de memória.** Para performance, `GrafoEngine` não guarda `List<GrafoNo>` na simulação: guarda **arrays paralelos** (`Float32List px, py, vx, vy; Int32List grau, cluster;`) e um `Map<String,int> idParaIndice`. Objetos `GrafoNo` são materializados só para o painter e para hit-testing. Isso elimina ponteiro-chasing e reduz GC pressure em ~70%.

### 7.2 Simulação de forças

Modelo *force-directed* com 4 forças, integração de Verlet e resfriamento exponencial.

```
por tick:
  α ← α + (αAlvo − α) · αDecay          // αDecay = 0.0228, αAlvo = 0
  
  1. REPULSÃO (Barnes-Hut, θ = 0.85)
     Constrói quadtree dos nós.
     Para cada nó i: percorre a árvore; se (largura/dist) < θ, trata o
     nó interno como massa agregada no centro de massa.
     F_rep = kRep · massa_j / dist²      (kRep = −280 por padrão)
     Complexidade: O(n log n) em vez de O(n²).

  2. ATRAÇÃO POR ARESTA (mola)
     Para cada aresta (i,j):
       d ← dist(i,j)
       F_mola = (d − comprimentoAlvo) · rigidez · pesoAresta
       comprimentoAlvo = 42 (config: "distância dos links" 10..120)
       rigidez = 1 / min(grau_i, grau_j)   ← nós hub ficam mais soltos

  3. CENTRO
     F_centro = (centroViewport − pos) · forcaCentro   (padrão 0.03)

  4. COLISÃO (só quando n < 1200)
     Resolve sobreposição: se dist < r_i + r_j + 2, empurra metade p/ cada.

  integração:
    vx ← (vx + Fx) · atrito                (atrito = 0.62)
    px ← px + vx · α
  
  parada:
    se α < 0.0012 → congela; para o Ticker; salva posições.
```

**Parâmetros expostos na UI** (painel de forças — ícone ⚙ do canto superior direito, ver `2.jpg`):

| Controle | Faixa | Padrão | Efeito |
|---|---|---|---|
| Força central | 0 – 1 | 0,03 | Compacta o grafo |
| Força de repulsão | 0 – 20 | 5,6 | Espalha os nós |
| Distância dos links | 10 – 120 | 42 | Comprimento das arestas |
| Grossura das linhas | 0,3 – 3 | 0,8 | Espessura das arestas |
| Tamanho dos nós | 0,5 – 5 | 1,6 | Multiplicador de raio |
| Atrito | 0,1 – 0,95 | 0,62 | Amortecimento |
| Zoom automático | on/off | on | Enquadra ao terminar |
| Animar entrada | on/off | on | Nós surgem do centro |

Todos persistem em `tb_cerebro_config.grafoForcas` por usuário, com botão **"Restaurar padrões"**.

### 7.3 Orçamento de frame e execução

| Plataforma | Estratégia |
|---|---|
| **Desktop / mobile** | Simulação em `Isolate` dedicado. Envia `Float32List` de posições por `SendPort` a cada tick (transferência zero-copy com `TransferableTypedData`). UI apenas pinta. |
| **Web** | Sem isolate real. Simulação fatiada: `SchedulerBinding.addPostFrameCallback` executa **no máximo 6 ms** de física por frame, com laço de nós retomável (guarda índice `i` entre frames). Se estourar, reduz para 1 tick a cada 2 frames. |

```dart
// Guarda-corpo obrigatório
const budgetFisicaMs = 6.0;
final sw = Stopwatch()..start();
while (sw.elapsedMicroseconds < budgetFisicaMs * 1000 && !engine.congelado) {
  engine.tick();
}
```

### 7.4 Renderização — `GrafoPainter`

**Camadas (de trás para frente):**

1. **Fundo** — `AppColors.backgroundDark` (#0F1320) ou `background` (#F4F6FA) no tema claro.
2. **Arestas** — batch único via `Canvas.drawRawPoints(PointMode.lines, Float32List)`. Um `Paint` por *bucket* de opacidade (4 buckets: 1.0 / 0.55 / 0.25 / 0.10) → no máximo 4 draw calls para 20.000 arestas.
3. **Arestas destacadas** — curvas com `drawPath`, cor `pinkAccent`, largura 1,6.
4. **Nós** — `drawCircle` agrupado por cor. Acima de 2.500 nós, usa `drawRawAtlas` com um sprite de círculo pré-renderizado por cor (1 draw call por atlas).
5. **Anéis de foco** — nó em hover/seleção ganha halo de 3 px com `MaskFilter.blur(2)`.
6. **Rótulos** — `Paragraph` cacheado, desenhado só se passar no filtro de LOD (§7.5).
7. **Overlay** — tooltip, régua de zoom, mini-mapa (opcional).

**Cache de rótulos:**

```dart
class LabelCache {
  final _lru = LinkedHashMap<String, ui.Paragraph>();   // chave: "$texto|$escala"
  static const capacidade = 600;
  ui.Paragraph obter(String texto, double escala) { /* LRU + ui.ParagraphBuilder */ }
}
```

Construir um `Paragraph` custa ~40 µs. Com 800 rótulos visíveis seriam 32 ms/frame — inaceitável. O cache reduz para ~0,4 ms. **Invalidar apenas** quando o tema ou a escala de fonte muda (a escala é quantizada em passos de 0,25 para maximizar acerto de cache).

### 7.5 LOD (nível de detalhe) e culling

```dart
double raioDe(GrafoNo n, double zoom, ConfigGrafo c) {
  final base = 2.2 + 5.5 * math.sqrt(n.inDegree + n.outDegree);
  final pr   = 1.0 + 2.4 * math.pow(n.pagerank * nTotal, 0.55);
  return (base * pr * c.multiplicadorTamanho).clamp(2.0, 46.0);
}

bool mostrarRotulo(GrafoNo n, double zoom, int nVisiveis) {
  if (n.emFoco || n.selecionado || n.hover) return true;      // sempre
  if (zoom >= 2.2) return true;                                // zoom alto: tudo
  if (nVisiveis <= 60) return true;                            // grafo local
  final limiar = zoom < 0.6 ? 0.020            // muito longe: só os hubs
               : zoom < 1.1 ? 0.006
               : 0.0015;
  return n.pagerank >= limiar;                                 // relevância
}
```

**Culling:** só entram no laço de pintura os nós dentro do retângulo do viewport expandido em 15%. Implementado com a mesma quadtree da física, consultada por região (`quadtree.query(rectViewport)`), custo `O(log n + k)`.

**Degradação sob carga.** Se 3 frames consecutivos estourarem 16,6 ms:
`rótulos off` → `colisão off` → `arestas com opacidade < 0,3 off` → `θ de 0,85 para 1,2` → `amostragem: pinta 1 a cada 2 nós de grau 1`. Exibe chip discreto "modo performance" com botão para forçar qualidade máxima.

### 7.6 Métricas do grafo

Calculadas em isolate/Cloud Function e salvas em `tb_cerebro_snapshots` + `notas.metrics`.

**PageRank** (damping 0,85, 40 iterações ou `Δ < 1e-6`) — define tamanho e proeminência do nó. Arestas de embed pesam 2×.

```
PR(i) = (1−d)/N + d · Σ_{j→i} PR(j) · peso(j→i) / Σ_out(j)
```

**Louvain** (modularidade) — define cor por comunidade quando não há grupo manual. Resolução configurável (padrão 1,0); resolução maior → mais clusters, menores.

```
fase 1: cada nó começa em sua própria comunidade;
        move cada nó para a comunidade vizinha que maximiza ΔQ;
        repete até não haver melhoria.
fase 2: contrai comunidades em supernós; volta à fase 1.
para quando ΔQ_total < 1e-5.
```

**Outras métricas expostas na UI:**

| Métrica | Uso na interface |
|---|---|
| Componentes conexos | Painel "Ilhas": lista componentes desconectados com sugestão de link-ponte |
| Órfãs (grau 0) | Chip "N órfãs" na status bar → filtro de 1 clique |
| Nós-ponte (alta intermediação) | Badge 🌉 — "se esta nota sumir, o cérebro racha em 2" |
| Densidade `2E / N(N−1)` | Card no painel analítico |
| Distância média | Card + série temporal ("seu cérebro está encolhendo em diâmetro") |
| Coeficiente de agrupamento | Card |
| Crescimento (nós/semana) | Sparkline no painel analítico (ver `5.jpg`) |

### 7.7 Grafo local

Espelha o painel superior direito de `4.jpg`.

```dart
GrafoLocal construir({
  required String noFocal,
  int profundidade = 1,          // 1..5, slider na UI
  bool entrantes = true,
  bool saintes = true,
  bool incluirTags = false,
  bool incluirEntidades = true,
  bool incluirSemanticos = false, // arestas tracejadas §8.2
  int maxNos = 220,               // corta por PageRank ao estourar
})
```

**Layout radial ancorado:** o nó focal é fixado no centro (`fixado = true`) e os demais recebem uma força adicional que os empurra para o anel `r = 90 · saltos`. Isso produz o visual de hub-and-spoke da imagem `3.jpg` (nó central "Livros" com satélites laranja), muito mais legível que força pura para grafos pequenos.

### 7.8 Interações

| Gesto | Ação |
|---|---|
| Clique em nó | Seleciona; abre inspector (§10.6); grafo entra em modo foco |
| Clique duplo | Abre a nota no editor |
| `Ctrl` + clique | Abre em painel dividido |
| Arrastar nó | Fixa o nó na posição; ícone 📌; `Alt`+clique remove a fixação |
| Arrastar fundo | Pan |
| Scroll / pinça | Zoom (0,05× a 8×), centrado no cursor |
| Hover | Realça nó + vizinhos diretos, esmaece o resto para 0,12; tooltip após 400 ms |
| Clique no fundo | Limpa seleção e foco |
| Caixa de seleção (`Shift`+arrastar) | Multi-seleção → ações em lote (tag, mover, arquivar) |
| `Espaço` | Reaquece a simulação (α = 0,4) |
| `F` | Enquadra tudo |
| `L` | Alterna rótulos |
| `Esc` | Sai do modo foco |
| Duplo clique no fundo | Cria nota nova ancorada naquela posição |

**Modo foco** (destaque de `5.jpg`, com as arestas ciano irradiando do artigo selecionado): ao selecionar um nó, as arestas até profundidade *N* ganham cor de destaque e animação de fluxo (dash offset animado, 900 ms de loop). Todo o resto cai para 12% de opacidade. Toggle "seguir seleção" mantém o comportamento a cada clique.

---

## 8. Camada Semântica (IA)

É o que separa o Cérebro Vitta de "um Obsidian dentro do Flutter": o vault **entende** o que está escrito.

### 8.1 Chunking e embeddings

**Estratégia de chunking — *heading-aware* com sobreposição:**

```
1. Divide o corpo pelos headings (H1..H4), preservando o caminho hierárquico.
2. Se uma seção > 512 tokens, subdivide em parágrafos até caber, com 64
   tokens de sobreposição entre chunks consecutivos.
3. Se uma seção < 80 tokens, funde com a seguinte (evita chunks-ruído).
4. Cada chunk é prefixado com contexto para não perder o significado isolado:
     "[{titulo da nota}] > {H1} > {H2}\n\n{texto do chunk}"
5. Blocos ```vitta-query``` são EXCLUÍDOS (são código, não conhecimento).
6. Entity-links são expandidos para rótulo genérico, NUNCA para PII:
     [[@paciente:pac_812]] → "(paciente)"      ← §14
     [[@medico:med_44]]    → "Dra. Helena"     ← permitido (não é paciente)
```

**Geração** — nova Cloud Function `embedText` (mesmo padrão de `chatProxy.js`/`analyzeDocument`: chave **nunca** no cliente):

```
POST https://us-central1-agendaclinica-457713.cloudfunctions.net/embedText
Headers: Authorization: Bearer <Firebase ID token>
Body:   { "clinicaId": "cl_001", "textos": ["…", "…"], "dims": 768 }
Resp:   { "vetores": [[…768 floats…]], "modelo": "text-embedding-3-large@768",
          "tokens": 1284, "custoUsd": 0.00017 }
```

- Lote de até **96 textos** por chamada.
- *Rate limit* por clínica: 200 chamadas/hora (protege o orçamento — ver [`CUSTO.md`](../CUSTO.md)).
- Cache por hash SHA-1 do texto do chunk: reescrever um parágrafo não reindexa a nota inteira.
- Fila com backoff exponencial (1s, 4s, 16s, 64s) e persistência local — reinício do app não perde a fila.

**Quando reindexar:** `nota.embeddingVersao < nota.versao` **e** o diff de conteúdo excede 60 caracteres **ou** houve mudança de heading. Edições cosméticas não gastam tokens.

### 8.2 Os três tipos de "relacionado"

O painel direito (§10.7) mostra três listas distintas — esta separação é central para a UX:

| Tipo | Origem | Visual | Ação |
|---|---|---|---|
| **Menções vinculadas** | `back[notaId]` — links explícitos | Lista com nome + trecho de contexto, chip do link destacado (ver `4.jpg`, painel "Linked mentions") | Clicar navega |
| **Menções não-vinculadas** | Ocorrência textual do título/alias sem `[[ ]]` | Mesmo layout, com botão **"Vincular"** por item e **"Vincular todas"** no cabeçalho | Insere `[[ ]]` no texto de origem |
| **Vizinhos semânticos** ⭐ | KNN sobre embeddings, `similaridade ≥ 0,74`, sem link explícito | Lista com barra de similaridade (0–100%) e o trecho que mais casou | "Criar link" / "Ignorar" (grava em `ignorados`) |

**Detecção de menções não-vinculadas** — problema clássico de multi-padrão. Usamos **Aho-Corasick** construído uma vez sobre todos os títulos e aliases do vault (≥ 4 caracteres, sem stopwords), com verificação de fronteira de palavra e exclusão das zonas de código/links já existentes. Custo: `O(tamanhoTexto + ocorrências)`, reconstrução do autômato apenas quando títulos mudam (debounce de 5 s).

### 8.3 Sugestões proativas (fila de curadoria)

A Cloud Function noturna `cerebroSugestoes` popula `tb_cerebro_sugestoes`:

| Tipo | Gatilho | Exemplo de justificativa |
|---|---|---|
| `link` | Similaridade ≥ 0,82 e sem link | "Ambas descrevem o protocolo de confirmação de 48h, com números coerentes." |
| `tag` | Nota sem tags e ≥ 3 vizinhos compartilham uma tag | "5 das 6 notas mais próximas usam `#operacao/absenteismo`." |
| `merge` | Similaridade ≥ 0,94 e tamanhos parecidos | "Provável duplicata criada em 12/03 e 04/07." |
| `mocSplit` | Nota com `outDegree > 45` | "Este MOC virou um monólito; sugiro dividir em 3 por tema." |
| `orfa` | Grau 0 há > 21 dias | "Órfã desde 12/07. Sugiro ligar a [[Operação Clínica]]." |
| `desatualizada` | `frontmatter.revisar_em < hoje` | "Marcada para revisão em 01/09; entidades citadas mudaram desde então." |
| `ponte` | Duas ilhas com similaridade média alta | "Estas 2 ilhas falam do mesmo tema — uma nota-ponte conectaria 34 notas." |
| `contradicao` ⭐ | Duas notas com alta similaridade e conclusões opostas (detecção por LLM) | "[[A]] diz que segunda 7h é o pior horário; [[B]] diz que é sexta 17h. Dados de julho contradizem [[A]]." |

**UI da fila:** painel "Sugestões" no rail esquerdo com badge de contagem. Cartões com **Aceitar** / **Rejeitar** / **Adiar 7d** / **Ver comparação lado a lado**. Aceitar aplica a mudança e registra evento. Rejeitar treina o limiar: 3 rejeições do mesmo par elevam o limiar daquele par para 0,95 permanentemente.

> **Regra anti-ruído:** no máximo **12 sugestões pendentes** por vez, ordenadas por score. Nada de caixa de entrada infinita — o objetivo é curadoria, não spam.

### 8.4 RAG sobre o vault (busca híbrida)

Quando o agente responde uma pergunta, o contexto vem de uma **fusão recíproca de ranks** (RRF) entre três fontes:

```
candidatos = 
    BM25(vault, consulta)             top 40
  ∪ KNN(embeddings, consulta)         top 40
  ∪ Vizinhança de grafo do nó focal   top 20  (se houver nota aberta)

RRF: score(d) = Σ_fontes 1 / (60 + rank_fonte(d))

reordenação (rerank):
  + 0.25 · pagerank_normalizado(d)
  + 0.15 · recencia(d)
  + 0.30 · (d.tipo ∈ {protocolo, decisao} ? 1 : 0)   ← autoridade operacional
  − 0.50 · (d.estado == rascunho ? 1 : 0)
  − 1.00 · (d.origem == agente && d.confianca < 0.6 ? 1 : 0)  ← evita eco da IA

corte: top 12 chunks ou 6.000 tokens, o que vier primeiro.
```

**Anti-eco (crítico).** Sem essa regra, a IA cita as próprias notas de baixa confiança e reforça os próprios erros ao longo do tempo. Toda nota com `origem == agente` entra no contexto **rotulada**: `[gerada por IA em 12/03, confiança 0,62, não revisada]`. O prompt do sistema instrui a nunca tratar essas notas como fato estabelecido e a preferir dados operacionais quando houver divergência.

**Montagem do contexto** enviado ao modelo:

```
## CONTEXTO DO CÉREBRO (12 trechos, 5.204 tokens)

### [1] Protocolo de Confirmação 48h  ·  protocolo  ·  revisado por usr_12 em 03/07
caminho: protocolos/confirmacao-48h.md  ·  relevância 0.91  ·  in:27 out:8
---
{texto do chunk}

### [2] Padrão · Faltas de Segunda  ·  analise  ·  ⚠ gerada por IA (confiança 0.71, não revisada)
…
```

### 8.5 Consolidação de memória (a rotina noturna)

O que faz o cérebro **crescer sozinho**. Roda às 02:30 (após o cálculo de scores das 02:00 descrito em [`AgentAI.md`](../AgentAI.md)), como `scheduledTasksCron.js`.

```
PIPELINE cerebroConsolidacao(clinicaId, data):

  ETAPA 1 · COLETA (sem LLM)
    - agendamentos do dia (realizados, faltas, cancelamentos, encaixes)
    - alertas disparados, scores críticos, eventos de overbooking
    - notas criadas/editadas por humanos hoje
    - conversas de IA encerradas hoje (tb_ia_chats)
    - avaliações e feedbacks recebidos

  ETAPA 2 · NOTA DIÁRIA (1 chamada LLM, modelo Flash)
    Gera diario/2026-08-19.md com seções fixas:
      ## Números do dia      (tabela, gerada por código, SEM LLM — nunca alucina)
      ## O que aconteceu     (3-6 bullets narrativos, com wikilinks)
      ## Anomalias           (desvios > 2σ da média de 28 dias)
      ## Perguntas em aberto (o que os dados não explicam)
    Linka automaticamente: [[diario/2026-08-18]] (anterior) e MOCs das entidades citadas.

  ETAPA 3 · PROMOÇÃO DE PADRÕES (LLM Pro, só se houver sinal)
    Se um mesmo padrão aparece em ≥ 3 notas diárias dos últimos 21 dias
    E ainda não existe nota permanente sobre ele:
      → cria padroes/{slug}.md  (tipo: analise, estado: rascunho, confianca: X)
      → linka as diárias de origem como evidência
      → cria sugestão para o gestor revisar
    ⚠ NUNCA publica direto se confianca < 0.80 ou se o padrão contradiz
      uma nota com tipo=decisao revisada por humano.

  ETAPA 4 · MANUTENÇÃO DO GRAFO (sem LLM)
    - recalcula PageRank, Louvain, componentes, órfãs
    - grava tb_cerebro_snapshots (posições + métricas)
    - marca notas com revisar_em vencido

  ETAPA 5 · SUGESTÕES (§8.3)
    - roda os 8 detectores; grava no máximo 12 pendentes

  ETAPA 6 · PODA (sem LLM)
    - arquiva rascunhos do agente não revisados há > 45 dias
    - aplica retenção tiered de versões
    - expira sugestões com > 30 dias

  ETAPA 7 · REVISÃO SEMANAL (domingos)
    - gera revisoes/2026-S33.md: o que mudou, o que cresceu, o que
      estagnou, top 5 notas por PageRank, ilhas novas, dívida de curadoria
    - notifica gestores via tb_notificacoes + e-mail (SendGrid)
```

**Orçamento por execução:** ≤ 3 chamadas LLM/dia em condição normal; ≤ 8 no domingo. Custo estimado < US$ 0,04/clínica/dia com DeepSeek-V4-Flash. Registrado em [`CUSTO.md`](../CUSTO.md).

**Idempotência:** a rotina é reexecutável para a mesma data sem duplicar notas (chave `diario/{data}` + campo `consolidacaoRunId`). Falha na etapa 3 não impede as etapas 4–6.

---

## 9. Integração com o Agente (MCP)

### 9.1 Catálogo de tools

Registradas em `core/modules/mcp/tools/cerebro_tools.dart`, seguindo o padrão de `McpTool` já existente no projeto.

| # | Tool | Tipo | Descrição resumida |
|---|---|---|---|
| 1 | `cerebro_buscar` | leitura | Busca híbrida (texto + semântica + grafo) |
| 2 | `cerebro_ler` | leitura | Lê nota com backlinks/vizinhança opcionais |
| 3 | `cerebro_grafo` | leitura | Retorna subgrafo em torno de um nó |
| 4 | `cerebro_vizinhos` | leitura | KNN semântico de uma nota |
| 5 | `cerebro_caminho` | leitura | Menor caminho entre 2 nós (por que A e B se conectam?) |
| 6 | `cerebro_listar` | leitura | Lista com filtros (tag/tipo/estado/período) |
| 7 | `cerebro_escrever` | **escrita** | Cria/atualiza nota (4 modos) |
| 8 | `cerebro_linkar` | **escrita** | Cria link explícito entre 2 notas |
| 9 | `cerebro_taguear` | **escrita** | Adiciona/remove tags |
| 10 | `cerebro_mover` | **escrita** | Renomeia/move com atualização em cascata |
| 11 | `cerebro_arquivar` | **escrita** | Arquiva (soft) |
| 12 | `cerebro_diario` | **escrita** | Abre/cria nota diária e faz append em seção |
| 13 | `cerebro_canvas` | **escrita** | Cria/edita canvas |
| 14 | `cerebro_reverter` | **escrita** | Reverte nota para versão anterior |

### 9.2 Contratos (JSON Schema)

```jsonc
// ── 1. cerebro_buscar ─────────────────────────────────────────────────────
{
  "name": "cerebro_buscar",
  "description": "Busca no Cérebro (segundo cérebro da clínica). Use SEMPRE antes de responder qualquer pergunta que possa já ter sido analisada antes. Retorna trechos com caminho, tipo, confiança e proveniência.",
  "parameters": {
    "type": "object",
    "properties": {
      "consulta": { "type": "string", "description": "Pergunta ou termos em linguagem natural." },
      "modo": { "type": "string", "enum": ["texto","semantico","hibrido"], "default": "hibrido" },
      "tags": { "type": "array", "items": {"type":"string"} },
      "tipos": { "type": "array", "items": {"type":"string","enum":["nota","moc","diario","conceito","protocolo","analise","relatorio","reuniao","decisao","pessoa","fonte","memoria"]} },
      "periodo": { "type": "object", "properties": {"de":{"type":"string","format":"date"},"ate":{"type":"string","format":"date"}} },
      "incluirRascunhos": { "type": "boolean", "default": false },
      "limite": { "type": "integer", "default": 8, "maximum": 25 }
    },
    "required": ["consulta"]
  }
}
// Retorno:
// { "total": 34, "resultados": [ { "id","path","titulo","tipo","trecho",
//    "score":0.91,"origem":"agente","confianca":0.71,"revisado":false,
//    "atualizadoEm":"…","inDegree":27,"tags":[…] } ] }

// ── 7. cerebro_escrever ───────────────────────────────────────────────────
{
  "name": "cerebro_escrever",
  "description": "Cria ou atualiza uma nota. Escreva no Cérebro sempre que produzir uma análise que valerá para o futuro. NÃO use para respostas triviais ou conversacionais.",
  "parameters": {
    "type": "object",
    "properties": {
      "path": { "type": "string", "description": "Ex.: 'agente/analises/faltas-segunda.md'. Notas do agente DEVEM ficar sob 'agente/'." },
      "titulo": { "type": "string" },
      "conteudo": { "type": "string", "description": "Markdown VFM. Use [[wikilinks]] fartamente e [[@tipo:id]] para entidades. NUNCA escreva nome, CPF ou telefone de paciente." },
      "modo": { "type": "string", "enum": ["criar","substituir","append","patch"], "default": "criar" },
      "secao": { "type": "string", "description": "Para modo=append: heading sob o qual inserir." },
      "tipo": { "type": "string", "default": "analise" },
      "tags": { "type": "array", "items": {"type":"string"} },
      "frontmatter": { "type": "object" },
      "confianca": { "type": "number", "minimum": 0, "maximum": 1,
                     "description": "OBRIGATÓRIO. Sua confiança real na análise. Seja honesto: < 0.7 vira rascunho para revisão humana." },
      "motivo": { "type": "string", "description": "OBRIGATÓRIO. Por que esta nota deve existir. Vai para a auditoria." }
    },
    "required": ["path","conteudo","confianca","motivo"]
  }
}
// Retorno: { "ok":true, "id":"nt_…", "versao":3, "estado":"rascunho",
//            "linksResolvidos":12, "linksQuebrados":["Protocolo X"],
//            "avisos":["'Protocolo X' não existe — considere criar."] }

// ── 5. cerebro_caminho ────────────────────────────────────────────────────
{
  "name": "cerebro_caminho",
  "description": "Descobre COMO dois conceitos/entidades se conectam no cérebro. Use para perguntas do tipo 'o que a Dra. Helena tem a ver com o pico de faltas?'.",
  "parameters": {
    "type":"object",
    "properties": {
      "de":   {"type":"string","description":"nt_… ou @tipo:id ou título"},
      "para": {"type":"string"},
      "maxSaltos": {"type":"integer","default":4,"maximum":6},
      "maxCaminhos": {"type":"integer","default":3}
    },
    "required":["de","para"]
  }
}
// Retorno: { "caminhos":[ { "saltos":3,
//   "no":[{"id","titulo","tipo"},…],
//   "via":[{"aresta":"wiki","contexto":"…trecho que criou a ligação…"},…] } ] }
```

> Os 11 contratos restantes seguem o mesmo padrão e ficam versionados em `lib/core/modules/mcp/tools/cerebro_tools.dart`. Todo contrato **deve** ter `description` escrita para o modelo (quando usar, quando não usar), não para o desenvolvedor.

### 9.3 Política de escrita do agente

```
┌─ Toda escrita do agente passa por este guarda ────────────────────────────┐
│                                                                            │
│  1. NAMESPACE                                                              │
│     path DEVE começar com "agente/" — exceto:                              │
│       • diario/*        (via cerebro_diario)                               │
│       • padroes/*       (via consolidação, com confiança ≥ 0.80)           │
│     Tentar escrever em "protocolos/" ou "decisoes/" → ERRO.                │
│     Rationale: o agente propõe; o humano promove. Conhecimento              │
│     normativo da clínica só é escrito por gente.                           │
│                                                                            │
│  2. CONFIANÇA                                                              │
│     confianca ≥ 0.85  → estado "publicada"                                 │
│     0.60 ≤ c < 0.85   → estado "rascunho" + sugestão de revisão            │
│     confianca < 0.60  → REJEITADO; devolve "elabore mais ou colete dados"  │
│                                                                            │
│  3. PII (§14)                                                              │
│     Regex barra CPF, telefone, e-mail, CNS e nomes de pacientes            │
│     conhecidos no corpo. Violação → escrita rejeitada + evento de          │
│     segurança + a tool devolve instrução de usar [[@paciente:id]].         │
│                                                                            │
│  4. TAXA                                                                   │
│     ≤ 20 escritas por sessão de chat · ≤ 200 por dia por clínica.          │
│     Estouro → tool devolve erro amigável e a UI mostra aviso.              │
│                                                                            │
│  5. IDEMPOTÊNCIA                                                           │
│     Hash (path + conteudo) igual à versão atual → no-op, retorna ok.       │
│     Evita loop de reescrita idêntica.                                      │
│                                                                            │
│  6. ANTI-CICLO                                                             │
│     Uma nota criada pelo agente não pode virar fonte primária de           │
│     outra nota do agente dentro de 24 h (evita fabricação em cascata).     │
│     Detectado via campo `derivadaDe` + timestamp.                          │
│                                                                            │
│  7. AUDITORIA                                                              │
│     Todo write grava tb_cerebro_eventos com diff, motivo, toolCallId       │
│     e o modelo/versão usados. Imutável.                                    │
│                                                                            │
│  8. APROVAÇÃO (se config.escritaAgenteRequerAprovacao)                     │
│     Escrita fica pendente e aparece como card no chat com                  │
│     "Aprovar / Editar / Descartar" antes de tocar o vault.                 │
└────────────────────────────────────────────────────────────────────────────┘
```

### 9.4 Prompt de sistema — adendo do Cérebro

Anexado ao system prompt existente do `AiAgentService` quando o Cérebro está ativo:

```
Você tem acesso ao CÉREBRO da clínica: um segundo cérebro em grafo com notas,
protocolos, decisões, análises anteriores e entidades operacionais.

PROTOCOLO OBRIGATÓRIO
1. ANTES de responder qualquer pergunta analítica, chame `cerebro_buscar`.
   O cérebro provavelmente já sabe. Repetir análise que já existe é desperdício
   e gera contradição.
2. Ao citar algo do cérebro, referencie o caminho: (ver [[protocolos/confirmacao-48h]]).
3. Notas marcadas "gerada por IA / não revisada" NÃO são fato estabelecido.
   Trate como hipótese. Se dados operacionais contradisserem, os DADOS vencem —
   e avise que a nota precisa de correção.
4. DEPOIS de produzir uma análise não-trivial, chame `cerebro_escrever`.
   Uma análise que não vira nota é uma análise perdida.
5. Ligue o que escrever: sempre inclua [[wikilinks]] para notas relacionadas
   (descubra-as com `cerebro_buscar`) e [[@tipo:id]] para entidades citadas.
   Nota sem links é nota órfã — o cérebro fica burro.
6. NUNCA escreva nome, CPF, telefone, e-mail ou CNS de paciente. Use
   [[@paciente:id]]. A interface resolve o nome para quem tem permissão.
7. Sua `confianca` deve ser honesta. Inflacionar confiança para publicar
   direto é a pior coisa que você pode fazer aqui.
8. Se encontrar contradição entre duas notas, NÃO escolha silenciosamente:
   diga qual é, e proponha a resolução ao humano.
```

### 9.5 Ciclo autônomo (visão temporal)

```
 02:00  scheduledTasksCron  → scores de absenteísmo         [já existe]
 02:30  cerebroConsolidacao → etapas 1-6 (§8.5)             [novo]
 02:50  cerebroMetricas     → PageRank/Louvain/snapshot     [novo]
 03:00  cerebroEmbeddings   → fila de reindexação           [novo]
 07:30  briefingMatinal     → e-mail ao gestor com o link
                              da nota diária + 3 sugestões  [estende existente]
 Dom 04:00  revisaoSemanal  → revisoes/YYYY-Snn.md          [novo]
 Contínuo  onWrite(nota)    → espelho meta + tags + fila de embedding
```

---

## 10. UI/UX — Especificação de Interface

### 10.0 Mapeamento imagem → especificação

| Imagem | O que ela estabelece | Seção que a implementa |
|---|---|---|
| `4.jpg` | **Anatomia mestra**: 4 zonas (rail + explorer / editor / grafo local / outline+backlinks). Densidade tipográfica, hierarquia de listas de wikilinks, painel "Linked mentions" com trecho + chip destacado. | §10.1 – §10.4, §10.7 |
| `2.jpg` | **Grafo em tela cheia**: fundo escuro azulado, rótulos por nó, nós coloridos por grupo (amarelo/magenta/vermelho/azul), controles ⚙ e 🔗 no canto superior direito do painel, **status bar** inferior direita com contagens. | §10.5, §10.10 |
| `Sem título.jpg` | **Escala e proporção**: nós dimensionados por grau, hub rosa dominante, arestas cinza finas de baixo contraste, alta densidade sem virar mingau. | §7.5, §10.5.3 |
| `3.jpg` | **Grafo local hub-and-spoke**: nó central azul rotulado com satélites laranja igualmente espaçados. Referência direta para o layout radial ancorado. | §7.7, §10.5.4 |
| `5.jpg` | **Modo Analítico**: painel esquerdo de **facetas** com contagens, sparklines e barras; centro com **modo foco** (arestas ciano irradiando); painel direito **inspector** do item selecionado (título, categorias, autores, link, resumo); abas superiores **Network / Flow / List**; status bar descritiva. | §10.6 |

---

### 10.1 Anatomia global (desktop ≥ 1440 px)

Derivada de `4.jpg`, ajustada ao design system do Vitta.

```
┌─┬──────────────────┬──────────────────────────────────────┬─────────────────────┐
│R│  PAINEL ESQUERDO │            ÁREA CENTRAL              │   PAINEL DIREITO    │
│A│      280 px      │              flex                    │       320 px        │
│I│  (200-420 resize)│                                      │  (260-460 resize)   │
│L├──────────────────┼──────────────────────────────────────┼─────────────────────┤
│ │ ┌──────────────┐ │ ┌─ abas ─────────────────────────┐   │ ┌─ acordeão ──────┐ │
│4│ │ 🔍 Buscar… ⌘K│ │ │ ▣ Absenteísmo ×│ ▣ Diário ×│ + │   │ │ ▸ PROPRIEDADES  │ │
│8│ └──────────────┘ │ ├────────────────────────────────┤   │ ├─────────────────┤ │
│p│                  │ │ ← → │ mocs/absenteismo.md  ⋯   │   │ │ ▾ SUMÁRIO       │ │
│x│ ▾ FIXADAS     3  │ ├────────────────────────────────┤   │ │  ● Absenteísmo  │ │
│ │   📌 Absenteísmo │ │                                │   │ │   ○ Diagnóstico │ │
│▣│   📌 Protocolos  │ │   # Absenteísmo — MOC          │   │ │   ○ Ações       │ │
│ │                  │ │                                │   │ ├─────────────────┤ │
│🔍│ ▾ PASTAS         │ │   links: [[Operação]] ·        │   │ │ ▾ VINCULADAS  27│ │
│ │  ▾ 📁 mocs    12 │ │          [[Indicadores]]       │   │ │  Padrão·Faltas  │ │
│#│    📄 absenteís..│ │                                │   │ │  "…impacto em   │ │
│ │    📄 operacao   │ │   > [!insight] Descoberta      │   │ │   [Absenteísmo] │ │
│⚡│  ▸ 📁 protocolos │ │   > Segundas 7h = 34% das      │   │ │   em março…"    │ │
│ │  ▸ 📁 diario  214│ │   > faltas ^insight-seg        │   │ ├─────────────────┤ │
│🕸│  ▸ 📁 agente   48│ │                                │   │ │ ▾ NÃO-VINC.    4│ │
│ │                  │ │   ## Diagnóstico               │   │ │  Reunião 02/09  │ │
│▦│ ▾ TAGS           │ │   - [[Padrão · Faltas]]        │   │ │  [ Vincular ]   │ │
│ │  #moc         18 │ │   - [[@medico:med_44]] 👩‍⚕️     │   │ ├─────────────────┤ │
│⚙│  #operacao    64 │ │                                │   │ │ ▾ SEMÂNTICOS   6│ │
│ │   └#absenteís.42 │ │   ```vitta-query               │   │ │  ▓▓▓▓▓░ 0.87    │ │
│ │  #protocolo   11 │ │   TABELA titulo, relevancia    │   │ │  Confirmação48h │ │
│ │                  │ │   DE tag(#operacao)            │   │ │  [+ Link] [ ✕ ] │ │
│ │ ▾ SUGESTÕES   ⑫  │ │   ```                          │   │ └─────────────────┘ │
│ │  ⚡ 3 links       │ ├────────────────────────────────┤   ├─────────────────────┤ │
│ │  ⚡ 1 duplicata   │ │  GRAFO LOCAL          ⚙ ⤢ ⟳   │   │                     │ │
│ │                  │ │        ○──────●                │   │  (painel direito    │ │
│ │                  │ │       ╱   ╲    ╲               │   │   pode alternar     │ │
│ │                  │ │      ○     ◉────○              │   │   para o grafo)     │ │
│ │                  │ │             ╲                  │   │                     │ │
│ │                  │ │              ○                 │   │                     │ │
│ │                  │ │  profundidade ●━━━○ 2   [tags] │   │                     │ │
│ └──────────────────┘ └────────────────────────────────┘   └─────────────────────┘ │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ✓ sinc  ·  2.140 notas  ·  8.921 links  ·  17 órfãs  ·  12 sugestões  ·  842 pal │
└──────────────────────────────────────────────────────────────────────────────────┘
```

**Zonas e regras:**

| Zona | Largura | Resize | Colapso | Persistência |
|---|---|---|---|---|
| Rail | 48 px fixo | não | não | — |
| Painel esquerdo | 280 px | 200–420 px, drag na borda | `Ctrl+B` | `SharedPreferences` por usuário |
| Área central | flex, mín. 480 px | — | — | — |
| Grafo local (dentro do centro) | 34% da altura | 20–60%, drag horizontal | ícone ⤢ | idem |
| Painel direito | 320 px | 260–460 px | `Ctrl+Shift+B` | idem |
| Status bar | 26 px fixo | não | ocultável em Config | idem |

**Divisórias:** `VerticalDivider(width: 1, color: AppColors.borderOf(context))`, com *hit area* de 8 px e cursor `SystemMouseCursors.resizeColumn`. Duplo clique na divisória → restaura largura padrão.

### 10.2 Rail (barra de ícones, 48 px)

Espelha a coluna de ícones à esquerda em `2.jpg` e `4.jpg`.

| Ordem | Ícone (Material) | Painel | Atalho | Badge |
|---|---|---|---|---|
| 1 | `folder_outlined` | Explorer (pastas/arquivos) | `Ctrl+Shift+E` | — |
| 2 | `search` | Busca global | `Ctrl+Shift+F` | — |
| 3 | `tag_outlined` | Tags | `Ctrl+Shift+T` | — |
| 4 | `bolt_outlined` | Sugestões da IA | `Ctrl+Shift+S` | contagem (âmbar) |
| 5 | `hub_outlined` | Grafo global | `Ctrl+G` | — |
| 6 | `analytics_outlined` | Modo analítico | `Ctrl+Shift+A` | — |
| 7 | `dashboard_customize_outlined` | Canvas | `Ctrl+Shift+C` | — |
| 8 | `today_outlined` | Nota diária de hoje | `Ctrl+D` | ponto se não criada |
| 9 | `bookmark_outline` | Favoritas | — | — |
| 10 | `history` | Recentes / histórico | — | — |
| — | *(spacer)* | | | |
| 11 | `psychology_outlined` | **Voltar ao chat da IA** | `Ctrl+I` | ponto se agente ativo |
| 12 | `settings_outlined` | Config do vault | `Ctrl+,` | — |

Estados: repouso `textSecondary` · hover `surfaceAlt` de fundo + `textPrimary` · ativo barra de 3 px `pinkAccent` na esquerda + ícone `pinkAccent`. Tooltip à direita após 600 ms com nome + atalho.

### 10.3 Painel esquerdo — os 5 modos

**10.3.1 Explorer** — árvore com pastas colapsáveis (indentação 14 px por nível, guia vertical de 1 px em `border`). Item: `[ícone 16] título · [contador]`. Ícone por `NotaTipo`. Notas do agente ganham `✦` sutil em `pinkAccent`. Rascunhos ficam em itálico 70% de opacidade. Menu de contexto: Abrir · Abrir em painel · Renomear · Mover · Duplicar · Nova nota aqui · Copiar wikilink · Arquivar · Ver histórico · Ver no grafo. Drag & drop reordena e move (com aviso de "N links serão reescritos").

**10.3.2 Busca** — campo + resultados agrupados por nota, com até 3 trechos por nota e o termo destacado em `pinkAccent` sobre `pinkAccentLight` (tema claro) / `pinkAccent@18%` (escuro). Chips de operadores rápidos abaixo do campo: `tag:` `path:` `tipo:` `origem:agente` `semelhante:`. Contador "34 resultados em 21 notas · 28 ms".

**10.3.3 Tags** — lista hierárquica (ver `4.jpg`, canto inferior esquerdo). Cada linha: `#tag` + contagem alinhada à direita. Clique filtra; `Ctrl`+clique adiciona ao filtro do grafo; menu de contexto permite atribuir cor (vira `GrupoGrafo`).

**10.3.4 Sugestões** — cartões (§8.3), no máximo 12.

**10.3.5 Recentes/Favoritas** — listas simples com timestamp relativo ("há 12 min").

### 10.4 Editor (área central)

**Abas**: reordenáveis por drag, fecháveis, com `⋯` para "fechar outras / fechar à direita / dividir à direita / dividir abaixo". Máximo de 12 abas visíveis, depois overflow em menu. Aba com alterações não salvas mostra `●` em vez do `×`.

**Barra de contexto** (abaixo das abas): `←` `→` navegação · breadcrumb do path (clicável por segmento) · indicador de estado (`rascunho` âmbar / `IA ✦ 0.71` / `revisada ✓`) · `⋯` menu.

**Modos de visualização** (`Ctrl+E` alterna):

| Modo | Comportamento |
|---|---|
| **Live Preview** (padrão) | Formatação renderizada; a sintaxe do elemento sob o cursor "abre" para edição. Wikilinks clicáveis com `Ctrl`. |
| **Edição** | Markdown cru com *syntax highlighting* (wikilinks azul, tags amarelo, headings bold + cor por nível, callouts com barra colorida). |
| **Leitura** | Só renderizado; largura máxima de linha de 78ch centralizada; clique simples navega. |

**Tipografia do editor:**

| Elemento | Fonte | Tamanho | Peso | Cor | Espaçamento |
|---|---|---|---|---|---|
| H1 | Poppins | 28 | 700 | `textPrimary` | 32/16 |
| H2 | Poppins | 21 | 600 | `textPrimary` | 28/10 |
| H3 | Poppins | 17 | 600 | `textPrimary` | 22/8 |
| Corpo | Inter | 15 | 400 | `textPrimary` | 1,65 leading |
| Código inline | JetBrains Mono | 13,5 | 400 | `secondary` | fundo `surfaceAlt`, raio 4 |
| Bloco de código | JetBrains Mono | 13,5 | 400 | — | fundo `surfaceAlt`, raio 8, padding 12 |
| Wikilink | Inter | 15 | 500 | `primary` | sem sublinhado; sublinha no hover |
| Tag | Inter | 13 | 500 | `warning` | pílula `warningLight`, raio 999 |
| Citação | Inter | 15 | 400 itálico | `textSecondary` | barra esquerda 3 px `border` |

Largura de leitura confortável: `min(760px, 100%)`, centralizada, com opção "largura total" na config.

**Autocomplete** — dispara em `[[`, `#`, `/`, `@`:

```
┌────────────────────────────────────────────┐
│ [[abs                                      │
├────────────────────────────────────────────┤
│ 📄 Absenteísmo — MOC          mocs/     ⏎ │  ← seleção
│ 📊 Padrão · Faltas de Segunda padroes/     │
│ 📋 Protocolo de Confirmação   protocolos/  │
│ ─────────────────────────────────────────  │
│ ✦ Criar "abs"                              │
└────────────────────────────────────────────┘
```

- Máximo de 8 itens + ação "criar".
- Ranking: alias exato → título prefixo → fuzzy → recência → PageRank.
- `↑↓` navega, `⏎` insere, `Tab` insere e continua com `|` para alias, `Esc` fecha.
- `#` lista tags existentes (com contagem); `/` lista comandos de bloco (tabela, callout, query, embed, data, template); `@` lista entidades operacionais com busca ao vivo em `tb_pacientes`/`tb_medicos`.

**Hover preview**: passar 500 ms sobre um wikilink abre um cartão flutuante de 380×260 px com o início da nota, com sombra `elevation 8` e seta apontando para o link. `Ctrl` + hover trava o cartão (permite rolar dentro).

### 10.5 Painel de Grafo

#### 10.5.1 Cabeçalho (referência: `2.jpg`, canto superior direito)

```
┌───────────────────────────────────────────────────────────────────────┐
│  Grafo global                          🔍 filtrar…    ⚙   ⛓   ⤢   ⋯  │
└───────────────────────────────────────────────────────────────────────┘
```

- **⚙ Configurações** → popover com Filtros / Grupos / Exibição / Forças (§10.5.2)
- **⛓ Forças** → atalho direto para o grupo "Forças"
- **⤢ Tela cheia** → o grafo assume toda a área central
- **⋯** → Exportar PNG · Exportar SVG · Copiar como Mermaid · Salvar visão · Restaurar padrões

#### 10.5.2 Popover de configuração (4 grupos colapsáveis)

```
╔═ FILTROS ═══════════════════════════════════╗
║ Busca         [ tag:#operacao -tipo:diario ]║
║ ☑ Tags              ☑ Anexos                ║
║ ☐ Links não resolvidos                      ║
║ ☑ Entidades operacionais                    ║
║ ☐ Arestas semânticas (tracejadas)           ║
║ ☐ Notas arquivadas                          ║
║ Origem   ( Todas | Humano | IA )            ║
╠═ GRUPOS ════════════════════════════════════╣
║ ● #moc                        [#F43F5E] ✕   ║
║ ● tipo:protocolo              [#2E9E8F] ✕   ║
║ ● @paciente                   [#0EA5E9] ✕   ║
║ ● origem:agente               [#7C3AED] ✕   ║
║ [ + Novo grupo ]                            ║
║ ☐ Colorir por cluster (Louvain) — auto      ║
╠═ EXIBIÇÃO ══════════════════════════════════╣
║ Rótulos       ●━━━━━━○━━━━━  auto           ║
║ Tamanho nós   ━━━━●━━━━━━━━  1.6            ║
║ Espessura     ━━●━━━━━━━━━━  0.8            ║
║ Setas         ☐   Animar fluxo   ☑          ║
║ Profundidade  ●━━○━━━━  2   (grafo local)   ║
║ Modo foco ao selecionar          ☑          ║
╠═ FORÇAS ════════════════════════════════════╣
║ Central       ━━●━━━━━━━━━━  0.03           ║
║ Repulsão      ━━━━━●━━━━━━━  5.6            ║
║ Dist. links   ━━━━●━━━━━━━━  42             ║
║ Atrito        ━━━━━━●━━━━━━  0.62           ║
║ [ Reaquecer ]  [ Restaurar padrões ]        ║
╚═════════════════════════════════════════════╝
```

#### 10.5.3 Paleta do grafo

Fundo escuro por padrão (todas as referências visuais usam tema escuro), acompanhando o tema do app quando o usuário escolhe claro.

| Elemento | Escuro | Claro |
|---|---|---|
| Fundo | `#0F1320` | `#F4F6FA` |
| Grade (opcional, 40 px) | `#FFFFFF @ 3%` | `#000000 @ 3%` |
| Aresta padrão | `#2D3446` | `#D3D9E4` |
| Aresta destacada | `#F43F5E` | `#F43F5E` |
| Aresta semântica | `#7C3AED` tracejada 4-3 | idem |
| Rótulo | `#A0A8B8` | `#6B7280` |
| Rótulo em foco | `#F2F4F8` | `#1A1D29` |
| Halo de seleção | `#F43F5E @ 35%` blur 3 | idem |

**Cores por tipo de nó** (padrão quando não há grupo manual):

| Tipo | Cor | Hex | Racional |
|---|---|---|---|
| MOC / hub | Rosa | `#F43F5E` | Hub dominante de `Sem título.jpg`; é a cor de acento da IA no app |
| Nota | Slate | `#94A3B8` | Neutra, maioria silenciosa |
| Conceito | Violeta | `#7C3AED` | Já usado para "privada" no app |
| Protocolo | Teal | `#2E9E8F` | `AppColors.secondary` — normativo/saudável |
| Análise (IA) | Azul | `#1B53D0` | `AppColors.primary` |
| Diário | Cinza-azulado | `#64748B` | Fundo temporal, não compete |
| Decisão | Âmbar | `#C77700` | `AppColors.warning` |
| Paciente | Sky | `#0EA5E9` | Entidade, distinta de conhecimento |
| Médico | Esmeralda | `#10B981` | — |
| Consulta | Laranja | `#F59E0B` | Satélites laranja de `3.jpg` |
| Alerta/Risco | Vermelho | `#C62828` | `AppColors.danger` |
| Tag | Amarelo | `#FACC15` | Amarelo dominante de `2.jpg` |
| Não resolvido | Contorno | `#475569` vazado, 1 px tracejado | Convenção Obsidian |

Nós de nota do agente ganham um anel externo de 1,5 px em `#7C3AED` — permite ver de relance quanto do cérebro foi escrito por IA.

#### 10.5.4 Grafo local (referência `3.jpg` e painel superior de `4.jpg`)

Cabeçalho compacto: título "Grafo local" + slider de profundidade + toggles `[tags] [entidades] [semânticos]` + botão de tela cheia. Layout radial ancorado (§7.7). O nó focal recebe rótulo sempre visível em negrito e um halo permanente.

#### 10.5.5 Vazios e carregamento

| Situação | Tela |
|---|---|
| Vault vazio | Ilustração + "Seu cérebro está vazio." + botões **Criar primeira nota** / **Importar vault (.zip)** / **Deixar a IA semear** (gera 8 notas-base a partir dos dados da clínica) |
| Nota sem links | "Esta nota ainda não se conectou a nada." + botão "Ver 6 sugestões semânticas" |
| Filtro sem resultado | "Nenhum nó passa neste filtro." + botão "Limpar filtros" |
| Carregando | Esqueleto: 40 círculos cinza em posições fixas com shimmer 1,2 s (nunca spinner genérico) |
| Grafo grande demais | Aviso "12.400 nós — mostrando os 3.000 mais relevantes por PageRank" + botão "Mostrar tudo (pode travar)" |

### 10.6 Modo Analítico (referência: `5.jpg`)

Visão "cientista de dados do próprio cérebro". Ocupa a área central inteira, com layout próprio de 3 colunas.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ CÉREBRO · Analítico   [🔍 buscar no grafo…]   Rede │ Fluxo │ Lista      ⓘ ⚙ │
├──────────────┬───────────────────────────────────────┬───────────────────────┤
│  FACETAS     │              GRAFO (modo foco)        │      INSPECTOR        │
│   264 px     │                 flex                  │        320 px         │
├──────────────┼───────────────────────────────────────┼───────────────────────┤
│ [Tudo][Notas]│                                       │ Nó selecionado        │
│ [Entid][Tags]│              ○     ○                  │ ───────────────────── │
│              │           ╲  │  ╱                     │ Padrão · Faltas de    │
│ ▾ NOTAS  2140│         ○───◉───○      ○              │ Segunda               │
│ ▁▂▃▅▇▆▅ +12%│           ╱  │  ╲    ╱                 │                       │
│ moc       18 │          ○   ○   ○──○                 │ Tipo:    análise ✦IA  │
│ protocolo 11 │                                       │ Conf.:   0.71 ⚠       │
│ análise   96 │        (arestas destacadas em         │ Estado:  rascunho     │
│ diário   214 │         ciano irradiando do nó        │ Criada:  12/03/2026   │
│              │         selecionado)                  │ Autor:   agt_absent.  │
│ ▾ ENTID.  842│                                       │ ───────────────────── │
│ ▓▓▓▓▓▓░ pac  │                                       │ MÉTRICAS              │
│ ▓▓▓░░░░ méd  │                                       │ PageRank  0.0184  #7  │
│ ▓▓░░░░░ cons │                                       │ Entradas  27          │
│              │                                       │ Saídas    12          │
│ ▾ TAGS    312│                                       │ Cluster   #3 Operação │
│ #operacao 64 │                                       │ Ponte     🌉 sim      │
│ #moc      18 │                                       │ ───────────────────── │
│ #q3       27 │                                       │ RESUMO (IA)           │
│              │                                       │ Concentração de       │
│ ▾ ORIGEM     │                                       │ faltas em segundas    │
│ humano   61% │                                       │ 7h-8h, ligada à não   │
│ IA ✦     39% │                                       │ aplicação do protoc…  │
│              │                                       │ ───────────────────── │
│ ▾ PERÍODO    │                                       │ CONEXÕES  (27)        │
│ ▁▃▅▇▅▃▁ 90d │                                       │ → [[Confirmação 48h]] │
│ [====●===]   │                                       │ → [[@medico:med_44]]  │
│              │                                       │ ───────────────────── │
│ [ Limpar ]   │                                       │ [Abrir] [Grafo local] │
├──────────────┴───────────────────────────────────────┴───────────────────────┤
│ 2.140 nós · 8.921 arestas · 7 componentes · densidade 0.0039 · Louvain: 11 cl.│
└──────────────────────────────────────────────────────────────────────────────┘
```

**Painel de facetas** (esquerda) — cada grupo traz:
- Contagem total à direita do nome (como "Papers (30)", "Citations (1326)" em `5.jpg`).
- **Sparkline** de 90 dias mostrando crescimento, com variação percentual colorida (verde/vermelho).
- **Barras horizontais** proporcionais para os 5 principais itens (as barras azuis de "Affiliations" em `5.jpg`).
- Clique = filtro; `Ctrl`+clique = adiciona; clique com o filtro ativo = remove. Filtros ativos viram chips removíveis no topo.

**Abas superiores:**

| Aba | O que mostra |
|---|---|
| **Rede** | O grafo (padrão) |
| **Fluxo** | Sankey temporal: como o conhecimento flui — evento operacional → nota diária → padrão promovido → protocolo/decisão. Revela onde o cérebro trava (ex.: "34 padrões detectados, 3 viraram protocolo"). |
| **Lista** | Tabela densa ordenável: título, tipo, PageRank, entradas, saídas, cluster, origem, confiança, atualizado. Multi-seleção com ações em lote. Exporta CSV/XLSX (o projeto já tem `excel` e `file_saver`). |

**Inspector** (direita) — espelha o painel "Selected Article" de `5.jpg`: identidade, categorias, proveniência, link para abrir, métricas, resumo gerado por IA (cacheado por versão da nota) e lista de conexões.

**Status bar do analítico** — frase descritiva no lugar de números soltos, como em `5.jpg` ("30 papers for size: medium across last month"): *"2.140 nós · 8.921 arestas · 7 componentes · densidade 0.0039 · 11 clusters · atualizado há 6 h"*.

### 10.7 Painel direito — acordeão

Ordem fixa, cada seção colapsável e com estado persistido:

1. **Propriedades** — editor de frontmatter em formulário (chave/valor tipado: texto, data, número, lista, ref de nota, ref de entidade). Botão "+ propriedade".
2. **Sumário** — árvore de headings (H1–H4) com indentação e realce do heading visível no viewport (scroll spy). Clique rola até a seção. É o painel superior direito de `4.jpg`.
3. **Menções vinculadas** *(N)* — nome da nota de origem + trecho de contexto com o link destacado em pílula (exatamente o padrão de `4.jpg`). Agrupável por pasta.
4. **Menções não-vinculadas** *(N)* — mesmo layout + botão "Vincular" por item.
5. **Vizinhos semânticos** *(N)* — barra de similaridade + trecho + ações.
6. **Histórico** — timeline de versões com autor (👤 ou ✦), data e resumo do diff; clique abre comparação lado a lado; botão "Restaurar".

### 10.8 Canvas

Quadro infinito com pan/zoom (0,1×–4×), grade de 20 px com *snap* opcional.

- **Cartões**: nota (renderiza o conteúdo, redimensionável, com link vivo), texto livre, entidade (chip rico), imagem, grupo (retângulo rotulado que arrasta o conteúdo junto).
- **Arestas**: arrastar de uma das 4 alças laterais; rótulo editável; estilo sólido/tracejado; seta em uma ou nas duas pontas; cor da paleta de 6.
- **Barra de ferramentas** flutuante inferior-central: `+Nota` `+Texto` `+Entidade` `+Grupo` `Selecionar` `Conectar` `Zoom` `Enquadrar`.
- **Ação de IA**: "Organizar com IA" (agrupa cartões por tema e sugere arestas) e "Virar nota" (converte o canvas em uma nota estruturada com as conexões narradas).
- Formato de arquivo compatível com `.canvas` do Obsidian na exportação.

### 10.9 Command Palette e Quick Switcher

Estende `core/widgets/command_palette.dart` (já existente).

| Atalho | Ferramenta | Prefixos |
|---|---|---|
| `Ctrl+O` | **Quick Switcher** — abrir nota | vazio = recentes; `#` tag; `@` entidade; `>` comando; `?` ajuda |
| `Ctrl+P` | **Command Palette** — ações | busca fuzzy sobre ~70 comandos |
| `Ctrl+Shift+O` | Abrir em painel dividido | — |

Comandos do Cérebro registrados na paleta (extrato): Nova nota · Nova nota a partir de template · Nota diária de hoje · Nota diária de ontem · Inserir link `Ctrl+K` · Inserir embed · Inserir query · Inserir callout · Alternar preview · Abrir grafo global · Abrir grafo local · Abrir modo analítico · Renomear nota `F2` · Mover nota · Arquivar · Ver histórico · Exportar PDF/MD/ZIP · Vincular todas as menções · Perguntar à IA sobre esta nota · Resumir com IA · Expandir com IA · Encontrar contradições · Sugerir tags · Sugerir links · Consolidar agora · Ver auditoria da nota.

### 10.10 Status bar (referência: `2.jpg`, canto inferior direito)

Altura 26 px, `surfaceAlt`, texto 11 px `textSecondary`, itens separados por `·`, todos clicáveis:

```
✓ sinc há 3s │ 2.140 notas │ 8.921 links │ 17 órfãs │ ⚡12 │ 842 palavras │ 5.219 caracteres │ 3 min de leitura │ ⌘K
```

| Item | Clique |
|---|---|
| Status de sync | Painel de fila de sincronização; vermelho se offline com N pendentes |
| Notas / links | Abre modo analítico |
| Órfãs | Filtra explorer por `orfa:true` |
| ⚡ sugestões | Abre painel de sugestões |
| Palavras/caracteres | Alterna entre nota atual e seleção |
| Tempo de leitura | — |

### 10.11 Responsividade

Respeitando `core/utils/responsive.dart` e os breakpoints já usados em `ia_screen.dart` (1024 / 768).

| Faixa | Layout |
|---|---|
| **≥ 1440 px** | 4 zonas simultâneas (§10.1) |
| **1024–1439** | Painel direito vira *overlay* sobre o editor (`endDrawer`), acionado por botão; grafo local colapsa para 25% |
| **768–1023 (tablet)** | Rail + 1 painel por vez. Explorer e editor alternam por *segmented control* no topo. Grafo em tela cheia sob demanda. |
| **< 768 (mobile)** | Navegação em pilha: Explorer → Nota → (aba inferior: Conteúdo / Grafo / Links / Info). Editor otimizado para toque com barra de formatação acima do teclado (`[[`, `#`, `- [ ]`, `>`, `**`, `` ` ``). Grafo limitado a 400 nós, sem rótulos abaixo de zoom 1,5×, colisão desligada. |

**Mobile — regras específicas:**
- Toque longo em nó do grafo = menu de contexto (evita conflito com pan).
- Pinça só faz zoom; um dedo faz pan.
- Autocomplete vira bottom sheet.
- Painel direito vira aba, nunca overlay lateral.

### 10.12 Design tokens e motion

**Espaçamento** — reutiliza `AppSpacing` (4/8/12/16/24/32) e `radiusMd`.

**Elevação:** painéis 0 (só borda) · popovers 8 · hover preview 8 · diálogos 16 · toasts 6.

**Motion:**

| Transição | Duração | Curva |
|---|---|---|
| Abrir/fechar painel | 220 ms | `Curves.easeOutCubic` |
| Trocar aba | 140 ms | `easeOut` |
| Hover preview (fade+scale 0.96→1) | 160 ms | `easeOutBack` leve |
| Foco no grafo (esmaecer resto) | 320 ms | `easeInOut` |
| Nó entrando no grafo | 400 ms | `elasticOut` (escala 0→1) |
| Câmera "voar até o nó" | 600 ms | `easeInOutCubic` |
| Fluxo de aresta (dash offset) | 900 ms loop | `linear` |
| Shimmer de esqueleto | 1200 ms loop | `easeInOut` |

Tudo respeita `MediaQuery.disableAnimations` / `prefers-reduced-motion`: com movimento reduzido, o grafo pula direto para a posição final (usa o snapshot, sem simulação animada).

### 10.13 Acessibilidade

- **Contraste**: todo texto ≥ 4,5:1; rótulos do grafo ≥ 3:1 contra o fundo. `#A0A8B8` sobre `#0F1320` = 7,1:1 ✓.
- **Cor nunca é o único canal**: nós têm forma por categoria (círculo = nota, losango = entidade, quadrado = tag, triângulo = alerta) além da cor. Integra `core/utils/color_blind.dart` já existente (paletas alternativas para deuteranopia/protanopia/tritanopia).
- **Teclado**: 100% navegável. `Tab` percorre painéis; dentro do grafo, `Tab` percorre nós por ordem de PageRank e `⏎` abre. Focus ring de 2 px `pinkAccent` sempre visível.
- **Leitores de tela**: cada nó do grafo expõe `Semantics(label: "Nota Absenteísmo, 27 entradas, 12 saídas, cluster Operação")`. O grafo inteiro tem alternativa textual: botão "Ver como lista" que abre a aba Lista com o mesmo filtro.
- **Zoom de fonte**: layout íntegro até 200% (`textScaleFactor`). Painéis crescem, não quebram.
- **Anúncios**: salvamento, conflito e conclusão de sugestão anunciados via `SemanticsService.announce`.

### 10.14 Atalhos de teclado (completo)

| Atalho | Ação | Atalho | Ação |
|---|---|---|---|
| `Ctrl+O` | Quick switcher | `Ctrl+G` | Grafo global |
| `Ctrl+P` | Command palette | `Ctrl+Shift+G` | Grafo local em tela cheia |
| `Ctrl+N` | Nova nota | `Ctrl+Shift+A` | Modo analítico |
| `Ctrl+D` | Nota diária de hoje | `Ctrl+B` | Painel esquerdo |
| `Ctrl+S` | Salvar agora | `Ctrl+Shift+B` | Painel direito |
| `Ctrl+E` | Alternar edição/leitura | `Ctrl+\` | Dividir à direita |
| `Ctrl+K` | Inserir wikilink | `Ctrl+Shift+\` | Dividir abaixo |
| `Ctrl+Shift+K` | Inserir entity-link | `Ctrl+W` | Fechar aba |
| `Ctrl+T` | Inserir tag | `Ctrl+Tab` | Próxima aba |
| `Ctrl+Shift+F` | Busca global | `Alt+←` / `Alt+→` | Voltar / avançar |
| `Ctrl+F` | Buscar na nota | `F2` | Renomear |
| `Ctrl+/` | Comentar linha (`%%`) | `Ctrl+Shift+I` | Perguntar à IA sobre a nota |
| `Ctrl+Shift+S` | Sugestões | `Ctrl+I` | Voltar ao chat |
| `Ctrl+,` | Config do vault | `Esc` | Fechar overlay / sair do foco |
| `Espaço` (no grafo) | Reaquecer simulação | `F` (no grafo) | Enquadrar tudo |
| `L` (no grafo) | Alternar rótulos | `1..9` (no grafo) | Profundidade do grafo local |

Todos configuráveis em Config → Atalhos, com detecção de conflito.

### 10.15 Estados de erro

| Erro | Tratamento |
|---|---|
| Offline ao salvar | Salva local, chip "1 pendente" na status bar, sincroniza ao voltar. Sem modal. |
| Conflito de versão | Barra âmbar no topo do editor: "Esta nota mudou em outro lugar" + [Ver diferenças] [Manter a minha] [Usar a de lá] |
| Nota > 900 KB | Aviso ao passar de 400 KB; migração automática para Storage com toast |
| Embedding falhou | Ícone ⚠ discreto no painel de semânticos, com "tentar de novo"; jamais bloqueia a edição |
| Grafo travou (3 frames > 33 ms) | Entra em modo performance e mostra chip com "Qualidade máxima" |
| Tool do agente rejeitada por PII | Card vermelho no chat com o motivo e o trecho ofensor mascarado |
| Firestore `permission-denied` | "Você não tem permissão para editar o Cérebro" + link "solicitar acesso" |

---

## 11. Estrutura de Arquivos (Flutter)

```
lib/features/cerebro/
│
├── cerebro_screen.dart                    # shell: rail + painéis + status bar
│
├── data/                                  # ── L1 PERSISTÊNCIA ──────────────
│   ├── models/
│   │   ├── nota.dart                      # Nota + NotaMeta + fromMap/toMap
│   │   ├── nota_enums.dart                # NotaTipo, NotaOrigem, NotaEstado
│   │   ├── aresta.dart                    # Aresta, LinkTipo
│   │   ├── entidade_ref.dart              # EntidadeRef, EntidadeTipo
│   │   ├── sugestao.dart
│   │   ├── canvas_board.dart
│   │   ├── vault_config.dart
│   │   └── versao_nota.dart
│   ├── nota_repository.dart               # CRUD + otimista + fila offline
│   ├── link_repository.dart               # tb_cerebro_links + backlinks servidor
│   ├── vetor_repository.dart              # tb_cerebro_vetores + findNearest
│   ├── sugestao_repository.dart
│   ├── canvas_repository.dart
│   ├── evento_repository.dart             # auditoria (append-only)
│   ├── snapshot_repository.dart
│   ├── vault_config_repository.dart
│   ├── storage_overflow.dart              # notas > 900KB → Cloud Storage
│   ├── sync_queue.dart                    # fila persistente + backoff
│   └── conflito_resolver.dart             # merge 3 vias
│
├── index/                                 # ── L2 ÍNDICE ────────────────────
│   ├── parser/
│   │   ├── parser_vfm.dart                # orquestrador do pipeline §6.1
│   │   ├── frontmatter.dart               # split + YAML mínimo (sem dep. externa)
│   │   ├── mascara_codigo.dart            # zonas proibidas
│   │   ├── tokenizer.dart                 # single-pass §6.3
│   │   ├── ast.dart                       # NotaAst, nós do AST
│   │   ├── extrator.dart                  # AST → links/tags/headings/blocos/stats
│   │   └── sintaxes_markdown.dart         # md.InlineSyntax p/ flutter_markdown
│   ├── vault_index.dart                   # os 6 índices §6.2
│   ├── indexador.dart                     # atualização incremental §6.4
│   ├── resolvedor_link.dart               # pipeline de resolução §5.2
│   ├── trigram_index.dart
│   ├── aho_corasick.dart                  # menções não-vinculadas §8.2
│   ├── bm25.dart
│   └── busca_service.dart                 # ranking híbrido + operadores §6.5
│
├── graph/                                 # ── L3 GRAFO ─────────────────────
│   ├── grafo_modelo.dart                  # GrafoNo, GrafoAresta, arrays paralelos
│   ├── grafo_engine.dart                  # ciclo de simulação, α, congelamento
│   ├── forcas/
│   │   ├── quadtree.dart                  # Barnes-Hut + query por região
│   │   ├── forca_repulsao.dart
│   │   ├── forca_mola.dart
│   │   ├── forca_centro.dart
│   │   ├── forca_colisao.dart
│   │   └── forca_radial.dart              # grafo local ancorado §7.7
│   ├── grafo_isolate.dart                 # simulação fora da UI (não-web)
│   ├── grafo_web_scheduler.dart           # fatiamento de 6 ms/frame (web)
│   ├── metricas/
│   │   ├── pagerank.dart
│   │   ├── louvain.dart
│   │   ├── componentes.dart
│   │   ├── intermediacao.dart
│   │   └── caminho_minimo.dart            # BFS bidirecional p/ cerebro_caminho
│   ├── grafo_builder.dart                 # VaultIndex → grafo (com filtros)
│   ├── grafo_filtro.dart                  # DSL de filtro + grupos de cor
│   ├── lod.dart                           # raio, rótulos, degradação §7.5
│   ├── label_cache.dart
│   ├── grafo_painter.dart                 # CustomPainter em camadas §7.4
│   └── grafo_hit_test.dart
│
├── semantic/                              # ── L4 SEMÂNTICA ─────────────────
│   ├── chunker.dart                       # heading-aware + overlap §8.1
│   ├── embedding_service.dart             # CF embedText + cache por hash
│   ├── embedding_queue.dart               # fila com backoff, persistente
│   ├── vector_store_local.dart            # int8 quantizado + cosseno
│   ├── knn_service.dart                   # findNearest + fallback
│   ├── rrf_fusion.dart                    # fusão recíproca de ranks §8.4
│   ├── reranker.dart
│   ├── sugestoes_engine.dart              # 8 detectores §8.3
│   └── redator_pii.dart                   # sanitização antes de embutir §14
│
├── agent/                                 # ── L5 AGENTE ────────────────────
│   ├── cerebro_tools.dart                 # 14 tools MCP §9.1-9.2
│   ├── politica_escrita.dart              # 8 guardas §9.3
│   ├── prompt_cerebro.dart                # adendo de system prompt §9.4
│   ├── consolidacao_service.dart          # cliente da rotina §8.5
│   ├── contexto_builder.dart              # monta o bloco de contexto RAG
│   └── aprovacao_service.dart             # fila de aprovação de escrita
│
├── bridge/                                # ── PONTE OPERACIONAL ────────────
│   ├── entidade_resolver.dart             # @tipo:id → NotaVirtual
│   ├── projetores/
│   │   ├── projetor_paciente.dart
│   │   ├── projetor_medico.dart
│   │   ├── projetor_agendamento.dart
│   │   ├── projetor_score.dart            # tb_absenteismo_scores
│   │   ├── projetor_overbooking.dart
│   │   └── projetor_alerta.dart
│   ├── entidade_cache.dart                # LRU + TTL 5 min
│   └── permissao_entidade.dart            # checagem por papel §14
│
├── providers/                             # ── L6 ESTADO ────────────────────
│   ├── vault_provider.dart
│   ├── nota_provider.dart
│   ├── editor_provider.dart
│   ├── abas_provider.dart
│   ├── busca_provider.dart
│   ├── grafo_provider.dart
│   ├── grafo_config_provider.dart
│   ├── backlinks_provider.dart
│   ├── semantico_provider.dart
│   ├── sugestoes_provider.dart
│   ├── analitico_provider.dart
│   ├── canvas_provider.dart
│   └── layout_provider.dart               # larguras, colapsos, painel ativo
│
├── ui/                                    # ── L7 APRESENTAÇÃO ──────────────
│   ├── rail/
│   │   └── cerebro_rail.dart
│   ├── esquerda/
│   │   ├── painel_esquerdo.dart
│   │   ├── explorer_tree.dart
│   │   ├── explorer_item.dart
│   │   ├── painel_busca.dart
│   │   ├── painel_tags.dart
│   │   ├── painel_sugestoes.dart
│   │   ├── card_sugestao.dart
│   │   └── painel_recentes.dart
│   ├── editor/
│   │   ├── area_editor.dart
│   │   ├── barra_abas.dart
│   │   ├── barra_contexto.dart
│   │   ├── editor_markdown.dart           # controller + highlight + live preview
│   │   ├── editor_controller.dart
│   │   ├── autocomplete_popup.dart
│   │   ├── hover_preview.dart
│   │   ├── renderizador_vfm.dart          # builders p/ flutter_markdown
│   │   ├── widgets_vfm/
│   │   │   ├── wikilink_span.dart
│   │   │   ├── entity_chip.dart
│   │   │   ├── embed_card.dart
│   │   │   ├── callout_box.dart
│   │   │   ├── tag_chip.dart
│   │   │   ├── task_item.dart
│   │   │   └── query_block_view.dart
│   │   └── query/
│   │       ├── query_parser.dart          # DSL §5.1
│   │       ├── query_executor.dart
│   │       └── query_render.dart          # tabela/lista/cartões/gráfico/kanban
│   ├── grafo/
│   │   ├── painel_grafo.dart
│   │   ├── grafo_view.dart                # gestos + painter + hit test
│   │   ├── grafo_config_popover.dart      # 4 grupos §10.5.2
│   │   ├── grafo_legenda.dart
│   │   ├── grafo_local_view.dart
│   │   └── grafo_vazio.dart
│   ├── analitico/
│   │   ├── analitico_screen.dart
│   │   ├── painel_facetas.dart
│   │   ├── faceta_grupo.dart              # contagem + sparkline + barras
│   │   ├── inspector_no.dart
│   │   ├── aba_rede.dart
│   │   ├── aba_fluxo.dart                 # sankey
│   │   └── aba_lista.dart
│   ├── direita/
│   │   ├── painel_direito.dart
│   │   ├── secao_propriedades.dart
│   │   ├── secao_sumario.dart
│   │   ├── secao_vinculadas.dart
│   │   ├── secao_nao_vinculadas.dart
│   │   ├── secao_semanticos.dart
│   │   └── secao_historico.dart
│   ├── canvas/
│   │   ├── canvas_screen.dart
│   │   ├── canvas_painter.dart
│   │   ├── canvas_card.dart
│   │   └── canvas_toolbar.dart
│   ├── comum/
│   │   ├── status_bar.dart
│   │   ├── nota_icone.dart
│   │   ├── badge_origem.dart              # ✦ IA + confiança
│   │   ├── barra_similaridade.dart
│   │   ├── diff_view.dart
│   │   └── estados_vazios.dart
│   └── dialogos/
│       ├── criar_nota_dialog.dart
│       ├── mover_nota_dialog.dart
│       ├── desambiguador_sheet.dart
│       ├── conflito_dialog.dart
│       ├── aprovacao_escrita_dialog.dart
│       ├── importar_vault_dialog.dart
│       └── exportar_dialog.dart
│
└── config/
    ├── cerebro_config_screen.dart
    ├── config_atalhos.dart
    └── config_grafo.dart

lib/core/modules/mcp/tools/
└── cerebro_tools.dart                     # registro das 14 tools no McpServer

cloud_functions/  (e functions/ — o projeto mantém as duas pastas em espelho)
├── embedText.js
├── cerebroConsolidacao.js
├── cerebroMetricas.js
├── cerebroSugestoes.js
├── cerebroOnWriteNota.js                  # espelho meta + tags + fila embedding
├── cerebroPurgaLgpd.js
└── cerebroRetencaoVersoes.js

test/cerebro/
├── parser_test.dart                       # 20 casos-limite §6.3
├── resolvedor_link_test.dart
├── indexador_incremental_test.dart
├── busca_ranking_test.dart
├── quadtree_test.dart
├── pagerank_test.dart
├── louvain_test.dart
├── caminho_minimo_test.dart
├── chunker_test.dart
├── redator_pii_test.dart
├── politica_escrita_test.dart
├── conflito_resolver_test.dart
├── arquitetura_test.dart                  # regra de dependência entre camadas
├── widget/
│   ├── explorer_test.dart
│   ├── editor_autocomplete_test.dart
│   ├── backlinks_test.dart
│   └── grafo_interacao_test.dart
├── golden/
│   ├── grafo_pequeno_escuro.png
│   ├── grafo_pequeno_claro.png
│   ├── editor_live_preview.png
│   └── analitico_facetas.png
└── perf/
    ├── parse_bench.dart
    ├── grafo_5000_bench.dart
    └── busca_bench.dart
```

**Contagem:** 78 arquivos Dart de produção + 7 Cloud Functions + 21 arquivos de teste.

---

## 12. Mapa de Estado (Riverpod)

```
                        ┌──────────────────────┐
                        │  clinicaAtualProvider│  (já existe no app)
                        └──────────┬───────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │      vaultProvider           │  AsyncNotifier<Vault>
                    │  carrega metas + índices     │  ← boot §4.9
                    └───┬───────────┬──────────┬───┘
                        │           │          │
     ┌──────────────────▼──┐  ┌─────▼──────┐  ┌▼────────────────────┐
     │ vaultIndexProvider  │  │explorerProv│  │ statusVaultProvider │
     │ (6 índices, keepAlive)│ │(árvore)   │  │ (contagens p/ bar)  │
     └───┬─────────┬───────┬┘  └────────────┘  └─────────────────────┘
         │         │       │
   ┌─────▼───┐ ┌───▼────┐ ┌▼─────────────┐
   │busca    │ │backlinks│ │ grafoProvider│  ← family(GrafoEscopo)
   │Provider │ │Provider │ │ Notifier     │     global | local(id) | filtrado
   │(family) │ │(family) │ └──┬───────────┘
   └─────────┘ └─────────┘    │
                              ├──▶ grafoConfigProvider  (forças, filtros, grupos)
                              ├──▶ grafoSelecaoProvider (nó selecionado/hover)
                              └──▶ grafoMetricasProvider(pagerank, clusters)

     ┌────────────────────────────────────────────────┐
     │ abasProvider  StateNotifier<List<AbaNota>>     │
     │   ↳ abaAtivaProvider                            │
     │        ↳ notaProvider.family(notaId)  Async     │  carrega conteúdo
     │             ↳ editorProvider.family(notaId)     │  buffer + dirty + undo
     │                  ↳ astProvider.family(notaId)   │  parse memoizado
     │                       ↳ sumarioProvider         │
     │                       ↳ propriedadesProvider    │
     └────────────────────────────────────────────────┘

     ┌────────────────────────────────────────────────┐
     │ semanticoProvider.family(notaId)  Async        │  KNN, cache 10 min
     │ sugestoesProvider                 Stream       │  tb_cerebro_sugestoes
     │ analiticoProvider                 Async        │  facetas + séries
     │ layoutProvider                    StateNotifier│  larguras/colapsos
     │ aprovacaoProvider                 Stream       │  fila de escrita da IA
     └────────────────────────────────────────────────┘
```

**Regras de estado:**

1. `vaultIndexProvider` é `keepAlive` — reconstruí-lo custa segundos.
2. `notaProvider` e `editorProvider` são `autoDispose` com `cacheTime` de 5 min (fechar e reabrir a aba não recarrega do Firestore).
3. **Nunca** colocar `List<GrafoNo>` dentro de um `StateProvider`: a simulação muta arrays; o `GrafoNotifier` emite um `GrafoTick` leve (contador + `Listenable`) e o `CustomPainter` lê os arrays diretamente via `repaint: listenable`. Isso evita reconstruir a árvore de widgets a 60 fps.
4. `editorProvider` mantém pilha de *undo* própria (200 passos, agrupando digitação por 500 ms), independente da do Firestore.
5. Toda escrita passa por `NotaRepository`, nunca direto do widget.

---

## 13. Orçamentos de Performance

### 13.1 Metas por tamanho de vault

| Métrica | 500 notas | 2.000 notas | 10.000 notas |
|---|---|---|---|
| Boot até shell interativo | 250 ms | 300 ms | 350 ms |
| Boot até índices prontos | 350 ms | 900 ms | 3,5 s (progressivo) |
| Memória do índice | 6 MB | 22 MB | 95 MB (modo servidor) |
| Grafo — 1º frame | 180 ms | 400 ms | 900 ms (top 3.000) |
| Grafo — layout estável | 0,9 s | 2,5 s | 6 s (ou snapshot: instantâneo) |
| Grafo — FPS em pan/zoom | 60 | 60 | 45+ (modo performance) |
| Busca textual | 8 ms | 28 ms | 120 ms |
| Busca semântica | 700 ms | 850 ms | 1,1 s |
| Abrir nota (quente) | 40 ms | 60 ms | 80 ms |
| Backlinks de nota com 200 refs | 12 ms | 18 ms | 30 ms (servidor) |
| Salvar + reindexar | 25 ms | 45 ms | 70 ms |

### 13.2 Estratégias obrigatórias

| Problema | Estratégia |
|---|---|
| Rebuild de widget a 60 fps | `CustomPainter` com `repaint: Listenable` + `RepaintBoundary` no grafo |
| Alocação por frame | Arrays `Float32List` reutilizados; zero `List<double>` no laço |
| GC no tokenizer | `StringBuffer` reutilizado, `substring` só quando necessário |
| Parágrafos de texto | `LabelCache` LRU 600, escala quantizada em 0,25 |
| Download de 15 MB no boot | Espelho `tb_cerebro_notas_meta` sem `conteudo` |
| Trigramas caros | Construção lazy no 1º uso da busca, fatiada em frames |
| Backlinks acima de 3.000 notas | Modo servidor com query indexada |
| Embeddings caros | Cache por hash de chunk + reindexação por diff |
| Jank no web | Fatiamento de 6 ms/frame com laço retomável |
| Listas longas | `ListView.builder` + `itemExtent` fixo onde possível |
| Firestore | Paginação de 500, `snapshots()` só no que é reativo (sugestões, aprovação) |

### 13.3 Harness de benchmark

`test/cerebro/perf/` gera vaults sintéticos (500/2.000/10.000 notas, densidade de link realista via distribuição de lei de potência) e falha o CI se qualquer métrica regredir mais de **15%** contra a linha de base versionada em `test/cerebro/perf/baseline.json`.

---

## 14. Segurança, Multi-tenant e LGPD

### 14.1 Isolamento

- **Toda** query filtra por `clinicaId` — imposto por regras de segurança (§4.8) **e** por asserção no repositório (`assert(doc.clinicaId == clinicaAtual)`), que lança em debug.
- Troca de clínica **destrói** todo o estado do vault: índices, cache, grafo, embeddings locais. `vaultProvider` é invalidado por `ref.listen(clinicaAtualProvider)`. Vazamento entre clínicas é bug de severidade crítica.
- Chaves de API (Azure/SendGrid/Z-API) **nunca** no cliente — o Cérebro só fala com Cloud Functions autenticadas, no mesmo padrão de `chatProxy.js` e `analyzeDocument`.

### 14.2 PII — a regra central

> **Dado identificável de paciente jamais é materializado no corpo de uma nota.**

Isso vale para humanos e para a IA. O que se escreve é `[[@paciente:pac_812]]`; o nome só aparece em tempo de render, para quem tem permissão.

**Camadas de defesa:**

1. **Prompt** (§9.4, item 6) — instrução explícita ao modelo.
2. **`RedatorPii`** — validação em `politica_escrita.dart` antes de qualquer `cerebro_escrever`:

```dart
final padroes = <String, RegExp>{
  'cpf':      RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b'),
  'cns':      RegExp(r'\b[1-2]\d{14}\b'),
  'telefone': RegExp(r'\b(?:\+55\s?)?\(?\d{2}\)?\s?9?\d{4}-?\d{4}\b'),
  'email':    RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]{2,}\b'),
  'rg':       RegExp(r'\b\d{1,2}\.?\d{3}\.?\d{3}-?[\dxX]\b'),
  'cartao':   RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
};
// + verificação contra nomes de pacientes conhecidos da clínica
//   (índice Aho-Corasick de nomes com ≥ 2 tokens, casefold, sem acento)
```

3. **Aviso na UI** — se um humano digitar PII, banner âmbar: *"Detectamos um CPF. Prefira `[[@paciente:id]]` — o Cérebro resolve o nome para quem pode ver."* com botão **"Substituir por referência"** (busca o paciente e troca).
4. **Embeddings** — `RedatorPii.sanitizarParaEmbedding()` roda **antes** de enviar texto para a Cloud Function. Nome de paciente vira `(paciente)`. Nenhum PII deixa a infraestrutura em vetor.
5. **Export** — PII e notas `sensivel: true` são removidas ou mascaradas conforme a opção escolhida no diálogo de exportação.

### 14.3 Permissão por papel

| Papel | Ler notas | Ler `sensivel` | Escrever | Resolver `@paciente` | Config | Auditoria |
|---|---|---|---|---|---|---|
| `admin` | ✓ | ✓ | ✓ | nome completo | ✓ | ✓ |
| `gestor` | ✓ | ✓ | ✓ | nome completo | — | ✓ |
| `medico` | ✓ | ✓ | apenas as próprias | nome completo (só seus pacientes) | — | — |
| `recepcao` | ✓ | ✗ | ✗ | iniciais (`M. S.`) | — | — |

Sem permissão, o `EntityChip` renderiza cinza com cadeado e rótulo "Paciente #812" — o link continua navegável no grafo (a topologia não é segredo), mas a identidade não é revelada.

### 14.4 Auditoria

`tb_cerebro_eventos` é **append-only** (regra `allow update, delete: if false`). Registra ator, ação, diff, motivo, `toolCallId`, modelo e versão. A tela Config → Auditoria permite filtrar por período, ator e nota, e exporta CSV para o encarregado de dados (DPO).

### 14.5 Direito ao esquecimento

Quando um paciente exerce o direito de eliminação, a Cloud Function `cerebroPurgaLgpd`:

1. Localiza todas as notas com `entityRefs` contendo `paciente:{id}` (query indexada).
2. Substitui cada `[[@paciente:{id}]]` por `[[@removido:lgpd]]` — o nó vira uma lápide anônima, preservando a **topologia** e as análises agregadas.
3. Remove chunks de embedding que citem a entidade e reindexa as notas afetadas.
4. Varre o corpo com `RedatorPii` e mascara ocorrências residuais.
5. Registra um evento `purgaLgpd` com a contagem de notas afetadas (sem citar o paciente).
6. Emite relatório em PDF para o DPO (o projeto já usa `printing`/`pdf`).

**SLA:** ≤ 15 dias corridos, conforme LGPD art. 18.

### 14.6 Retenção

| Dado | Retenção |
|---|---|
| Notas ativas | Indefinida (é a memória institucional) |
| Notas soft-deleted | 30 dias → purga física |
| Versões | Tiered (§4.10) |
| Eventos de auditoria | 5 anos |
| Embeddings | Enquanto a nota existir |
| Sugestões | 30 dias (TTL) |
| Snapshots de grafo | 90 dias |

---

## 15. Telemetria e Métricas de Produto

### 15.1 Eventos

```
cerebro_aberto            { origem: rail|atalho|link|chat }
cerebro_nota_criada       { tipo, origem, viaTemplate }
cerebro_nota_editada      { deltaChars, duracaoSessaoSeg }
cerebro_link_criado       { manual|autocomplete|sugestao|agente }
cerebro_busca             { modo, nResultados, latenciaMs, clicouResultado }
cerebro_grafo_aberto      { escopo, nNos, nArestas, fps_p50, fps_p05 }
cerebro_grafo_no_clicado  { tipo, pagerankPercentil }
cerebro_sugestao_decidida { tipo, decisao, score, segundosAteDecisao }
cerebro_agente_escreveu   { tool, confianca, estado, aprovadaPorHumano }
cerebro_conflito          { resolucao: auto|manual|ia }
cerebro_pii_bloqueado     { padrao, ator }         ⚠ sem o valor detectado
cerebro_performance       { operacao, latenciaMs, tamanhoVault }
```

### 15.2 KPIs

| KPI | Definição | Meta 90 dias |
|---|---|---|
| **North Star — Densidade de conexão** | `arestas / notas` | ≥ 3,5 |
| Taxa de órfãs | `órfãs / total` | ≤ 8% |
| Adoção | Usuários que abrem o Cérebro ≥ 3×/semana | ≥ 60% dos gestores |
| Aceite de sugestões | `aceitas / decididas` | ≥ 45% |
| Confiabilidade da IA | Notas de IA revisadas e aprovadas sem edição | ≥ 70% |
| Recall do RAG | Perguntas respondidas com contexto do Cérebro | ≥ 80% |
| Tempo até o insight | Da pergunta à resposta acionável | ≤ 25 s |
| Promoção de conhecimento | Padrões que viram protocolo/decisão por mês | ≥ 2 |
| Saúde de performance | Sessões sem entrar em modo performance | ≥ 95% |

### 15.3 Painel interno

Nova aba em `features/admin_agentes/`: "Saúde do Cérebro" por clínica — crescimento de nós/arestas, distribuição de PageRank, taxa de órfãs, custo de embeddings, uso de tools, taxa de rejeição de sugestões. Alerta quando a densidade cair 2 semanas seguidas (sinal de que o vault virou depósito e não cérebro).

---

## 16. Plano de Implementação por Fases

> Ordem obrigatória — cada fase entrega valor sozinha e é pré-requisito da seguinte. Estimativas em dias de 1 desenvolvedor sênior com apoio de agentes.

### F0 · Fundação (8 d) — *"escrever e ler notas"*

| # | Tarefa | Arquivos | Aceite |
|---|---|---|---|
| 0.1 | Modelos + enums | `data/models/*` | `toMap`/`fromMap` round-trip em teste |
| 0.2 | `NotaRepository` com CRUD e escrita otimista | `data/nota_repository.dart` | Criar/editar/arquivar funciona offline |
| 0.3 | Regras de segurança + índices no Firestore | `firestore.rules`, `firestore.indexes.json` | Suite de rules passa (emulador) |
| 0.4 | Cloud Function `cerebroOnWriteNota` (espelho meta) | `cloud_functions/` + `functions/` | Espelho consistente em 100 escritas |
| 0.5 | Shell da tela + rail + 3 painéis redimensionáveis | `cerebro_screen.dart`, `ui/rail/` | Layout de §10.1 com resize e persistência |
| 0.6 | Explorer básico (árvore, criar, renomear) | `ui/esquerda/explorer_*` | Árvore de 500 notas rola a 60 fps |
| 0.7 | Editor markdown cru + autosave | `ui/editor/editor_*` | Autosave 2 s idle; sem perda ao fechar |
| 0.8 | Status bar | `ui/comum/status_bar.dart` | Contagens corretas e clicáveis |
| 0.9 | Rota + entrada no drawer + `IaView.cerebro` | `navigation/`, `ia_session.dart` | Navegável de 3 caminhos |

### F1 · Links e Backlinks (7 d) — *"o vault vira grafo"*

| # | Tarefa | Aceite |
|---|---|---|
| 1.1 | Parser VFM completo (tokenizer + AST + extrator) | 20 casos-limite de §6.3 passam |
| 1.2 | Os 6 índices + atualização incremental | Editar nota de 50 KB reindexar em ≤ 45 ms |
| 1.3 | Resolvedor de links (9 etapas de §5.2) | Ambiguidade e link quebrado tratados |
| 1.4 | Renderização VFM (wikilink, tag, callout, embed, task) | Golden test do live preview |
| 1.5 | Autocomplete `[[` `#` `/` `@` | Popup em ≤ 60 ms com 2.000 notas |
| 1.6 | Painel de backlinks + menções não-vinculadas (Aho-Corasick) | "Vincular todas" reescreve corretamente |
| 1.7 | Hover preview | 500 ms, sem vazar `OverlayEntry` |
| 1.8 | `cerebro_mover` com reescrita em cascata | 300 notas atualizadas atomicamente |
| 1.9 | Busca textual + operadores | Todos os operadores de §6.5 |
| 1.10 | Quick switcher + command palette | 70 comandos registrados |

### F2 · Grafo (9 d) — *"ver o cérebro"*

| # | Tarefa | Aceite |
|---|---|---|
| 2.1 | Quadtree + Barnes-Hut | Teste contra força bruta, erro < 3% |
| 2.2 | Engine de simulação (4 forças, α) | 2.000 nós estabilizam em ≤ 2,5 s |
| 2.3 | Isolate (nativo) + scheduler fatiado (web) | Sem jank em ambos |
| 2.4 | `GrafoPainter` em camadas + `LabelCache` | 60 fps com 2.000/8.000 |
| 2.5 | Hit test + gestos (§7.8) | Todos os 12 gestos |
| 2.6 | Grafo local radial ancorado | Visual de `3.jpg` |
| 2.7 | Popover de configuração (4 grupos) | Persistido por usuário |
| 2.8 | Grupos de cor por query + paleta por tipo | Visual de `2.jpg` |
| 2.9 | PageRank + Louvain + componentes + órfãs | Validado contra networkx |
| 2.10 | LOD + degradação sob carga | 10.000 nós sem travar |
| 2.11 | Modo foco com arestas animadas | Visual de `5.jpg` |
| 2.12 | Exportar PNG/SVG/Mermaid | Arquivos abrem corretamente |

### F3 · Semântica (7 d) — *"o cérebro entende"*

| # | Tarefa | Aceite |
|---|---|---|
| 3.1 | CF `embedText` + rate limit + cache | Lote de 96, custo registrado |
| 3.2 | Chunker heading-aware | Chunks com caminho hierárquico |
| 3.3 | `RedatorPii` (sanitização pré-embedding) | 6 padrões + nomes; 0 falso-negativo no corpus de teste |
| 3.4 | Fila de embeddings com backoff persistente | Sobrevive a restart |
| 3.5 | Índice vetorial + `findNearest` + fallback local | KNN k=20 em ≤ 900 ms |
| 3.6 | Painel de vizinhos semânticos | Barra de similaridade + ações |
| 3.7 | 8 detectores de sugestão | Máx. 12 pendentes, ordenadas |
| 3.8 | RRF + reranker + anti-eco | Contexto rotulado por proveniência |
| 3.9 | Arestas semânticas no grafo (tracejadas) | Toggle funcional |

### F4 · Agente (8 d) — *"o cérebro escreve sozinho"*

| # | Tarefa | Aceite |
|---|---|---|
| 4.1 | 14 tools MCP registradas | Schemas validados; agente as chama |
| 4.2 | `PoliticaEscrita` (8 guardas) | Cada guarda com teste dedicado |
| 4.3 | Adendo de system prompt | Agente busca antes de responder em ≥ 90% dos casos |
| 4.4 | Fila de aprovação + cards no chat | Aprovar/Editar/Descartar |
| 4.5 | Auditoria append-only + tela de histórico | Diff legível, reversão funciona |
| 4.6 | CF `cerebroConsolidacao` (7 etapas) | Idempotente; ≤ 3 chamadas LLM/dia |
| 4.7 | CF `cerebroMetricas` + snapshots | Grafo abre instantâneo a partir do snapshot |
| 4.8 | Nota diária + revisão semanal | Geradas com links corretos |
| 4.9 | Briefing matinal com link da nota diária | E-mail entregue |
| 4.10 | Ponte operacional (6 projetores + permissões) | `@paciente` respeita papel |

### F5 · Analítico, Canvas e Polimento (9 d)

| # | Tarefa |
|---|---|
| 5.1 | Modo analítico: facetas + sparklines + barras |
| 5.2 | Inspector do nó com resumo por IA |
| 5.3 | Aba Fluxo (sankey de promoção de conhecimento) |
| 5.4 | Aba Lista + exportação CSV/XLSX |
| 5.5 | Canvas completo + "Organizar com IA" + "Virar nota" |
| 5.6 | Blocos `vitta-query` (parser + 8 renderizadores) |
| 5.7 | Templates + propriedades tipadas |
| 5.8 | Import/export de vault (.zip compatível com Obsidian) |
| 5.9 | Responsividade tablet/mobile |
| 5.10 | Acessibilidade completa (§10.13) |
| 5.11 | CF `cerebroPurgaLgpd` + relatório PDF |
| 5.12 | Telemetria + painel "Saúde do Cérebro" |
| 5.13 | Onboarding: "Deixar a IA semear" (8 notas-base) |
| 5.14 | Harness de performance no CI |

**Total: 48 dias úteis** (~10 semanas). F0→F2 já entrega um Obsidian funcional; F3→F4 é o que torna o produto único.

### 16.1 Ordem de paralelização

```
F0 ──┬── F1 ──┬── F2 ─────┐
     │        │           ├── F5
     └──── F3 (após 1.2) ─┤
              └── F4 (após F3.5 e F1.9)
```

`F3` pode começar assim que os índices de `F1.2` existirem. `F4` depende de KNN (`F3.5`) e busca (`F1.9`). `F5` fecha tudo.

---

## 17. Critérios de Aceite (Gherkin)

```gherkin
# ── LINKS ─────────────────────────────────────────────────────────────────
Funcionalidade: Wikilinks e backlinks

  Cenário: Criar link para nota existente
    Dado que existe a nota "protocolos/confirmacao-48h.md" com título "Protocolo de Confirmação 48h"
    E que estou editando "mocs/absenteismo.md"
    Quando eu digito "[[Protocolo de Conf"
    Então o autocomplete exibe "Protocolo de Confirmação 48h" em até 60 ms
    Quando eu pressiono Enter
    Então o texto vira "[[Protocolo de Confirmação 48h]]"
    E ao salvar, a nota de destino exibe "Absenteísmo — MOC" em Menções vinculadas
    E o grafo mostra uma aresta entre os dois nós sem recarregar a página

  Cenário: Link quebrado vira criação de nota
    Dado que não existe nota com título "Fila de Espera Inteligente"
    Quando eu escrevo "[[Fila de Espera Inteligente]]" e salvo
    Então o link é renderizado em vermelho tracejado
    E o nó aparece vazado no grafo se "links não resolvidos" estiver ligado
    Quando eu clico no link
    Então abre o diálogo "Criar nota" com o título pré-preenchido
    E ao confirmar, a nota é criada e o link resolvido automaticamente

  Cenário: Renomear atualiza todas as referências
    Dado que 37 notas referenciam "[[Absenteísmo — MOC]]"
    Quando eu renomeio para "Absenteísmo — Mapa Central"
    Então as 37 notas são atualizadas em uma única operação
    E aliases preservam o texto exibido em "[[…|as faltas]]"
    E um único evento de auditoria registra a operação
    E é possível reverter tudo com um clique

# ── GRAFO ─────────────────────────────────────────────────────────────────
Funcionalidade: Visualização em grafo

  Cenário: Abrir grafo global de vault médio
    Dado um vault com 2.000 notas e 8.900 links
    Quando eu pressiono Ctrl+G
    Então o primeiro frame aparece em até 400 ms usando o snapshot noturno
    E o layout se estabiliza em até 2,5 s
    E o pan/zoom mantém 60 fps
    E os rótulos aparecem apenas nos nós de maior PageRank

  Cenário: Modo foco
    Dado que o grafo global está aberto
    Quando eu clico no nó "Absenteísmo — MOC"
    Então os nós até 2 saltos ficam destacados com arestas animadas
    E os demais caem para 12% de opacidade em 320 ms
    E o inspector à direita exibe métricas, resumo e conexões
    Quando eu pressiono Esc
    Então o grafo volta ao estado normal

  Cenário: Grafo grande entra em modo performance
    Dado um vault com 12.000 notas
    Quando eu abro o grafo global
    Então são exibidos os 3.000 nós de maior PageRank
    E um aviso explica o corte com opção de mostrar tudo
    E se 3 frames consecutivos passarem de 33 ms, ativa o modo performance
    E um chip permite forçar qualidade máxima

# ── SEMÂNTICA ─────────────────────────────────────────────────────────────
Funcionalidade: Descoberta semântica

  Cenário: Vizinhos semânticos sem link explícito
    Dado que "padroes/faltas-segunda.md" e "protocolos/confirmacao-48h.md" tratam do mesmo tema
    E que não há wikilink entre elas
    Quando eu abro a primeira
    Então a seção "Vizinhos semânticos" lista a segunda com similaridade ≥ 0,74
    E exibe o trecho que mais contribuiu para a proximidade
    Quando eu clico em "Criar link"
    Então o wikilink é inserido no fim da seção "Notas relacionadas"
    E o par sai da lista de sugestões

  Cenário: Sugestão rejeitada não volta
    Dado uma sugestão de link entre A e B
    Quando eu a rejeito 3 vezes ao longo do tempo
    Então o limiar daquele par sobe para 0,95 permanentemente
    E ela não reaparece em condições normais

# ── AGENTE ────────────────────────────────────────────────────────────────
Funcionalidade: Escrita autônoma

  Cenário: Agente consulta antes de responder
    Dado que existe "padroes/faltas-segunda.md" analisando faltas às segundas
    Quando eu pergunto no chat "por que temos tantas faltas na segunda?"
    Então o agente chama cerebro_buscar antes de responder
    E a resposta cita "(ver [[padroes/faltas-segunda]])"
    E não repete a análise do zero

  Cenário: Escrita de baixa confiança vira rascunho
    Quando o agente chama cerebro_escrever com confianca = 0,68
    Então a nota é criada com estado "rascunho"
    E aparece em itálico no explorer com o badge "✦ IA 0.68"
    E entra na fila de sugestões de revisão
    E não é usada como fonte primária por outra nota do agente por 24 h

  Cenário: PII bloqueada
    Quando o agente tenta escrever "Maria Silva (CPF 123.456.789-00) faltou 3 vezes"
    Então a escrita é rejeitada
    E a tool devolve instrução para usar [[@paciente:id]]
    E um evento de segurança é registrado sem o valor detectado
    E o chat exibe card vermelho explicando o bloqueio

  Cenário: Humano vence a IA em conflito
    Dado que eu editei "agente/analises/x.md" às 14:00
    E o agente tenta atualizar a mesma nota às 14:01 com base na versão anterior
    Então minha versão é preservada
    E a versão do agente vira sugestão do tipo "merge"
    E eu posso ver as duas lado a lado

# ── CONSOLIDAÇÃO ──────────────────────────────────────────────────────────
Funcionalidade: Rotina noturna

  Cenário: Nota diária é gerada
    Dado que houve 42 consultas, 6 faltas e 2 encaixes em 19/08/2026
    Quando a consolidação roda às 02:30
    Então "diario/2026-08-19.md" é criada
    E a seção "Números do dia" é gerada por código, sem LLM
    E há link para "diario/2026-08-18" e para os MOCs das entidades citadas
    E rodar de novo no mesmo dia não duplica a nota

  Cenário: Padrão é promovido
    Dado que o mesmo padrão aparece em 4 notas diárias dos últimos 21 dias
    E que não existe nota permanente sobre ele
    Quando a consolidação roda
    Então uma nota é criada em "padroes/" com estado rascunho
    E as diárias de origem são linkadas como evidência
    E o gestor recebe sugestão de revisão
    Mas se o padrão contradiz uma decisão revisada por humano, nada é publicado
    E a contradição é reportada como sugestão do tipo "contradicao"

# ── LGPD ──────────────────────────────────────────────────────────────────
Funcionalidade: Direito ao esquecimento

  Cenário: Purga de paciente
    Dado que o paciente pac_812 é citado em 14 notas via [[@paciente:pac_812]]
    Quando a purga LGPD é executada
    Então as 14 referências viram [[@removido:lgpd]]
    E a topologia do grafo é preservada
    E os embeddings que citam a entidade são removidos e reindexados
    E um relatório PDF é gerado para o DPO
    E nenhum dado identificável do paciente permanece no vault

# ── MULTI-TENANT ──────────────────────────────────────────────────────────
Funcionalidade: Isolamento entre clínicas

  Cenário: Troca de clínica limpa o estado
    Dado que estou na clínica A com 800 notas carregadas
    Quando eu troco para a clínica B
    Então todos os índices, cache, grafo e vetores locais são destruídos
    E nenhuma nota da clínica A aparece em qualquer busca, grafo ou sugestão
    E a barra de status reflete apenas os números da clínica B
```

---

## 18. Plano de Testes

### 18.1 Pirâmide

| Nível | Quantidade alvo | Cobertura mínima |
|---|---|---|
| Unitário | ~240 testes | 85% em `index/`, `graph/metricas/`, `semantic/`, `agent/politica_escrita` |
| Widget | ~45 testes | Todos os painéis e diálogos |
| Golden | 12 | Grafo (claro/escuro), editor, analítico, canvas |
| Integração | 14 fluxos | Cenários de §17 ponta a ponta com emulador |
| Performance | 8 benchmarks | Falha o CI com regressão > 15% |
| Regras de segurança | ~30 | Emulador Firestore, matriz papel × operação |

### 18.2 Testes críticos e não-óbvios

| Teste | Por que existe |
|---|---|
| Parser: 20 casos-limite | Toda a integridade do grafo depende do parser |
| `arquitetura_test.dart` | Impede que a UI importe repositórios direto e o módulo apodreça |
| Isolamento por clínica | Vazamento entre clínicas é falha crítica de privacidade |
| PII com 500 nomes brasileiros reais + variações | Falso-negativo é vazamento de dado de saúde |
| Anti-eco do RAG | Sem ele, o cérebro alucina em cascata ao longo dos meses |
| Idempotência da consolidação | Retry de cron não pode duplicar notas |
| Conflito 3 vias com 12 padrões de edição | Perder texto do usuário destrói a confiança no produto |
| Reescrita em cascata de 500 links | Batch parcial deixaria o vault inconsistente |
| Barnes-Hut vs força bruta | Otimização silenciosamente errada arruína o layout |
| Louvain determinístico (seed fixa) | Cores não podem dançar entre sessões |
| Grafo com ciclos e self-loops | Casos que quebram algoritmos ingênuos |
| Vault vazio / 1 nota / 10.000 notas | Extremos são onde a UI quebra |
| Simulação de queda de rede no meio do save | Fila offline precisa ser confiável |
| `textScaleFactor` 2.0 | Acessibilidade real, não teatro |

### 18.3 Dados de teste

`test/cerebro/fixtures/` traz 3 vaults sintéticos versionados:

- **`vault_pequeno`** (40 notas) — legível à mão, usado nos testes unitários.
- **`vault_medio`** (2.000 notas, lei de potência com expoente 2,1) — realista para widget/perf.
- **`vault_patologico`** (500 notas) — o vault dos pesadelos: ciclos, self-loops, títulos duplicados, emoji, RTL, nota de 2 MB, 400 aliases colidindo, links quebrados, tags com 8 níveis, frontmatter malformado.

---

## 19. Riscos e Mitigações

| # | Risco | P | I | Mitigação |
|---|---|---|---|---|
| R1 | **Performance do grafo no Flutter Web** — sem isolate, jank | Alta | Alto | Scheduler fatiado (§7.3), snapshot pré-computado, LOD agressivo, degradação automática. Benchmark obrigatório no CI. |
| R2 | **Custo de embeddings** escala com o vault | Média | Médio | Cache por hash, reindexação por diff, rate limit por clínica, 768 dims em vez de 3072, toggle para desligar. Monitorado em [`CUSTO.md`](../CUSTO.md). |
| R3 | **Vazamento de PII** em nota ou embedding | Baixa | **Crítico** | 5 camadas (§14.2), teste com 500 nomes, bloqueio na tool, auditoria, revisão de segurança antes do go-live. |
| R4 | **Cérebro vira depósito** — muitas notas, poucos links | **Alta** | Alto | Densidade como North Star, sugestões proativas, alerta de órfãs na status bar, revisão semanal, onboarding que semeia MOCs. |
| R5 | **Eco da IA** — a IA cita a si mesma e fabrica em cascata | Média | Alto | Anti-ciclo de 24 h, rotulagem de proveniência no contexto, penalização no rerank, dados operacionais sempre vencem. |
| R6 | **Limite de 1 MB do Firestore** | Média | Médio | Overflow para Storage a 900 KB, aviso a 400 KB, sugestão de dividir a nota. |
| R7 | **Conflitos de edição** frustram usuários | Média | Médio | Versão monotônica no servidor, auto-merge de 3 vias, humano sempre vence a IA. |
| R8 | **Complexidade do módulo** trava a manutenção | **Alta** | Médio | Camadas com teste de dependência, glossário obrigatório, 78 arquivos pequenos em vez de poucos gigantes. |
| R9 | **Adoção baixa** — ninguém usa | Média | Alto | O cérebro se popula sozinho pela consolidação: tem valor no dia 1 mesmo sem escrita humana. Entrada pelo chat que o usuário já usa. |
| R10 | **Bloqueio do índice vetorial** (indisponível/custo) | Baixa | Médio | Fallback local int8 desde o primeiro dia, testado, não é caminho morto. |
| R11 | **Louvain instável** — cores mudam a cada execução | Média | Baixo | Seed fixa + estabilização: mantém o id do cluster com maior sobreposição com o anterior. |
| R12 | **Migração futura de esquema** | Média | Médio | `schemaVersao` no `tb_cerebro_config`, migradores versionados e idempotentes em `data/migracoes/`. |

---

## 20. Anexos

### 20.1 Vault semente (`Deixar a IA semear`)

8 notas criadas no onboarding, a partir dos dados reais da clínica:

```
000-inicio.md                    MOC raiz — porta de entrada do cérebro
mocs/operacao.md                 MOC de operação (agenda, recepção, fila)
mocs/absenteismo.md              MOC de absenteísmo (dados reais dos últimos 90 d)
mocs/equipe.md                   MOC da equipe, com [[@medico:*]] de todos
mocs/pacientes.md                MOC de pacientes, com os 10 de maior risco
protocolos/confirmacao-48h.md    Protocolo atual, extraído da config de lembretes
protocolos/overbooking.md        Regras de encaixe vigentes
diario/{hoje}.md                 Primeira nota diária
```

Cada nota já nasce linkada às outras — o vault começa com densidade ~3,0, nunca com um grafo de pontos soltos.

### 20.2 Formato de import/export

**Export** (`.zip`):

```
vault-cl_001-2026-08-19.zip
├── notas/                    espelho fiel da estrutura de pastas, .md com frontmatter
├── canvas/                   *.canvas (JSON compatível com Obsidian)
├── anexos/
├── .obsidian/
│   ├── graph.json            grupos e forças → abre igual no Obsidian real
│   └── app.json
└── vitta-meta.json           métricas, entity-links resolvidos, auditoria (opcional)
```

Opções no diálogo: incluir notas arquivadas · incluir rascunhos de IA · resolver entity-links para texto (⚠ materializa PII — exige confirmação e papel `admin`) · incluir histórico de versões.

**Import**: aceita `.zip` de vault Obsidian. Converte `[[links]]` normalmente, preserva frontmatter, mapeia tags, relata o que não pôde ser convertido (plugins, Dataview, LaTeX) em uma nota `import-relatorio.md`.

### 20.3 Exemplo de nota diária gerada

````markdown
---
tipo: diario
data: 2026-08-19
tags: [diario, operacao]
origem: agente
confianca: 0.95
consolidacaoRunId: run_20260819_0230
---

# 19 de agosto de 2026 · terça

← [[diario/2026-08-18]] · [[diario/2026-08-20]] → · [[mocs/operacao]]

## Números do dia

| Indicador | Valor | vs. média 28d |
|---|---:|---:|
| Consultas realizadas | 42 | +8% |
| Faltas | 6 | **+140%** ⚠ |
| Cancelamentos | 3 | −25% |
| Encaixes via overbooking | 2 | — |
| Taxa de confirmação | 71% | −12% |

## O que aconteceu

- Pico de faltas concentrado no turno da manhã de [[@medico:med_44]] — 4 das 6.
- O [[protocolos/confirmacao-48h]] não foi disparado para 9 agendamentos por
  falha de integração no Z-API às 06:12 (ver [[@alerta:al_7781]]).
- Dois encaixes bem-sucedidos a partir da fila de espera ([[@overbooking:ob_2201]]).

## Anomalias

> [!risco] Faltas 2,4σ acima da média
> A correlação com a falha de confirmação é forte, mas não conclusiva:
> 3 das 6 faltas receberam confirmação normalmente.
> Ver [[padroes/faltas-segunda]] — o padrão de turno persiste.

## Perguntas em aberto

- A falha do Z-API às 06:12 foi isolada ou recorrente? Não há histórico suficiente.
- Por que 3 pacientes confirmados ainda assim faltaram? Sugere causa fora do lembrete.
````

### 20.4 Checklist de "pronto para produção"

```
FUNCIONAL
[ ] Todos os cenários de §17 passam em integração
[ ] Import/export testado com vault Obsidian real de 1.000+ notas
[ ] 3 vaults de fixture no CI (pequeno, médio, patológico)
[ ] Todos os estados vazios/erro implementados (§10.5.5, §10.15)

PERFORMANCE
[ ] Benchmarks dentro dos budgets de §13.1 nas 3 plataformas (web, Windows, Android)
[ ] Sem vazamento de memória em 30 min de uso (DevTools)
[ ] Grafo de 10.000 nós não trava o app

SEGURANÇA
[ ] Regras de segurança com suite completa no emulador
[ ] `/security-review` executado sem achados de severidade alta
[ ] Teste de PII com 500 nomes + variações: 0 falso-negativo
[ ] Isolamento por clínica verificado com 2 contas simultâneas
[ ] Nenhuma chave de API no bundle do cliente

QUALIDADE
[ ] Cobertura ≥ 85% nas camadas críticas
[ ] `flutter analyze` sem warnings
[ ] Golden tests estáveis em 3 execuções
[ ] `arquitetura_test.dart` passa

ACESSIBILIDADE
[ ] Navegação 100% por teclado
[ ] Contraste verificado em ambos os temas
[ ] Leitor de tela testado no fluxo principal
[ ] `textScaleFactor` 2.0 sem quebra de layout

DOCUMENTAÇÃO
[ ] `update_data.md` atualizado com o motivo de cada mudança de esquema
[ ] `database.md` com as 10 coleções novas
[ ] `CUSTO.md` com a projeção de custo de embeddings e LLM
[ ] `MCP.md` com as 14 tools
[ ] `AGENTS.md` com o módulo `cerebro` no mapa de dependências
[ ] Onboarding em vídeo de 3 min para gestores
```

### 20.5 Decisões arquiteturais registradas

| # | Decisão | Alternativa descartada | Por quê |
|---|---|---|---|
| ADR-1 | Markdown como fonte da verdade | JSON estruturado / blocos | Portabilidade, edição humana natural, compatibilidade com Obsidian |
| ADR-2 | Entidades operacionais como nós virtuais | Copiar dados para notas | Evita duplicação, mantém PII fora do vault, sempre atualizado |
| ADR-3 | Índices em memória no cliente | Só servidor | Latência de backlinks/autocomplete precisa ser < 60 ms |
| ADR-4 | Modo servidor acima de 3.000 notas | Sempre em memória | Web tem teto de memória; degradar é melhor que travar |
| ADR-5 | 768 dims (Matryoshka) | 3072 dims completos | 4× mais barato e rápido, perda de recall < 2% |
| ADR-6 | Namespace `agente/` para escrita da IA | IA escreve em qualquer lugar | Separa proposta de norma; humano promove conhecimento |
| ADR-7 | Auditoria append-only | Log mutável | Exigência de conformidade e confiança na IA |
| ADR-8 | `CustomPainter` + arrays paralelos | Widgets por nó / pacote externo | 60 fps com milhares de nós é impossível com um widget por nó |
| ADR-9 | Louvain para cor, PageRank para tamanho | Cor por pasta, tamanho por grau | Revela estrutura emergente, não a que já conhecemos |
| ADR-10 | Consolidação por cron, não em tempo real | Streaming contínuo | Custo previsível, sem tempestade de escritas, janela para revisão |

---

## 📌 Próximos passos imediatos

1. Revisar e aprovar esta especificação (especialmente §9.3 — política de escrita do agente — e §14 — LGPD).
2. Criar `TASKS.md` do módulo com o backlog de F0 (9 tarefas), conforme a regra 4 de [`AGENTS.md`](../AGENTS.md).
3. Registrar as 10 coleções novas em [`database.md`](../database.md) e o motivo em [`update_data.md`](../update_data.md).
4. Provisionar o índice vetorial no Firestore (comando em §4.5) e a Cloud Function `embedText`.
5. Iniciar F0.1 → F0.9.

> **Lembrete de escopo:** F0→F2 entrega um Obsidian funcional dentro do Vitta. É bom, mas é commodity. O que ninguém mais tem é F3→F4: um cérebro que **lê os próprios dados operacionais todas as noites, escreve o que aprendeu, liga ao que já sabia e traz de volta na próxima pergunta.** Essa é a feature. O resto é a infraestrutura que a torna possível.
