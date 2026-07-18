---@brief [[
--- watchexec.nvim runner module.
--- Spawns and manages the watchexec child process via Neovim's job API
--- (`vim.fn.jobstart`), pipes stdout/stderr to the output window, and
--- applies ANSI-free highlights.
---@brief ]]

local config = require("watchexec.config")

local M = {}

local ns = vim.api.nvim_create_namespace("watchexec-runner-highlights")

---@class watchexec.RunnerState
---@field job_id integer|nil
---@field pid integer|nil
---@field cmd string|nil
---@field stop_requested boolean

---@type watchexec.RunnerState
local state = {
  job_id = nil,
  pid = nil,
  cmd = nil,
  stop_requested = false,
}

---Strip ANSI escape sequences from a string.
---@param text string
---@return string
local function strip_ansi(text)
  local result =
      text:gsub("\x1b%[%??[0-9;]*[a-zA-Z]", ""):gsub("\x1b%][0-9;]*.-(\x1b\\|\x07)", ""):gsub("\x1b[()][0-9A-Za-z]", "")

  return result
end

---Normalize output text: strip ANSI, handle \\r characters (CRLF -> LF,
---inline progress overwrites), and detect leading \\r for line overwrite.
---@param text string
---@return string, boolean
local function normalize_output(text)
  if not text or text == "" then
    return "", false
  end

  text = text:gsub("\r\n", "\n")
  text =
      text:gsub("\x1b%[%??[0-9;]*[a-zA-Z]", ""):gsub("\x1b%][0-9;]*.-(\x1b\\|\x07)", ""):gsub("\x1b[()][0-9A-Za-z]", "")

  local start_cr = text:len() > 0 and text:byte(1) == 0x0D

  local lines = vim.split(text, "\n", { plain = true })
  local out_lines = {}

  for i = 1, #lines do
    local current = lines[i]
    local found = false

    for p = #current, 1, -1 do
      if current:byte(p) == 0x0D then
        current = current:sub(p + 1)
        found = true
        break
      end
    end

    if not found or current ~= "" then
      table.insert(out_lines, current)
    end
  end

  return table.concat(out_lines, "\n"), start_cr
end

---Apply diagnostic highlights to keywords found in a line.
---Matches error, warning, success patterns using case-insensitive patterns.
---@param buf integer
---@param line_idx integer
---@param line string
local function apply_highlights(buf, line_idx, line)
  for _, p in ipairs({
    { p = "[Ee][Rr][Rr][Oo][Rr]",         h = "DiagnosticError" },
    { p = "[Ff][Aa][Ii][Ll][Ee][Dd]?",    h = "DiagnosticError" },
    { p = "[Ee][Rr][Rr]!",                h = "DiagnosticError" },
    { p = "[Ff][Aa][Tt][Aa][Ll]",         h = "DiagnosticError" },
    { p = "[Ww][Aa][Rr][Nn][Ii][Nn][Gg]", h = "DiagnosticWarn" },
    { p = "[Ww][Aa][Rr][Nn]!",            h = "DiagnosticWarn" },
    { p = "[Ss][Uu][Cc][Cc][Ee][Ss][Ss]", h = "DiagnosticOk" },
    { p = "[Pp][Aa][Ss][Ss][Ee][Dd]",     h = "DiagnosticOk" },
    { p = "%^%d+ .-[Ss]ucceed",           h = "DiagnosticOk" },
    { p = "%[ok%]",                       h = "DiagnosticOk" },
    { p = "[Oo][Kk]!",                    h = "DiagnosticOk" },
  }) do
    local s, e = line:find(p.p)

    if s then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, line_idx, s - 1, { end_col = e, hl_group = p.h })
    end
  end
end

---Process job output data and append to the window with highlights.
---@param text string
local function process_data(text)
  if text == "" then
    return
  end

  local clean, overwrite = normalize_output(text)

  if clean == "" then
    return
  end

  require("watchexec.window").append(clean, overwrite)
  require("watchexec.indicator").process_output(clean)
  require("watchexec.indicator").refresh()

  local buf = require("watchexec.window").get_buf()

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.split(clean, "\n", { plain = true })
  local line_count = vim.api.nvim_buf_line_count(buf)

  for i, line in ipairs(lines) do
    apply_highlights(buf, line_count - #lines + i - 1, line)
  end
end

---Split a string into arguments by whitespace.
---@param str string
---@return string[]
local function split_args(str)
  local args = {}

  for part in str:gmatch("%S+") do
    table.insert(args, part)
  end

  return args
end

---Build the command list for jobstart from the binary, config args, and command.
---@param command string
---@return string[]
local function build_cmd(command)
  local cfg = config.get()
  local binary = cfg.watchexec.bin
  local cmd_parts = {}

  if not binary then
    return cmd_parts
  end

  if binary:match("^wsl%.exe") then
    for part in binary:gmatch("%S+") do
      table.insert(cmd_parts, part)
    end
  else
    table.insert(cmd_parts, binary)
  end

  for _, a in ipairs(cfg.watchexec.args) do
    table.insert(cmd_parts, a)
  end

  for _, a in ipairs(split_args(command)) do
    table.insert(cmd_parts, a)
  end

  return cmd_parts
end

---Start a watchexec process for the given command.
---Builds the argument list and spawns via `vim.fn.jobstart`.
---@param command string Shell command to watch and execute
function M.start(command)
  state.stop_requested = false
  require("watchexec.indicator").reset()

  local cmd_parts = build_cmd(command)
  local binary = cmd_parts[1]

  if not binary then
    vim.notify("watchexec.nvim: watchexec binary not found", vim.log.levels.ERROR)
    return
  end

  state.cmd = command

  local job_id = vim.fn.jobstart(cmd_parts, {
    on_stdout = function(_, data, _)
      vim.schedule(function()
        process_data(table.concat(data, "\n"))
      end)
    end,
    on_stderr = function(_, data, _)
      vim.schedule(function()
        local text = table.concat(data, "\n")
        local clean, _ = normalize_output(text)

        if clean ~= "" then
          process_data(clean)
        end
      end)
    end,
    on_exit = function(job_id, code, _)
      vim.schedule(function()
        if state.job_id ~= job_id then
          return
        end

        if state.stop_requested then
          state.stop_requested = false
          require("watchexec.indicator").reset()
        else
          require("watchexec.indicator").process_exit()
          require("watchexec.window").append(string.format("[watchexec] exited: code=%d", code))
          require("watchexec.indicator").refresh()
        end

        state.job_id = nil
        state.pid = nil
      end)
    end,
  })

  if not job_id or job_id <= 0 then
    vim.notify("watchexec.nvim: failed to spawn " .. binary, vim.log.levels.ERROR)
    state.cmd = nil
    return
  end

  local pid = vim.fn.jobpid(job_id)

  state.job_id = job_id
  state.pid = pid
end

---Stop the currently running watchexec process.
---Uses jobstop and PID-based kill for robustness on Windows.
function M.stop()
  if state.job_id then
    state.stop_requested = true
    pcall(vim.fn.jobstop, state.job_id)
  end

  if state.pid then
    pcall(vim.uv.kill, state.pid, "term")
  end

  state.job_id = nil
  state.pid = nil
  state.cmd = nil
end

---Check whether a watchexec process is currently running.
---@return boolean
function M.is_running()
  return state.job_id ~= nil
end

---Return the command string passed to the running process, or nil.
---@return string|nil
function M.get_cmd()
  return state.cmd
end

M._normalize_output = normalize_output
M._strip_ansi = strip_ansi

return M
