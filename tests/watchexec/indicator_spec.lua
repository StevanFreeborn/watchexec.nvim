local indicator = require("watchexec.indicator")
local config = require("watchexec.config")
local stub = require("luassert.stub")

describe("watchexec indicator", function()
  local runner
  local window

  before_each(function()
    config.reset()
    config.setup({ indicator = { enabled = true } })
    indicator.reset()

    runner = require("watchexec.runner")
    window = require("watchexec.window")

    stub(runner, "is_running", function()
      return false
    end)
    stub(window, "is_visible", function()
      return false
    end)
  end)

  after_each(function()
    runner.is_running:revert()
    window.is_visible:revert()
  end)

  describe("process_output()", function()
    it("marks last_outcome as success on success pattern", function()
      indicator.process_output("[Command was successful]")
      assert.equals("success", indicator.get_last_outcome())
    end)

    it("sets waiting_for_outcome on running pattern", function()
      indicator.process_output("[Running] echo hello")
      indicator.refresh()
      assert.is_nil(indicator.get_win())
    end)

    it("marks failure when next command starts before success", function()
      indicator.process_output("[Running] echo first")
      indicator.process_output("[Running] echo second")

      indicator.refresh()

      local win = indicator.get_win()
      assert.is_true(vim.api.nvim_win_is_valid(win))
      assert.equals("failure", indicator.get_last_outcome())
    end)

    it("marks failure on Command exited with code pattern", function()
      indicator.process_output("[Command exited with code 1]")
      assert.equals("failure", indicator.get_last_outcome())
    end)

    it("leaves outcome unchanged for unrelated lines", function()
      indicator.process_output("some random output")
      assert.is_nil(indicator.get_last_outcome())
    end)
  end)

  describe("process_exit()", function()
    it("marks failure if a command was in-flight", function()
      indicator.process_output("[Running] echo hello")
      indicator.process_exit()
      assert.equals("failure", indicator.get_last_outcome())
    end)

    it("does nothing if no command was in-flight", function()
      indicator.process_exit()
      assert.is_nil(indicator.get_last_outcome())
    end)
  end)

  describe("refresh()", function()
    it("creates indicator when outcome known and window hidden", function()
      indicator.process_output("[Command was successful]")

      indicator.refresh()

      local win = indicator.get_win()
      assert.is_true(vim.api.nvim_win_is_valid(win))
    end)

    it("does not create indicator when disabled", function()
      config.reset()
      config.setup({ indicator = { enabled = false } })

      indicator.process_output("[Command was successful]")

      indicator.refresh()

      assert.is_nil(indicator.get_win())
    end)

    it("does not create indicator when window is visible", function()
      indicator.process_output("[Command was successful]")

      window.is_visible:revert()
      stub(window, "is_visible", function()
        return true
      end)

      indicator.refresh()

      assert.is_nil(indicator.get_win())
    end)

    it("does not create indicator when last_outcome is nil", function()
      indicator.refresh()

      assert.is_nil(indicator.get_win())
    end)

    it("closes indicator when window becomes visible and reopens when hidden", function()
      local visible = false
      window.is_visible:revert()
      stub(window, "is_visible", function()
        return visible
      end)

      indicator.process_output("[Command was successful]")

      indicator.refresh()

      assert.is_not_nil(indicator.get_win())

      visible = true

      indicator.refresh()

      assert.is_nil(indicator.get_win())
      assert.equals("success", indicator.get_last_outcome())

      visible = false

      indicator.refresh()

      assert.is_not_nil(indicator.get_win())
    end)

    it("creates a non-focusable float window", function()
      indicator.process_output("[Command was successful]")

      indicator.refresh()

      local win = indicator.get_win()
      local win_config = vim.api.nvim_win_get_config(win)

      assert.is_false(win_config.focusable)
    end)
  end)

  describe("reset()", function()
    it("clears last_outcome and waiting_for_outcome", function()
      indicator.process_output("[Running] echo hello")
      indicator.reset()
      assert.is_nil(indicator.get_last_outcome())
    end)
  end)
end)
