local config = require("watchexec.config")
local stub = require("luassert.stub")

describe("watchexec config", function()
  after_each(function()
    config.reset()
  end)

  describe("defaults", function()
    it("returns default values before setup", function()
      local cfg = config.get()

      assert.equals("watchexec", cfg.watchexec.bin)
      assert.same({}, cfg.watchexec.args)
      assert.equals("float", cfg.window.type)
      assert.equals("below", cfg.window.split)
      assert.equals(12, cfg.window.size)
      assert.is_true(cfg.auto_scroll)
      assert.equals(5000, cfg.max_lines)
    end)
  end)

  describe("setup()", function()
    it("merges user options over defaults", function()
      config.setup({
        auto_scroll = false,
        watchexec = { args = { "-e", "py" } },
      })

      local cfg = config.get()

      assert.is_false(cfg.auto_scroll)
      assert.same({ "-e", "py" }, cfg.watchexec.args)
      assert.equals("watchexec", cfg.watchexec.bin)
    end)

    it("returns without changes when opts is nil", function()
      config.setup(nil)

      local cfg = config.get()

      assert.equals("watchexec", cfg.watchexec.bin)
    end)

    it("finds watchexec binary via PATH", function()
      local exec_stub = stub(vim.fn, "executable", function(name)
        if name == "watchexec" then
          return 1
        end
        return 0
      end)

      config.setup({})

      local cfg = config.get()

      assert.equals("watchexec", cfg.watchexec.bin)

      exec_stub:revert()
    end)

    it("falls back to candidate paths when not in PATH", function()
      local exec_stub = stub(vim.fn, "executable", function(name)
        return 0
      end)

      local expand_stub = stub(vim.fn, "expand", function(name)
        if name == "~" then
          return "/home/user"
        end
        return ""
      end)

      local has_stub = stub(vim.fn, "has", function(name)
        return 0
      end)

      config.setup({})

      local cfg = config.get()

      assert.is_nil(cfg.watchexec.bin)

      exec_stub:revert()
      expand_stub:revert()
      has_stub:revert()
    end)

    it("notifies when binary is not found", function()
      local exec_stub = stub(vim.fn, "executable", function()
        return 0
      end)

      local has_stub = stub(vim.fn, "has", function()
        return 0
      end)

      local expand_stub = stub(vim.fn, "expand", function()
        return "/home/user"
      end)

      local notify_stub = stub(vim, "notify")

      config.setup({})

      assert
        .stub(notify_stub)
        .was_called_with("watchexec.nvim: could not find watchexec binary. Set opts.watchexec.bin in your config.", vim.log.levels.WARN)

      exec_stub:revert()
      has_stub:revert()
      expand_stub:revert()
      notify_stub:revert()
    end)
  end)

  describe("get()", function()
    it("returns the current config table", function()
      config.setup({ max_lines = 100 })

      local cfg = config.get()

      assert.equals(100, cfg.max_lines)
    end)
  end)
end)
