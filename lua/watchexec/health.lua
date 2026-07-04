local M = {}

function M.check()
  if vim.fn.has("nvim-0.10") == 0 then
    vim.health.error("Neovim 0.10 or higher is required", { "Please upgrade your Neovim installation to v0.10+" })
    return
  end

  vim.health.start("watchexec.nvim diagnostics")
  vim.health.ok("Neovim 0.10+ is installed")

  local bin_path = "watchexec"

  if vim.fn.executable(bin_path) == 1 then
    vim.health.ok(string.format("Binary '%s' is installed and executable", bin_path))
  else
    vim.health.error(string.format("Binary '%s' was not found in PATH", bin_path), {
      "Install watchexec",
      "Or verify your plugin configuration if using a custom binary path.",
    })
  end
end

return M
