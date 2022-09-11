local M = {}

local pending_config
local current_session

local function do_setup()
  if pending_config then
    require("resession.config").setup(pending_config)
    pending_config = nil
  end
end

---Initialize resession with configuration options
---@param config table
M.setup = function(config)
  pending_config = config or {}
end

---Get the name of the current session
---@return string|nil
M.get_current = function()
  return current_session
end

---Detach from the current session
M.detach = function()
  current_session = nil
end

---@class resession.ListOpts
---@field dir nil|string Name of directory to save to (overrides config.dir)

---@params opts nil|resession.ListOpts
---@return string[]
M.list = function(opts)
  opts = opts or {}
  local config = require("resession.config")
  local files = require("resession.files")
  local util = require("resession.util")
  local session_dir = util.get_session_dir(opts.dir)
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

---@class resession.DeleteOpts
---@field dir nil|string Name of directory to save to (overrides config.dir)

---@param name string
---@param opts nil|resession.DeleteOpts
M.delete = function(name, opts)
  opts = opts or {}
  local files = require("resession.files")
  local util = require("resession.util")
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
  local filename = util.get_session_file(name, opts.dir)
  if not files.delete_file(filename) then
    error(string.format("No session '%s'", filename))
  end
  if current_session == name then
    current_session = nil
  end
end

---@class resession.SaveOpts
---@field detach nil|boolean Immediately detach from the saved session
---@field notify nil|boolean Notify on success
---@field dir nil|string Name of directory to save to (overrides config.dir)

---@param name? string
---@param opts? resession.SaveOpts
M.save = function(name, opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    notify = true,
  })
  if not name then
    name = current_session
  end
  if not name then
    vim.ui.input({ prompt = "Session name" }, function(selected)
      if selected then
        M.save(selected, opts)
      end
    end)
    return
  end
  local config = require("resession.config")
  local files = require("resession.files")
  local layout = require("resession.layout")
  local util = require("resession.util")
  local filename = util.get_session_file(name, opts.dir)
  local data = {
    buffers = {},
    tabs = {},
    global = {
      cwd = vim.fn.getcwd(-1, -1),
      height = vim.o.lines - vim.o.cmdheight,
      width = vim.o.columns,
      options = util.save_global_options(),
    },
  }
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if config.buffers.filter(bufnr) then
      local buf = {
        name = vim.api.nvim_buf_get_name(bufnr),
        loaded = vim.api.nvim_buf_is_loaded(bufnr),
        options = util.save_buf_options(bufnr),
      }
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

  for ext_name in pairs(config.extensions) do
    local ext = util.get_extension(ext_name)
    if ext then
      local ok, ext_data = pcall(ext.on_save)
      if ok then
        data[ext_name] = ext_data
      else
        vim.notify(
          string.format("[resession] Extension %s save error: %s", ext_name, ext_data),
          vim.log.levels.ERROR
        )
      end
    end
  end

  files.write_json_file(filename, data)
  if not opts.detach then
    current_session = name
  end
  if opts.notify then
    vim.notify(string.format("Saved session %s", name))
  end
end

local function open_clean_tab()
  -- Detect if we're already in a "clean" tab
  -- (one window, and one empty scratch buffer)
  if #vim.api.nvim_tabpage_list_wins(0) == 1 then
    if vim.api.nvim_buf_get_name(0) == "" then
      local lines = vim.api.nvim_buf_get_lines(0, -1, 2, false)
      if #lines == 1 and lines[1] == "" then
        return
      end
    end
  end
  vim.cmd("tabnew")
end

local function close_everything()
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(scratch, "buflisted", false)
  vim.api.nvim_buf_set_option(scratch, "bufhidden", "wipe")
  vim.api.nvim_win_set_buf(0, scratch)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].buflisted then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
  vim.cmd("silent! tabonly")
  vim.cmd("silent! only")
end

---@class resession.LoadOpts
---@field detach nil|boolean Detach from session after loading
---@field reset nil|boolean Close everthing before loading the session (default true)
---@field silence_errors nil|boolean Don't error when trying to load a missing session
---@field dir nil|string Name of directory to load from (overrides config.dir)

---@param name? string
---@param opts? resession.LoadOpts
M.load = function(name, opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    reset = true,
  })
  local config = require("resession.config")
  local files = require("resession.files")
  local layout = require("resession.layout")
  local util = require("resession.util")
  if not name then
    local sessions = M.list()
    if vim.tbl_isempty(sessions) then
      vim.notify("No saved sessions", vim.log.levels.WARN)
      return
    end
    vim.ui.select(sessions, {}, function(selected)
      if selected then
        M.load(selected, opts)
      end
    end)
    return
  end
  local filename = util.get_session_file(name, opts.dir)
  local data = files.load_json_file(filename)
  if not data then
    if not opts.silence_errors then
      error(string.format("Could not find session %s", name))
    end
    return
  end
  if opts.reset then
    close_everything()
  else
    open_clean_tab()
  end
  -- Set the options immediately
  util.restore_global_options(data.global.options)
  local scale = {
    vim.o.columns / data.global.width,
    (vim.o.lines - vim.o.cmdheight) / data.global.height,
  }
  vim.cmd(string.format("cd %s", data.global.cwd))
  for _, buf in ipairs(data.buffers) do
    local bufnr = vim.fn.bufadd(buf.name)
    if buf.loaded then
      vim.fn.bufload(bufnr)
    end
    util.restore_buf_options(bufnr, buf.options)
  end

  local curwin
  for i, tab in ipairs(data.tabs) do
    if i > 1 then
      vim.cmd("tabnew")
    end
    if tab.cwd then
      vim.cmd(string.format("tcd %s", tab.cwd))
    end
    local win = layout.set_winlayout(tab.wins, scale)
    if win then
      curwin = win
    end
  end
  -- This can be nil if we saved a session in a window with an unsupported buffer
  if curwin then
    vim.api.nvim_set_current_win(curwin)
  end

  for ext_name in pairs(config.extensions) do
    if data[ext_name] then
      local ext = util.get_extension(ext_name)
      if ext then
        local ok, err = pcall(ext.on_load, data[ext_name])
        if not ok then
          vim.notify(
            string.format("[resession] Extension %s load error: %s", ext_name, err),
            vim.log.levels.ERROR
          )
        end
      end
    end
  end

  -- We re-apply the options because sometimes the cmdheight gets messed up for some reason
  for k, v in pairs(data.global.options) do
    vim.o[k] = v
  end
  if opts.detach then
    current_session = nil
  else
    current_session = name
  end
end

-- Make sure all the API functions trigger the lazy load
for k, v in pairs(M) do
  if type(v) == "function" and k ~= "setup" then
    M[k] = function(...)
      do_setup()
      return v(...)
    end
  end
end

return M
