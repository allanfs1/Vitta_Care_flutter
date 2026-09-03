<#
.SYNOPSIS
  Sobe o app Vitta em desenvolvimento com a IA funcionando (acesso DIRETO ao
  Azure AI Foundry). A chave AZURE_AI_KEY e lida em tempo de execucao de
  .specify\AI_chaves.md (gitignored) — o segredo nunca e digitado nem versionado.

.EXAMPLE
  .\scripts\dev-run.ps1
  .\scripts\dev-run.ps1 -d windows

.NOTES
  Producao (web): NAO use este script. Rode com o proxy, sem a chave no bundle:
    flutter build web --dart-define=AI_PROXY_URL=https://us-central1-agendaclinica-457713.cloudfunctions.net/chatProxy
#>
$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$chaves = Join-Path $root '.specify\AI_chaves.md'

if (-not (Test-Path $chaves)) {
  Write-Error "Nao encontrei $chaves. Preencha conforme AI_chaves.md secao 2."
  exit 1
}

# Token alfanumerico de ~84 chars, ancorado na linha do AI Foundry / DeepSeek
# (para nao pegar a chave do Document Intelligence, de formato parecido).
$line = Select-String -Path $chaves -Pattern 'AZURE_AI_KEY|AZURE_DEEPSEEK_KEY|DeepSeek' |
        Select-Object -First 5
$key  = $null
foreach ($l in $line) {
  $mm = [regex]::Match($l.Line, '[A-Za-z0-9]{70,100}')
  if ($mm.Success) { $key = $mm.Value; break }
}

if (-not $key) {
  Write-Error "AZURE_AI_KEY nao encontrada em $chaves (ver secao 3.1)."
  exit 1
}

Write-Host ">> AZURE_AI_KEY carregada de AI_chaves.md ($($key.Length) chars) — modo: Azure direto (dev)"
& flutter run -d chrome --dart-define=AZURE_AI_KEY=$key @args
