local health = require("watchexec.health")
local stub = require("luassert.stub")

describe("watchexec healthcheck", function()
  local start_stub
  local ok_stub
  local error_stub
  local has_stub
  local exec_stub

  before_each(function()
    start_stub = stub(vim.health, "start")
    ok_stub = stub(vim.health, "ok")
    error_stub = stub(vim.health, "error")
  end)

  after_each(function()
    start_stub:revert()
    ok_stub:revert()
    error_stub:revert()

    if has_stub then
      has_stub:revert()
    end

    if exec_stub then
      exec_stub:revert()
    end
  end)

  it("reports all checks as OK when environment is valid", function()
    has_stub = stub(vim.fn, "has", function()
      return 1
    end)

    exec_stub = stub(vim.fn, "executable", function()
      return 1
    end)

    health.check()

    assert.stub(start_stub).was_called_with("watchexec.nvim diagnostics")
    assert.stub(ok_stub).was_called(2)
    assert.stub(error_stub).was_called(0)
  end)

  it("reports an error when watchexec is missing from PATH", function()
    has_stub = stub(vim.fn, "has", function()
      return 1
    end)

    exec_stub = stub(vim.fn, "executable", function()
      return 0
    end)

    health.check()

    assert.stub(ok_stub).was_called(1)
    assert.stub(error_stub).was_called(1)

    assert.stub(error_stub).was_called_with(
      "Binary 'watchexec' was not found in PATH",
      { "Install watchexec", "Or verify your plugin configuration if using a custom binary path." }
    )
  end)

  it("reports an error when using an outdated Neovim version", function()
    has_stub = stub(vim.fn, "has", function()
      return 0
    end)

    health.check()

    assert.stub(start_stub).was_called(0)
    assert.stub(ok_stub).was_called(0)
    assert.stub(error_stub).was_called(1)
  end)
end)
