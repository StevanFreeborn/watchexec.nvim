---@brief [[
--- watchexec.nvim window module.
--- Manages the output buffer and window (float or split), including
--- creation, display, text appending, and keymap-driven close.
---@brief ]]

local config = require("watchexec.config")

local M = {}

---@class watchexec.WindowState
---@field buf integer|nil
---@field win integer|nil
---@field visible boolean

---@type watchexec.WindowState
local state = {
  buf = nil,
  win = nil,
  visible = false,
}

---Create or reuse the output buffer.
---Sets buffer-local options and keymaps (<Esc> and q) to close the window.
---@return integer buf
function M.create_buf()
  local existing = state.buf
  if existing and vim.api.nvim_buf_is_valid(existing) then
    return existing
  end

  local buf = vim.api.nvim_create_buf(false, true)

  state.buf = buf
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "watchexec-output", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  pcall(vim.api.nvim_buf_set_name, buf, "watchexec://output")

  vim.keymap.set("n", "<Esc>", function()
    M.close()
  end, { buffer = buf, nowait = true, desc = "Close watchexec window" })

  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = buf, nowait = true, desc = "Close watchexec window" })

  return buf
end

---Open the output window.
---Creates a float or split window per configuration, or reuses an existing one.
function M.open()
  local cfg = config.get()
  local buf = M.create_buf()

  local win = state.win

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_set_current_win(win)
    state.visible = true
    return
  end

  if cfg.window.type == "float" then
    ---@type watchexec.FloatOpts
    local float = cfg.window.float
    local width = float.width <= 1 and math.floor(vim.o.columns * float.width) or float.width
    local height = float.height <= 1 and math.floor(vim.o.lines * float.height) or float.height
    local row = float.row <= 1 and math.floor((vim.o.lines - height) * float.row) or float.row
    local col = float.col <= 1 and math.floor((vim.o.columns - width) * float.col) or float.col

    state.win = vim.api.nvim_open_win(buf, true, {
      relative = float.relative or "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = cfg.window.border or "single",
    })
  else
    local split = cfg.window.split
    local size = cfg.window.size
    local is_vertical = split == "left" or split == "right"
    local dir = (split == "below" or split == "right") and "belowright" or "aboveleft"
    local cmd = dir .. " " .. (is_vertical and size .. "vnew" or size .. "new")

    vim.cmd(cmd)

    local split_win = vim.api.nvim_get_current_win()
    state.win = split_win
    vim.api.nvim_win_set_buf(split_win, buf)
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  if #lines == 1 and lines[1] == "" then
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { " No job running. Use :WatchexecRun <command> to start one.", "" })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  end

  state.visible = true
  require("watchexec.indicator").refresh()
end

function M.close()
  local win = state.win

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end

  state.win = nil
  state.visible = false
  require("watchexec.indicator").refresh()
end

function M.toggle()
  if state.visible then
    M.close()
  else
    M.open()
  end
end

---Close the window and delete the buffer entirely.
function M.cleanup()
  M.close()

  local buf = state.buf

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  state.buf = nil
end

---Clear the output buffer and reset to the waiting placeholder.
function M.clear()
  local buf = state.buf

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { " No job running. Use :WatchexecRun <command> to start one.", "" })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

---Append text to the output buffer.
---On first append, replaces the "waiting for output" placeholder.
---Truncates the buffer when max_lines is exceeded.
---Auto-scrolls to the bottom when enabled.
---@param text string
function M.append(text)
  local buf = state.buf

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local cfg = config.get()
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

  local current = vim.api.nvim_buf_line_count(buf)
  local lines = vim.split(text, "\n", { plain = true })
  local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""

  if first_line:match("^ No job running") then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    vim.api.nvim_buf_set_lines(buf, current, -1, false, lines)
  end

  if cfg.max_lines and vim.api.nvim_buf_line_count(buf) > cfg.max_lines then
    local overflow = vim.api.nvim_buf_line_count(buf) - cfg.max_lines
    vim.api.nvim_buf_set_lines(buf, 0, overflow, false, {})
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local scroll_win = state.win

  if cfg.auto_scroll and scroll_win and vim.api.nvim_win_is_valid(scroll_win) then
    local line_count = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(scroll_win, { line_count, 0 })
  end
end

---Recalculate float window dimensions after terminal resize.
---No-op for split windows or when no window is displayed.
function M.resize_float()
  local win = state.win

  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local cfg = config.get()

  if cfg.window.type ~= "float" then
    return
  end

  ---@type watchexec.FloatOpts
  local float = cfg.window.float
  local width = float.width <= 1 and math.floor(vim.o.columns * float.width) or float.width
  local height = float.height <= 1 and math.floor(vim.o.lines * float.height) or float.height
  local row = float.row <= 1 and math.floor((vim.o.lines - height) * float.row) or float.row
  local col = float.col <= 1 and math.floor((vim.o.columns - width) * float.col) or float.col

  vim.api.nvim_win_set_config(win, {
    relative = float.relative or "editor",
    width = width,
    height = height,
    row = row,
    col = col,
  })
end

---Check whether the output window is currently displayed.
---@return boolean
function M.is_visible()
  return state.visible
end

---Return the output buffer handle, or nil if not yet created.
---@return integer|nil
function M.get_buf()
  return state.buf
end

---Return the output window handle, or nil if not yet created.
---@return integer|nil
function M.get_win()
  return state.win
end

return M
