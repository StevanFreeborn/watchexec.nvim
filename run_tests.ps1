$plenaryPath = ".tests/vendor/plenary.nvim"

if (-not (Test-Path $plenaryPath)) {
  Write-Host "Bootstrapping plenary.nvim for tests..." -ForegroundColor Yellow
  New-Item -ItemType Directory -Path ".tests/vendor" -Force | Out-Null
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $plenaryPath
}

nvim --headless -c "PlenaryBustedDirectory tests/watchexec/ {minimal_init = 'tests/minimal_init.lua'}"
