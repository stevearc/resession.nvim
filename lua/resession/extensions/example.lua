local M = {}

---Get the saved data for this extension
---@return any
M.on_save = function()
  return {}
end

M.on_load = function(data)
  --
end

---Called when resession gets configured
---This function is optional
---@param data table The configuration data passed in the config
M.config = function(data)
  --
end

---Check if a window is supported by this extension
---This function is optional for extensions
---@param winid integer
---@param bufnr integer
---@return boolean
M.is_win_supported = function(winid, bufnr)
  return true
end

---Save data for a window
---@param winid integer
---@return any
M.save_win = function(winid)
  return {}
end

---Called with the data from save_win
---@param winid integer
---@param config any
---@return integer|nil If the original window has been replaced, return the new ID that should replace it
M.load_win = function(winid, config)
  --
end

return M
