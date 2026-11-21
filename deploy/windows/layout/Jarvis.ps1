# Jarvis portable launcher (Windows). Approval engine stays on.
param(
  [string]$Chat = "",
  [switch]$NoWait
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$env:PATH = "$Root\bin\node;$Root\bin\llama;$Root\scripts;$env:PATH"
$env:LLAMA_BASE_URL = $(if ($env:LLAMA_BASE_URL) { $env:LLAMA_BASE_URL } else { "http://127.0.0.1:8080/v1" })
$env:COWORK_APPROVAL_PROMPTS = $(if ($env:COWORK_APPROVAL_PROMPTS) { $env:COWORK_APPROVAL_PROMPTS } else { "on" })
$Models = Join-Path $Root "models"
$Workspace = Join-Path $Root "workspace"
New-Item -ItemType Directory -Force -Path $Models, $Workspace, (Join-Path $Workspace ".cowork") | Out-Null

# Persona
$PersonaSrc = Join-Path $Root "cowork\resources\jarvis-persona"
if (Test-Path $PersonaSrc) {
  Copy-Item "$PersonaSrc\*.md" (Join-Path $Workspace ".cowork") -Force
}

# Fetch LFM3 if needed
$FetchLfm3 = Join-Path $Root "scripts\fetch-lfm3.ps1"
if (Test-Path $FetchLfm3) { & $FetchLfm3 -ModelsDir $Models }

# Pick a model
$Model = Join-Path $Models "LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf"
$Alias = "LFM3-1.7B-Uncensored"
$Ctx = "32768"
$Select = Join-Path $Root "scripts\select_model.py"
if ((Get-Command python -ErrorAction SilentlyContinue) -and (Test-Path $Select)) {
  try {
    $json = & python $Select | Out-String | ConvertFrom-Json
    if ($json.model_path -and (Test-Path $json.model_path)) {
      $Model = $json.model_path
      if ($json.alias) { $Alias = $json.alias }
      if ($json.ctx_size) { $Ctx = [string]$json.ctx_size }
      Write-Host "Selected $($json.tier) ($Alias, ctx=$Ctx) — $($json.reason)"
    }
  } catch {
    Write-Host "select_model.py failed; staying on LFM3. $_"
  }
}
if ($env:JARVIS_MODEL_FILE) { $Model = $env:JARVIS_MODEL_FILE }
if (-not (Test-Path $Model)) {
  Write-Error "Model not found: $Model. Run scripts\fetch-lfm3.ps1 first."
  exit 1
}

$Llama = Join-Path $Root "bin\llama\llama-server.exe"
if (-not (Test-Path $Llama)) {
  $FetchLlama = Join-Path $Root "scripts\fetch-llama.ps1"
  if (Test-Path $FetchLlama) { & $FetchLlama }
}
if (-not (Test-Path $Llama)) {
  Write-Error "llama-server.exe not found at $Llama. Run scripts\fetch-llama.ps1 on Windows."
  exit 1
}
$Node = Join-Path $Root "bin\node\node.exe"
if (-not (Test-Path $Node)) {
  $alt = Get-ChildItem -Path (Join-Path $Root "bin\node") -Filter node.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($alt) { $Node = $alt.FullName }
}

# Start llama-server if it is not already up.
$up = $false
try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "$($env:LLAMA_BASE_URL)/models" | Out-Null; $up = $true } catch { $up = $false }
if (-not $up) {
  Write-Host "Starting llama-server ($Alias)…"
  $llamaArgs = @("-m", $Model, "--host", "127.0.0.1", "--port", "8080", "--alias", $Alias, "--ctx-size", $Ctx, "--parallel", "1")
  Start-Process -FilePath $Llama -ArgumentList $llamaArgs -WindowStyle Minimized
  for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 2
    try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "$($env:LLAMA_BASE_URL)/models" | Out-Null; $up = $true; break } catch { }
  }
  if (-not $up) { Write-Error "llama-server did not become ready on $($env:LLAMA_BASE_URL)"; exit 1 }
}

$Cli = Join-Path $Root "cowork\bin\cowork-cli.js"
if ((Test-Path $Node) -and (Test-Path $Cli)) {
  & $Node $Cli providers configure openai-compatible --api-key local --model $Alias --base-url $env:LLAMA_BASE_URL 2>$null
  if ($Chat -ne "") {
    Set-Location $Workspace
    & $Node $Cli run $Chat --access-profile ask_for_approval
    exit $LASTEXITCODE
  }
  Write-Host ""
  Write-Host "Jarvis_liquid_agent is up. Approval engine is ON."
  Write-Host "  Server:  $($env:LLAMA_BASE_URL)"
  Write-Host "  Chat:    Jarvis.bat -Chat `"your request`""
  Write-Host "  Or:      `"$Node`" `"$Cli`" run `"your request`" --access-profile ask_for_approval"
} else {
  Write-Host "llama-server is up at $($env:LLAMA_BASE_URL)."
  Write-Host "CoWork CLI is not installed in cowork\ yet — see README.md (npm ci on Windows, Node >= 24)."
}

if (-not $NoWait -and $Chat -eq "") {
  Write-Host ""
  Pause
}
