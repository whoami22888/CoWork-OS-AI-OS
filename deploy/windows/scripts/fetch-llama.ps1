# Download a Windows x64 llama.cpp release (b12600+, lfm3) into bin/llama.
param([string]$Tag = "b12600")
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Dest = Join-Path $Root "bin\llama"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
if (Test-Path (Join-Path $Dest "llama-server.exe")) {
  Write-Host "llama-server.exe already present in $Dest"
  exit 0
}
$api = "https://api.github.com/repos/ggml-org/llama.cpp/releases/tags/$Tag"
Write-Host "Looking up llama.cpp $Tag assets…"
$rel = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "jarvis-portable" }
$asset = $rel.assets | Where-Object { $_.name -match 'win.*x64|windows.*x64|w64' -and $_.name -match '\.zip$' } | Select-Object -First 1
if (-not $asset) { throw "No Windows x64 zip found on llama.cpp $Tag. Download it by hand from https://github.com/ggml-org/llama.cpp/releases/tag/$Tag" }
$zip = Join-Path $env:TEMP $asset.name
Write-Host "Downloading $($asset.name)…"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $Dest -Force
# Some zips nest a folder; lift llama-server.exe up if needed.
$exe = Get-ChildItem $Dest -Recurse -Filter llama-server.exe | Select-Object -First 1
if ($exe -and $exe.DirectoryName -ne $Dest) {
  Copy-Item -Path (Join-Path $exe.DirectoryName "*") -Destination $Dest -Recurse -Force
}
if (-not (Test-Path (Join-Path $Dest "llama-server.exe"))) {
  throw "Unpacked $zip but llama-server.exe was not found."
}
Write-Host "llama-server.exe ready in $Dest"
