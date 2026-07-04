if vim.g.loaded_watchexec then
  return
end

vim.g.loaded_watchexec = 1

vim.api.nvim_create_user_command("SayHello", function()
  require("watchexec").say_hello()
end, {})
