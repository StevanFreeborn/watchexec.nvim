local plugin = require("watchexec")

describe("watchexec logic", function()
  before_each(function()
    plugin.setup({
      greeting = "Hello Test!",
    })
  end)

  it("can be required without errors", function()
    assert.not_nil(plugin)
  end)

  it("correctly applies user configuration", function()
    assert.equals("Hello Test!", plugin.config.greeting)
  end)
end)
