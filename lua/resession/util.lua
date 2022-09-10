local config = require("resession.config")
local M = {}

---@return table<string, any>
M.save_global_options = function()
  local ret = {}
  for _, opt in ipairs(config.options) do
    local info = vim.api.nvim_get_option_info(opt)
    if info.scope == "global" then
      ret[opt] = vim.go[opt]
    end
  end
  return ret
end

---@param winid integer
---@return table<string, any>
M.save_win_options = function(winid)
  local ret = {}
  for _, opt in ipairs(config.options) do
    local info = vim.api.nvim_get_option_info(opt)
    if info.scope == "win" then
      ret[opt] = vim.api.nvim_win_get_option(winid, opt)
    end
  end
  return ret
end

---@param bufnr integer
---@return table<string, any>
M.save_buf_options = function(bufnr)
  local ret = {}
  for _, opt in ipairs(config.options) do
    local info = vim.api.nvim_get_option_info(opt)
    if info.scope == "buf" then
      ret[opt] = vim.api.nvim_buf_get_option(bufnr, opt)
    end
  end
  return ret
end

---@param opts table<string, any>
M.restore_global_options = function(opts)
  for opt, val in pairs(opts) do
    local info = vim.api.nvim_get_option_info(opt)
    if info.scope == "global" then
      vim.go[opt] = val
    end
  end
end

---@param winid integer
---@param opts table<string, any>
M.restore_win_options = function(winid, opts)
  for opt, val in pairs(opts) do
    local info = vim.api.nvim_get_option_info(opt)
    if info.scope == "win" then
      vim.api.nvim_win_set_option(winid, opt, val)
    end
  end
end

---@param bufnr integer
---@param opts table<string, any>
M.restore_buf_options = function(bufnr, opts)
  for opt, val in pairs(opts) do
    local info = vim.api.nvim_get_option_info(opt)
    if info.scope == "buf" then
      vim.api.nvim_buf_set_option(bufnr, opt, val)
    end
  end
end

---@return string
M.get_session_dir = function()
  local files = require("resession.files")
  return files.get_stdpath_filename("data", config.dir)
end

---@param name string The name of the session
---@return string
M.get_session_file = function(name)
  local files = require("resession.files")
  local filename = string.format("%s.json", name:gsub(files.sep, "_"))
  return files.join(M.get_session_dir(), filename)
end

return M
