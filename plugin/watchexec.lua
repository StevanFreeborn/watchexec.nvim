---@type boolean|nil
if vim.g.loaded_watchexec then
  return
end

vim.g.loaded_watchexec = 1

vim.keymap.set("n", "<Leader>wxt", function()
  require("watchexec").toggle()
end, { desc = "Toggle watchexec window" })

vim.keymap.set("n", "<Leader>wxs", function()
  require("watchexec").stop()
end, { desc = "Stop watchexec" })

vim.keymap.set("n", "<Leader>wxr", function()
  local cmd = vim.fn.input("Watchexec: ")

  if cmd and #cmd > 0 then
    require("watchexec").run(cmd)
  end
end, { desc = "Run watchexec with prompt" })

vim.api.nvim_create_user_command("WatchexecRun", function(opts)
  require("watchexec").run(opts.args)
end, { nargs = 1, complete = "file" })

vim.api.nvim_create_user_command("WatchexecStop", function()
  require("watchexec").stop()
end, {})

vim.api.nvim_create_user_command("WatchexecToggle", function()
  require("watchexec").toggle()
end, {})

vim.api.nvim_set_hl(0, "WatchexecSuccess", { bg = "#00ff00", default = true })
vim.api.nvim_set_hl(0, "WatchexecFailure", { bg = "#ff0000", default = true })

vim.api.nvim_create_augroup("watchexec_nvim", { clear = true })

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = "watchexec_nvim",
  callback = function()
    require("watchexec.runner").stop()
  end,
})

---@type table|nil
local resize_timer

vim.api.nvim_create_autocmd("VimResized", {
  group = "watchexec_nvim",
  callback = function()
    if resize_timer then
      resize_timer:close()
    end

    resize_timer = vim.defer_fn(function()
      resize_timer = nil
      require("watchexec.window").resize_float()
      require("watchexec.indicator").reposition()
    end, 100)
  end,
})
