---@class watchexec.FloatOpts
---@field relative? string
---@field width? number
---@field height? number
---@field row? number
---@field col? number

---@class watchexec.WindowOpts
---@field type? "float"|"split"
---@field split? "below"|"above"|"left"|"right"
---@field size? integer
---@field float? watchexec.FloatOpts
---@field border? string|string[]

---@class watchexec.WatchexecOpts
---@field bin? string
---@field args? string[]

---@class watchexec.IndicatorPadding
---@field x? integer
---@field y? integer

---@class watchexec.IndicatorPatterns
---@field success? string
---@field running? string

---@class watchexec.IndicatorOpts
---@field enabled? boolean
---@field position? "bottom-left"|"bottom-right"|"top-left"|"top-right"
---@field success_hl? string
---@field failure_hl? string
---@field width? integer
---@field height? integer
---@field padding? watchexec.IndicatorPadding
---@field patterns? watchexec.IndicatorPatterns

---@class watchexec.Config
---@field watchexec? watchexec.WatchexecOpts
---@field window? watchexec.WindowOpts
---@field indicator? watchexec.IndicatorOpts
---@field auto_scroll? boolean
---@field max_lines? integer

local M = {}

---@type watchexec.Config
local defaults = {
  watchexec = {
    bin = "watchexec",
    args = {},
  },
  window = {
    type = "float",
    split = "below",
    size = 12,
    float = {
      relative = "editor",
      width = 0.8,
      height = 0.6,
      row = 0.5,
      col = 0.5,
    },
    border = "single",
  },
  indicator = {
    enabled = true,
    position = "bottom-right",
    success_hl = "WatchexecSuccess",
    failure_hl = "WatchexecFailure",
    width = 2,
    height = 1,
    padding = { x = 1, y = 3 },
    patterns = {
      success = "%[Command was successful%]",
      running = "%[Running",
    },
  },
  auto_scroll = true,
  max_lines = 5000,
}

---@type watchexec.Config
local config = vim.deepcopy(defaults)

---Search for the watchexec binary in PATH and candidate locations.
---@return string|nil
local function find_binary()
  local bin = config.watchexec.bin

  if bin and vim.fn.executable(bin) == 1 then
    return bin
  end

  local home = vim.fn.expand("~")

  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    local candidates = {
      home .. "\\cargo\\bin\\watchexec.exe",
      vim.fn.expand("$USERPROFILE") .. "\\.cargo\\bin\\watchexec.exe",
      "C:\\tools\\watchexec\\watchexec.exe",
    }

    for _, p in ipairs(candidates) do
      if vim.fn.executable(p) == 1 then
        return p
      end
    end
  else
    local candidates = {
      home .. "/.cargo/bin/watchexec",
      home .. "/.local/bin/watchexec",
      "/opt/homebrew/bin/watchexec",
      "/usr/local/bin/watchexec",
    }

    for _, p in ipairs(candidates) do
      if vim.fn.executable(p) == 1 then
        return p
      end
    end

    if vim.fn.executable("wsl.exe") == 1 then
      local result = vim.fn.system({ "wsl.exe", "which", "watchexec" })

      if vim.v.shell_error == 0 then
        result = vim.trim(result)
        if #result > 0 then
          return "wsl.exe --exec " .. result
        end
      end
    end
  end

  return nil
end

---Merge user options into the current config and resolve the binary path.
---@param opts? watchexec.Config
function M.setup(opts)
  if not opts then
    return
  end

  config = vim.tbl_deep_extend("force", config, opts)

  config.watchexec.bin = find_binary()

  if not config.watchexec.bin then
    vim.notify(
      "watchexec.nvim: could not find watchexec binary. Set opts.watchexec.bin in your config.",
      vim.log.levels.WARN
    )
  end
end

---Return the current configuration table.
---@return watchexec.Config
function M.get()
  return config
end

---Reset configuration back to defaults.
function M.reset()
  config = vim.deepcopy(defaults)
end

return M
