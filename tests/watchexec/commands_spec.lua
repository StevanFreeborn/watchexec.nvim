local watchexec = require("watchexec")
local stub = require("luassert.stub")

describe("watchexec commands", function()
  local runner
  local window
  local indicator

  before_each(function()
    runner = require("watchexec.runner")
    window = require("watchexec.window")
    indicator = require("watchexec.indicator")

    stub(runner, "start")
    stub(runner, "stop")

    stub(runner, "is_running", function()
      return false
    end)

    stub(window, "open")
    stub(window, "close")
    stub(window, "toggle")

    stub(window, "resize_float")
    stub(window, "clear")

    stub(window, "is_visible", function()
      return false
    end)

    stub(indicator, "refresh")
    stub(indicator, "reset")
  end)

  after_each(function()
    runner.start:revert()
    runner.stop:revert()
    runner.is_running:revert()

    window.open:revert()
    window.close:revert()
    window.toggle:revert()
    window.resize_float:revert()
    window.clear:revert()
    window.is_visible:revert()

    indicator.refresh:revert()
    indicator.reset:revert()
  end)

  describe("run()", function()
    it("opens window and starts runner", function()
      watchexec.run("echo hello")

      assert.stub(runner.start).was_called_with("echo hello")
      assert.stub(window.clear).was_called(1)
      assert.stub(window.open).was_called(1)
    end)

    it("does not open window if already visible", function()
      window.is_visible:revert()
      stub(window, "is_visible", function()
        return true
      end)

      watchexec.run("echo hello")

      assert.stub(window.clear).was_called(1)
      assert.stub(window.open).was_called(0)
    end)

    it("stops previous run before starting new one", function()
      runner.is_running:revert()
      stub(runner, "is_running", function()
        return true
      end)

      watchexec.run("echo hello")

      assert.stub(runner.stop).was_called(1)
      assert.stub(window.clear).was_called(1)
      assert.stub(runner.start).was_called_with("echo hello")
    end)
  end)

  describe("stop()", function()
    it("stops the runner", function()
      watchexec.stop()

      assert.stub(runner.stop).was_called(1)
      assert.stub(window.clear).was_called(1)
      assert.stub(indicator.reset).was_called(1)
      assert.stub(indicator.refresh).was_called(1)
    end)
  end)

  describe("VimLeavePre autocmd", function()
    it("stops the runner on exit", function()
      dofile("plugin/watchexec.lua")

      vim.api.nvim_exec_autocmds("VimLeavePre", { group = "watchexec_nvim" })

      assert.stub(runner.stop).was_called(1)
      assert.stub(window.clear).was_called(0)
    end)
  end)

  describe("VimResized autocmd", function()
    it("calls resize_float on terminal resize", function()
      dofile("plugin/watchexec.lua")

      vim.api.nvim_exec_autocmds("VimResized", { group = "watchexec_nvim" })

      vim.wait(200, function()
        return pcall(function()
          assert.stub(window.resize_float).was_called(1)
          return true
        end)
      end)

      assert.stub(window.resize_float).was_called(1)
    end)
  end)

  describe("keymaps", function()
    before_each(function()
      vim.g.loaded_watchexec = nil
      dofile("plugin/watchexec.lua")
    end)

    local function leader()
      return vim.g.mapleader or "\\"
    end

    it("defines <Leader>wxt toggle keymap", function()
      local maps = vim.api.nvim_get_keymap("n")
      local found = false
      for _, m in ipairs(maps) do
        if m.lhs == leader() .. "wxt" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("defines <Leader>wxs stop keymap", function()
      local maps = vim.api.nvim_get_keymap("n")
      local found = false
      for _, m in ipairs(maps) do
        if m.lhs == leader() .. "wxs" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("defines <Leader>wxr run keymap", function()
      local maps = vim.api.nvim_get_keymap("n")
      local found = false
      for _, m in ipairs(maps) do
        if m.lhs == leader() .. "wxr" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("invokes toggle via <Leader>wxt", function()
      local ldr = leader()
      vim.cmd("normal " .. ldr .. "wxt")

      assert.stub(window.clear).was_called(1)
      assert.stub(runner.start).was_called(0)
      assert.stub(window.open).was_called(1)
    end)

    it("invokes stop via <Leader>wxs", function()
      local ldr = leader()
      vim.cmd("normal " .. ldr .. "wxs")

      assert.stub(runner.stop).was_called(1)
      assert.stub(window.clear).was_called(1)
    end)

    it("prompts and runs via <Leader>wxr", function()
      local input_stub = stub(vim.fn, "input", function()
        return "echo hello"
      end)

      local ldr = leader()
      vim.cmd("normal " .. ldr .. "wxr")

      assert.stub(window.clear).was_called(1)
      assert.stub(runner.start).was_called_with("echo hello")
      assert.stub(window.open).was_called(1)

      input_stub:revert()
    end)
  end)

  describe("toggle()", function()
    it("opens window with placeholder if nothing running", function()
      watchexec.toggle()

      assert.stub(window.clear).was_called(1)
      assert.stub(runner.start).was_called(0)
      assert.stub(window.open).was_called(1)
    end)

    it("hides window if runner is running and window is visible", function()
      runner.is_running:revert()

      stub(runner, "is_running", function()
        return true
      end)

      window.is_visible:revert()

      stub(window, "is_visible", function()
        return true
      end)

      watchexec.toggle()

      assert.stub(window.clear).was_called(0)
      assert.stub(runner.start).was_called(0)
      assert.stub(window.toggle).was_called(1)
    end)

    it("opens window if runner is running but not visible", function()
      runner.is_running:revert()

      stub(runner, "is_running", function()
        return true
      end)

      window.is_visible:revert()

      stub(window, "is_visible", function()
        return false
      end)

      watchexec.toggle()

      assert.stub(window.clear).was_called(0)
      assert.stub(runner.start).was_called(0)
      assert.stub(window.open).was_called(1)
    end)

    it("closes window if nothing running and window is visible", function()
      window.is_visible:revert()

      stub(window, "is_visible", function()
        return true
      end)

      watchexec.toggle()

      assert.stub(window.clear).was_called(0)
      assert.stub(runner.start).was_called(0)
      assert.stub(window.close).was_called(1)
      assert.stub(window.open).was_called(0)
    end)
  end)
end)
