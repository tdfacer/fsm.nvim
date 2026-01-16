local config = require("fsm.config")

describe("config", function()
  before_each(function()
    -- Reset config to defaults
    config.setup({})
  end)

  describe("setup", function()
    it("uses defaults when no options provided", function()
      config.setup()
      local cfg = config.get()
      assert.equals(10, cfg.workspace_range[1])
      assert.equals(19, cfg.workspace_range[2])
      assert.equals(99, cfg.parking_workspace)
    end)

    it("merges user options", function()
      config.setup({
        parking_workspace = 50,
      })
      local cfg = config.get()
      assert.equals(50, cfg.parking_workspace)
      -- Defaults still applied
      assert.equals(10, cfg.workspace_range[1])
    end)

    it("deep merges nested options", function()
      config.setup({
        suspend_policy = {
          browsers = "close",
        },
      })
      local cfg = config.get()
      assert.equals("close", cfg.suspend_policy.browsers)
      assert.equals("keep", cfg.suspend_policy.terminals)
    end)

    it("expands data_dir path", function()
      config.setup({
        data_dir = "~/test/focus",
      })
      local cfg = config.get()
      assert.truthy(cfg.data_dir:match("^/"))
    end)
  end)

  describe("foci_dir", function()
    it("returns correct path", function()
      config.setup({ data_dir = "/tmp/test-focus" })
      assert.equals("/tmp/test-focus/foci", config.foci_dir())
    end)
  end)

  describe("focus_dir", function()
    it("returns correct path for slug", function()
      config.setup({ data_dir = "/tmp/test-focus" })
      assert.equals("/tmp/test-focus/foci/my-focus", config.focus_dir("my-focus"))
    end)
  end)
end)
