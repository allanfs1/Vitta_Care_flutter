/**
 * migrateTenantField.js — Migração ÚNICA do campo de tenant (§6.6 de
 * `.specify/CUSTO.md`). O campo CANÔNICO é `idclinica` (minúsculo, como
 * DocumentReference para `tb_clinica`) — é o dominante na base (49 índices vs 2
 * de idClinica). Este script garante `idclinica` (reference) em todo documento,
 * derivando de `idClinica`/`clinicaId`/`id_clinica` quando faltar.
 *
 * NÃO é uma Cloud Function — é um script administrativo, executado manualmente
 * UMA vez, fora do cron, com credenciais de admin. É idempotente (rerodar não
 * duplica nem reescreve quem já tem `idClinica`).
 *
 * Pré-requisitos:
 *   1. EXPORTE o Firestore antes (rollback): `gcloud firestore export gs://...`.
 *   2. Credenciais admin: `GOOGLE_APPLICATION_CREDENTIALS=/caminho/sa.json`.
 *
 * Uso:
 *   node functions/scripts/migrateTenantField.js --dry-run            # só conta
 *   node functions/scripts/migrateTenantField.js                      # aplica
 *   node functions/scripts/migrateTenantField.js --collections=users,tickets
 *
 * Depois de validar a contagem migrada e os relatórios da IA, é seguro reduzir
 * TENANT_FIELDS a apenas `idclinica` em scheduledTasksCron.js e reativar a
 * agregação count() em taxa_absenteismo.
 */

const { initializeApp, applicationDefault, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

// Coleções que usam `idclinica` legado (alinhadas às ferramentas do agente).
const DEFAULT_COLLECTIONS = [
  "tb_agendamentos",
  "users",
  "tb_medicos",
  "tickets",
  "tb_overbooking_events",
  "queue_realoc",
  "tb_relatorio_ia",
  "email_logs",
  "email_queue",
];

const PAGE = 300;

function parseArgs() {
  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");
  const col = args.find((a) => a.startsWith("--collections="));
  const collections = col ? col.split("=")[1].split(",").map((s) => s.trim()).filter(Boolean) : DEFAULT_COLLECTIONS;
  return { dryRun, collections };
}

/// Extrai o id da clínica de um valor legado (reference | path | string).
function clinicIdOf(v) {
  if (!v) return null;
  if (v.id) return v.id;                      // DocumentReference
  if (typeof v === "string") return v.split("/").pop();
  if (v.path) return String(v.path).split("/").pop();
  return null;
}

async function migrateCollection(db, name, dryRun) {
  let migrated = 0, scanned = 0, skipped = 0;
  let last = null;

  for (;;) {
    let q = db.collection(name).orderBy("__name__").limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    let batch = db.batch();
    let ops = 0;
    for (const doc of snap.docs) {
      scanned++;
      const d = doc.data();
      // Já tem o canônico `idclinica` como reference → nada a fazer (idempotência).
      if (d.idclinica && d.idclinica.id) { skipped++; continue; }
      // Deriva o id da clínica das demais variantes.
      const id = clinicIdOf(d.idclinica) || clinicIdOf(d.idClinica) ||
        clinicIdOf(d.clinicaId) || clinicIdOf(d.id_clinica);
      if (!id) { skipped++; continue; }       // sem tenant utilizável
      if (!dryRun) {
        batch.update(doc.ref, { idclinica: db.collection("tb_clinica").doc(id) });
        ops++;
        if (ops >= 450) { await batch.commit(); batch = db.batch(); ops = 0; }
      }
      migrated++;
    }
    if (!dryRun && ops > 0) await batch.commit();
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }

  console.log(
    `[${name}] escaneados=${scanned} ${dryRun ? "a_migrar" : "migrados"}=${migrated} ignorados=${skipped}`
  );
  return { migrated, scanned, skipped };
}

async function main() {
  const { dryRun, collections } = parseArgs();
  if (!getApps().length) initializeApp({ credential: applicationDefault() });
  const db = getFirestore();

  console.log(`Migração → idclinica (canônico) ${dryRun ? "(DRY-RUN)" : "(APLICANDO)"} em: ${collections.join(", ")}`);
  let total = 0;
  for (const name of collections) {
    try {
      const r = await migrateCollection(db, name, dryRun);
      total += r.migrated;
    } catch (e) {
      console.error(`[${name}] erro: ${e && e.message ? e.message : e}`);
    }
  }
  console.log(`Concluído. Total ${dryRun ? "a migrar" : "migrado"}: ${total}.`);
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
