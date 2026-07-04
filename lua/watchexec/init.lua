local M = {}

M.config = {
  greeting = "Hello from my plugin"
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.say_hello()
  print(M.config.greeting)
end

return M
