local config = require("watchexec.config")
local window = require("watchexec.window")
local indicator = require("watchexec.indicator")
local stub = require("luassert.stub")

describe("watchexec window", function()
  before_each(function()
    config.reset()
    config.setup({})
    window.cleanup()
    stub(indicator, "refresh")
    stub(indicator, "reset")
  end)

  after_each(function()
    window.cleanup()
    config.reset()
    indicator.refresh:revert()
    indicator.reset:revert()
  end)

  describe("open()", function()
    it("opens a float window by default", function()
      window.open()

      local win = window.get_win()
      local win_config = vim.api.nvim_win_get_config(win)

      assert.equals("editor", win_config.relative)
      assert.is_true(vim.api.nvim_win_is_valid(win))
      assert.is_true(window.is_visible())
    end)

    it("opens a float window when configured", function()
      config.setup({
        window = { type = "float" },
      })

      window.open()

      local win = window.get_win()

      assert.is_true(vim.api.nvim_win_is_valid(win))

      local win_config = vim.api.nvim_win_get_config(win)

      assert.equals("editor", win_config.relative)
    end)

    it("reuses existing window if still valid", function()
      window.open()

      window.close()
      window.open()

      local second_win = window.get_win()

      assert.is_true(vim.api.nvim_win_is_valid(second_win))
    end)
  end)

  describe("close()", function()
    it("closes the open window", function()
      window.open()

      local wins_before = #vim.api.nvim_list_wins()

      window.close()

      local wins_after = #vim.api.nvim_list_wins()

      assert.equals(wins_before - 1, wins_after)
      assert.is_nil(window.get_win())
      assert.is_false(window.is_visible())
    end)

    it("does nothing if no window is open", function()
      assert.is_nil(window.get_win())

      window.close()

      assert.is_nil(window.get_win())
    end)
  end)

  describe("toggle()", function()
    it("opens the window if closed", function()
      window.toggle()

      assert.not_nil(window.get_win())
    end)

    it("closes the window if open", function()
      window.open()
      window.toggle()

      assert.is_nil(window.get_win())
    end)
  end)

  describe("cleanup()", function()
    it("closes the window and deletes the buffer", function()
      window.open()

      local buf = window.get_buf()

      window.cleanup()

      assert.is_false(vim.api.nvim_buf_is_valid(buf))
      assert.is_nil(window.get_buf())
      assert.is_nil(window.get_win())
    end)
  end)

  describe("is_visible()", function()
    it("returns true after open", function()
      window.open()

      assert.is_true(window.is_visible())
    end)

    it("returns false after close", function()
      window.open()
      window.close()

      assert.is_false(window.is_visible())
    end)
  end)

  describe("resize_float()", function()
    it("recalculates float dimensions after terminal resize", function()
      config.setup({
        window = { type = "float" },
      })
      window.open()

      local win = window.get_win()
      local before = vim.api.nvim_win_get_config(win)
      local orig_cols = vim.o.columns
      local orig_lines = vim.o.lines

      vim.o.columns = orig_cols + 20
      vim.o.lines = orig_lines + 10

      window.resize_float()

      local after = vim.api.nvim_win_get_config(win)
      vim.o.columns = orig_cols
      vim.o.lines = orig_lines

      assert.is_not.equals(before.width, after.width)
      assert.is_not.equals(before.height, after.height)
    end)

    it("does nothing when no window is open", function()
      window.resize_float()
    end)

    it("does nothing for split windows", function()
      window.open()

      window.resize_float()
    end)
  end)

  describe("get_buf() / get_win()", function()
    it("returns nil before open", function()
      assert.is_nil(window.get_buf())
      assert.is_nil(window.get_win())
    end)

    it("returns values after open", function()
      window.open()

      assert.not_nil(window.get_buf())
      assert.not_nil(window.get_win())
    end)
  end)

  describe("append()", function()
    it("appends text to the buffer", function()
      window.open()

      local buf = window.get_buf()

      window.append("line one")
      window.append("line two")

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      assert.equals("line one", lines[1])
      assert.equals("line two", lines[2])
    end)

    it("does nothing when buffer is invalid", function()
      window.append("should not error")
    end)

    it("replaces the waiting placeholder on first append", function()
      window.open()

      local buf = window.get_buf()

      vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
      vim.api.nvim_buf_set_lines(
        buf,
        0,
        -1,
        false,
        { " No job running. Use :WatchexecRun <command> to start one.", "" }
      )
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

      window.append("first output")

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      assert.equals("first output", lines[1])
    end)

    it("truncates to max_lines when exceeded", function()
      config.setup({
        max_lines = 3,
      })

      window.open()

      local buf = window.get_buf()

      window.append("a")
      window.append("b")
      window.append("c")
      window.append("d")

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      assert.equals(3, #lines)
      assert.equals("b", lines[1])
      assert.equals("c", lines[2])
      assert.equals("d", lines[3])
    end)

    it("scrolls to bottom when auto_scroll is enabled", function()
      config.setup({ auto_scroll = true })
      window.open()

      window.append("line one")
      window.append("line two")

      local win = window.get_win()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local buf = window.get_buf()
      local line_count = vim.api.nvim_buf_line_count(buf)

      assert.equals(line_count, cursor[1])
    end)
  end)

  describe("keymaps", function()
    it("maps <Esc> to close the window", function()
      window.open()
      local buf = window.get_buf()
      local maps = vim.api.nvim_buf_get_keymap(buf, "n")
      local found = false
      for _, m in ipairs(maps) do
        if m.lhs == "<Esc>" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("maps q to close the window", function()
      window.open()
      local buf = window.get_buf()
      local maps = vim.api.nvim_buf_get_keymap(buf, "n")
      local found = false
      for _, m in ipairs(maps) do
        if m.lhs == "q" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("calls window.close() via the <Esc> keymap", function()
      window.open()
      assert.is_true(window.is_visible())

      vim.cmd("normal " .. "\027")

      assert.is_false(window.is_visible())
    end)

    it("calls window.close() via the q keymap", function()
      window.open()
      assert.is_true(window.is_visible())

      vim.cmd("normal q")

      assert.is_false(window.is_visible())
    end)
  end)
end)
