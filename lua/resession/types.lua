---@class resession.ListOpts
---@field dir nil|string Name of directory to save to (overrides config.dir)

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

---@class resession.Extension
---@field on_save? fun():any
---@field on_pre_load? fun(data: any)
---@field on_post_load? fun(data: any)
---@field config? fun(options: table)
---@field is_win_supported? fun(winid: integer, bufnr: integer): boolean
---@field save_win? fun(winid: integer): any
---@field load_win? fun(winid: integer, data: any): nil|integer

---@class resession.SessionInfo
---@field name string Name of the current session
---@field dir string Name of the directory that the current session is saved in
