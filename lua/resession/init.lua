local M = {}

local pending_config
M.setup = function(config)
  pending_config = config or {}
end

---@param name string
---@return string
local function get_session_file(name)
  local files = require("resession.files")
  return files.get_stdpath_filename("data", "session", string.format("%s.json", name))
end

---@return string[]
M.list = function()
  local files = require("resession.files")
  local session_dir = files.get_stdpath_filename("data", "session")
  if not files.exists(session_dir) then
    return {}
  end
  local fd = vim.loop.fs_opendir(session_dir, nil, 32)
  local entries = vim.loop.fs_readdir(fd)
  local ret = {}
  while entries do
    for _, entry in ipairs(entries) do
      if entry.type == "file" then
        local name = entry.name:match("^(.+)%.json$")
        if name then
          table.insert(ret, name)
        end
      end
    end
    entries = vim.loop.fs_readdir(fd)
  end
  vim.loop.fs_closedir(fd)
  return ret
end

M.delete = function(name)
  local files = require("resession.files")
  if not name then
    local sessions = M.list()
    if vim.tbl_isempty(sessions) then
      vim.notify("No saved sessions", vim.log.levels.WARN)
      return
    end
    vim.ui.select(sessions, {}, function(selected)
      if selected then
        M.delete(selected)
      end
    end)
    return
  end
  local filename = get_session_file(name)
  if not files.delete_file(filename) then
    error(string.format("No session '%s'", filename))
  end
end

---@param name? string
M.save = function(name)
  if not name then
    vim.ui.input({ prompt = "Session name" }, function(selected)
      if selected then
        M.save(selected)
      end
    end)
    return
  end
  local config = require("resession.config")
  local files = require("resession.files")
  local layout = require("resession.layout")
  local util = require("resession.util")
  local filename = get_session_file(name)
  local data = {
    buffers = {},
    tabs = {},
    cwd = vim.fn.getcwd(-1, -1),
  }
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if util.should_save_buffer(bufnr) then
      local buf = {
        name = vim.api.nvim_buf_get_name(bufnr),
        loaded = vim.api.nvim_buf_is_loaded(bufnr),
        options = {},
      }
      for _, option in ipairs(config.buffers.options) do
        buf.options[option] = vim.bo[bufnr][option]
      end
      table.insert(data.buffers, buf)
    end
  end
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    local tab = {}
    local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
    if vim.fn.haslocaldir(-1, tabnr) == 1 then
      tab.cwd = vim.fn.getcwd(-1, tabnr)
    end
    table.insert(data.tabs, tab)
    local winlayout = vim.fn.winlayout(tabnr)
    tab.wins = layout.add_win_info_to_layout(tabnr, winlayout)
  end
  files.write_json_file(filename, data)
end

local function close_everything()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  vim.cmd("silent! tabonly")
  vim.cmd("silent! only")
  vim.bo.bufhidden = "wipe"
  vim.bo.buflisted = false
end

---@param name? string
M.load = function(name)
  local files = require("resession.files")
  local layout = require("resession.layout")
  if not name then
    local sessions = M.list()
    if vim.tbl_isempty(sessions) then
      vim.notify("No saved sessions", vim.log.levels.WARN)
      return
    end
    vim.ui.select(sessions, {}, function(selected)
      if selected then
        M.load(selected)
      end
    end)
    return
  end
  local filename = get_session_file(name)
  local data = files.load_json_file(filename)
  if not data then
    vim.notify(string.format("Could not find session %s", name), vim.log.levels.ERROR)
    return
  end
  close_everything()
  vim.cmd(string.format("cd %s", data.cwd))
  for _, buf in ipairs(data.buffers) do
    local bufnr = vim.fn.bufadd(buf.name)
    if buf.loaded then
      vim.fn.bufload(bufnr)
    end
    for opt, v in pairs(buf.options) do
      vim.bo[bufnr][opt] = v
    end
  end

  for i, tab in ipairs(data.tabs) do
    if i > 1 then
      vim.cmd("tabnew")
    end
    if tab.cwd then
      vim.cmd(string.format("tcd %s", tab.cwd))
    end
    layout.set_winlayout(tab.wins)
  end
end

-- Make sure all the API functions trigger the lazy load
for k, v in pairs(M) do
  if type(v) == "function" and k ~= "setup" then
    M[k] = function(...)
      if pending_config then
        require("resession.config").setup(pending_config)
        pending_config = nil
      end
      return v(...)
    end
  end
end

return M
