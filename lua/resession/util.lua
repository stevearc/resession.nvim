local config = require("resession.config")
local M = {}

---@param opt string
---@return string
local function get_option_scope(opt)
  -- This only exists in nvim-0.9
  if vim.api.nvim_get_option_info2 then
    return vim.api.nvim_get_option_info2(opt, {}).scope
  else
    ---@diagnostic disable-next-line: redundant-parameter
    return vim.api.nvim_get_option_info(opt).scope
  end
end

local ext_cache = {}
---@param name string
---@return resession.Extension?
M.get_extension = function(name)
  if ext_cache[name] then
    return ext_cache[name]
  end
  local has_ext, ext = pcall(require, string.format("resession.extensions.%s", name))
  if has_ext then
    if ext.config then
      local ok, err = pcall(ext.config, config.extensions[name])
      if not ok then
        vim.notify_once(
          string.format("Error configuring resession extension %s: %s", name, err),
          vim.log.levels.ERROR
        )
        return
      end
    end
    ext_cache[name] = ext
    return ext
  else
    vim.notify_once(string.format("[resession] Missing extension '%s'", name), vim.log.levels.WARN)
  end
end

---@return table<string, any>
M.save_global_options = function()
  local ret = {}
  for _, opt in ipairs(config.options) do
    if get_option_scope(opt) == "global" then
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
    if get_option_scope(opt) == "win" then
      ret[opt] = vim.wo[winid][opt]
    end
  end
  return ret
end

---@param bufnr integer
---@return table<string, any>
M.save_buf_options = function(bufnr)
  local ret = {}
  for _, opt in ipairs(config.options) do
    if get_option_scope(opt) == "buf" then
      ret[opt] = vim.bo[bufnr][opt]
    end
  end
  return ret
end

---@param bufnr integer
---@return table<string, any>
M.save_tab_options = function(bufnr)
  local ret = {}
  -- 'cmdheight' is the only tab-local option, but the scope from nvim_get_option_info is incorrect
  -- since there's no way to fetch a tabpage-local option, we rely on this being called from inside
  -- the relevant tabpage
  if vim.tbl_contains(config.options, "cmdheight") then
    ret.cmdheight = vim.o.cmdheight
  end
  return ret
end

---@param opts table<string, any>
M.restore_global_options = function(opts)
  for opt, val in pairs(opts) do
    if get_option_scope(opt) == "global" then
      vim.go[opt] = val
    end
  end
end

---@param winid integer
---@param opts table<string, any>
M.restore_win_options = function(winid, opts)
  for opt, val in pairs(opts) do
    if get_option_scope(opt) == "win" then
      vim.api.nvim_set_option_value(opt, val, { scope = "local", win = winid })
    end
  end
end

---@param bufnr integer
---@param opts table<string, any>
M.restore_buf_options = function(bufnr, opts)
  for opt, val in pairs(opts) do
    if get_option_scope(opt) == "buf" then
      vim.bo[bufnr][opt] = val
    end
  end
end

---@param opts table<string, any>
M.restore_tab_options = function(opts)
  -- 'cmdheight' is the only tab-local option. See save_tab_options
  if opts.cmdheight then
    -- empirically, this seems to only set the local tab value
    vim.o.cmdheight = opts.cmdheight
  end
end

---@param dirname? string
---@return string
M.get_session_dir = function(dirname)
  local files = require("resession.files")
  return files.get_stdpath_filename("data", dirname or config.dir)
end

---@param name string The name of the session
---@param dirname? string
---@return string
M.get_session_file = function(name, dirname)
  local files = require("resession.files")
  local filename = string.format("%s.json", name:gsub(files.sep, "_"))
  return files.join(M.get_session_dir(dirname), filename)
end

M.include_buf = function(tabpage, bufnr, tabpage_bufs)
  if not config.buf_filter(bufnr) then
    return false
  end
  if not tabpage then
    return true
  end
  return tabpage_bufs[bufnr] or config.tab_buf_filter(tabpage, bufnr)
end

M.shorten_path = function(path)
  local home = os.getenv("HOME")
  if not home then
    return path
  end
  local idx, chars = string.find(path, home)
  if idx == 1 then
    return "~" .. string.sub(path, idx + chars)
  else
    return path
  end
end

return M
