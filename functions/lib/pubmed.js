/**
 * pubmed.js — lógica do conector NCBI E-utilities, isolada do HTTP (fábrica que
 * recebe `db`/`Timestamp`/`fetch`/relógio injetados) para ser testável com um
 * Firestore falso — mesmo padrão de `lib/publicAgenda.js` e `lib/dataAccess.js`.
 *
 * Ver `.specify/EVIDENCIAS.md` para a especificação do módulo.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Três decisões que este arquivo carrega, e por quê:
 *
 * 1. **O limitador de taxa é global, não por instância.** O NCBI limita por
 *    **IP**, e todas as instâncias da Cloud Function compartilham o pool de IPs
 *    de saída do projeto. Um token bucket em memória contaria certo dentro de
 *    cada instância e erraria no agregado — que é justamente o número que o
 *    NCBI enxerga. Por isso o bucket vive numa transação do Firestore.
 *
 * 2. **PHI é bloqueado em código, não no prompt.** Este conector manda texto
 *    para um servidor de terceiro (NIH, fora do país). A regra "nunca escreva
 *    CPF/nome/telefone" que o Cérebro aplica hoje é instrução de prompt — um
 *    modelo pode desobedecer. Aqui a checagem é determinística e recusa antes
 *    de qualquer rede.
 *
 * 3. **O cache é compartilhado entre clínicas, de propósito.** O registro do
 *    PMID 31452104 é idêntico para toda clínica: é literatura pública, não dado
 *    de tenant. Cachear por clínica multiplicaria o custo do Firestore pelo
 *    número de clínicas sem nenhum ganho. O que é por clínica — buscas, notas,
 *    histórico — não passa por aqui. Ver EVIDENCIAS.md §4.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const crypto = require("crypto");

/** Base pública das E-utilities. */
const BASE_PADRAO = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils";

/**
 * Teto de req/s enviado ao NCBI.
 *
 * O NCBI documenta ~3 req/s por IP sem API key e 10 req/s com chave. Operamos
 * abaixo do teto de propósito: o limite é do IP compartilhado do projeto, e
 * estourar não devolve erro amigável — o NCBI bloqueia o tráfego.
 */
const TAXA_SEM_CHAVE = 2;
const TAXA_COM_CHAVE = 8;

/** Espera máxima por um token antes de desistir e devolver 429 ao cliente. */
const ESPERA_MAX_MS = 2500;

/** TTL do cache por ação (ms). Metadado muda menos que a consulta. */
const TTL_MS = {
  esearch: 15 * 60 * 1000, //  15 min — a busca é o que mais muda
  esummary: 24 * 60 * 60 * 1000, //  24 h
  efetch: 24 * 60 * 60 * 1000, //  24 h
  espell: 7 * 24 * 60 * 60 * 1000, //   7 d
  elink: 24 * 60 * 60 * 1000, //  24 h
};

/** Acima disto não vale a pena cachear (limite de 1 MiB por documento). */
const CACHE_MAX_BYTES = 700 * 1024;

/** Teto de PMIDs por chamada — acima disso a URL fica grande demais. */
const MAX_IDS = 200;

/** Status HTTP que valem retry. */
const RETRIAVEIS = new Set([429, 500, 502, 503, 504]);

const COL_CACHE = "tb_pubmed_cache";
const COL_RATE = "tb_pubmed_rate";
const DOC_RATE = "global";

// ─────────────────────────── Guarda de PHI ───────────────────────────

/**
 * Padrões de dado pessoal que **nunca** podem sair para o NCBI.
 *
 * Calibrados contra falso positivo: uma consulta legítima carrega anos
 * (`2022:2026[pdat]`), números de dose (`10 mg`) e PMIDs de 8 dígitos. Por isso
 * a regra genérica exige **11+ dígitos seguidos** — abaixo disso, o risco de
 * barrar busca válida é maior que o de vazamento.
 */
const PADROES_PHI = [
  {
    id: "cpf",
    rotulo: "CPF",
    re: /\b\d{3}\.\d{3}\.\d{3}-\d{2}\b|\b\d{11}\b/,
  },
  {
    id: "cns",
    rotulo: "Cartão Nacional de Saúde",
    re: /\b\d{15}\b/,
  },
  {
    id: "cnpj",
    rotulo: "CNPJ",
    re: /\b\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}\b|\b\d{14}\b/,
  },
  {
    id: "email",
    rotulo: "e-mail",
    re: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/,
  },
  {
    id: "telefone",
    rotulo: "telefone",
    re: /\(\d{2}\)\s?9?\d{4}-?\d{4}|\b\d{2}\s9\d{4}-?\d{4}\b/,
  },
  {
    id: "digitos_longos",
    rotulo: "sequência longa de dígitos",
    re: /\d{11,}/,
  },
];

/**
 * Devolve os rótulos dos padrões de dado pessoal encontrados em [texto].
 * Lista vazia = liberado.
 */
function detectarPhi(texto) {
  const s = (texto == null ? "" : String(texto));
  if (!s.trim()) return [];
  const achados = [];
  for (const p of PADROES_PHI) {
    if (p.re.test(s) && !achados.includes(p.rotulo)) achados.push(p.rotulo);
  }
  return achados;
}

// ─────────────────────────── Utilidades ───────────────────────────

function chaveCache(acao, params) {
  const norm = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== null && params[k] !== "")
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join("&");
  return crypto.createHash("sha256").update(`${acao}|${norm}`).digest("hex");
}

/** Normaliza a lista de PMIDs: só dígitos, sem duplicata, com teto. */
function normalizarIds(ids) {
  const bruto = Array.isArray(ids) ? ids : String(ids || "").split(",");
  const vistos = new Set();
  for (const v of bruto) {
    const s = String(v == null ? "" : v).trim();
    if (/^\d+$/.test(s) && !vistos.has(s)) vistos.add(s);
    if (vistos.size >= MAX_IDS) break;
  }
  return [...vistos];
}

function dormir(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

/**
 * Extrai o conteúdo de uma tag XML simples (sem filhos), já decodificando as
 * cinco entidades predefinidas.
 *
 * Uso restrito ao ESpell, que é o único endpoint sem JSON (ver `espell`).
 * Não é — e não deve virar — parser de XML genérico: para estrutura de
 * verdade, o caminho é ESummary em JSON.
 */
function extrairTag(xml, tag) {
  const m = new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`, "i").exec(String(xml || ""));
  if (!m) return "";
  return m[1]
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&")
    .trim();
}

class PubmedErro extends Error {
  constructor(mensagem, status, codigo) {
    super(mensagem);
    this.status = status || 502;
    this.codigo = codigo || "UPSTREAM_ERROR";
  }
}

// ─────────────────────────── Fábrica ───────────────────────────

/**
 * @param {object} deps
 * @param {object} deps.db            Firestore (Admin SDK ou falso)
 * @param {object} deps.Timestamp     Timestamp do Admin SDK ou falso
 * @param {function} [deps.fetchImpl] `fetch` (injetável nos testes)
 * @param {function} [deps.now]       Relógio em ms (injetável nos testes)
 * @param {function} [deps.sleep]     Espera (injetável nos testes)
 * @param {object} deps.config        { baseUrl, tool, email, apiKey }
 */
module.exports = function createPubmed({
  db,
  Timestamp,
  fetchImpl,
  now,
  sleep,
  config = {},
}) {
  const doFetch = fetchImpl || globalThis.fetch;
  const agora = now || (() => Date.now());
  const esperar = sleep || dormir;

  const baseUrl = (config.baseUrl || BASE_PADRAO).replace(/\/+$/, "");
  const tool = config.tool || "";
  const email = config.email || "";
  const apiKey = config.apiKey || "";
  const taxaPorSegundo = apiKey ? TAXA_COM_CHAVE : TAXA_SEM_CHAVE;

  /**
   * `tool` e `email` são exigidos pelo NCBI em toda requisição. Sem eles a
   * aplicação fica anônima e sujeita a bloqueio sem aviso — falhar aqui, na
   * configuração, é melhor que descobrir em produção por tráfego barrado.
   */
  function exigirIdentificacao() {
    if (!tool || !email) {
      throw new PubmedErro(
        "Conector NCBI não configurado: defina NCBI_TOOL e NCBI_EMAIL. " +
          "O NCBI exige os dois em toda chamada.",
        503,
        "NOT_CONFIGURED",
      );
    }
  }

  function paramsComuns() {
    const p = { tool, email };
    if (apiKey) p.api_key = apiKey;
    return p;
  }

  // ── Limitador global (token bucket em transação) ──────────────────────

  /**
   * Consome um token do bucket compartilhado. Devolve `0` quando o token saiu
   * na hora, ou os ms que faltavam quando foi preciso esperar.
   *
   * Espera curta é resolvida aqui (o chamador quer o resultado, não um erro);
   * espera longa vira 429 para o cliente, porque segurar a function ocupada é
   * pagar por tempo ocioso.
   */
  async function consumirToken() {
    const ref = db.collection(COL_RATE).doc(DOC_RATE);
    let esperaTotal = 0;

    for (let tentativa = 0; tentativa < 3; tentativa++) {
      const t0 = agora();
      const estado = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const dados = snap.exists ? snap.data() : null;
        const tokensAntes = typeof dados?.tokens === "number" ? dados.tokens : taxaPorSegundo;
        const desde = typeof dados?.atualizadoMs === "number" ? dados.atualizadoMs : t0;

        // Reposição proporcional ao tempo decorrido, limitada à capacidade.
        const decorrido = Math.max(0, t0 - desde);
        const repostos = (decorrido / 1000) * taxaPorSegundo;
        const disponivel = Math.min(taxaPorSegundo, tokensAntes + repostos);

        if (disponivel >= 1) {
          tx.set(ref, { tokens: disponivel - 1, atualizadoMs: t0 }, { merge: true });
          return { ok: true, esperaMs: 0 };
        }
        // Quanto falta para completar 1 token.
        const faltam = ((1 - disponivel) / taxaPorSegundo) * 1000;
        tx.set(ref, { tokens: disponivel, atualizadoMs: t0 }, { merge: true });
        return { ok: false, esperaMs: Math.ceil(faltam) };
      });

      if (estado.ok) return esperaTotal;

      esperaTotal += estado.esperaMs;
      if (esperaTotal > ESPERA_MAX_MS) {
        throw new PubmedErro(
          "Limite de requisições ao NCBI atingido. Tente novamente em instantes.",
          429,
          "RATE_LIMITED",
        );
      }
      await esperar(estado.esperaMs);
    }

    throw new PubmedErro(
      "Não foi possível obter vaga no limitador do NCBI.",
      429,
      "RATE_LIMITED",
    );
  }

  // ── Cache ─────────────────────────────────────────────────────────────

  async function lerCache(chave) {
    try {
      const snap = await db.collection(COL_CACHE).doc(chave).get();
      if (!snap.exists) return null;
      const d = snap.data() || {};
      if (typeof d.expiraMs !== "number" || d.expiraMs <= agora()) return null;
      return { payload: JSON.parse(d.payload), gravadoMs: d.gravadoMs };
    } catch (_) {
      // Cache é otimização: falha nele nunca derruba a consulta.
      return null;
    }
  }

  async function gravarCache(chave, acao, payload) {
    try {
      const texto = JSON.stringify(payload);
      if (texto.length > CACHE_MAX_BYTES) return;
      const t = agora();
      await db.collection(COL_CACHE).doc(chave).set({
        acao,
        payload: texto,
        gravadoMs: t,
        expiraMs: t + (TTL_MS[acao] || TTL_MS.esearch),
        // Campo de conveniência para uma futura TTL policy do Firestore.
        expiraEm: Timestamp ? Timestamp.fromDate(new Date(t + (TTL_MS[acao] || TTL_MS.esearch))) : null,
      });
    } catch (_) {
      // idem
    }
  }

  // ── Chamada HTTP com retry ────────────────────────────────────────────

  async function chamar(caminho, params, { texto = false } = {}) {
    exigirIdentificacao();

    const url = new URL(`${baseUrl}/${caminho}`);
    const todos = { ...params, ...paramsComuns() };
    for (const [k, v] of Object.entries(todos)) {
      if (v !== undefined && v !== null && v !== "") url.searchParams.set(k, String(v));
    }

    let ultimoErro = null;
    for (let tentativa = 0; tentativa < 4; tentativa++) {
      await consumirToken();

      let res;
      try {
        res = await doFetch(url.toString(), {
          method: "GET",
          headers: { Accept: texto ? "text/plain" : "application/json" },
          signal: AbortSignal.timeout(20000),
        });
      } catch (e) {
        // Rede/timeout: vale retry.
        ultimoErro = new PubmedErro(`Falha de rede ao chamar o NCBI: ${e.message}`, 502);
        await esperar(backoff(tentativa));
        continue;
      }

      if (res.ok) {
        const corpo = texto ? await res.text() : await res.json().catch(() => null);
        if (!texto && corpo === null) {
          // O endpoint devolveu algo que não é JSON (erro do NCBI costuma vir
          // em XML mesmo com retmode=json). Não vale retry: a requisição está
          // malformada, repetir só gasta cota.
          throw new PubmedErro("O NCBI devolveu resposta não-JSON.", 502, "UPSTREAM_ERROR");
        }
        return corpo;
      }

      if (!RETRIAVEIS.has(res.status)) {
        const detalhe = (await res.text().catch(() => "")).slice(0, 300);
        throw new PubmedErro(
          `NCBI HTTP ${res.status}${detalhe ? `: ${detalhe}` : ""}`,
          res.status === 400 ? 400 : 502,
          res.status === 400 ? "INVALID_QUERY" : "UPSTREAM_ERROR",
        );
      }

      ultimoErro = new PubmedErro(`NCBI HTTP ${res.status}`, 502);
      await esperar(backoff(tentativa));
    }

    throw ultimoErro || new PubmedErro("Falha ao chamar o NCBI.", 502);
  }

  /** Backoff exponencial com jitter determinístico o bastante para testar. */
  function backoff(tentativa) {
    const base = Math.min(1000 * 2 ** tentativa, 8000);
    return base + (agora() % 250);
  }

  async function comCache(acao, params, executar, opts = {}) {
    const chave = chaveCache(acao, params);
    const guardado = await lerCache(chave);
    if (guardado) return { ...guardado.payload, _cache: true };

    const fresco = await executar();
    await gravarCache(chave, acao, fresco);
    return { ...fresco, _cache: false };
  }

  // ── Operações ─────────────────────────────────────────────────────────

  /**
   * ESearch — pesquisa e devolve PMIDs.
   * O `querytranslation` do NCBI é preservado: é o que o PubMed **realmente**
   * pesquisou, e sem ele não dá para auditar a diferença entre a pergunta do
   * médico e a busca executada.
   */
  async function esearch({ term, retmax = 20, retstart = 0, sort = "relevance", usehistory = false } = {}) {
    const consulta = String(term || "").trim();
    if (!consulta) throw new PubmedErro("Informe o termo de busca.", 400, "INVALID_QUERY");

    const phi = detectarPhi(consulta);
    if (phi.length) {
      throw new PubmedErro(
        `A busca foi bloqueada: o termo contém ${phi.join(", ")}. ` +
          "Dado pessoal de paciente nunca é enviado ao PubMed. Reescreva a pergunta " +
          "apenas com os elementos clínicos (condição, intervenção, desfecho).",
        400,
        "PHI_BLOCKED",
      );
    }

    const params = {
      db: "pubmed",
      term: consulta,
      retmode: "json",
      retmax: Math.min(Math.max(Number(retmax) || 20, 1), 100),
      retstart: Math.max(Number(retstart) || 0, 0),
      sort,
    };
    if (usehistory) params.usehistory = "y";

    const bruto = await comCache("esearch", params, () => chamar("esearch.fcgi", params));
    const r = bruto?.esearchresult || {};

    if (r.ERROR) {
      throw new PubmedErro(`Consulta rejeitada pelo NCBI: ${r.ERROR}`, 400, "INVALID_QUERY");
    }

    return {
      total: Number(r.count || 0),
      retornados: Array.isArray(r.idlist) ? r.idlist.length : 0,
      retstart: Number(r.retstart || 0),
      pmids: Array.isArray(r.idlist) ? r.idlist : [],
      // A consulta como o PubMed a interpretou — o campo mais importante para auditoria.
      queryTraduzida: r.querytranslation || "",
      queryEnviada: consulta,
      webenv: r.webenv || null,
      queryKey: r.querykey || null,
      doCache: bruto._cache === true,
      buscadoEm: new Date(agora()).toISOString(),
    };
  }

  /** ESummary — metadados dos artigos (JSON). */
  async function esummary({ pmids } = {}) {
    const ids = normalizarIds(pmids);
    if (!ids.length) throw new PubmedErro("Informe ao menos um PMID.", 400, "INVALID_QUERY");

    const params = { db: "pubmed", id: ids.join(","), retmode: "json", version: "2.0" };
    const bruto = await comCache("esummary", params, () => chamar("esummary.fcgi", params));
    const result = bruto?.result || {};
    const ordem = Array.isArray(result.uids) ? result.uids : ids;

    return {
      artigos: ordem.map((id) => normalizarArtigo(result[id], id)).filter(Boolean),
      doCache: bruto._cache === true,
      buscadoEm: new Date(agora()).toISOString(),
    };
  }

  /**
   * EFetch — abstracts em XML.
   *
   * **Era `retmode=text` e mudou.** O formato texto é um relatório para humanos:
   * a citação quebra em várias linhas, e separá-la do resumo por heurística de
   * linha erra — a continuação da linha `doi:` vazava para dentro do resumo,
   * porque só a primeira linha começava com a palavra. O XML resolve por
   * estrutura, e ainda entrega os rótulos de seção (BACKGROUND/METHODS/...)
   * que o texto descarta.
   *
   * O XML **não é parseado aqui**: a function repassa cru e o cliente extrai
   * duas tags conhecidas (`efetch_xml.dart`). Assim continua não havendo
   * dependência de parser XML no servidor — a preocupação que motivou a
   * escolha original segue atendida.
   */
  async function efetchAbstracts({ pmids } = {}) {
    const ids = normalizarIds(pmids);
    if (!ids.length) throw new PubmedErro("Informe ao menos um PMID.", 400, "INVALID_QUERY");

    const params = { db: "pubmed", id: ids.join(","), retmode: "xml", rettype: "abstract" };
    const chave = chaveCache("efetch", params);
    const guardado = await lerCache(chave);
    if (guardado) return { ...guardado.payload, doCache: true };

    const xml = await chamar("efetch.fcgi", params, { texto: true });
    const payload = { xml: String(xml || ""), pmids: ids };
    await gravarCache(chave, "efetch", payload);
    return { ...payload, doCache: false, buscadoEm: new Date(agora()).toISOString() };
  }

  /**
   * ESpell — sugestão de correção de termo.
   *
   * ⚠️ **ESpell só responde XML.** Diferente de ESearch/ESummary/ELink, este
   * endpoint devolve **HTTP 500** quando recebe `retmode=json` — verificado
   * contra o serviço real em 2026-09-01. O `pubmed_ncbi_eutilities_swagger.json`
   * que acompanha o projeto declara `RetModeJson` aqui; está errado.
   *
   * Por isso a resposta é lida como texto e o campo é extraído por regex de uma
   * tag única e bem conhecida (`<CorrectedQuery>`) — não é parsing de XML
   * genérico, e não justifica trazer uma dependência de parser (que é
   * superfície de ataque conhecida em XML).
   */
  async function espell({ term } = {}) {
    const consulta = String(term || "").trim();
    if (!consulta) throw new PubmedErro("Informe o termo.", 400, "INVALID_QUERY");
    const phi = detectarPhi(consulta);
    if (phi.length) {
      throw new PubmedErro(
        `Termo bloqueado: contém ${phi.join(", ")}.`,
        400,
        "PHI_BLOCKED",
      );
    }

    // Sem `retmode`: o padrão do ESpell é XML, e pedir JSON quebra.
    const params = { db: "pubmed", term: consulta };
    const chave = chaveCache("espell", params);
    const guardado = await lerCache(chave);
    if (guardado) return { ...guardado.payload, doCache: true };

    const xml = await chamar("espell.fcgi", params, { texto: true });
    const payload = {
      original: extrairTag(xml, "Query") || consulta,
      corrigido: extrairTag(xml, "CorrectedQuery"),
    };
    await gravarCache(chave, "espell", payload);
    return { ...payload, doCache: false };
  }

  /**
   * ELink — artigos relacionados a um PMID.
   *
   * ⚠️ **Hoje o NCBI devolve `linksets` sem `linksetdbs` para `pubmed_pubmed`**
   * — verificado em 2026-09-01 contra vários PMIDs, em JSON e em XML: o
   * conjunto "Related Articles" simplesmente não vem. O código abaixo está
   * correto (lê a estrutura e devolve lista vazia); é a fonte que não entrega.
   *
   * Mantido porque o custo é zero e o NCBI pode restaurar o cálculo. Quem
   * consome deve tratar lista vazia como normal, não como erro — a tool
   * `pubmed_relacionados` orienta o modelo a usar `pubmed_buscar` nesse caso.
   */
  async function elink({ pmid, retmax = 10 } = {}) {
    const ids = normalizarIds([pmid]);
    if (!ids.length) throw new PubmedErro("Informe um PMID válido.", 400, "INVALID_QUERY");

    const params = {
      dbfrom: "pubmed",
      db: "pubmed",
      id: ids[0],
      linkname: "pubmed_pubmed",
      retmode: "json",
    };
    const bruto = await comCache("elink", params, () => chamar("elink.fcgi", params));

    const conjuntos = bruto?.linksets || [];
    const primeiro = conjuntos[0] || {};
    const dbs = primeiro.linksetdbs || [];
    const alvo = dbs.find((d) => d.linkname === "pubmed_pubmed") || dbs[0] || {};
    const ligados = Array.isArray(alvo.links) ? alvo.links : [];

    return {
      origem: ids[0],
      // O primeiro relacionado costuma ser o próprio artigo.
      relacionados: ligados.filter((x) => String(x) !== ids[0]).slice(0, Math.min(Number(retmax) || 10, 50)),
      doCache: bruto._cache === true,
    };
  }

  return {
    detectarPhi,
    chaveCache,
    normalizarIds,
    normalizarArtigo,
    esearch,
    esummary,
    efetchAbstracts,
    espell,
    elink,
    PubmedErro,
    _consumirToken: consumirToken,
    _taxaPorSegundo: taxaPorSegundo,
  };
};

// ─────────────────────────── Normalização ───────────────────────────

/**
 * Converte um DocSum do ESummary no formato mínimo por artigo
 * (EVIDENCIAS.md §5). Defensivo: o ESummary omite campos com frequência, e um
 * registro incompleto ainda é útil se o PMID estiver lá.
 */
function normalizarArtigo(doc, pmid) {
  if (!doc || typeof doc !== "object") return null;
  if (doc.error) return null;

  const ids = Array.isArray(doc.articleids) ? doc.articleids : [];
  const acharId = (tipo) => {
    const achado = ids.find((x) => x && x.idtype === tipo);
    return achado && achado.value ? String(achado.value) : null;
  };

  const autores = Array.isArray(doc.authors)
    ? doc.authors
        .filter((a) => a && a.name && a.authtype !== "CollectiveName")
        .map((a) => String(a.name))
    : [];

  const id = String(doc.uid || pmid || "");

  return {
    pmid: id,
    titulo: (doc.title || "").toString().replace(/\s+/g, " ").trim(),
    autores,
    periodico: (doc.fulljournalname || doc.source || "").toString(),
    // `pubdate` do NCBI vem em formatos variados ("2024 May 3", "2024"); a
    // precisão original é preservada em vez de forçar uma data falsa.
    dataPublicacao: (doc.pubdate || doc.epubdate || "").toString(),
    ano: anoDe(doc.pubdate || doc.epubdate || ""),
    doi: acharId("doi"),
    pmcid: acharId("pmc"),
    tiposPublicacao: Array.isArray(doc.pubtype) ? doc.pubtype.map(String) : [],
    volume: (doc.volume || "").toString(),
    paginas: (doc.pages || "").toString(),
    url: id ? `https://pubmed.ncbi.nlm.nih.gov/${id}/` : "",
  };
}

function anoDe(pubdate) {
  const m = String(pubdate || "").match(/\b(1[89]\d{2}|20\d{2})\b/);
  return m ? Number(m[1]) : null;
}

module.exports.detectarPhi = detectarPhi;
module.exports.normalizarArtigo = normalizarArtigo;
module.exports.PubmedErro = PubmedErro;
module.exports.TAXA_SEM_CHAVE = TAXA_SEM_CHAVE;
module.exports.TAXA_COM_CHAVE = TAXA_COM_CHAVE;
