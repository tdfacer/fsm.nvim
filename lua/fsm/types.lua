---@meta
-- LuaCATS type annotations for FSM

---@alias FocusState "active" | "suspended" | "archived"

---@class FocusMeta
---@field slug string Unique identifier (slugified name)
---@field name string Human-readable name
---@field state FocusState Current state
---@field workspace_num? number Allocated workspace number (10-19)
---@field workspace_name? string Full workspace name (e.g., "10:FOCUS-incident-rds")
---@field created_at string ISO 8601 timestamp
---@field updated_at string ISO 8601 timestamp
---@field suspended_at? string ISO 8601 timestamp of last suspension
---@field resumed_at? string ISO 8601 timestamp of last resume
---@field env? table<string, string> Environment variables (redacted)
---@field cwd? string Working directory
---@field tmux_session? string tmux session name
---@field parked_containers? number[] Container IDs parked to workspace 99
---@field parked_metadata? table[] Metadata about parked windows for identification

---@class FocusConfig
---@field log_level LogLevel
---@field workspace_range number[] Min and max workspace numbers [11, 19]
---@field parking_workspace number Workspace for parked windows (99)
---@field suspend_policy SuspendPolicy How to handle windows on suspend
---@field apps AppConfig Application launch commands
---@field tmux TmuxConfig tmux configuration
---@field notes NotesConfig Notes configuration
---@field urls UrlsConfig URL configuration
---@field redact_env_vars string[] Patterns for env vars to redact
---@field data_dir string Data storage directory

---@class FocusConfigOpts
---@field log_level? LogLevel
---@field workspace_range? integer[]
---@field parking_workspace? number
---@field suspend_policy? SuspendPolicy
---@field apps? AppConfig
---@field tmux? TmuxConfig
---@field notes? NotesConfig
---@field urls? UrlsConfig
---@field redact_env_vars? string[]
---@field data_dir? string

---@class SuspendPolicy
---@field terminals "keep" | "park" | "close"
---@field browsers "keep" | "park" | "close"

---@class AppConfig
---@field terminal string Terminal launch command template
---@field browser string Browser launch command template

---@class TmuxConfig
---@field enabled boolean Whether to use tmux
---@field session_prefix string Prefix for tmux session names
---@field track_cwd boolean Track and restore working directory

---@class NotesConfig
---@field auto_open boolean Whether to auto-open notes on focus start

---@class UrlsConfig
---@field auto_open_on_resume boolean Whether to auto-open URLs when resuming a focus

---@class DriverResult
---@field ok boolean Whether the operation succeeded
---@field error? string Error message if failed
---@field data? any Result data

return {}
