/**
 * fakeFirestore.js — Firestore em memória para os testes de custo. Implementa o
 * subconjunto da API usado por `lib/dataAccess.js` e CONTABILIZA leituras
 * (1/doc em get, 1 em count, 1 em doc.get) para validar as garantias do CUSTO.md.
 *
 * `opts.failOn({ coll, filters, agg })` permite simular índice composto ausente
 * (FAILED_PRECONDITION) e exercitar o caminho de fallback.
 *
 * `doc.set()`/`doc.update()` **persistem de verdade** no `seed` em memória (com
 * merge quando `{merge: true}` é passado) e ficam registrados em `writes` —
 * usado por `lib/publicAgenda.js` (`functions/test/publicAgenda.test.js`), que
 * precisa ver o que acabou de gravar em consultas seguintes na mesma execução
 * (ex.: duas solicitações seguidas para o mesmo horário). `doc()` sem `id` gera
 * um id aleatório, como o `.doc()` real do Firestore.
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
  const writes = [];

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
      async add(data) {
        const d = makeDoc(coll, undefined);
        await d.set(data);
        return d;
      },
    };
  }
  function makeDoc(coll, id) {
    const docId = id ?? ("auto-" + Math.random().toString(36).slice(2, 10));
    function upsert(data, merge) {
      const list = seed[coll] || (seed[coll] = []);
      const idx = list.findIndex((x) => x.id === docId);
      const base = merge && idx >= 0 ? strip(list[idx]) : {};
      const row = { id: docId, ...base, ...data };
      if (idx >= 0) list[idx] = row;
      else list.push(row);
    }
    return {
      id: docId, _ref: true, path: `${coll}/${docId}`,
      async get() {
        reads.total += 1;
        reads.queries.push({ coll, doc: docId });
        const r = (seed[coll] || []).find((x) => x.id === docId);
        return { exists: !!r, id: docId, data: () => (r ? strip(r) : undefined) };
      },
      async update(data) {
        writes.push({ type: "update", coll, id: docId, data });
        upsert(data, true);
      },
      async set(data, options) {
        writes.push({ type: "set", coll, id: docId, data, options });
        upsert(data, !!(options && options.merge));
      },
    };
  }
  function collection(name) { return makeQuery(name, [], null); }

  const db = {
    collection,
    // A transação aplica as escritas de verdade. Antes `update()` era no-op, o
    // que fazia qualquer código transacional (lock de tarefa, token bucket do
    // NCBI) "passar" no teste sem nunca gravar — o teste ficava verde
    // justamente onde o bug moraria. Não há isolamento nem retry aqui: o que se
    // testa é a lógica dentro da transação, não a semântica do Firestore.
    async runTransaction(fn) {
      return fn({
        async get(r) { return r.get(); },
        set(r, data, options) { return r.set(data, options); },
        update(r, data) { return r.update(data); },
      });
    },
  };
  return { db, reads, writes, Timestamp, ref, ts };
}

module.exports = { createFakeFirestore, Timestamp, ref, ts };
