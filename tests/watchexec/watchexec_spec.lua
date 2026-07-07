local watchexec = require("watchexec")

describe("watchexec module", function()
  it("can be required without errors", function()
    assert.not_nil(watchexec)
  end)

  it("exposes setup function", function()
    assert.is_function(watchexec.setup)
  end)

  it("exposes run function", function()
    assert.is_function(watchexec.run)
  end)

  it("exposes stop function", function()
    assert.is_function(watchexec.stop)
  end)

  it("exposes toggle function", function()
    assert.is_function(watchexec.toggle)
  end)

  it("setup delegates to config", function()
    local config = require("watchexec.config")

    watchexec.setup({ auto_scroll = false })

    assert.equals(false, config.get().auto_scroll)
  end)
end)
