/**
 * Testes do conector NCBI E-utilities (`lib/pubmed.js`).
 *
 * Roda com `node --test`, sem rede e sem projeto real: `fetch` e o relógio são
 * injetados, e o Firestore é o falso de `fakeFirestore.js`.
 *
 * O que estes testes protegem, em ordem de importância:
 *   1. PHI nunca sai para o NCBI (guarda em código, não no prompt).
 *   2. O limitador de taxa é global e realmente gasta token.
 *   3. Cache evita a segunda chamada de rede.
 *   4. `querytranslation` sobrevive — é o que torna a busca auditável.
 */

const test = require("node:test");
const assert = require("node:assert/strict");

const { createFakeFirestore, Timestamp } = require("./fakeFirestore");
const createPubmed = require("../lib/pubmed");
const { detectarPhi, normalizarArtigo } = require("../lib/pubmed");

const CONFIG = {
  baseUrl: "https://eutils.example/entrez/eutils",
  tool: "vitta_test",
  email: "dev@example.com",
};

/** Monta um `fetch` falso que devolve respostas em fila e registra as URLs. */
function fakeFetch(respostas) {
  const chamadas = [];
  const fila = [...respostas];
  const fn = async (url) => {
    chamadas.push(url);
    const r = fila.length > 1 ? fila.shift() : fila[0];
    if (typeof r === "function") return r(url);
    return {
      ok: r.status === undefined || (r.status >= 200 && r.status < 300),
      status: r.status || 200,
      async json() {
        if (r.json === undefined) throw new Error("não é JSON");
        return r.json;
      },
      async text() {
        return r.text !== undefined ? r.text : JSON.stringify(r.json ?? {});
      },
    };
  };
  fn.chamadas = chamadas;
  return fn;
}

function montar({ respostas = [{ json: {} }], seed = {}, agoraMs = 1_700_000_000_000, config = CONFIG } = {}) {
  const { db, writes } = createFakeFirestore(seed);
  let relogio = agoraMs;
  const esperas = [];
  const doFetch = fakeFetch(respostas);
  const api = createPubmed({
    db,
    Timestamp,
    fetchImpl: doFetch,
    now: () => relogio,
    sleep: async (ms) => {
      esperas.push(ms);
      relogio += ms; // o tempo passa: é o que repõe token no bucket
    },
    config,
  });
  return {
    api,
    doFetch,
    writes,
    esperas,
    avancar: (ms) => { relogio += ms; },
    get relogio() { return relogio; },
  };
}

// ───────────────────────────── PHI ─────────────────────────────

test("guarda de PHI", async (t) => {
  await t.test("bloqueia CPF com e sem máscara", () => {
    assert.deepEqual(detectarPhi("paciente 123.456.789-01 com diabetes"), ["CPF"]);
    assert.ok(detectarPhi("diabetes 12345678901").includes("CPF"));
  });

  await t.test("bloqueia e-mail, telefone e cartão do SUS", () => {
    assert.deepEqual(detectarPhi("contato maria@clinica.com"), ["e-mail"]);
    assert.ok(detectarPhi("ligar (11) 98765-4321").includes("telefone"));
    assert.ok(detectarPhi("cns 123456789012345").includes("Cartão Nacional de Saúde"));
  });

  await t.test("NÃO bloqueia consulta clínica legítima", () => {
    // Este é o teste que evita a guarda virar estorvo: janela de datas, dose,
    // PMID de 8 dígitos e faixa etária são numéricos e precisam passar.
    assert.deepEqual(detectarPhi("diabetes type 2[tiab] AND 2022:2026[pdat]"), []);
    assert.deepEqual(detectarPhi("metformin 850 mg AND adults 40-65"), []);
    assert.deepEqual(detectarPhi("31452104"), []);
    assert.deepEqual(detectarPhi("SGLT2 inhibitor[tiab] NOT animals[mesh]"), []);
  });

  await t.test("esearch recusa antes de qualquer rede", async () => {
    const { api, doFetch } = montar();
    await assert.rejects(
      () => api.esearch({ term: "diabetes do paciente 123.456.789-01" }),
      (e) => e.codigo === "PHI_BLOCKED" && e.status === 400,
    );
    // O ponto central: nenhuma requisição saiu.
    assert.equal(doFetch.chamadas.length, 0);
  });
});

// ─────────────────────────── Configuração ───────────────────────────

test("exige tool e email do NCBI", async () => {
  const { api, doFetch } = montar({ config: { baseUrl: CONFIG.baseUrl, tool: "", email: "" } });
  await assert.rejects(
    () => api.esearch({ term: "asthma" }),
    (e) => e.codigo === "NOT_CONFIGURED" && e.status === 503,
  );
  assert.equal(doFetch.chamadas.length, 0);
});

test("tool e email vão em toda chamada", async () => {
  const { api, doFetch } = montar({
    respostas: [{ json: { esearchresult: { count: "1", idlist: ["1"] } } }],
  });
  await api.esearch({ term: "asthma" });
  const url = new URL(doFetch.chamadas[0]);
  assert.equal(url.searchParams.get("tool"), "vitta_test");
  assert.equal(url.searchParams.get("email"), "dev@example.com");
  assert.equal(url.searchParams.get("db"), "pubmed");
});

// ───────────────────────────── ESearch ─────────────────────────────

test("esearch preserva a consulta traduzida pelo NCBI", async () => {
  const { api } = montar({
    respostas: [{
      json: {
        esearchresult: {
          count: "1287",
          retstart: "0",
          idlist: ["31452104", "31556701"],
          querytranslation: '"diabetes mellitus, type 2"[MeSH Terms]',
        },
      },
    }],
  });
  const r = await api.esearch({ term: "diabetes type 2[tiab]" });
  assert.equal(r.total, 1287);
  assert.deepEqual(r.pmids, ["31452104", "31556701"]);
  // Sem isto não há como auditar o que o PubMed realmente pesquisou.
  assert.equal(r.queryTraduzida, '"diabetes mellitus, type 2"[MeSH Terms]');
  assert.equal(r.queryEnviada, "diabetes type 2[tiab]");
});

test("esearch propaga erro de consulta do NCBI como 400", async () => {
  const { api } = montar({
    respostas: [{ json: { esearchresult: { ERROR: "Invalid field" } } }],
  });
  await assert.rejects(
    () => api.esearch({ term: "x[campoinexistente]" }),
    (e) => e.codigo === "INVALID_QUERY" && e.status === 400,
  );
});

test("esearch limita retmax ao teto e recusa termo vazio", async () => {
  const { api, doFetch } = montar({
    respostas: [{ json: { esearchresult: { count: "0", idlist: [] } } }],
  });
  await api.esearch({ term: "asthma", retmax: 5000 });
  assert.equal(new URL(doFetch.chamadas[0]).searchParams.get("retmax"), "100");

  await assert.rejects(() => api.esearch({ term: "   " }), (e) => e.status === 400);
});

// ───────────────────────────── Cache ─────────────────────────────

test("cache evita a segunda chamada de rede", async () => {
  const { api, doFetch } = montar({
    respostas: [{ json: { esearchresult: { count: "2", idlist: ["1", "2"] } } }],
  });
  const a = await api.esearch({ term: "asthma" });
  const b = await api.esearch({ term: "asthma" });

  assert.equal(a.doCache, false);
  assert.equal(b.doCache, true);
  assert.equal(doFetch.chamadas.length, 1, "a segunda busca não pode ir à rede");
  assert.deepEqual(b.pmids, a.pmids);
});

test("cache expira e volta à rede", async () => {
  const ctx = montar({
    respostas: [{ json: { esearchresult: { count: "1", idlist: ["1"] } } }],
  });
  await ctx.api.esearch({ term: "asthma" });
  ctx.avancar(16 * 60 * 1000); // TTL de esearch é 15 min
  const depois = await ctx.api.esearch({ term: "asthma" });
  assert.equal(depois.doCache, false);
  assert.equal(ctx.doFetch.chamadas.length, 2);
});

test("consultas diferentes não colidem no cache", async () => {
  const { api, doFetch } = montar({
    respostas: [{ json: { esearchresult: { count: "1", idlist: ["1"] } } }],
  });
  await api.esearch({ term: "asthma" });
  await api.esearch({ term: "diabetes" });
  assert.equal(doFetch.chamadas.length, 2);
});

// ─────────────────────── Limitador de taxa ───────────────────────

test("limitador global", async (t) => {
  await t.test("gasta um token por chamada e persiste no Firestore", async () => {
    const { api, writes } = montar({
      respostas: [{ json: { esearchresult: { count: "0", idlist: [] } } }],
    });
    await api.esearch({ term: "a" });
    const rate = writes.filter((w) => w.coll === "tb_pubmed_rate");
    assert.ok(rate.length >= 1, "o bucket precisa ser gravado");
    // Sem API key a capacidade é 2/s; após uma chamada resta 1.
    assert.equal(api._taxaPorSegundo, 2);
    assert.ok(rate[rate.length - 1].data.tokens < 2);
  });

  await t.test("espera quando o balde esvazia, em vez de estourar o NCBI", async () => {
    const ctx = montar({
      respostas: [{ json: { esearchresult: { count: "0", idlist: [] } } }],
      // Balde já vazio, atualizado agora: não há token disponível.
      seed: { tb_pubmed_rate: [{ id: "global", tokens: 0, atualizadoMs: 1_700_000_000_000 }] },
    });
    await ctx.api.esearch({ term: "termo-unico-sem-cache" });
    assert.ok(ctx.esperas.length >= 1, "deveria ter esperado por um token");
    assert.ok(ctx.esperas[0] > 0);
  });

  await t.test("capacidade sobe para 8/s com API key", () => {
    const { api } = montar({ config: { ...CONFIG, apiKey: "chave" } });
    assert.equal(api._taxaPorSegundo, 8);
  });

  await t.test("cache não gasta token", async () => {
    const ctx = montar({
      respostas: [{ json: { esearchresult: { count: "0", idlist: [] } } }],
    });
    await ctx.api.esearch({ term: "asthma" });
    const antes = ctx.writes.filter((w) => w.coll === "tb_pubmed_rate").length;
    await ctx.api.esearch({ term: "asthma" }); // vem do cache
    const depois = ctx.writes.filter((w) => w.coll === "tb_pubmed_rate").length;
    assert.equal(depois, antes, "resposta cacheada não pode consumir cota do NCBI");
  });
});

// ───────────────────────────── Retry ─────────────────────────────

test("429 é retentado e depois tem sucesso", async () => {
  let n = 0;
  const doFetch = async () => {
    n += 1;
    if (n === 1) return { ok: false, status: 429, async text() { return "slow down"; } };
    return { ok: true, status: 200, async json() { return { esearchresult: { count: "1", idlist: ["7"] } }; } };
  };
  const { db } = createFakeFirestore({});
  let relogio = 1_700_000_000_000;
  const api = createPubmed({
    db, Timestamp, fetchImpl: doFetch,
    now: () => relogio,
    sleep: async (ms) => { relogio += ms; },
    config: CONFIG,
  });
  const r = await api.esearch({ term: "asthma" });
  assert.deepEqual(r.pmids, ["7"]);
  assert.equal(n, 2);
});

test("400 do NCBI não é retentado", async () => {
  let n = 0;
  const doFetch = async () => {
    n += 1;
    return { ok: false, status: 400, async text() { return "Bad request"; } };
  };
  const { db } = createFakeFirestore({});
  const api = createPubmed({
    db, Timestamp, fetchImpl: doFetch,
    now: () => 1_700_000_000_000,
    sleep: async () => {},
    config: CONFIG,
  });
  await assert.rejects(
    () => api.esearch({ term: "asthma" }),
    (e) => e.status === 400 && e.codigo === "INVALID_QUERY",
  );
  assert.equal(n, 1, "repetir um 400 só gasta cota do NCBI");
});

// ──────────────────────── Normalização ────────────────────────

test("normalizarArtigo", async (t) => {
  const doc = {
    uid: "31452104",
    title: "Effect  of   SGLT2 inhibitors\non outcomes",
    fulljournalname: "New England Journal of Medicine",
    source: "N Engl J Med",
    pubdate: "2019 Sep 19",
    volume: "381",
    pages: "1995-2008",
    authors: [
      { name: "McMurray JJV", authtype: "Author" },
      { name: "DAPA-HF Committees", authtype: "CollectiveName" },
    ],
    articleids: [
      { idtype: "pubmed", value: "31452104" },
      { idtype: "doi", value: "10.1056/NEJMoa1911303" },
      { idtype: "pmc", value: "PMC123456" },
    ],
    pubtype: ["Randomized Controlled Trial"],
  };

  await t.test("extrai os campos mínimos e monta a URL do PubMed", () => {
    const a = normalizarArtigo(doc);
    assert.equal(a.pmid, "31452104");
    assert.equal(a.titulo, "Effect of SGLT2 inhibitors on outcomes"); // espaços normalizados
    assert.equal(a.periodico, "New England Journal of Medicine");
    assert.equal(a.doi, "10.1056/NEJMoa1911303");
    assert.equal(a.pmcid, "PMC123456");
    assert.equal(a.ano, 2019);
    assert.equal(a.dataPublicacao, "2019 Sep 19"); // precisão original preservada
    assert.equal(a.url, "https://pubmed.ncbi.nlm.nih.gov/31452104/");
    assert.deepEqual(a.tiposPublicacao, ["Randomized Controlled Trial"]);
  });

  await t.test("descarta autor coletivo da lista de pessoas", () => {
    assert.deepEqual(normalizarArtigo(doc).autores, ["McMurray JJV"]);
  });

  await t.test("tolera registro incompleto sem lançar", () => {
    const a = normalizarArtigo({ uid: "1" });
    assert.equal(a.pmid, "1");
    assert.equal(a.doi, null);
    assert.equal(a.ano, null);
    assert.deepEqual(a.autores, []);
  });

  await t.test("devolve null para registro de erro do NCBI", () => {
    assert.equal(normalizarArtigo({ error: "cannot get document summary" }), null);
    assert.equal(normalizarArtigo(null), null);
  });
});

test("esummary mantém a ordem devolvida pelo NCBI e ignora erros", async () => {
  const { api } = montar({
    respostas: [{
      json: {
        result: {
          uids: ["2", "1"],
          1: { uid: "1", title: "Um", articleids: [] },
          2: { uid: "2", title: "Dois", articleids: [] },
          3: { error: "not found" },
        },
      },
    }],
  });
  const r = await api.esummary({ pmids: ["1", "2", "3"] });
  assert.deepEqual(r.artigos.map((a) => a.pmid), ["2", "1"]);
});

test("normalizarIds descarta lixo, deduplica e limita", async () => {
  const { api } = montar();
  assert.deepEqual(api.normalizarIds(["12", "abc", "12", " 34 ", ""]), ["12", "34"]);
  assert.equal(api.normalizarIds(Array.from({ length: 500 }, (_, i) => String(i + 1))).length, 200);
  assert.deepEqual(api.normalizarIds("1,2,3"), ["1", "2", "3"]);
});

test("esummary recusa lista vazia sem ir à rede", async () => {
  const { api, doFetch } = montar();
  await assert.rejects(() => api.esummary({ pmids: [] }), (e) => e.status === 400);
  await assert.rejects(() => api.esummary({ pmids: ["abc"] }), (e) => e.status === 400);
  assert.equal(doFetch.chamadas.length, 0);
});

// ───────────────────────── EFetch / ELink / ESpell ─────────────────────────

test("efetch pede XML e repassa cru", async () => {
  // O XML é repassado sem parsing: quem extrai as tags é o cliente
  // (`efetch_xml.dart`). Assim o servidor segue sem dependência de parser XML.
  const XML = '<PubmedArticleSet><PubmedArticle><PMID Version="1">31452104</PMID>' +
    '<Abstract><AbstractText Label="RESULTS">Abstract text here.</AbstractText>' +
    "</Abstract></PubmedArticle></PubmedArticleSet>";
  const { api, doFetch } = montar({ respostas: [{ text: XML }] });
  const r = await api.efetchAbstracts({ pmids: ["31452104"] });

  assert.ok(r.xml.includes("Abstract text here."));
  assert.deepEqual(r.pmids, ["31452104"]);
  const url = new URL(doFetch.chamadas[0]);
  // `text` traía o resumo: a citação quebra em linhas e vazava para dentro
  // dele. Ver o comentário de `efetchAbstracts`.
  assert.equal(url.searchParams.get("retmode"), "xml");
  assert.equal(url.searchParams.get("rettype"), "abstract");
});

test("elink tolera resposta sem linksetdbs (comportamento atual do NCBI)", async () => {
  // Verificado em 2026-09-01: o NCBI devolve `linksets` sem `linksetdbs` para
  // pubmed_pubmed, em JSON e em XML, para qualquer PMID. Lista vazia é o
  // normal — o parser não pode quebrar nem inventar resultado.
  const { api } = montar({
    respostas: [{
      json: { linksets: [{ dbfrom: "pubmed", ids: ["31535829"] }] },
    }],
  });
  const r = await api.elink({ pmid: "31535829" });
  assert.deepEqual(r.relacionados, []);
  assert.equal(r.origem, "31535829");
});

test("elink devolve relacionados sem repetir a origem", async () => {
  const { api } = montar({
    respostas: [{
      json: {
        linksets: [{
          linksetdbs: [{ linkname: "pubmed_pubmed", links: ["31452104", "999", "888"] }],
        }],
      },
    }],
  });
  const r = await api.elink({ pmid: "31452104" });
  assert.deepEqual(r.relacionados, ["999", "888"]);
  assert.equal(r.origem, "31452104");
});

test("espell", async (t) => {
  // O ESpell é o único endpoint que NÃO aceita JSON: com `retmode=json` o NCBI
  // devolve HTTP 500 (verificado contra o serviço real em 2026-09-01). O
  // swagger que acompanha o projeto documenta `retmode` aqui — está errado.
  const XML = `<?xml version="1.0"?>
<eSpellResult>
	<Database>pubmed</Database>
	<Query>hipertenssion</Query>
	<CorrectedQuery>hypertension</CorrectedQuery>
	<ERROR/>
</eSpellResult>`;

  await t.test("lê a correção do XML", async () => {
    const { api } = montar({ respostas: [{ text: XML }] });
    const r = await api.espell({ term: "hipertenssion" });
    assert.equal(r.corrigido, "hypertension");
    assert.equal(r.original, "hipertenssion");
  });

  await t.test("NÃO envia retmode — é o que quebrava o endpoint", async () => {
    const { api, doFetch } = montar({ respostas: [{ text: XML }] });
    await api.espell({ term: "hipertenssion" });
    const url = new URL(doFetch.chamadas[0]);
    assert.equal(url.searchParams.get("retmode"), null);
  });

  await t.test("termo já correto devolve correção vazia", async () => {
    const semCorrecao = `<eSpellResult><Query>hypertension</Query>` +
      `<CorrectedQuery></CorrectedQuery></eSpellResult>`;
    const { api } = montar({ respostas: [{ text: semCorrecao }] });
    const r = await api.espell({ term: "hypertension" });
    assert.equal(r.corrigido, "");
  });

  await t.test("decodifica entidades XML", async () => {
    const comEntidade = `<eSpellResult><Query>a&amp;b</Query>` +
      `<CorrectedQuery>heart &amp; failure</CorrectedQuery></eSpellResult>`;
    const { api } = montar({ respostas: [{ text: comEntidade }] });
    const r = await api.espell({ term: "a&b" });
    assert.equal(r.corrigido, "heart & failure");
  });

  await t.test("bloqueia PHI antes da rede", async () => {
    const { api, doFetch } = montar({ respostas: [{ text: XML }] });
    await assert.rejects(
      () => api.espell({ term: "joao@paciente.com" }),
      (e) => e.codigo === "PHI_BLOCKED",
    );
    assert.equal(doFetch.chamadas.length, 0);
  });
});
