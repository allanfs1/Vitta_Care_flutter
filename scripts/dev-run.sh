#!/usr/bin/env bash
# Sobe o app Vitta em desenvolvimento com a IA funcionando (acesso DIRETO ao
# Azure AI Foundry). A chave `AZURE_AI_KEY` é lida em tempo de execução de
# `.specify/AI_chaves.md` (arquivo gitignored) — o segredo nunca é digitado à
# mão nem entra em arquivo versionado.
#
#   Uso:  ./scripts/dev-run.sh              # flutter run -d chrome
#         ./scripts/dev-run.sh -d windows   # repassa flags ao flutter run
#
# Produção (web): NÃO use este script — a chave ficaria legível no bundle.
#   flutter build web --dart-define=AI_PROXY_URL=https://us-central1-agendaclinica-457713.cloudfunctions.net/chatProxy
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHAVES="$ROOT/.specify/AI_chaves.md"

if [ ! -f "$CHAVES" ]; then
  echo "erro: não encontrei $CHAVES" >&2
  echo "      copie/preencha o arquivo conforme AI_chaves.md §2 e tente de novo." >&2
  exit 1
fi

# A chave do AI Foundry é um token alfanumérico de ~84 chars. Ancoramos a busca
# na linha que menciona AZURE_AI_KEY / DeepSeek para não pegar a do Document
# Intelligence (que tem formato parecido e aparece depois no arquivo).
KEY="$(grep -iE 'AZURE_AI_KEY|AZURE_DEEPSEEK_KEY|DeepSeek' "$CHAVES" \
        | grep -oE '[A-Za-z0-9]{70,100}' | head -n1 || true)"

if [ -z "${KEY:-}" ]; then
  echo "erro: AZURE_AI_KEY não encontrada em $CHAVES" >&2
  echo "      confira a seção 3.1 (Azure AI Foundry) do arquivo." >&2
  exit 1
fi

echo ">> AZURE_AI_KEY carregada de AI_chaves.md (${#KEY} chars) — modo: Azure direto (dev)"
exec flutter run -d chrome --dart-define=AZURE_AI_KEY="$KEY" "$@"
