$ErrorActionPreference = "Stop"

Write-Host "=== Format check ==="
stylua --check .

if ($LASTEXITCODE -ne 0) {
  Write-Host "FAIL: Format check failed. Run 'stylua .' to fix." -ForegroundColor Red
  exit 1
}

Write-Host "PASS" -ForegroundColor Green

Write-Host "`n=== Lint ==="

lua-language-server --check=.

if ($LASTEXITCODE -ne 0) {
  Write-Host "FAIL: Lint found issues." -ForegroundColor Red
  exit 1
}

Write-Host "PASS" -ForegroundColor Green

$plenaryPath = ".tests/vendor/plenary.nvim"

if (-not (Test-Path $plenaryPath)) {
  Write-Host "Bootstrapping plenary.nvim for tests..." -ForegroundColor Yellow
  New-Item -ItemType Directory -Path ".tests/vendor" -Force | Out-Null
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $plenaryPath
}

Write-Host "`n=== Test ==="

nvim --headless -c "PlenaryBustedDirectory tests/watchexec/ {minimal_init = 'tests/minimal_init.lua'}"

if ($LASTEXITCODE -ne 0) {
  Write-Host "FAIL: Tests failed." -ForegroundColor Red
  exit 1
}

Write-Host "PASS" -ForegroundColor Green

Write-Host "`nAll checks passed!" -ForegroundColor Green
