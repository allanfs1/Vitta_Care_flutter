/**
 * Verificação do conector contra o NCBI REAL (sem mock).
 *
 * Não faz parte da suíte: `npm test` precisa rodar offline e determinístico.
 * Isto existe para validar as SUPOSIÇÕES sobre o formato das respostas — que
 * é onde um teste com fixture própria não ajuda em nada.
 *
 * Uso (na pasta `functions/`):
 *   node scripts/verificar-ncbi.js
 *
 * Faz ~7 chamadas reais ao NCBI. Rode depois de mexer no conector, e antes de
 * publicar `pubmedProxy`. Foi assim que se descobriu, em 2026-09-01, que o
 * ESpell devolve HTTP 500 com `retmode=json` — os 31 testes com fixture
 * passavam, porque a fixture era a minha suposição, não a resposta real.
 */

const createPubmed = require("../lib/pubmed");
const { createFakeFirestore, Timestamp } = require("../test/fakeFirestore");

const { db } = createFakeFirestore({});
const api = createPubmed({
  db,
  Timestamp,
  config: {
    tool: "vitta_app_verificacao",
    email: "dev@example.com", // placeholder — verificação pontual
  },
});

const falhas = [];
function checar(nome, condicao, detalhe) {
  const ok = !!condicao;
  console.log(`  ${ok ? "OK  " : "FALHA"} ${nome}${detalhe ? ` — ${detalhe}` : ""}`);
  if (!ok) falhas.push(nome);
}

(async () => {
  console.log("\n=== 1. ESearch contra o PubMed real ===");
  const busca = await api.esearch({
    term: "dapagliflozin[tiab] AND heart failure[tiab] AND 2019:2020[pdat]",
    retmax: 5,
  });
  console.log(`  total=${busca.total}  pmids=${busca.pmids.join(",")}`);
  console.log(`  queryTraduzida: ${busca.queryTraduzida.slice(0, 120)}...`);
  checar("total > 0", busca.total > 0, `${busca.total}`);
  checar("devolveu PMIDs", busca.pmids.length > 0, `${busca.pmids.length}`);
  checar("querytranslation preenchido", busca.queryTraduzida.length > 0);
  checar("PMIDs são numéricos", busca.pmids.every((p) => /^\d+$/.test(p)));

  console.log("\n=== 2. ESummary — o formato que a normalização assume ===");
  const resumo = await api.esummary({ pmids: busca.pmids.slice(0, 3) });
  checar("devolveu artigos", resumo.artigos.length > 0, `${resumo.artigos.length}`);

  const a = resumo.artigos[0];
  console.log("  primeiro artigo:");
  console.log(`    pmid:      ${a.pmid}`);
  console.log(`    titulo:    ${(a.titulo || "").slice(0, 80)}`);
  console.log(`    autores:   ${a.autores.slice(0, 3).join("; ")}${a.autores.length > 3 ? " ..." : ""}`);
  console.log(`    periodico: ${a.periodico}`);
  console.log(`    data:      ${a.dataPublicacao}   ano: ${a.ano}`);
  console.log(`    doi:       ${a.doi}`);
  console.log(`    pmcid:     ${a.pmcid}`);
  console.log(`    tipos:     ${a.tiposPublicacao.join(", ")}`);
  console.log(`    url:       ${a.url}`);

  checar("pmid preenchido", !!a.pmid);
  checar("titulo preenchido", !!a.titulo && a.titulo.length > 5);
  checar("autores extraídos", a.autores.length > 0);
  checar("periodico preenchido", !!a.periodico);
  checar("ano extraído de pubdate", typeof a.ano === "number" && a.ano > 1900, `${a.ano}`);
  checar("url montada", a.url.includes(a.pmid));
  checar("tiposPublicacao é lista", Array.isArray(a.tiposPublicacao));
  // DOI não é obrigatório, mas nesta faixa quase todo artigo tem — se vier
  // null em TODOS, a extração de articleids está errada.
  const comDoi = resumo.artigos.filter((x) => x.doi).length;
  checar("ao menos um DOI extraído", comDoi > 0, `${comDoi}/${resumo.artigos.length}`);

  console.log("\n=== 3. EFetch — formato do abstract em texto ===");
  const fetch = await api.efetchAbstracts({ pmids: busca.pmids.slice(0, 2) });
  const texto = fetch.texto;
  console.log(`  ${texto.length} chars`);
  console.log("  ---- amostra ----");
  console.log(texto.split("\n").slice(0, 12).map((l) => "  | " + l).join("\n"));
  checar("texto não vazio", texto.length > 100);
  // A separação por PMID no cliente depende desta marca.
  checar(
    "contém a marca 'PMID: <id>' que o cliente usa para separar",
    busca.pmids.slice(0, 2).some((p) => texto.includes(`PMID: ${p}`)),
  );

  console.log("\n=== 4. ESpell ===");
  const spell = await api.espell({ term: "hipertenssion" });
  console.log(`  "${spell.original}" -> "${spell.corrigido}"`);
  checar("sugeriu correção", spell.corrigido.length > 0, spell.corrigido);

  console.log("\n=== 5. ELink — relacionados ===");
  const link = await api.elink({ pmid: busca.pmids[0], retmax: 5 });
  console.log(`  origem=${link.origem}  relacionados=${link.relacionados.join(",") || "(nenhum)"}`);
  // NÃO se exige lista não-vazia: verificado em 2026-09-01 que o NCBI não vem
  // computando `pubmed_pubmed` para nenhum PMID (JSON e XML). O que se testa é
  // que o parser tolera isso sem quebrar nem inventar resultado.
  checar("parser tolera resposta sem linksetdbs", Array.isArray(link.relacionados));
  checar("não repete a origem", !link.relacionados.includes(link.origem));
  if (link.relacionados.length === 0) {
    console.log("  NOTA: NCBI sem Related Articles — esperado hoje (EVIDENCIAS.md §9).");
  }

  console.log("\n=== 6. Guarda de PHI contra o serviço real ===");
  let bloqueou = false;
  try {
    await api.esearch({ term: "diabetes do paciente CPF 123.456.789-01" });
  } catch (e) {
    bloqueou = e.codigo === "PHI_BLOCKED";
  }
  checar("PHI bloqueado antes de sair", bloqueou);

  console.log("\n=== 7. Cache: segunda chamada não vai à rede ===");
  const t0 = Date.now();
  const r2 = await api.esearch({
    term: "dapagliflozin[tiab] AND heart failure[tiab] AND 2019:2020[pdat]",
    retmax: 5,
  });
  const ms = Date.now() - t0;
  checar("veio do cache", r2.doCache === true, `${ms}ms`);

  console.log("\n" + "=".repeat(60));
  if (falhas.length === 0) {
    console.log("TUDO OK — o conector bate com o formato real do NCBI.");
  } else {
    console.log(`${falhas.length} FALHA(S): ${falhas.join(" | ")}`);
    process.exitCode = 1;
  }
})().catch((e) => {
  console.error("\nERRO NA VERIFICAÇÃO:", e && e.message);
  console.error(e);
  process.exitCode = 1;
});
