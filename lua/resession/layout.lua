local config = require("resession.config")
local util = require("resession.util")
local M = {}

---Only exposed for testing purposes
---@private
---@param tabnr integer
---@param winid integer
---@param current_win integer
---@return table|false
M.get_win_info = function(tabnr, winid, current_win)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local win = {}
  local supported_by_ext = false
  for ext_name in pairs(config.extensions) do
    local ext = util.get_extension(ext_name)
    if ext and ext.is_win_supported and ext.is_win_supported(winid, bufnr) then
      local ok, extension_data = pcall(ext.save_win, winid)
      if ok then
        win.extension_data = extension_data
        win.extension = ext_name
        supported_by_ext = true
      else
        vim.notify(
          string.format('[resession] Extension "%s" save_win error: %s', ext_name, extension_data),
          vim.log.levels.ERROR
        )
      end
      break
    end
  end
  if not supported_by_ext and not config.buf_filter(bufnr) then
    return false
  end
  win = vim.tbl_extend("error", win, {
    bufname = vim.api.nvim_buf_get_name(bufnr),
    current = winid == current_win,
    cursor = vim.api.nvim_win_get_cursor(winid),
    width = vim.api.nvim_win_get_width(winid),
    height = vim.api.nvim_win_get_height(winid),
    options = util.save_win_options(winid),
  })
  local winnr = vim.api.nvim_win_get_number(winid)
  if vim.fn.haslocaldir(winnr, tabnr) == 1 then
    win.cwd = vim.fn.getcwd(winnr, tabnr)
  end
  return win
end

---@param tabnr integer
---@param layout table
---@param current_win integer
M.add_win_info_to_layout = function(tabnr, layout, current_win)
  local type = layout[1]
  if type == "leaf" then
    layout[2] = M.get_win_info(tabnr, layout[2], current_win)
    if not layout[2] then
      return false
    end
  else
    local last_slot = 1
    local items = layout[2]
    for _, v in ipairs(items) do
      local ret = M.add_win_info_to_layout(tabnr, v, current_win)
      if ret then
        items[last_slot] = ret
        last_slot = last_slot + 1
      end
    end
    while #items >= last_slot do
      table.remove(items)
    end
    if #items == 1 then
      return items[1]
    elseif #items == 0 then
      return false
    end
  end
  return layout
end

local function set_winlayout(layout)
  local type = layout[1]
  if type == "leaf" then
    local win = layout[2]
    win.winid = vim.api.nvim_get_current_win()
    if win.cwd then
      vim.cmd(string.format("lcd %s", win.cwd))
    end
  else
    local winids = {}
    for i in ipairs(layout[2]) do
      if i > 1 then
        if type == "row" then
          vim.cmd("vsplit")
        else
          vim.cmd("split")
        end
      end
      table.insert(winids, vim.api.nvim_get_current_win())
    end
    for i, v in ipairs(layout[2]) do
      vim.api.nvim_set_current_win(winids[i])
      set_winlayout(v)
    end
  end
end

---@param base integer
---@param factor number
---@return integer
local function scale(base, factor)
  return math.floor(base * factor + 0.5)
end

---@param layout table
---@param scale_factor number[] Scaling factor for [width, height]
local function set_winlayout_data(layout, scale_factor, visit_data)
  local type = layout[1]
  if type == "leaf" then
    local win = layout[2]
    vim.api.nvim_set_current_win(win.winid)
    if win.extension then
      local ext = util.get_extension(win.extension)
      if ext then
        -- Re-enable autocmds so if the extensions rely on BufReadCmd it works
        vim.o.eventignore = ""
        local ok, new_winid = pcall(ext.load_win, win.winid, win.extension_data)
        vim.o.eventignore = "all"
        if ok then
          win.winid = new_winid or win.winid
        else
          vim.notify(
            string.format('[resession] Extension "%s" load_win error: %s', win.extension, new_winid),
            vim.log.levels.ERROR
          )
        end
      end
    else
      local bufnr = vim.fn.bufadd(win.bufname)
      vim.api.nvim_win_set_buf(win.winid, bufnr)
      -- After setting the buffer into the window, manually set the filetype to trigger syntax highlighting
      vim.o.eventignore = ""
      vim.api.nvim_buf_set_option(bufnr, "filetype", vim.bo[bufnr].filetype)
      vim.o.eventignore = "all"
    end
    pcall(vim.api.nvim_win_set_cursor, win.winid, win.cursor)
    util.restore_win_options(win.winid, win.options)
    local width_scale = vim.wo.winfixwidth and 1 or scale_factor[1]
    vim.api.nvim_win_set_width(win.winid, scale(win.width, width_scale))
    local height_scale = vim.wo.winfixheight and 1 or scale_factor[2]
    vim.api.nvim_win_set_height(win.winid, scale(win.height, height_scale))
    if win.current then
      visit_data.winid = win.winid
    end
  else
    for _, v in ipairs(layout[2]) do
      set_winlayout_data(v, scale_factor, visit_data)
    end
  end
end

---@param layout table
---@param scale_factor number[] Scaling factor for [width, height]
---@return integer? The window that should have focus after session load
M.set_winlayout = function(layout, scale_factor)
  if not layout then
    return
  end
  set_winlayout(layout)
  local ret = {}
  set_winlayout_data(layout, scale_factor, ret)
  return ret.winid
end

return M
