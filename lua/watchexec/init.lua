---@brief [[
--- watchexec.nvim integrates the watchexec CLI into Neovim, providing a
--- floating or split window to display file-watching command output.
---@brief ]]

local config = require("watchexec.config")
local runner = require("watchexec.runner")
local window = require("watchexec.window")
local indicator = require("watchexec.indicator")

local M = {}

---Merge user-provided options into the config and resolve the watchexec binary.
---Call this in your init.lua: `require("watchexec").setup({...})`.
---@param opts? watchexec.Config
function M.setup(opts)
  config.setup(opts)
end

---Start a watchexec process for the given command.
---Stops any previously running process, opens the output window if hidden,
---then spawns the child process.
---@param command string Shell command to run under watchexec
function M.run(command)
  if runner.is_running() then
    runner.stop()
  end

  window.clear()

  if not window.is_visible() then
    window.open()
  end

  runner.start(command)
  indicator.refresh()
end

---Stop the currently running watchexec process.
function M.stop()
  runner.stop()
  window.clear()
  indicator.reset()
  indicator.refresh()
end

---Toggle the watchexec output window.
---If no process is running and window is hidden, opens with a placeholder.
---If no process is running and window is visible, closes it.
---If running and visible, hides the window.
---If running but hidden, shows the window.
function M.toggle()
  if not runner.is_running() then
    if window.is_visible() then
      window.close()
    else
      window.clear()
      window.open()
    end
  elseif window.is_visible() then
    window.toggle()
  else
    window.open()
  end
end

return M
