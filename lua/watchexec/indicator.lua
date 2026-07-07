---@brief [[
--- watchexec.nvim indicator module.
--- Shows a small non-focusable float indicating the last command outcome
--- while the main output window is hidden and a job is running.
---@brief ]]

---@diagnostic disable: need-check-nil

local config = require("watchexec.config")

local M = {}

local ns = vim.api.nvim_create_namespace("watchexec-indicator-highlights")

local state = {
  win = nil,
  buf = nil,
  ---@type "success"|"failure"|nil
  last_outcome = nil,
  waiting_for_outcome = false,
}

---@return integer
local function create_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  " })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  return buf
end

---@return integer, integer
local function calculate_position()
  local cfg = config.get().indicator
  local width = cfg.width or 2
  local height = cfg.height or 1
  local pad_x = cfg.padding and cfg.padding.x or 1
  local pad_y = cfg.padding and cfg.padding.y or 1
  local statusline_offset = 2

  if cfg.position == "bottom-left" then
    return vim.o.lines - height - statusline_offset, pad_x
  elseif cfg.position == "bottom-right" then
    return vim.o.lines - height - statusline_offset, vim.o.columns - width - pad_x
  elseif cfg.position == "top-left" then
    return pad_y, pad_x
  elseif cfg.position == "top-right" then
    return pad_y, vim.o.columns - width - pad_x
  end

  return vim.o.lines - height - statusline_offset, pad_x
end

local function close_float()
  local win = state.win

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end

  state.win = nil
end

local function create_float()
  local cfg = config.get().indicator
  local cfg_width = cfg.width or 2
  local cfg_height = cfg.height or 1
  local buf = state.buf

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = create_buf()
    state.buf = buf
  end

  local row, col = calculate_position()
  local hl = state.last_outcome == "success" and (cfg.success_hl or "WatchexecSuccess")
    or (cfg.failure_hl or "WatchexecFailure")

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep(" ", cfg_width) })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { end_col = cfg_width, hl_group = hl, hl_eol = true })

  state.win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = cfg_width,
    height = cfg_height,
    row = row,
    col = col,
    style = "minimal",
    focusable = false,
    noautocmd = true,
  })
end

---Process output text from the running job.
---Tracks command lifecycle based on configured patterns.
---@param text string
function M.process_output(text)
  local cfg = config.get().indicator
  local running_pat = cfg.patterns.running
  local success_pat = cfg.patterns.success

  for line in text:gmatch("[^\n]+") do
    if running_pat and line:find(running_pat) then
      if state.waiting_for_outcome then
        state.last_outcome = "failure"
      end

      state.waiting_for_outcome = true
    elseif success_pat and line:find(success_pat) then
      state.last_outcome = "success"
      state.waiting_for_outcome = false
    elseif line:find("^%[Command ") and not (success_pat and line:find(success_pat)) then
      state.last_outcome = "failure"
      state.waiting_for_outcome = false
    end
  end
end

---Notify the indicator that the process has exited.
---If a command was in-flight it is marked as failed.
function M.process_exit()
  if state.waiting_for_outcome then
    state.last_outcome = "failure"
    state.waiting_for_outcome = false
  end
end

---Reset tracked outcome (e.g. when starting a new job).
function M.reset()
  state.last_outcome = nil
  state.waiting_for_outcome = false
end

---Show or hide the indicator based on current state.
---Shows when: enabled, window hidden, and outcome known.
function M.refresh()
  local cfg = config.get().indicator
  local enabled = cfg.enabled ~= false
  local window_visible = require("watchexec.window").is_visible()

  if enabled and not window_visible and state.last_outcome then
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      M.reposition()
    else
      create_float()
    end
  else
    close_float()
  end
end

---Recalculate the indicator position.
function M.reposition()
  local win = state.win

  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local cfg = config.get().indicator
  local cfg_width = cfg.width or 2
  local cfg_height = cfg.height or 1
  local row, col = calculate_position()
  local hl = state.last_outcome == "success" and (cfg.success_hl or "WatchexecSuccess")
    or (cfg.failure_hl or "WatchexecFailure")
  local buf = state.buf

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { end_col = cfg_width, hl_group = hl, hl_eol = true })
  end

  vim.api.nvim_win_set_config(win, {
    relative = "editor",
    width = cfg_width,
    height = cfg_height,
    row = row,
    col = col,
  })
end

---@return integer|nil
function M.get_win()
  return state.win
end

---@return "success"|"failure"|nil
function M.get_last_outcome()
  return state.last_outcome
end

return M
