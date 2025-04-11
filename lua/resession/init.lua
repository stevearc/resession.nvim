local M = {}

-- TODO remove after https://github.com/folke/neodev.nvim/pull/163 lands
---@diagnostic disable: inject-field

local uv = vim.uv or vim.loop

local has_setup = false
local pending_config
local current_session
local tab_sessions = {}
local session_configs = {}
local hooks = setmetatable({
  pre_load = {},
  post_load = {},
  pre_save = {},
  post_save = {},
}, {
  __index = function(t, key)
    error(string.format('Unrecognized hook "%s"', key))
  end,
})
local hook_to_event = {
  pre_load = "ResessionLoadPre",
  post_load = "ResessionLoadPost",
  pre_save = "ResessionSavePre",
  post_save = "ResessionSavePost",
}

local function do_setup()
  if pending_config then
    local conf = pending_config
    pending_config = nil
    require("resession.config").setup(conf)

    if not has_setup then
      for hook, _ in pairs(hooks) do
        M.add_hook(hook, function()
          require("resession.util").event(hook_to_event[hook])
        end)
      end
      has_setup = true
    end
  end
end

local function dispatch(name, ...)
  for _, cb in ipairs(hooks[name]) do
    cb(...)
  end
end

---Initialize resession with configuration options
---@param config table
M.setup = function(config)
  pending_config = config or {}
  if has_setup then
    do_setup()
  end
end

---Load an extension some time after calling setup()
---@param name string Name of the extension
---@param opts table Configuration options for extension
M.load_extension = function(name, opts)
  if has_setup then
    local config = require("resession.config")
    local util = require("resession.util")
    config.extensions[name] = opts
    util.get_extension(name)
  elseif pending_config then
    pending_config.extensions = pending_config.extensions or {}
    pending_config.extensions[name] = opts
  else
    error("Cannot call resession.load_extension() before resession.setup()")
  end
end

---Get the name of the current session
---@return string?
M.get_current = function()
  local tabpage = vim.api.nvim_get_current_tabpage()
  return tab_sessions[tabpage] or current_session
end

---Get information about the current session
---@return nil|resession.SessionInfo
M.get_current_session_info = function()
  local session = M.get_current()
  if not session then
    return nil
  end
  local save_dir = session_configs[session].dir
  return {
    name = session,
    dir = save_dir,
    tab_scoped = tab_sessions[vim.api.nvim_get_current_tabpage()] ~= nil,
  }
end

---Detach from the current session
M.detach = function()
  current_session = nil
  local tabpage = vim.api.nvim_get_current_tabpage()
  tab_sessions[tabpage] = nil
end

---List all available saved sessions
---@param opts? resession.ListOpts
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
  ---@diagnostic disable-next-line: param-type-mismatch
  local fd = assert(uv.fs_opendir(session_dir, nil, 256))
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast fd luv_dir_t
  local entries = uv.fs_readdir(fd)
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
    entries = uv.fs_readdir(fd)
  end
  uv.fs_closedir(fd)
  -- Order options
  if config.load_order == "filename" then
    -- Sort by filename
    table.sort(ret)
  elseif config.load_order == "modification_time" then
    -- Sort by modification_time
    local default = { mtime = { sec = 0 } }
    table.sort(ret, function(a, b)
      local file_a = uv.fs_stat(session_dir .. "/" .. a .. ".json") or default
      local file_b = uv.fs_stat(session_dir .. "/" .. b .. ".json") or default
      return file_a.mtime.sec > file_b.mtime.sec
    end)
  elseif config.load_order == "creation_time" then
    -- Sort by creation_time in descending order (most recent first)
    local default = { birthtime = { sec = 0 } }
    table.sort(ret, function(a, b)
      local file_a = uv.fs_stat(session_dir .. "/" .. a .. ".json") or default
      local file_b = uv.fs_stat(session_dir .. "/" .. b .. ".json") or default
      return file_a.birthtime.sec > file_b.birthtime.sec
    end)
  end
  return ret
end

local function remove_tabpage_session(name)
  for k, v in pairs(tab_sessions) do
    if v == name then
      tab_sessions[k] = nil
      break
    end
  end
end

---Delete a saved session
---@param name? string If not provided, prompt for session to delete
---@param opts? resession.DeleteOpts
M.delete = function(name, opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    notify = true,
  })
  local files = require("resession.files")
  local util = require("resession.util")
  if not name then
    local sessions = M.list({ dir = opts.dir })
    if vim.tbl_isempty(sessions) then
      vim.notify("No saved sessions", vim.log.levels.WARN)
      return
    end
    vim.ui.select(
      sessions,
      { kind = "resession_delete", prompt = "Delete session" },
      function(selected)
        if selected then
          M.delete(selected, { dir = opts.dir })
        end
      end
    )
    return
  end
  local filename = util.get_session_file(name, opts.dir)
  if files.delete_file(filename) then
    if opts.notify then
      vim.notify(string.format('Deleted session "%s"', name))
    end
  else
    error(string.format('No session "%s"', filename))
  end
  if current_session == name then
    current_session = nil
  end
  remove_tabpage_session(name)
end

---@param name string
---@param opts resession.SaveOpts
---@param target_tabpage? integer
local function save(name, opts, target_tabpage)
  local config = require("resession.config")
  local files = require("resession.files")
  local layout = require("resession.layout")
  local util = require("resession.util")
  local filename = util.get_session_file(name, opts.dir)
  dispatch("pre_save", name, opts, target_tabpage)
  local eventignore = vim.o.eventignore
  vim.o.eventignore = "all"
  local data = {
    buffers = {},
    tabs = {},
    tab_scoped = target_tabpage ~= nil,
    global = {
      cwd = vim.fn.getcwd(-1, -1),
      height = vim.o.lines - vim.o.cmdheight,
      width = vim.o.columns,
      -- Don't save global options for tab-scoped session
      options = target_tabpage and {} or util.save_global_options(),
    },
  }
  local current_win = vim.api.nvim_get_current_win()
  local tabpage_bufs = {}
  if target_tabpage then
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(target_tabpage)) do
      local bufnr = vim.api.nvim_win_get_buf(winid)
      tabpage_bufs[bufnr] = true
    end
  end
  local is_unexpected_exit = vim.v.exiting ~= vim.NIL and vim.v.exiting > 0
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if util.include_buf(target_tabpage, bufnr, tabpage_bufs) then
      local buf = {
        name = vim.api.nvim_buf_get_name(bufnr),
        -- if neovim quit unexpectedly, all buffers will appear as unloaded.
        -- As a hack, we just assume that all of them were loaded, to avoid all of them being
        -- *unloaded* when the session is restored.
        loaded = is_unexpected_exit or vim.api.nvim_buf_is_loaded(bufnr),
        options = util.save_buf_options(bufnr),
        last_pos = vim.api.nvim_buf_get_mark(bufnr, '"'),
      }
      table.insert(data.buffers, buf)
    end
  end
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  local tabpages = target_tabpage and { target_tabpage } or vim.api.nvim_list_tabpages()
  for _, tabpage in ipairs(tabpages) do
    vim.api.nvim_set_current_tabpage(tabpage)
    local tab = {}
    local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
    if target_tabpage or vim.fn.haslocaldir(-1, tabnr) == 1 then
      tab.cwd = vim.fn.getcwd(-1, tabnr)
    end
    tab.options = util.save_tab_options(tabpage)
    table.insert(data.tabs, tab)
    local winlayout = vim.fn.winlayout(tabnr)
    tab.wins = layout.add_win_info_to_layout(tabnr, winlayout, current_win)
  end
  vim.api.nvim_set_current_tabpage(current_tabpage)

  for ext_name, ext_config in pairs(config.extensions) do
    local ext = util.get_extension(ext_name)
    if ext and ext.on_save and (ext_config.enable_in_tab or not target_tabpage) then
      local ok, ext_data = pcall(ext.on_save, {
        tabpage = target_tabpage,
      })
      if ok then
        data[ext_name] = ext_data
      else
        vim.notify(
          string.format('[resession] Extension "%s" save error: %s', ext_name, ext_data),
          vim.log.levels.ERROR
        )
      end
    end
  end

  files.write_json_file(filename, data)
  if opts.notify then
    vim.notify(string.format('Saved session "%s"', name))
  end
  if opts.attach then
    session_configs[name] = {
      dir = opts.dir or config.dir,
    }
  end
  vim.o.eventignore = eventignore
  dispatch("post_save", name, opts, target_tabpage)
end

---Save a session to disk
---@param name? string
---@param opts? resession.SaveOpts
M.save = function(name, opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    notify = true,
    attach = true,
  })
  if not name then
    -- If no name, default to the current session
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
  save(name, opts)
  tab_sessions = {}
  if opts.attach then
    current_session = name
  else
    current_session = nil
  end
end

---Save a tab-scoped session
---@param name? string If not provided, will prompt user for session name
---@param opts? resession.SaveOpts
M.save_tab = function(name, opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    notify = true,
    attach = true,
  })
  local cur_tabpage = vim.api.nvim_get_current_tabpage()
  if not name then
    name = tab_sessions[cur_tabpage]
  end
  if not name then
    vim.ui.input({ prompt = "Session name" }, function(selected)
      if selected then
        M.save_tab(selected, opts)
      end
    end)
    return
  end
  save(name, opts, cur_tabpage)
  current_session = nil
  remove_tabpage_session(name)
  if opts.attach then
    tab_sessions[cur_tabpage] = name
  else
    tab_sessions[cur_tabpage] = nil
  end
end

---Save all current sessions to disk
---@param opts? resession.SaveAllOpts
M.save_all = function(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    notify = true,
  })
  if current_session then
    save(current_session, vim.tbl_extend("keep", opts, session_configs[current_session]))
  else
    -- First prune tab-scoped sessions for closed tabs
    local invalid_tabpages = vim.tbl_filter(function(tabpage)
      return not vim.api.nvim_tabpage_is_valid(tabpage)
    end, vim.tbl_keys(tab_sessions))
    for _, tabpage in ipairs(invalid_tabpages) do
      tab_sessions[tabpage] = nil
    end
    -- Save all tab-scoped sessions
    for tabpage, name in pairs(tab_sessions) do
      save(name, vim.tbl_extend("keep", opts, session_configs[name]), tabpage)
    end
  end
end

local function open_clean_tab()
  -- Detect if we're already in a "clean" tab
  -- (one window, and one empty scratch buffer)
  if #vim.api.nvim_tabpage_list_wins(0) == 1 then
    if vim.api.nvim_buf_get_name(0) == "" then
      local lines = vim.api.nvim_buf_get_lines(0, -1, 2, false)
      if vim.tbl_isempty(lines) then
        vim.bo.buflisted = false
        vim.bo.bufhidden = "wipe"
        return
      end
    end
  end
  vim.cmd.tabnew()
end

local function close_everything()
  local is_floating_win = vim.api.nvim_win_get_config(0).relative ~= ""
  if is_floating_win then
    -- Go to the first window, which will not be floating
    vim.cmd.wincmd({ args = { "w" }, count = 1 })
  end

  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].bufhidden = "wipe"
  vim.api.nvim_win_set_buf(0, scratch)
  vim.bo[scratch].buftype = ""
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].buflisted then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
  vim.cmd.tabonly({ mods = { emsg_silent = true } })
  vim.cmd.only({ mods = { emsg_silent = true } })
end

local _is_loading = false
---Load a session
---@param name? string
---@param opts? resession.LoadOpts
---    attach? boolean Stay attached to session after loading (default true)
---    reset? boolean|"auto" Close everything before loading the session (default "auto")
---    silence_errors? boolean Don't error when trying to load a missing session
---    dir? string Name of directory to load from (overrides config.dir)
---@note
--- The default value of `reset = "auto"` will reset when loading a normal session, but _not_ when
--- loading a tab-scoped session.
M.load = function(name, opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    reset = "auto",
    attach = true,
  })
  local config = require("resession.config")
  local files = require("resession.files")
  local layout = require("resession.layout")
  local util = require("resession.util")
  if not name then
    local sessions = M.list({ dir = opts.dir })
    if vim.tbl_isempty(sessions) then
      vim.notify("No saved sessions", vim.log.levels.WARN)
      return
    end
    local select_opts = { kind = "resession_load", prompt = "Load session" }
    if config.load_detail then
      local session_data = {}
      for _, session_name in ipairs(sessions) do
        local filename = util.get_session_file(session_name, opts.dir)
        local data = files.load_json_file(filename)
        session_data[session_name] = data
      end
      select_opts.format_item = function(session_name)
        local data = session_data[session_name]
        local formatted = session_name
        if data then
          if data.tab_scoped then
            local tab_cwd = data.tabs[1].cwd
            formatted = formatted .. string.format(" (tab) [%s]", util.shorten_path(tab_cwd))
          else
            formatted = formatted .. string.format(" [%s]", util.shorten_path(data.global.cwd))
          end
        end
        return formatted
      end
    end
    vim.ui.select(sessions, select_opts, function(selected)
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
      error(string.format('Could not find session "%s"', name))
    end
    return
  end
  dispatch("pre_load", name, opts)
  _is_loading = true
  if opts.reset == "auto" then
    opts.reset = not data.tab_scoped
  end
  if opts.reset then
    close_everything()
  else
    open_clean_tab()
  end
  -- Don't trigger autocmds during session load
  local eventignore = vim.o.eventignore
  vim.o.eventignore = "all"
  -- Ignore all messages (including swapfile messages) during session load
  local shortmess = vim.o.shortmess
  vim.o.shortmess = "aAF"
  if not data.tab_scoped then
    -- Set the options immediately
    util.restore_global_options(data.global.options)
  end

  for ext_name in pairs(config.extensions) do
    if data[ext_name] then
      local ext = util.get_extension(ext_name)
      if ext and ext.on_pre_load then
        local ok, err = pcall(ext.on_pre_load, data[ext_name])
        if not ok then
          vim.notify(
            string.format("[resession] Extension %s on_pre_load error: %s", ext_name, err),
            vim.log.levels.ERROR
          )
        end
      end
    end
  end

  local scale = {
    vim.o.columns / data.global.width,
    (vim.o.lines - vim.o.cmdheight) / data.global.height,
  }

  local last_bufnr
  for _, buf in ipairs(data.buffers) do
    local bufnr = vim.fn.bufadd(buf.name)
    last_bufnr = bufnr

    if buf.loaded then
      vim.fn.bufload(bufnr)
      vim.b[bufnr]._resession_need_edit = true
      vim.b[bufnr].resession_restore_last_pos = true
      vim.api.nvim_create_autocmd("BufEnter", {
        desc = "Resession: complete setup of restored buffer",
        callback = function(args)
          if vim.b[args.buf].resession_restore_last_pos then
            pcall(vim.api.nvim_win_set_cursor, 0, buf.last_pos)
            vim.b[args.buf].resession_restore_last_pos = nil
          end
          -- This triggers the autocmds that set filetype, syntax highlighting, and checks the swapfile
          if vim.b._resession_need_edit then
            vim.b._resession_need_edit = nil
            vim.cmd.edit({ mods = { emsg_silent = true } })
          end
        end,
        buffer = bufnr,
        once = true,
        nested = true,
      })
    end
    util.restore_buf_options(bufnr, buf.options)
  end

  -- Ensure the cwd is set correctly for each loaded buffer
  if not data.tab_scoped then
    vim.api.nvim_set_current_dir(data.global.cwd)
  end

  local curwin
  for i, tab in ipairs(data.tabs) do
    if i > 1 then
      vim.cmd.tabnew()
      -- Tabnew creates a new empty buffer. Dispose of it when hidden.
      vim.bo.buflisted = false
      vim.bo.bufhidden = "wipe"
    end
    if tab.cwd then
      vim.cmd.tcd({ args = { tab.cwd } })
    end
    local win = layout.set_winlayout(tab.wins, scale)
    if win then
      curwin = win
    end
    if tab.options then
      util.restore_tab_options(tab.options)
    end
  end

  -- curwin can be nil if we saved a session in a window with an unsupported buffer, in which case we will switch to
  -- the last restored buffer.
  if curwin then
    vim.api.nvim_set_current_win(curwin)
  elseif last_bufnr then
    vim.cmd("buffer " .. last_bufnr)
  end

  for ext_name in pairs(config.extensions) do
    if data[ext_name] then
      local ext = util.get_extension(ext_name)
      if ext and ext.on_post_load then
        local ok, err = pcall(ext.on_post_load, data[ext_name])
        if not ok then
          vim.notify(
            string.format('[resession] Extension "%s" on_post_load error: %s', ext_name, err),
            vim.log.levels.ERROR
          )
        end
      end
    end
  end

  current_session = nil
  if opts.reset then
    tab_sessions = {}
  end
  remove_tabpage_session(name)
  if opts.attach then
    if data.tab_scoped then
      tab_sessions[vim.api.nvim_get_current_tabpage()] = name
    else
      current_session = name
    end
    session_configs[name] = {
      dir = opts.dir or config.dir,
    }
  end
  vim.o.eventignore = eventignore
  vim.o.shortmess = shortmess
  _is_loading = false
  dispatch("post_load", name, opts)

  -- In case the current buffer has a swapfile, make sure we trigger all the necessary autocmds
  vim.b._resession_need_edit = nil
  vim.cmd.edit({ mods = { emsg_silent = true } })
end

---Add a callback that runs at a specific time
---@param name "pre_save"|"post_save"|"pre_load"|"post_load"
---@param callback fun(...: any)
M.add_hook = function(name, callback)
  table.insert(hooks[name], callback)
end

---Remove a hook callback
---@param name "pre_save"|"post_save"|"pre_load"|"post_load"
---@param callback fun(...: any)
M.remove_hook = function(name, callback)
  local cbs = hooks[name]
  for i, cb in ipairs(cbs) do
    if cb == callback then
      table.remove(cbs, i)
      break
    end
  end
end

---The default config.buf_filter (takes all buflisted files with "", "acwrite", or "help" buftype)
---@param bufnr integer
---@return boolean
M.default_buf_filter = function(bufnr)
  local buftype = vim.bo[bufnr].buftype
  if buftype == "help" then
    return true
  end
  if buftype ~= "" and buftype ~= "acwrite" then
    return false
  end
  if vim.api.nvim_buf_get_name(bufnr) == "" then
    return false
  end
  return vim.bo[bufnr].buflisted
end

---Returns true if a session is currently being loaded
---@return boolean
M.is_loading = function()
  return _is_loading
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
