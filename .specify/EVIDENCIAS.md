# Evidências — Pesquisa Científica com Fonte Verificável

Especificação do módulo que transforma pergunta clínica em busca no PubMed e
devolve resposta **rastreável até a fonte**.

> **Tela**: `/evidencias` · **Ferramentas do agente**: `pubmed_*` (4)
> **Cloud Function**: `pubmedProxy` · **Fonte**: NCBI E-utilities (PubMed)
> **Coleções**: `tb_pubmed_cache` · `tb_pubmed_rate`

---

## 1. O problema que resolve

Um LLM responde pergunta clínica de memória. A resposta soa correta, cita um
estudo plausível, e o PMID não existe. Esse é o pior erro possível num produto
médico — não porque a resposta está errada, mas porque **parece verificável e
não é**.

O módulo separa duas coisas que o chat sozinho mistura:

| | Quem faz | O que garante |
|---|---|---|
| **Descoberta da evidência** | PubMed (determinístico) | O artigo existe |
| **Interpretação** | LLM | Leitura em linguagem clínica |

O modelo não é a fonte; ele lê o que o PubMed devolveu. E toda citação passa por
uma validação em código antes de virar fonte na tela (§6).

**O que o módulo não faz:** diagnóstico, prescrição, nem substituição de
diretriz. O PubMed indexa literatura — não é base regulatória de medicamentos
nem repositório de protocolo institucional, e indexar não significa ter texto
completo.

---

## 2. Origem e adaptação

Veio de dois documentos (`Projeto_IA_Medica_PubMed_Integracao_Tecnica` e
`Manual_Implantacao_PubMed_NCBI_EUtilities`, 31/08/2026) que propõem uma stack
**que não é a nossa**: Python/FastAPI, PostgreSQL, pgvector, Redis, Celery,
Kubernetes, OpenAI Responses API.

Isto aqui é **adaptação, não transplante** — a mesma disciplina que o
`README.md` exige depois do episódio das specs importadas do `app_company`:

| O documento propõe | Aqui | Por quê |
|---|---|---|
| Backend Python/FastAPI | Cloud Function Node (`pubmedProxy`) | É o que o projeto já publica |
| PostgreSQL (evidence store) | Firestore + Cérebro | Não há Postgres no projeto |
| pgvector / embeddings | **nada** — busca lexical | Não existe camada semântica (§9) |
| Redis (cache + fila) | `tb_pubmed_cache` + `tb_scheduled_tasks` | Ambos já existem |
| Celery workers | Tarefas agendadas | Já resolve busca salva/alerta |
| Rate limiter em memória | Token bucket em transação Firestore | O limite do NCBI é por **IP**, e as instâncias compartilham o IP |
| OpenAI Responses API | Azure DeepSeek (`chatProxy`) | É o provedor do projeto |
| Endpoints REST `/v1/clinical/*` | Ferramentas MCP + tela | O agente já tem loop de ferramentas |

> ⚠️ **O `pubmed_ncbi_eutilities_swagger.json` do projeto tem ao menos um erro:**
> declara `retmode=json` para `/espell.fcgi`, que na verdade responde HTTP 500
> com esse parâmetro. Use-o como ponto de partida, não como contrato — e
> confirme com `scripts/verificar-ncbi.js` (§13.1).

---

## 3. Arquitetura

```
   ┌──────────────────┐        ┌──────────────────────┐
   │ Tela /evidencias │        │ Agente /ia           │
   │ (busca manual)   │        │ (tools pubmed_*)     │
   └────────┬─────────┘        └──────────┬───────────┘
            │                             │
            └──────────────┬──────────────┘
                           ▼
                    PubmedService (Dart)
                    + ID token do usuário
                           │ HTTPS POST
                           ▼
            ┌──────────────────────────────┐
            │ Cloud Function pubmedProxy   │
            │  1. verifyIdToken  ← LOGIN   │
            │  2. guarda de PHI            │
            │  3. cache (Firestore)        │
            │  4. token bucket global      │
            │  5. retry com backoff        │
            └──────────────┬───────────────┘
                           ▼
              NCBI E-utilities (PubMed)
        esearch · esummary · efetch · elink · espell
```

### 3.0 Dois caminhos, um preferido

O `pubmedProxy` é o caminho pretendido. Quando ele **não está publicado**, o app
cai para um conector direto ao NCBI (`pubmed_direct.dart`) e avisa na tela.

| | Proxy | Direto (plano B) |
|---|---|---|
| Guarda de PHI | servidor, inescapável | `phi_guard.dart`, no cliente |
| Limite de taxa | balde global coordenado | o do navegador do usuário |
| Cache | compartilhado entre clínicas | memória da aba |
| API key do NCBI | usada (10 req/s) | não usada (~3 req/s) |
| Autenticação | exigida | não há |

A linha que importa é a primeira: **a guarda de PHI continua rodando**. É a
única cujo furo teria consequência de LGPD; as demais custam desempenho.

**Por que o plano B existe.** Sem ele a tela fica inútil até alguém rodar
`firebase deploy`. Um módulo de pesquisa que só funciona depois de um deploy
manual não é um módulo, é uma promessa.

**Por que funciona no navegador.** O NCBI responde `Access-Control-Allow-Origin: *`
(verificado em 2026-09-01). Nenhum segredo é exposto: o caminho direto não usa
API key — o teto menor é o preço de não embarcar credencial no bundle.

> **Só o proxy indisponível dispara o plano B.** Um `PHI_BLOCKED` ou um
> `INVALID_QUERY` são respostas legítimas do servidor; repetir pelo caminho
> direto contornaria a guarda. Coberto pelo teste *"PHI bloqueado pelo servidor
> NÃO cai para o direto"*.

**Três códigos contam como indisponível:**

| Código | Situação |
|---|---|
| `NOT_DEPLOYED` (404) | a function não existe |
| `NETWORK` | rede caiu, ou o navegador bloqueou por CORS |
| `NOT_CONFIGURED` (503) | **publicada, mas sem `NCBI_TOOL`/`NCBI_EMAIL`** |

O terceiro entrou depois e é o menos óbvio: sem ele, publicar a function sem
configurar as variáveis deixava a tela **pior do que antes do deploy** — em vez
de cair para o NCBI direto, ela morria num 503. Um proxy mal configurado tem
que degradar como um proxy ausente.

### 3.1 Por que o proxy é o caminho preferido

**Três razões, nenhuma delas estética:**

1. A API key não pode ir para o cliente (build web expõe tudo — ver `AI_chaves.md`).
2. O limite do NCBI é por **IP**. Cada dispositivo teria seu próprio balde e
   ninguém controlaria o agregado, que é o número que o NCBI enxerga.
3. A guarda de dado pessoal precisa rodar onde o usuário não contorna.

### 3.1 `pubmedProxy` **exige login** — e as outras cinco functions não

`chatProxy`, `emailProxy`, `whatsappProxy`, `analyzeDocument` e
`anthropicProxy` aceitam qualquer chamador. Isso é risco aberto em
[`ATENCAO.md`](ATENCAO.md) e **não se repete aqui**: `pubmedProxy` valida
`Authorization: Bearer <ID token>` com `verifyIdToken`.

Aqui há um agravante que não existe nas outras. Um proxy de IA aberto custa
cota. Um proxy de PubMed aberto faz o **NCBI barrar o IP do projeto** — e a
pesquisa para de funcionar para **todas as clínicas** ao mesmo tempo.
Autenticar é requisito de funcionamento, não só de higiene.

---

## 4. Multi-tenant — a exceção deliberada

Toda ferramenta MCP é escopada por clínica. Estas também passam pela guarda de
`McpServer.callTool` (sem clínica resolvida, nada é despachado — `MCP.md` §3.1).

**Mas o resultado não é dado de tenant.** O PMID 31452104 é o mesmo artigo para
toda clínica: literatura pública. Por isso `tb_pubmed_cache` e `tb_pubmed_rate`
são **compartilhados entre clínicas**, de propósito:

- Cachear por clínica multiplicaria o custo do Firestore pelo número de
  clínicas, sem nenhum ganho.
- O balde de taxa **precisa** ser global: o NCBI conta por IP, não por tenant.

O que é por clínica — buscas salvas, notas do Cérebro, histórico — não passa
por essas coleções.

> ⚠️ Não "corrija" isto adicionando `clinicaId` ao cache. Não é esquecimento; é
> a razão de o módulo escalar.

---

## 5. Modelo de dados

### 5.1 Artigo normalizado

Campos mínimos (Manual §20.1). `pmid` é a **chave natural** — sempre presente.

| Campo | Origem | Obrigatório |
|---|---|---|
| `pmid` | ESummary `uid` | sim |
| `titulo` | `title` (espaços normalizados) | sim |
| `autores` | `authors[]` sem `CollectiveName` | sim (pode ser vazio) |
| `periodico` | `fulljournalname` ou `source` | sim |
| `dataPublicacao` | `pubdate` — **precisão original preservada** | sim |
| `ano` | extraído de `pubdate` | não |
| `doi` / `pmcid` | `articleids[]` | não |
| `tiposPublicacao` | `pubtype[]` → desenho do estudo | não |
| `url` | derivado do PMID | sim |
| `abstractTexto` | EFetch, sob demanda | não |
| `abstractSecoes` | EFetch XML — seções rotuladas | não |

**O EFetch é lido em XML, não em texto.** O formato texto é um relatório para
humanos: a citação quebra em várias linhas e separá-la por heurística erra — a
continuação da linha `doi:` vazava para dentro do resumo. O XML resolve por
estrutura e ainda entrega os rótulos (BACKGROUND/METHODS/RESULTS/CONCLUSIONS),
que o texto descarta. Para leitura clínica isso importa: uma frase em
CONCLUSIONS pesa diferente da mesma frase em METHODS.

**`dataPublicacao` fica como string.** O NCBI devolve `"2024 May 3"`, `"2024"`,
`"2024 Spring"`. Converter para `DateTime` inventaria dia e mês que o registro
não afirma — e num contexto onde recência é critério clínico, inventar data é
pior que exibir imprecisão.

**Deduplicação é por PMID.** DOI é auxiliar: nem todo registro tem, e registros
diferentes podem apontar para versões diferentes (Manual §20.3).

### 5.2 Coleções

| Coleção | Conteúdo | TTL |
|---|---|---|
| `tb_pubmed_cache` | Resposta bruta por hash de `(ação, params)` | esearch 15 min · esummary/efetch/elink 24 h · espell 7 d |
| `tb_pubmed_rate` | Doc único `global`: `{tokens, atualizadoMs}` | — |

TTL é política operacional, não garantia de frescor: `buscadoEm` sempre
acompanha o resultado.

---

## 6. Validação de citação — a trava anti-invenção

`lib/features/evidencias/citacao_validator.dart`

> **Regra: todo PMID citado tem que estar no pacote recuperado.**

O prompt já manda o modelo citar só o que recebeu, e reduz muito a invenção.
Mas quando o modelo erra, ele erra de forma convincente — um PMID de 8 dígitos
plausível. Por isso a garantia é código:

| Etapa | Comportamento |
|---|---|
| Extração | Aceita `PMID: 123`, `PMID 123`, `[PMID: 123]`, `[12345678]` |
| **Não** aceita | Número solto — ano (2024), dose (850 mg), amostra (12345) |
| Validação | Separa em `validos` / `invalidos` / `naoCitados` |
| Marcação | Citação inválida recebe `⚠️(não verificada)` **no texto** |

**Por que marcar em vez de apagar.** Apagar esconderia o problema: a afirmação
continuaria lá, agora sem fonte aparente — pior que uma fonte visivelmente
furada.

`semCitacao` é distinto de `!ok`: resposta sem nenhuma fonte não é citação
errada, é resposta que o médico deve tratar como orientação geral. A UI avisa
os dois casos com textos diferentes.

---

## 7. Ferramentas do agente (`pubmed_*`)

Registradas em `lib/core/modules/mcp/tools/pubmed_tools.dart`. Ver
[`MCP.md`](MCP.md) §6.20.

| Tool | Uso |
|---|---|
| `pubmed_buscar` | Pesquisa e devolve artigos com PMID, título, autores, ano, desenho |
| `pubmed_artigo` | Resumo (abstract) completo de até 10 PMIDs |
| `pubmed_relacionados` | PMIDs relacionados (ELink) |
| `pubmed_corrigir_termo` | Correção ortográfica (ESpell) |

**Registradas mesmo sem serviço.** Em modo demonstração e sem login não há
cliente, mas as tools continuam no catálogo e devolvem erro explicativo. Se
fossem omitidas, o modelo não veria a capacidade e responderia **de memória** —
exatamente o que o módulo existe para evitar.

As descrições carregam o contrato de citação (`NUNCA invente PMID`) e a regra
de PHI. É instrução, não garantia — as garantias são §3.1 e §6.

---

## 7.1 Modo agente — pesquisa por I.A.

`lib/features/evidencias/ia/`

Uma busca devolve artigos. O agente conduz uma **revisão rápida**:

```
 pergunta em português
   |
   v
 1. PICO ............ o modelo decompoe; o medico ve e PODE CORRIGIR
   v
 2. estrategia ...... PICO -> consulta Entrez  (codigo, nao modelo)
   v
 3. busca ........... PubMed
   v
 4. calibra <------+   0 resultados? amplia. Milhares? restringe.
   v              |   (teto de 3 reescritas — o loop nao e infinito)
   +--------------+
   v
 5. le resumos ...... EFetch dos 8 mais relevantes
   v
 6. sintetiza ....... o modelo escreve, citando SO o que recebeu
   v
 7. valida .......... CitacaoValidator confere cada PMID      <- a trava
```

### Três decisões que sustentam o modo

**A montagem da consulta é código, não prompt.** O passo 2 poderia ser "modelo,
escreva a consulta Entrez". Seria menos código e mais frágil: a sintaxe é
rígida, o modelo erra colchete, e o erro aparece como "0 resultados" —
indistinguível de "não há literatura". Em `Pico.paraEntrez` a estrutura é
garantida; o modelo contribui com o que faz bem: vocabulário clínico.

**O comparador amplia, não restringe.** Erro comum e caro: exigir o comparador
com `AND` reduz o resultado a estudos que citam os dois braços no resumo, e
joga fora justamente as metanálises. Ele entra como sinônimo do bloco da
intervenção.

**A calibração afrouxa na ordem do que custa menos:** primeiro tira o desfecho
(o campo que mais zera busca), depois o filtro de desenho, depois a janela de
datas. Verificado ao vivo: PICO completo devolveu 3 resultados (pouco); sem o
desfecho, 207 (faixa boa).

### O PICO é editável

É o ponto de correção mais barato do fluxo. Consertar "population: elderly"
antes da busca custa um clique; descobrir o erro depois de ler a síntese custa
a consulta inteira.

### O agente mostra o trabalho

Cada passo aparece enquanto acontece — a interpretação, cada estratégia com
quantos resultados deu, quantos resumos foram lidos, a conferência das
citações. Um painel que só mostrasse a resposta final seria mais limpo e muito
pior: a síntese seria tão verificável quanto um chute.

---

## 7.2 Chat de pesquisa

`lib/features/evidencias/ia/chat_pesquisa.dart`

### Por que existe, se já há o modo agente

| | Perguntar (agente) | Chat |
|---|---|---|
| Formato | uma revisão estruturada | conversa |
| Estratégia | PICO + calibração, em código | o modelo escolhe as buscas |
| Custo | várias chamadas, ~30 s | rápido por turno |
| Serve para | responder a fundo | explorar, refinar, tirar dúvida |

O médico faz as duas coisas. *"Metformina reduz eventos cardiovasculares em
idosos?"* pede revisão. *"E se ele tiver doença renal?"* — a pergunta que vem
logo depois — pede conversa, com o contexto anterior de pé.

### O acervo é acumulativo, e é isso que faz o seguimento funcionar

Cada busca do modelo entra no acervo, que **persiste pela conversa inteira**. A
validação confere contra ele, não só contra o último turno — senão citar no
turno 5 um artigo achado no turno 2 seria marcado como invenção, exatamente o
contrário do desejado. Coberto por *"citação de artigo achado em turno anterior
continua válida"*.

Limpar a conversa limpa o acervo junto: sem o acervo as citações antigas
deixariam de conferir; sem limpar a conversa o modelo citaria artigos que a
tela não mostra mais.

### Duas ferramentas, e só

`buscar_literatura` e `ler_resumos`. **Nenhuma tool de dados da clínica** — o
chat fala com um serviço externo, e misturar aqui uma ferramenta que lê
pacientes abriria caminho para dado de paciente virar termo de busca.

A guarda de PHI roda também **no cliente**, antes da chamada: num chat o modelo
monta o termo sozinho, então um dado do paciente escorregar do histórico para a
busca é risco real.

### O aviso de "respondeu sem buscar"

Quando o modelo responde sem chamar ferramenta nenhuma, a mensagem ganha um
aviso vermelho. É o caso em que ele respondeu **de memória** — o modo de falha
que o módulo inteiro existe para evitar — e é invisível sem esse sinal.

### A validação roda no fim, não durante

O texto é transmitido token a token (o médico vê a resposta nascendo), e a
conferência acontece quando há texto completo. Validar parcial marcaria como
inventado um PMID que ainda está sendo escrito.

---

## 7.3 Nível de evidência — a leitura em varredura

`lib/features/evidencias/nivel_evidencia.dart`

O desenho do estudo já aparecia como selo de texto. Texto obriga a ler cada
card. Um médico triando 20 resultados **varre** — e o que ele procura é força
de evidência.

Cada card ganhou uma barra lateral colorida pelo nível:

| Nível | Desenhos | Papel |
|---|---|---|
| Síntese | Metanálise, revisão sistemática | topo da pirâmide |
| Experimental | Ensaio randomizado | melhor controle de confusão |
| Observacional | Coorte, caso-controle, multicêntrico | evidência primária |
| Narrativa | Revisão, diretriz | útil, não é evidência primária |
| Relato | Relato de caso | gera hipótese |
| Indefinido | só "Journal Article" | o NCBI não declarou |

**A hierarquia tem críticas conhecidas** — uma metanálise de ensaios ruins não
vale mais que um ensaio bem-feito, e desenho não é qualidade. Por isso o nível
é ponto de partida da triagem, nunca nota do estudo, e o card continua
mostrando o desenho por extenso.

**"Journal Article" é indefinido, não observacional.** É o tipo genérico que
quase todo registro carrega; tratá-lo como desenho daria falsa precisão. Já um
tipo declarado que ainda não mapeamos cai em observacional — descartá-lo como
"não informado" jogaria fora o que o registro afirma.

No chat, as fontes de cada resposta mostram essas cores como barrinhas: a força
da evidência da resposta inteira num relance, sem abrir a lista.

---

## 7.4 Idiomas e tradução de conteúdo

`lib/core/i18n/` · `lib/features/evidencias/ia/tradutor.dart`

### Duas camadas diferentes

| | O quê | Como |
|---|---|---|
| **Interface** | rótulos, avisos, botões | mapas Dart por idioma, com queda no português |
| **Conteúdo** | título e resumo dos artigos | IA, sob demanda, opcional |

A segunda é a que muda a vida do usuário: a interface pode estar em português,
mas **o PubMed é em inglês**. Para quem lê inglês com esforço, isso transforma
triagem de dez segundos em leitura de dois minutos por artigo — e é o que faz a
busca de evidência ser abandonada na prática.

### Por que mapas Dart e não ARB com codegen

`gen_l10n` é o padrão do Flutter e o formato que tradutores esperam. Ficou de
fora por três motivos deste projeto:

1. **Não há etapa de codegen no build.** Introduzir uma faz `flutter test` e a
   CI dependerem de rodar `gen-l10n` antes — um modo de falha novo e silencioso.
2. **Chave faltando precisa ser visível, não fatal.** Aqui cai no português e o
   app segue; com codegen, quebra o build ou vira string vazia.
3. **A tradução dinâmica é o recurso principal**, e isso é IA em tempo de
   execução, não ARB.

Migrar depois é mecânico — as chaves já estão nomeadas e agrupadas por módulo.

### As ferramentas de migração, e o que elas ensinaram

`tool/i18n_*.py` — varrer, migrar, consertar, achar órfã, limpar morta.

Três armadilhas que custaram caro e estão travadas em comentário no código:

**1. Não dá para adivinhar `const` com regex.** Uma expressão
(`const WeekSelector(),`) parece uma declaração. A primeira versão tentou e
pulou 25 de 54 strings de um módulo, quase todas sem necessidade. O fluxo
passou a usar o compilador como oráculo: migra tudo → `flutter analyze` →
`i18n_consertar.py` desfaz só o que ele recusou.

**2. Chave viva não é só a que vem depois de `.t(`.** O detector de chaves
mortas casava `\.t2?\('chave'` e perdeu três formas legítimas —
`t.t(cond ? 'a' : 'b')`, `t.plural(n, 'a', 'b')` e `NavItem(chave: 'x')`.
Resultado: apagou 14 chaves vivas e quebrou a tela. Hoje coleta **toda** string
com formato de chave; sobrar é inofensivo, faltar não é.

**3. Âncora do assistente tem o mesmo formato de chave de tradução.**
`HelpAnchors` usa `'nav.home'`, `'home.kpis'` — e `'nav.agenda'` é âncora **e**
chave ao mesmo tempo. As ferramentas excluem `assistant_tours.dart`
explicitamente.

### O português é a fonte da verdade

`textos_pt.dart` é o mapa completo; os outros podem ficar para trás sem quebrar
nada. Isso torna possível traduzir por partes. `evidencias_i18n_sessao_test`
imprime a cobertura a cada execução e falha se algum idioma cair abaixo de 80%.

Um teste específico confere que os **marcadores** (`{n}`) sobrevivem à
tradução: uma tradução que perde o `{n}` mostra "Filtros ()" — erro que só
aparece em produção, no idioma que ninguém testa.

### Três decisões que mantêm a tradução segura

**O original nunca é substituído — é acrescentado.** Os dois textos convivem e
a tela alterna. Tradução automática de termo clínico erra: "outcome" e
"positive predictive value" têm traduções que mudam o sentido. Quem decide uma
conduta precisa poder conferir a frase original sem sair da tela.

**PMID, DOI, doses e acrônimos nunca são traduzidos.** O prompt proíbe, e a
validação de citação continua rodando sobre o **original**. Um modelo que
"traduzisse" um PMID quebraria a rastreabilidade — a única coisa que o módulo
existe para garantir.

**Hedging é preservado.** O prompt é explícito: "may reduce" não é "reduces".
Aumentar a certeza de uma afirmação clínica é o pior erro possível aqui.

Falha de tradução devolve o original marcado — nunca esconde o artigo.

---

## 7.5 Sessões, histórico e exportação

`lib/features/evidencias/sessoes/`

### Sessão não é favorito de artigo — é o estado da investigação

Guarda a pergunta, a estratégia que o PubMed executou, os artigos, a síntese e
a conversa.

Guardar só a consulta seria mais barato e errado: rodar a mesma busca duas
semanas depois devolve outro conjunto (o PubMed indexa todo dia), e a síntese
citaria artigos que sumiram da lista. Uma revisão precisa ser **reprodutível**:
o que se leu naquele dia é o que sustenta a conduta tomada naquele dia. Por
isso `queryTraduzida` e `salvaEm` são obrigatórios.

### Por que fica no dispositivo, e não no Firestore

Sessão é anotação de estudo de um profissional, não dado da clínica:

1. **Custo por leitura** — uma sessão carrega 20 artigos com resumo; a lista
   viraria dezenas de leituras a cada abertura da tela.
2. **Escopo errado** — `tb_*` é por clínica. A pesquisa do Dr. A não é da
   clínica nem do Dr. B, e um médico atende em mais de uma.
3. **Dado do NIH replicado** — resumo é conteúdo público de terceiro; espelhar
   é custo e superfície sem retorno.

A troca está dita na tela: as sessões ficam neste dispositivo. Sincronizar é
backlog, e aí o lugar é uma coleção **por usuário**.

### Restaurar não refaz a busca

Recolocar a tela no estado salvo **não** reexecuta a consulta. Reexecutar
devolveria outro conjunto (o PubMed indexa todo dia) e a síntese passaria a
citar artigos que não estão mais na lista — quebrando exatamente a
reprodutibilidade que a sessão existe para garantir. Os resumos salvos voltam
para o mapa de seções, então nem a rede é tocada. Coberto por *"restaurar NÃO
refaz a busca na rede"*.

### Histórico é separado das sessões

Histórico é rastro automático (toda busca entra, some sozinho); sessão é ato
deliberado de guardar. Misturar faria o médico caçar o que salvou no meio do
que apenas passou. Limpar um não afeta o outro — há teste para isso.

### Tetos existem por um motivo

`SharedPreferences` carrega tudo na memória no boot. Sem teto (50 sessões, 40
buscas), o app ficaria mais lento para iniciar a cada pesquisa salva — uma
degradação lenta e difícil de atribuir depois.

Entrada corrompida é ignorada, não fatal: perder **uma** sessão é muito melhor
que a lista inteira deixar de abrir.

### Exportação: quatro formatos, quatro destinos

| Formato | Para onde vai |
|---|---|
| Markdown | prontuário, e-mail, discussão de caso |
| RIS / BibTeX | Zotero, Mendeley, EndNote |
| JSON | backup e reimportação |

O Markdown carrega **a estratégia de busca e a data**, não só os artigos. É a
diferença entre "achei estes artigos" e "pesquisei assim, neste dia, e achei
estes artigos" — outra pessoa consegue repetir a busca e ver o que mudou.

---

## 8. UX

A tela é feita para **verificar**, não só ler.

| Bloco | Conteúdo |
|---|---|
| Modo | Buscar · Perguntar · Chat — seletor no topo, antes do campo |
| Busca | Campo + ordenação (Relevância / Mais recentes) |
| Resultado | Total encontrado × exibido |
| **Como pesquisamos** | `queryEnviada` × `queryTraduzida`, data, origem e se veio de cache |
| Card | Barra lateral por nível de evidência (§7.3), desenho e ano em destaque, depois título, autoria, periódico |
| Expandido | Resumo em seções rotuladas, PMID/DOI/PMC, ações |
| Ações | Abrir no PubMed · Texto completo (PMC) · Citar (Vancouver/ABNT/BibTeX/RIS) |
| Filtros | Desenho do estudo, janela, população, faixa etária, acesso, idioma |
| Histórico | Últimas 40 buscas, persistente, por modo |
| Sessões | Salvar · restaurar · renomear · exportar |
| Tradução | Botão por artigo; alterna com o original |

**O seletor de modo vem antes do campo, não num menu.** A escolha muda o que o
usuário deve digitar: em Buscar são termos em inglês com sintaxe Entrez; em
Perguntar e Chat é português corrente. Um campo só, sem indicação clara do
modo, faria o médico digitar português numa busca literal e concluir que "não
tem nada publicado" — o erro mais caro do módulo.

**"Como pesquisamos" não é enfeite.** `querytranslation` é o que o PubMed
*realmente* executou depois de expandir sinônimos e MeSH. Sem isso o médico não
tem como entender por que um artigo esperado não apareceu, e a busca vira
caixa-preta.

**Resumo sob demanda.** O EFetch de 20 artigos traz centenas de KB que quase
ninguém lê inteiros, e cada chamada consome cota do NCBI.

**Zero resultado dispara o ESpell.** Grafia errada é a causa mais comum, e
concluir "não existe literatura sobre isso" por causa de um typo é um erro caro.

**Filtro ativo é acusado no estado vazio.** É a causa mais comum de "não achou
nada" e a mais fácil de esquecer — por isso vem antes de qualquer dica de
vocabulário, com um botão de limpar ao lado.

**Filtros são aditivos dentro do grupo.** Marcar "Metanálise" e "Ensaio
randomizado" traz os dois (`OR`), não a interseção — que seria sempre vazia.

**Quatro formatos de citação.** O destino manda: periódico pede Vancouver,
trabalho brasileiro pede ABNT, gerenciador de referências pede BibTeX ou RIS.
Oferecer só um faz o médico reformatar à mão, que é onde erro de citação entra.

**O aviso de caminho direto fala com o médico, não com o desenvolvedor.** Ele
já disse *"o proxy de evidências não respondeu (rede ou CORS)"* — "CORS" não
significa nada para quem atende, e "proxy" não é problema dele. Hoje diz que a
busca está saindo direto no PubMed, que os resultados são os mesmos e que a
proteção de dados continua ativa. A causa técnica vive no tooltip e no log.

O aviso é **dispensável** e some depois de lido: fixo, custava uma faixa da
tela em toda busca para repetir algo que não muda e que o médico não pode
resolver. A informação não se perde — "Como pesquisamos" registra a origem de
cada consulta.

**Salvar só aparece quando há o que salvar.** Botão morto ensina o usuário a
ignorar a barra inteira.

**A exportação copia em vez de baixar.** O download programático é bloqueado no
sandbox da web e é no-op fora dela (§9); copiar funciona nos dois, e o médico
cola onde precisa.

**Esqueleto em vez de spinner.** Mostra a forma do que vem, o que faz a espera
parecer menor e evita o salto de layout quando os cards chegam.

---

## 9. Limites conhecidos

| Limite | Situação | Consequência |
|---|---|---|
| **Sem camada semântica** | Não há embeddings no projeto (`tb_cerebro_vetores` declarado, nada gera) | Busca é lexical; o reranking do documento §11 não existe. O Best Match do PubMed cobre bem o caso comum |
| **Sem MeSH terms** | O EFetch XML já é lido, mas só para `AbstractText` | Extrair MeSH exigiria parser de verdade; hoje o modelo *sugere* descritores no PICO e eles entram junto com `[tiab]`, então um MeSH inválido reduz mas não zera |
| **Abrir link fora da web** | `openExternalUrl` só tem implementação web; o projeto não usa `url_launcher` | Fora da web o link é copiado para a área de transferência, com aviso |
| **Sem síntese multi-artigo na tela** | A tela lista; a síntese acontece no `/ia` via ferramentas | Deliberado: separa descoberta de interpretação |
| **Sem busca salva / alerta** | `tb_scheduled_tasks` já suportaria | Backlog |
| **Teto de 10.000 resultados** | Limite do ESearch para PubMed | Consultas muito amplas precisam de segmentação por data |
| **ELink não devolve nada** | Verificado em 2026-09-01: o NCBI não computa `pubmed_pubmed` para nenhum PMID (JSON e XML) | `pubmed_relacionados` sempre devolve lista vazia com orientação para usar `pubmed_buscar`. O código está correto e fica no lugar caso o NCBI restaure |

---

## 10. Configuração

Obrigatório antes do deploy — o NCBI exige `tool` e `email` em **toda**
chamada, e sem eles a function responde 503:

```bash
firebase functions:config:set   # ou variáveis de ambiente da function
#   NCBI_TOOL=vitta_app
#   NCBI_EMAIL=<e-mail do responsável técnico>
```

Opcional (recomendado se o uso crescer):

```bash
firebase functions:secrets:set NCBI_API_KEY
```

| Sem API key | Com API key |
|---|---|
| ~3 req/s por IP (NCBI) | 10 req/s |
| Balde opera a **2/s** | Balde opera a **8/s** |

A margem é deliberada: estourar o limite não devolve erro amigável — o NCBI
bloqueia o tráfego.

Deploy:

```bash
firebase deploy --only functions:pubmedProxy
```

> Nunca `firebase deploy --only functions` sem nome — apaga as functions dos
> outros codebases. Ver [`CLOUD_FUNCTION.md`](CLOUD_FUNCTION.md) §2.

---

## 11. Proteção de dado pessoal (LGPD)

> **Nada identificável de paciente sai para o NCBI.** A consulta vai para um
> servidor de terceiro (NIH, Estados Unidos), e dado de saúde é dado sensível
> na LGPD.

A guarda está em `functions/lib/pubmed.js` (`detectarPhi`) e roda **antes de
qualquer rede**:

| Padrão | Bloqueia |
|---|---|
| CPF | `123.456.789-01` e 11 dígitos seguidos |
| CNS | 15 dígitos |
| CNPJ | com máscara ou 14 dígitos |
| E-mail | qualquer endereço |
| Telefone | `(11) 98765-4321` e variantes |
| Genérico | 11+ dígitos consecutivos |

**Calibrada contra falso positivo.** Consulta legítima carrega ano
(`2022:2026[pdat]`), dose (`850 mg`) e PMID (8 dígitos). Por isso a regra
genérica exige **11+ dígitos**: abaixo disso o risco de barrar busca válida
supera o de vazamento. Coberto por
`functions/test/pubmed.test.js › guarda de PHI`.

Bloqueio **não é falha**: a UI mostra escudo e texto que ensina a reescrever, e
a tool devolve ao modelo a instrução de refazer a busca só com elementos
clínicos.

O MVP é **pesquisa/educação**: nada do prontuário alimenta a busca. Levar
contexto de paciente exigiria camada de desidentificação e revisão de base
legal — decisão registrada, não pendência esquecida.

---

## 12. Estrutura de arquivos

```
functions/
├── pubmedProxy.js              ← HTTP: auth, parse, CORS  (allow-list de ações)
├── lib/pubmed.js               ← lógica testável: PHI, rate, cache, retry
├── test/pubmed.test.js         ← 37 testes (node --test, sem rede)
└── scripts/verificar-ncbi.js   ← verificação contra o NCBI real (§13.1)

lib/features/evidencias/
├── evidencias_screen.dart      ← tela /evidencias (2 modos)
├── evidencias_providers.dart   ← estado + controller
├── pubmed_service.dart         ← orquestra proxy → direto
├── pubmed_direct.dart          ← plano B: NCBI direto do app  (§3.0)
├── pubmed_models.dart          ← ArtigoPubmed, SecaoResumo, ResultadoBusca
├── efetch_xml.dart             ← leitor do EFetch XML
├── phi_guard.dart              ← espelho em Dart da guarda de PHI
├── filtros_busca.dart          ← filtros clínicos → Entrez
├── citacao_validator.dart      ← trava anti-PMID-inventado
├── nivel_evidencia.dart        ← pirâmide de evidência → cor  (§7.3)
├── sessoes/
│   ├── sessao_models.dart      ← o estado da investigação  (§7.5)
│   ├── sessao_store.dart       ← persistência local + histórico
│   └── sessao_export.dart      ← Markdown · RIS · BibTeX · JSON
├── ia/
│   ├── pico.dart               ← PICO → consulta Entrez
│   ├── agente_evidencias.dart  ← o loop de 7 passos  (§7.1)
│   ├── chat_pesquisa.dart      ← conversa com acervo acumulativo  (§7.2)
│   └── tradutor.dart           ← tradução de conteúdo por IA  (§7.4)
└── widgets/
    ├── artigo_card.dart · barra_pesquisa.dart · painel_filtros.dart
    ├── painel_agente.dart · painel_chat.dart · painel_sessoes.dart
    └── estados_vazios.dart · formatos_citacao.dart

lib/core/modules/mcp/tools/pubmed_tools.dart   ← 4 tools do agente
test/features/
├── evidencias_test.dart          ← 25 testes (validação, modelos, cliente)
├── evidencias_ia_test.dart       ← 33 testes (fallback, PHI, XML, PICO, citação)
├── evidencias_chat_test.dart     ← 18 testes (chat, ferramentas, nível)
├── evidencias_i18n_sessao_test.dart ← 30 testes (idiomas, sessões, export)
└── evidencias_widget_test.dart   ← 24 testes de widget (a tela de verdade)
tool/verificar_evidencias.dart    ← verificação ao vivo do caminho direto
```

---

## 13. Testes

| Onde | Quantos | Cobre |
|---|---|---|
| `functions/test/pubmed.test.js` | 37 | PHI, rate limiter, cache, retry, normalização |
| `test/features/evidencias_test.dart` | 25 | Validação de citação, modelos, cliente, tools |
| `test/features/evidencias_ia_test.dart` | 33 | Fallback, guarda de PHI no cliente, EFetch XML, filtros, PICO, formatos de citação |
| `test/features/evidencias_chat_test.dart` | 18 | Ferramentas do chat, validação acumulativa, nível de evidência |
| `test/features/evidencias_i18n_sessao_test.dart` | 30 | Idiomas e cobertura de tradução, sessões, histórico, exportação |
| `test/features/evidencias_widget_test.dart` | 24 | A tela renderizada: os três modos, filtros, sessões, estados vazios, responsividade |

Os dois rodam **sem rede e sem projeto real**: `fetch`, relógio e Firestore são
injetados. Os testes que mais importam:

- *"esearch recusa antes de qualquer rede"* — prova que PHI não vaza.
- *"NÃO bloqueia consulta clínica legítima"* — prova que a guarda não estorva.
- *"cache não gasta token"* — prova que resposta cacheada não consome cota.
- *"NÃO confunde ano, dose ou amostra com citação"* — prova que a validação não
  acusa erro onde não há.
- *"citação de artigo achado em turno anterior continua válida"* — prova que o
  seguimento do chat funciona sem virar falso positivo.
- *"bloqueia PHI no termo, sem ir à rede"* (chat) — prova que a guarda alcança
  também o termo que o **modelo** monta, não só o que o usuário digita.

### 13.1 Verificação contra o NCBI real

```bash
cd functions && node scripts/verificar-ncbi.js
```

Faz ~7 chamadas reais e confere as **suposições de formato** — que é onde um
teste com fixture própria não ajuda: a fixture é a suposição, não a resposta.

Rode depois de mexer no conector e antes de publicar `pubmedProxy`.

> **Foi assim que se achou o bug do ESpell.** Os 31 testes com fixture passavam
> e o endpoint devolvia HTTP 500 em produção, porque `retmode=json` não é
> suportado ali — e o `pubmed_ncbi_eutilities_swagger.json` do projeto declara
> que é. Especificação de terceiro é hipótese até bater no serviço.

O que ficou confirmado contra o serviço real (2026-09-01):

| Endpoint | JSON? | Observação |
|---|---|---|
| ESearch | ✅ | `querytranslation` vem preenchido |
| ESummary | ✅ | `articleids` traz DOI e PMC; `pubdate` em formato livre |
| EFetch | — texto | A marca `PMID: <id>` existe e sustenta a separação por artigo |
| ESpell | ❌ **500** | Só XML — corrigido |
| ELink | ✅ | Responde, mas sem `linksetdbs` (§9) |

---

## 14. Referências

| Assunto | Documento |
|---|---|
| Ferramentas do agente | [`MCP.md`](MCP.md) §6.20 |
| Plataforma de I.A. | [`AgentAI.md`](AgentAI.md) |
| Deploy | [`CLOUD_FUNCTION.md`](CLOUD_FUNCTION.md) |
| Chaves e endpoints | [`AI_chaves.md`](AI_chaves.md) |
| Riscos abertos | [`ATENCAO.md`](ATENCAO.md) |
| NCBI E-utilities | https://www.ncbi.nlm.nih.gov/books/NBK25499/ |
| API key do NCBI | https://www.ncbi.nlm.nih.gov/books/NBK53593/ |
