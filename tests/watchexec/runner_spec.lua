local config = require("watchexec.config")
local window = require("watchexec.window")
local runner = require("watchexec.runner")
local stub = require("luassert.stub")

describe("watchexec runner", function()
  local jobstart_stub
  local jobpid_stub
  local jobstop_stub
  local notify_stub
  local indicator

  before_each(function()
    config.reset()
    config.setup({})
    window.cleanup()

    jobstart_stub = stub(vim.fn, "jobstart", function()
      return 42
    end)

    jobpid_stub = stub(vim.fn, "jobpid", function()
      return 12345
    end)

    jobstop_stub = stub(vim.fn, "jobstop")
    notify_stub = stub(vim, "notify")

    indicator = require("watchexec.indicator")
    stub(indicator, "process_output")
    stub(indicator, "process_exit")
    stub(indicator, "reset")
    stub(indicator, "refresh")
  end)

  after_each(function()
    if runner.is_running() then
      runner.stop()
    end

    jobstart_stub:revert()
    jobpid_stub:revert()
    jobstop_stub:revert()

    notify_stub:revert()

    indicator.process_output:revert()
    indicator.process_exit:revert()
    indicator.reset:revert()
    indicator.refresh:revert()

    window.cleanup()

    config.reset()
  end)

  describe("start()", function()
    it("spawns watchexec with binary and command args", function()
      window.open()
      runner.start("pytest")

      assert.stub(jobstart_stub).was_called(1)

      local cmd = jobstart_stub.calls[1].refs[1]

      assert.same({ "watchexec", "pytest" }, cmd)
    end)

    it("includes watchexec.args before command", function()
      config.setup({
        watchexec = { args = { "-e", "py" } },
      })
      window.open()
      runner.start("-- pytest")

      local cmd = jobstart_stub.calls[1].refs[1]

      assert.same({ "watchexec", "-e", "py", "--", "pytest" }, cmd)
    end)

    it("gets pid via jobpid", function()
      window.open()
      runner.start("test")

      assert.stub(jobpid_stub).was_called_with(42)
    end)

    it("notifies error when binary not found", function()
      config.get().watchexec.bin = nil
      window.open()
      runner.start("test")

      assert.stub(notify_stub).was_called_with("watchexec.nvim: watchexec binary not found", vim.log.levels.ERROR)
      assert.stub(jobstart_stub).was_called(0)
    end)

    it("stores is_running state after spawn", function()
      window.open()
      runner.start("test")

      assert.is_true(runner.is_running())
    end)

    it("stores cmd after spawn", function()
      window.open()
      runner.start("pytest -x")

      assert.equals("pytest -x", runner.get_cmd())
    end)

    it("provides callbacks to jobstart", function()
      window.open()
      runner.start("test")

      local opts = jobstart_stub.calls[1].refs[2]

      assert.is_function(opts.on_stdout)
      assert.is_function(opts.on_stderr)
      assert.is_function(opts.on_exit)
    end)
  end)

  describe("stop()", function()
    it("calls jobstop", function()
      window.open()
      runner.start("test")
      runner.stop()

      assert.stub(jobstop_stub).was_called_with(42)
    end)

    it("calls vim.uv.kill with pid", function()
      local uv_kill_stub = stub(vim.uv, "kill")

      window.open()
      runner.start("test")
      runner.stop()

      assert.stub(uv_kill_stub).was_called_with(12345, "term")

      uv_kill_stub:revert()
    end)

    it("clears running state", function()
      window.open()
      runner.start("test")
      runner.stop()

      assert.is_false(runner.is_running())
    end)

    it("does nothing if no process running", function()
      runner.stop()

      assert.is_false(runner.is_running())
    end)
  end)

  describe("is_running()", function()
    it("returns true after start", function()
      window.open()
      runner.start("test")

      assert.is_true(runner.is_running())
    end)

    it("returns false initially", function()
      assert.is_false(runner.is_running())
    end)
  end)

  describe("get_cmd()", function()
    it("returns the command passed to start", function()
      window.open()
      runner.start("pytest -x")

      assert.equals("pytest -x", runner.get_cmd())
    end)

    it("returns nil after stop", function()
      window.open()
      runner.start("test")
      runner.stop()

      assert.is_nil(runner.get_cmd())
    end)
  end)

  describe("normalize_output", function()
    it("removes ANSI sequences", function()
      local result = runner._strip_ansi("\x1b[31mred\x1b[0m")

      assert.equals("red", result)
    end)

    it("converts \\r\\n to \\n", function()
      local result, _ = runner._normalize_output("line1\r\nline2\r\nline3")

      assert.equals("line1\nline2\nline3", result)
    end)

    it("resolves inline overwrites (\\r splits)", function()
      local result, _ = runner._normalize_output("a\rb\rc")

      assert.equals("c", result)
    end)

    it("resolves mixed inline and line (\\r in last line)", function()
      local result, _ = runner._normalize_output("a\rb\nc\rd")

      assert.equals("b\nd", result)
    end)

    it("detects leading overwrite", function()
      local _, overwrite = runner._normalize_output("\rxyz")

      assert.is_true(overwrite)
    end)

    it("does not detect overwrite on normal text", function()
      local _, overwrite = runner._normalize_output("xyz")

      assert.is_false(overwrite)
    end)

    it("does not detect overwrite on CRLF that starts with \\r", function()
      local _, overwrite = runner._normalize_output("\r\nxyz")

      assert.is_false(overwrite)
    end)

    it("handles empty text", function()
      local result, overwrite = runner._normalize_output("")

      assert.equals("", result)
      assert.is_false(overwrite)
    end)
  end)

  describe("on_exit guard", function()
    it("ignores stale on_exit from replaced job", function()
      local call_count = 0

      jobstart_stub:revert()
      jobstart_stub = stub(vim.fn, "jobstart", function()
        call_count = call_count + 1
        return 42 + call_count
      end)

      jobpid_stub:revert()
      jobpid_stub = stub(vim.fn, "jobpid", function()
        return 10000 + call_count
      end)

      window.open()
      runner.start("first")

      local first_opts = jobstart_stub.calls[1].refs[2]

      runner.start("second")

      first_opts.on_exit(43, 0, nil)
      vim.cmd("sleep 1m")

      assert.is_true(runner.is_running())
      assert.equals("second", runner.get_cmd())
    end)
  end)
end)
