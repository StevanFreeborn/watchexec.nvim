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

Write-Host "`n=== Test ==="

nvim --headless -c "PlenaryBustedDirectory tests/watchexec/ {minimal_init = 'tests/minimal_init.lua'}"

if ($LASTEXITCODE -ne 0) {
  Write-Host "FAIL: Tests failed." -ForegroundColor Red
  exit 1
}

Write-Host "PASS" -ForegroundColor Green

Write-Host "`nAll checks passed!" -ForegroundColor Green
