---@class resession.ListOpts
---@field dir nil|string Name of directory to save to (overrides config.dir)
---

---@class resession.DeleteOpts
---@field dir nil|string Name of directory to save to (overrides config.dir)

---@class resession.SaveOpts
---@field attach nil|boolean Stay attached to session after saving
---@field notify nil|boolean Notify on success
---@field dir nil|string Name of directory to save to (overrides config.dir)

---@class resession.LoadOpts
---@field attach nil|boolean Attach to session after loading
---@field reset nil|boolean|"auto" Close everthing before loading the session (default "auto")
---@field silence_errors nil|boolean Don't error when trying to load a missing session
---@field dir nil|string Name of directory to load from (overrides config.dir)
