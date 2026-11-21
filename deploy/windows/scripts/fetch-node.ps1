param([string]$Version = "v24.22.1")
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Dest = Join-Path $Root "bin\node"
$zipName = "node-$Version-win-x64.zip"
$Url = "https://nodejs.org/dist/$Version/$zipName"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
if (Test-Path (Join-Path $Dest "node.exe") -or (Get-ChildItem $Dest -Recurse -Filter node.exe -ErrorAction SilentlyContinue)) {
  Write-Host "node.exe already present under $Dest"
  exit 0
}
$zip = Join-Path $env:TEMP $zipName
Write-Host "Downloading $zipName…"
Invoke-WebRequest -Uri $Url -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $Dest -Force
Write-Host "Node $Version unpacked under $Dest"
