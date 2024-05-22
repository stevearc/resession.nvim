---@class (exact) resession.ListOpts
---@field dir? string Name of directory to list (overrides config.dir)

---@class (exact) resession.DeleteOpts
---@field dir? string Name of directory to delete from (overrides config.dir)

---@class (exact) resession.SaveOpts
---@field attach? boolean Stay attached to session after saving (default true)
---@field notify? boolean Notify on success
---@field dir? string Name of directory to save to (overrides config.dir)

---@class (exact) resession.SaveAllOpts
---@field notify? boolean Notify on success

---@class (exact) resession.LoadOpts
---@field attach? boolean Attach to session after loading
---@field reset? boolean|"auto" Close everything before loading the session (default "auto")
---@field silence_errors? boolean Don't error when trying to load a missing session
---@field dir? string Name of directory to load from (overrides config.dir)

---@class (exact) resession.Extension.OnSaveOpts
---@field tabpage integer? The tabpage being saved, if in a tab-scoped session

---@class (exact) resession.Extension
---@field on_save? fun(opts: resession.Extension.OnSaveOpts):any
---@field on_pre_load? fun(data: any)
---@field on_post_load? fun(data: any)
---@field config? fun(options: table)
---@field is_win_supported? fun(winid: integer, bufnr: integer): boolean
---@field save_win? fun(winid: integer): any
---@field load_win? fun(winid: integer, data: any): nil|integer

---@class (exact) resession.SessionInfo
---@field name string Name of the current session
---@field dir string Name of the directory that the current session is saved in
