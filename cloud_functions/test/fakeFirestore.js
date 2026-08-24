/**
 * fakeFirestore.js — Firestore em memória para os testes de custo. Implementa o
 * subconjunto da API usado por `lib/dataAccess.js` e CONTABILIZA leituras
 * (1/doc em get, 1 em count, 1 em doc.get) para validar as garantias do CUSTO.md.
 *
 * `opts.failOn({ coll, filters, agg })` permite simular índice composto ausente
 * (FAILED_PRECONDITION) e exercitar o caminho de fallback.
 */

function ts(d) {
  const ms = d instanceof Date ? d.getTime() : d;
  return { _ts: true, ms, toDate() { return new Date(ms); }, toMillis() { return ms; } };
}
function ref(coll, id) {
  return { _ref: true, id, path: `${coll}/${id}` };
}

const Timestamp = {
  fromDate(d) { return ts(d); },
  now() { return ts(new Date()); },
};

function match(row, f) {
  const rv = row[f.field];
  const fv = f.value;
  if (f.op === "==") {
    if (fv && fv._ref) return !!(rv && rv.id === fv.id);
    return rv === fv;
  }
  const a = rv && rv._ts ? rv.ms : (rv && rv.toDate ? rv.toDate().getTime() : rv);
  const b = fv && fv._ts ? fv.ms : (fv && fv.getTime ? fv.getTime() : fv);
  if (f.op === ">=") return a >= b;
  if (f.op === "<=") return a <= b;
  if (f.op === "<") return a < b;
  if (f.op === ">") return a > b;
  return true;
}

function createFakeFirestore(seed = {}, opts = {}) {
  const failOn = opts.failOn || (() => false);
  const reads = { total: 0, queries: [] };

  const strip = (row) => { const { id, ...rest } = row; return rest; };

  function snapshot(rows) {
    return {
      docs: rows.map((r) => ({ id: r.id, data: () => strip(r), ref: { async update() {} } })),
      size: rows.length,
      empty: rows.length === 0,
    };
  }
  function runQuery(coll, filters, lim) {
    let rows = (seed[coll] || []).filter((r) => filters.every((f) => match(r, f)));
    if (lim != null) rows = rows.slice(0, lim);
    return rows;
  }
  function makeQuery(coll, filters, lim) {
    return {
      _coll: coll, _filters: filters, _limit: lim,
      where(field, op, value) { return makeQuery(coll, [...filters, { field, op, value }], lim); },
      orderBy() { return makeQuery(coll, filters, lim); },
      startAfter() { return makeQuery(coll, filters, lim); },
      limit(n) { return makeQuery(coll, filters, n); },
      async get() {
        if (failOn({ coll, filters })) throw new Error("FAILED_PRECONDITION: query requires an index.");
        const rows = runQuery(coll, filters, lim);
        reads.total += rows.length;
        reads.queries.push({ coll, fields: filters.map((f) => f.field) });
        return snapshot(rows);
      },
      count() {
        return {
          async get() {
            if (failOn({ coll, filters, agg: true })) throw new Error("FAILED_PRECONDITION");
            const rows = runQuery(coll, filters, null);
            reads.total += 1;
            reads.queries.push({ coll, fields: filters.map((f) => f.field), agg: true });
            return { data: () => ({ count: rows.length }) };
          },
        };
      },
      doc(id) { return makeDoc(coll, id); },
      async add() { return { id: "new-" + Math.random().toString(36).slice(2, 8) }; },
    };
  }
  function makeDoc(coll, id) {
    return {
      id, _ref: true, path: `${coll}/${id}`,
      async get() {
        reads.total += 1;
        reads.queries.push({ coll, doc: id });
        const r = (seed[coll] || []).find((x) => x.id === id);
        return { exists: !!r, id, data: () => (r ? strip(r) : undefined) };
      },
      async update() {}, async set() {},
    };
  }
  function collection(name) { return makeQuery(name, [], null); }

  const db = {
    collection,
    async runTransaction(fn) {
      return fn({ async get(r) { return r.get(); }, update() {} });
    },
  };
  return { db, reads, Timestamp, ref, ts };
}

module.exports = { createFakeFirestore, Timestamp, ref, ts };
