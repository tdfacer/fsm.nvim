-- Integration tests for focus lifecycle
-- These tests may require i3 and tmux to be available

local fsm = require("fsm")
local store = require("fsm.store")
local state = require("fsm.state")
local config = require("fsm.config")
local i3 = require("fsm.drivers.i3")
local tmux = require("fsm.drivers.tmux")

describe("focus lifecycle", function()
  local test_dir

  before_each(function()
    -- Use fresh temp directory
    test_dir = vim.fn.tempname()
    config.setup({
      data_dir = test_dir,
      tmux = { enabled = false }, -- Disable for simpler testing
    })
    state.clear()
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  describe("start", function()
    it("creates a new focus", function()
      local ok, err = fsm.start("Test Focus")
      assert.is_true(ok)
      assert.is_nil(err)

      assert.equals("test-focus", fsm.current())
      assert.is_true(store.exists("test-focus"))
    end)

    it("sets current focus", function()
      fsm.start("Test Focus")
      local focus = fsm.current_focus()
      assert.equals("test-focus", focus.slug)
      assert.equals("active", focus.state)
    end)
  end)

  describe("suspend", function()
    it("suspends current focus", function()
      fsm.start("Test Focus")
      local ok, err = fsm.suspend()
      assert.is_true(ok)
      assert.is_nil(err)

      local focus = store.load("test-focus")
      assert.equals("suspended", focus.state)
      assert.is_nil(fsm.current())
    end)

    it("suspends by slug", function()
      fsm.start("Test Focus")
      local ok = fsm.suspend("test-focus")
      assert.is_true(ok)
    end)

    it("fails when no focus active", function()
      local ok, err = fsm.suspend()
      assert.is_false(ok)
      assert.truthy(err:match("No focus"))
    end)
  end)

  describe("resume", function()
    it("resumes suspended focus", function()
      fsm.start("Test Focus")
      fsm.suspend()

      local ok, err = fsm.resume("test-focus")
      assert.is_true(ok)
      assert.is_nil(err)

      local focus = store.load("test-focus")
      assert.equals("active", focus.state)
      assert.equals("test-focus", fsm.current())
    end)
  end)

  describe("switch", function()
    it("suspends current and resumes new", function()
      fsm.start("Focus One")
      fsm.start("Focus Two")
      fsm.suspend()

      fsm.resume("focus-one")
      local ok = fsm.switch("focus-two")
      assert.is_true(ok)

      assert.equals("focus-two", fsm.current())
      local f1 = store.load("focus-one")
      assert.equals("suspended", f1.state)
    end)
  end)

  describe("archive", function()
    it("archives a focus", function()
      fsm.start("Test Focus")
      fsm.suspend()
      local ok = fsm.archive("test-focus")
      assert.is_true(ok)

      local focus = store.load("test-focus")
      assert.equals("archived", focus.state)
    end)

    it("cannot resume archived focus", function()
      fsm.start("Test Focus")
      fsm.suspend()
      fsm.archive("test-focus")

      local ok, err = fsm.resume("test-focus")
      assert.is_false(ok)
      assert.truthy(err:match("archived"))
    end)
  end)

  describe("list", function()
    it("lists all focuses", function()
      fsm.start("Focus One")
      fsm.suspend()
      fsm.start("Focus Two")

      local all = fsm.list()
      assert.equals(2, #all)
    end)

    it("filters by state", function()
      fsm.start("Focus One")
      fsm.suspend()
      fsm.start("Focus Two")

      local suspended = fsm.list({ state = "suspended" })
      assert.equals(1, #suspended)
      assert.equals("focus-one", suspended[1].slug)
    end)
  end)
end)

-- Conditional tests that require i3
if i3.available() then
  describe("i3 integration", function()
    it("allocates workspace", function()
      local num, err = i3.alloc_workspace(10, 19)
      assert.is_not_nil(num)
      assert.is_nil(err)
      assert.is_true(num >= 10 and num <= 19)
    end)

    it("gets workspaces", function()
      local workspaces, err = i3.get_workspaces()
      assert.is_not_nil(workspaces)
      assert.is_nil(err)
      assert.is_true(#workspaces > 0)
    end)
  end)
end

-- Conditional tests that require tmux
if tmux.available() then
  describe("tmux integration", function()
    local test_session = "fsm-test-session"

    after_each(function()
      -- Cleanup test session
      tmux.kill_session(test_session)
    end)

    it("creates and kills session", function()
      local ok = tmux.create_session(test_session)
      assert.is_true(ok)
      assert.is_true(tmux.session_exists(test_session))

      ok = tmux.kill_session(test_session)
      assert.is_true(ok)
      assert.is_false(tmux.session_exists(test_session))
    end)
  end)
end
