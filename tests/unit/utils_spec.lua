local utils = require("fsm.utils")

describe("utils", function()
  describe("slugify", function()
    it("converts to lowercase", function()
      assert.equals("hello", utils.slugify("HELLO"))
    end)

    it("replaces spaces with hyphens", function()
      assert.equals("hello-world", utils.slugify("hello world"))
    end)

    it("replaces underscores with hyphens", function()
      assert.equals("hello-world", utils.slugify("hello_world"))
    end)

    it("removes special characters", function()
      assert.equals("helloworld", utils.slugify("hello@world!"))
      assert.equals("test123", utils.slugify("test!@#123"))
    end)

    it("collapses multiple hyphens", function()
      assert.equals("hello-world", utils.slugify("hello---world"))
    end)

    it("trims leading and trailing hyphens", function()
      assert.equals("hello", utils.slugify("--hello--"))
    end)

    it("handles empty string", function()
      assert.equals("", utils.slugify(""))
    end)

    it("handles nil", function()
      assert.equals("", utils.slugify(nil))
    end)

    it("handles complex names", function()
      assert.equals("incident-rds-outage-2024", utils.slugify("Incident: RDS Outage 2024!"))
    end)
  end)

  describe("validate_name", function()
    it("accepts valid names", function()
      local ok, err = utils.validate_name("My Focus")
      assert.is_true(ok)
      assert.is_nil(err)
    end)

    it("rejects empty string", function()
      local ok, err = utils.validate_name("")
      assert.is_false(ok)
      assert.equals("Name cannot be empty", err)
    end)

    it("rejects nil", function()
      local ok, err = utils.validate_name(nil)
      assert.is_false(ok)
      assert.equals("Name cannot be empty", err)
    end)

    it("rejects very long names", function()
      local long_name = string.rep("a", 100)
      local ok, err = utils.validate_name(long_name)
      assert.is_false(ok)
      assert.equals("Name cannot exceed 64 characters", err)
    end)

    it("rejects names with no alphanumeric characters", function()
      local ok, err = utils.validate_name("@#$%")
      assert.is_false(ok)
      assert.equals("Name must contain at least one alphanumeric character", err)
    end)
  end)

  describe("timestamp", function()
    it("returns ISO 8601 format", function()
      local ts = utils.timestamp()
      -- Pattern: YYYY-MM-DDTHH:MM:SSZ
      assert.truthy(ts:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
    end)
  end)

  describe("deep_merge", function()
    it("merges simple tables", function()
      local t1 = { a = 1 }
      local t2 = { b = 2 }
      local result = utils.deep_merge(t1, t2)
      assert.equals(1, result.a)
      assert.equals(2, result.b)
    end)

    it("overrides values", function()
      local t1 = { a = 1 }
      local t2 = { a = 2 }
      local result = utils.deep_merge(t1, t2)
      assert.equals(2, result.a)
    end)

    it("merges nested tables", function()
      local t1 = { nested = { a = 1, b = 2 } }
      local t2 = { nested = { b = 3, c = 4 } }
      local result = utils.deep_merge(t1, t2)
      assert.equals(1, result.nested.a)
      assert.equals(3, result.nested.b)
      assert.equals(4, result.nested.c)
    end)

    it("does not modify original tables", function()
      local t1 = { a = 1 }
      local t2 = { b = 2 }
      utils.deep_merge(t1, t2)
      assert.is_nil(t1.b)
    end)
  end)

  describe("is_empty", function()
    it("returns true for empty table", function()
      assert.is_true(utils.is_empty({}))
    end)

    it("returns false for non-empty table", function()
      assert.is_false(utils.is_empty({ a = 1 }))
    end)

    it("returns false for array", function()
      assert.is_false(utils.is_empty({ 1, 2, 3 }))
    end)
  end)

  describe("split", function()
    it("splits by delimiter", function()
      local result = utils.split("a,b,c", ",")
      assert.equals(3, #result)
      assert.equals("a", result[1])
      assert.equals("b", result[2])
      assert.equals("c", result[3])
    end)
  end)

  describe("trim", function()
    it("trims whitespace", function()
      assert.equals("hello", utils.trim("  hello  "))
    end)

    it("handles no whitespace", function()
      assert.equals("hello", utils.trim("hello"))
    end)
  end)

  describe("redact_env", function()
    it("redacts matching variables", function()
      local env = {
        PATH = "/usr/bin",
        SECRET_KEY = "abc123",
        API_TOKEN = "xyz789",
      }
      local result = utils.redact_env(env, { ".*SECRET.*", ".*TOKEN.*" })
      assert.equals("/usr/bin", result.PATH)
      assert.equals("[REDACTED]", result.SECRET_KEY)
      assert.equals("[REDACTED]", result.API_TOKEN)
    end)
  end)
end)
