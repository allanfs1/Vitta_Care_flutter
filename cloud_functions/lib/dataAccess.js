/**
 * dataAccess.js — Camada de acesso a dados escopada por tenant (CUSTO.md §6.1/
 * §6.2/§6.3/§6.6). Fábrica que recebe `db` e `Timestamp` injetados, para ser
 * testável com um Firestore falso (`functions/test/fakeFirestore.js`).
 *
 * Garantias estruturais:
 *   - Nenhuma query sem filtro de tenant (sem full scan).
 *   - Cache por execução em `fetchAgendamentos`.
 *   - Janela temporal empurrada para a query quando informada.
 *   - Toda leitura é contabilizada no read meter (circuit breaker).
 */

const { apptDate } = require("./costGuards");

module.exports = function createDataAccess({ db, Timestamp, tenantFields, agendamentosLimit }) {
  const TENANT_FIELDS = tenantFields || ["idclinica", "idClinica"];
  const AGENDAMENTOS_QUERY_LIMIT = agendamentosLimit || 500;

  function clinicRef(clinicaId) {
    return db.collection("tb_clinica").doc(clinicaId);
  }

  async function meteredGet(query, meter) {
    const snap = await query.get();
    if (meter) meter.add(snap.size || 1);
    return snap;
  }

  async function meteredCount(query, meter) {
    const agg = await query.count().get();
    if (meter) meter.add(1);
    return agg.data().count;
  }

  // Cobre os formatos reais do campo de tenant em produção (heterogêneo):
  // `idclinica`/`idClinica` como DocumentReference OU como string, e o campo
  // `clinicaId` (string). A ordem prioriza o dominante (idclinica reference); o
  // early-break do tenantFetch evita rodar as variantes raras quando o limite
  // já foi suprido. Mantém a cobertura do antigo full-scan + belongsToClinic,
  // mas SEM full scan. (Docs com tenant como "tb_clinica/<id>" só serão
  // unificados pela migração §6.6.)
  function tenantQueries(collection, clinicaId) {
    const ref = clinicRef(clinicaId);
    const out = [];
    for (const f of TENANT_FIELDS) {
      out.push(db.collection(collection).where(f, "==", ref));        // reference
      out.push(db.collection(collection).where(f, "==", clinicaId));  // string
    }
    out.push(db.collection(collection).where("clinicaId", "==", clinicaId)); // campo string
    return out;
  }

  // O circuit breaker (§6.8) NUNCA pode ser engolido pelo fallback de índice:
  // re-lança para abortar a execução quando o orçamento de leitura estoura.
  const isBudgetError = (e) => e && /READ_BUDGET_EXCEEDED/.test(e.message || "");

  async function tenantFetch(collection, clinicaId, { build, memFilter, limit = 50 } = {}, meter) {
    const byId = new Map();
    for (const base of tenantQueries(collection, clinicaId)) {
      let docs = [];
      try {
        const q = (build ? build(base) : base).limit(limit);
        docs = (await meteredGet(q, meter)).docs;
      } catch (e) {
        if (isBudgetError(e)) throw e;
        // Índice composto ausente → query só-tenant + filtro em memória.
        try {
          const snap = await meteredGet(base.limit(Math.max(limit, 200)), meter);
          docs = memFilter
            ? snap.docs.filter((d) => memFilter({ id: d.id, ...d.data() }))
            : snap.docs;
        } catch (e2) {
          if (isBudgetError(e2)) throw e2;
          /* coleção/índice indisponível p/ esse campo */
        }
      }
      for (const d of docs) {
        if (!byId.has(d.id)) byId.set(d.id, { id: d.id, ...d.data() });
      }
      if (byId.size >= limit) break;
    }
    return [...byId.values()];
  }

  async function listScoped(collection, clinicaId, { filters = {}, limit = 50 } = {}, meter) {
    const entries = Object.entries(filters).filter(([, v]) => v != null && v !== "");
    const list = await tenantFetch(collection, clinicaId, {
      limit,
      build: (q) => entries.reduce((qq, [k, v]) => qq.where(k, "==", v), q),
      memFilter: (d) => entries.every(([k, v]) => String(d[k]) === String(v)),
    }, meter);
    return list.slice(0, limit);
  }

  async function fetchAgendamentos(clinicaId, cache, meter, { since = null, until = null } = {}) {
    const key = `${clinicaId}|${since ? since.getTime() : ""}|${until ? until.getTime() : ""}`;
    if (cache && cache.agendamentos.has(key)) return cache.agendamentos.get(key);

    const inWindow = (a) => {
      if (!since && !until) return true;
      const t = apptDate(a) ? apptDate(a).getTime() : null;
      if (t == null) return false;
      if (since && t < since.getTime()) return false;
      if (until && t > until.getTime()) return false;
      return true;
    };

    const list = await tenantFetch("tb_agendamentos", clinicaId, {
      limit: AGENDAMENTOS_QUERY_LIMIT,
      build: (q) => {
        let qq = q;
        if (since) qq = qq.where("dataConsulta", ">=", Timestamp.fromDate(since));
        if (until) qq = qq.where("dataConsulta", "<=", Timestamp.fromDate(until));
        return qq;
      },
      memFilter: inWindow,
    }, meter);

    if (cache) cache.agendamentos.set(key, list);
    return list;
  }

  return {
    clinicRef,
    meteredGet,
    meteredCount,
    tenantQueries,
    tenantFetch,
    listScoped,
    fetchAgendamentos,
  };
};
