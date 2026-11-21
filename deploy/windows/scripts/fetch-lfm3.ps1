param([string]$ModelsDir = "")
$ErrorActionPreference = "Stop"
if (-not $ModelsDir) { $ModelsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "models" }
New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null
$File = "LFM3-1.7B-Uncensored-AD-Q4_K_M.gguf"
$Dest = Join-Path $ModelsDir $File
$ExpectedBytes = 1132208000
$ExpectedSha = "b22df65673b54ed326f18f74826d76f3b65dadc237ffd6306cd52be04544827d"
$Url = "https://huggingface.co/AtomicChat/LFM3-1.7B-Uncensored-GGUF/resolve/main/$File"
if (Test-Path $Dest) {
  $size = (Get-Item $Dest).Length
  $sha = (Get-FileHash $Dest -Algorithm SHA256).Hash.ToLower()
  if ($size -eq $ExpectedBytes -and $sha -eq $ExpectedSha) {
    Write-Host "LFM3 already present and verified: $Dest"
    exit 0
  }
  Write-Host "Existing file failed checks (size=$size sha=$sha); re-downloading."
  Remove-Item $Dest -Force
}
Write-Host "Downloading LFM3 (1.13 GiB)…"
Invoke-WebRequest -Uri $Url -OutFile $Dest
$size = (Get-Item $Dest).Length
$sha = (Get-FileHash $Dest -Algorithm SHA256).Hash.ToLower()
if ($size -ne $ExpectedBytes -or $sha -ne $ExpectedSha) {
  throw "Download failed verification: size=$size sha256=$sha"
}
Write-Host "LFM3 ready: $Dest"
