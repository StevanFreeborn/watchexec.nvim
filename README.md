# watchexec.nvim

Integrate the [watchexec](https://github.com/watchexec/watchexec) CLI into
Neovim — run file-watching commands and view their output in a floating or
split window.

## Features

- **Floating or split** output window, configurable per-user.
- **Status indicator** — a small non-focusable float that shows success or failure when the main window is hidden.
- **ANSI escape sequence stripping** so output is clean.
- **Keyword highlighting** via `DiagnosticError`, `DiagnosticWarn`, and `DiagnosticOk` for error/warning/success keywords in output.
- **Auto-scroll** to the latest output, with configurable buffer size limits.
- **Auto-resize** on `VimResized`, and automatic cleanup on `VimLeavePre`.
- **Binary auto-discovery** — searches PATH, `~/.cargo/bin`, Homebrew, and WSL locations.

## Requirements

- Neovim >= 0.10
- [watchexec CLI](https://github.com/watchexec/watchexec)

Install the CLI:

```pwsh
cargo install watchexec
```

Or download a prebuilt binary from the [releases page](https://github.com/watchexec/watchexec/releases).

## Installation

### lazy.nvim

```lua
{
  "StevanFreeborn/watchexec.nvim",
  opts = {},
}
```

### packer.nvim

```lua
use {
  "StevanFreeborn/watchexec.nvim",
  config = function()
    require("watchexec").setup({})
  end,
}
```

### vim-plug

```vim
Plug 'StevanFreeborn/watchexec.nvim'
lua require("watchexec").setup({})
```

## Quick Start

After installing, restart Neovim and run:

```txt
:WatchexecRun echo hello
```

Or press `<Leader>wxr`, type a command at the prompt, and press Enter.

The output window opens automatically. Press `q` or `<Esc>` inside the window
to close it. Press `<Leader>wxt` to toggle it back.

## Configuration

`setup()` accepts an optional table with the following fields:

### `watchexec` — binary options

| Field  | Type     | Default       | Description                                                                     |
|--------|----------|---------------|---------------------------------------------------------------------------------|
| `bin`  | `string` | `"watchexec"` | Path to the watchexec executable. Auto-detected from PATH and common locations. |
| `args` | `table`  | `{}`          | Extra arguments passed to watchexec before the user command.                    |

### `window` — output window options

| Field    | Type                                         | Default       | Description                                            |
|----------|----------------------------------------------|---------------|--------------------------------------------------------|
| `type`   | `"float"` / `"split"`                        | `"float"`     | Window type.                                           |
| `split`  | `"below"` / `"above"` / `"left"` / `"right"` | `"below"`     | Split direction (only used when `type` is `"split"`).  |
| `size`   | `integer`                                    | `12`          | Split window size in rows/columns.                     |
| `border` | `string` / `table`                           | `"single"`    | Border style for floats (see `:help nvim_open_win()`). |
| `float`  | `table`                                      | *(see below)* | Float geometry.                                        |

#### `window.float` — float geometry

| Field      | Type     | Default    | Description                                                   |
|------------|----------|------------|---------------------------------------------------------------|
| `relative` | `string` | `"editor"` | Positioning anchor.                                           |
| `width`    | `number` | `0.8`      | Width in columns (values <= 1 are fractions of editor width). |
| `height`   | `number` | `0.6`      | Height in rows (values <= 1 are fractions of editor height).  |
| `row`      | `number` | `0.5`      | Row position (values <= 1 are fractions).                     |
| `col`      | `number` | `0.5`      | Column position (values <= 1 are fractions).                  |

### `indicator` — status indicator options

| Field        | Type                                                              | Default              | Description                      |
|--------------|-------------------------------------------------------------------|----------------------|----------------------------------|
| `enabled`    | `boolean`                                                         | `true`               | Enable/disable the indicator.    |
| `position`   | `"bottom-left"` / `"bottom-right"` / `"top-left"` / `"top-right"` | `"bottom-right"`     | Screen corner.                   |
| `success_hl` | `string`                                                          | `"WatchexecSuccess"` | Highlight for success state.     |
| `failure_hl` | `string`                                                          | `"WatchexecFailure"` | Highlight for failure state.     |
| `width`      | `integer`                                                         | `2`                  | Indicator width in cells.        |
| `height`     | `integer`                                                         | `1`                  | Indicator height in cells.       |
| `padding`    | `table`                                                           | `{ x = 1, y = 1 }`  | Offset from editor edges.        |
| `patterns`   | `table`                                                           | *(see below)*        | Lua patterns for parsing output. |

#### `indicator.patterns`

| Field     | Type     | Default                        | Description                                 |
|-----------|----------|--------------------------------|---------------------------------------------|
| `success` | `string` | `"%[Command was successful%]"` | Pattern matching successful command output. |
| `running` | `string` | `"%[Running"`                  | Pattern matching command start.             |

### General options

| Field         | Type      | Default | Description                                          |
|---------------|-----------|---------|------------------------------------------------------|
| `auto_scroll` | `boolean` | `true`  | Scroll to bottom on new output.                      |
| `max_lines`   | `integer` | `5000`  | Maximum lines in the output buffer (oldest trimmed). |

### Full config example

```lua
require("watchexec").setup({
  auto_scroll = false,
  max_lines = 1000,
  watchexec = {
    bin = "watchexec",
    args = { "--shell", "bash" },
  },
  window = {
    type = "split",
    split = "below",
    size = 15,
  },
  indicator = {
    enabled = true,
    position = "bottom-left",
  },
})
```

## Commands

| Command                   | Description                                                                                       |
|---------------------------|---------------------------------------------------------------------------------------------------|
| `:WatchexecRun {command}` | Start watchexec with the given shell command. Stops any previous run and opens the output window. |
| `:WatchexecStop`          | Stop the currently running watchexec process and clear the output.                                |
| `:WatchexecToggle`        | Toggle the output window.                                                                         |

## Keymaps

| Keymap        | Action             | Description                      |
|---------------|--------------------|----------------------------------|
| `<Leader>wxt` | `:WatchexecToggle` | Toggle the output window.        |
| `<Leader>wxs` | `:WatchexecStop`   | Stop the running process.        |
| `<Leader>wxr` | `:WatchexecRun`    | Prompt for a command and run it. |

## Highlight Groups

| Group              | Default         | Description                                           |
|--------------------|-----------------|-------------------------------------------------------|
| `WatchexecSuccess` | `guibg=#00ff00` | Indicator background when the last command succeeded. |
| `WatchexecFailure` | `guibg=#ff0000` | Indicator background when the last command failed.    |

Output lines are also highlighted using built-in diagnostic groups:

- `DiagnosticError` — for error, fail, fatal keywords
- `DiagnosticWarn`  — for warning keywords
- `DiagnosticOk`    — for success, passed, ok keywords

## API

```lua
---@param opts? watchexec.Config
require("watchexec").setup(opts)

---@param command string
require("watchexec").run(command)

require("watchexec").stop()

require("watchexec").toggle()
```

## Documentation

Full help is available in Neovim:

```txt
:help watchexec
```

## License

MIT
