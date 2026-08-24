# EXEC_CUSTO.md — Runbook de deploy da otimização de custo

Comandos prontos para aplicar a otimização de `.specify/CUSTO.md`. Rodar da
**raiz do repositório** (`vitta_app/`). Projeto: `agendaclinica-457713`.

> **Estado atual (jun/2026):**
> - ✅ Índices Firestore — **já deployados** (aditivo; 11 novos em `idclinica`).
> - ⛔ Function `scheduledTasksCron` — **bloqueada por billing** (Secret Manager 403).
> - ⏸ Migração de dados — script pronto, **não executada**.

---

## 0. PRÉ-REQUISITO (destrava tudo) — billing + secrets

O deploy da function falhou com:
`403 ... Secret Manager ... requires billing to be enabled`.

1. Habilitar/regularizar **billing** do projeto:
   https://console.developers.google.com/billing/enable?project=agendaclinica-457713
2. Confirmar que os **secrets** existem (codebase `ia` carrega todos no deploy):
   ```bash
   firebase functions:secrets:get AZURE_AI_KEY      --project agendaclinica-457713
   firebase functions:secrets:get SENDGRID_API_KEY  --project agendaclinica-457713
   firebase functions:secrets:get AZURE_DOCINTEL_KEY --project agendaclinica-457713
   ```
   (Se algum faltar: `firebase functions:secrets:set <NOME> --project agendaclinica-457713`.)

---

## 1. DEPLOY — comando único (índices + function)

Índices são idempotentes (re-rodar é inócuo). Function só sobe após o billing OK.

```bash
firebase deploy \
  --only firestore:indexes,functions:ia:scheduledTasksCron \
  --project agendaclinica-457713 --non-interactive
```

> Se quiser separar: primeiro `--only firestore:indexes`, depois
> `--only functions:ia:scheduledTasksCron`.

---

## 2. VERIFICAÇÃO pós-deploy

```bash
# (a) Índices: nenhum deve estar "Building" travado; sem FAILED_PRECONDITION.
firebase firestore:indexes --project agendaclinica-457713 | grep -c idclinica

# (b) Função publicada e agendada (*/15).
firebase functions:list --project agendaclinica-457713 | grep scheduledTasksCron

# (c) Custo por execução: o log estruturado traz "reads" por tarefa.
#     Esperado < 300; circuit breaker aborta acima de READ_BUDGET (1500).
firebase functions:log --only scheduledTasksCron --project agendaclinica-457713 \
  | grep task_run
```

Critérios de aceite (CUSTO.md §8): `reads` por execução **< 500**; sem
`READ_BUDGET_EXCEEDED` recorrente; sem `FAILED_PRECONDITION` nos logs.

---

## 3. MIGRAÇÃO do campo de tenant (§6.6) — opcional, após validar o deploy

Unifica o tenant em `idclinica` (canônico) e **elimina a dupla query**. Requer
credenciais admin (`GOOGLE_APPLICATION_CREDENTIALS`) e `gcloud`.

```bash
# 3.1 BACKUP antes (rollback):
gcloud firestore export gs://agendaclinica-457713-backups/$(date +%F) \
  --project agendaclinica-457713

# 3.2 Simular (não grava):
node functions/scripts/migrateTenantField.js --dry-run

# 3.3 Aplicar:
node functions/scripts/migrateTenantField.js

# 3.4 (opcional) só uma coleção:
node functions/scripts/migrateTenantField.js --collections=tb_agendamentos
```

Depois da migração validada, é seguro: reduzir `TENANT_FIELDS` a apenas
`["idclinica"]` e reativar a agregação `count()` em `taxa_absenteismo`
(scheduledTasksCron.js), e então redeployar (passo 1).

---

## 4. ROLLBACK

- **Function:** redeploy da revisão anterior pelo Console
  (Cloud Functions → scheduledTasksCron → versões) ou `git revert` + passo 1.
- **Índices:** são aditivos; remover via Console se necessário (não afeta dados).
- **Migração:** restaurar o export do passo 3.1.

---

## 5. AJUSTE FINO de custo (sem novo código)

Diais em `functions/scheduledTasksCron.js` (constantes no topo):
- `READ_BUDGET` (1500) → teto de leituras por execução; baixar aperta.
- `MAX_TASKS_PER_RUN` (10) → tarefas por tick.
- `schedule` (`*/15`) → frequência; `*/30` reduz pela metade.

Testes locais (sem Firebase): `cd functions && npm test` → `# pass 20`.
