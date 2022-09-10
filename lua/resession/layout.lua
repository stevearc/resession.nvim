local config = require("resession.config")
local util = require("resession.util")
local M = {}

---@param tabnr integer
---@param winid integer
---@return table|false
M.get_win_info = function(tabnr, winid)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  if not util.should_save_buffer(bufnr) then
    return false
  end
  local win = {
    bufname = vim.api.nvim_buf_get_name(bufnr),
    current = vim.api.nvim_get_current_win() == winid,
    cursor = vim.api.nvim_win_get_cursor(winid),
    width = vim.api.nvim_win_get_width(winid),
    height = vim.api.nvim_win_get_height(winid),
    options = {},
  }
  for _, opt in ipairs(config.windows.options) do
    win.options[opt] = vim.api.nvim_win_get_option(winid, opt)
  end
  local winnr = vim.api.nvim_win_get_number(winid)
  if vim.fn.haslocaldir(winnr, tabnr) == 1 then
    win.cwd = vim.fn.getcwd(winnr, tabnr)
  end
  return win
end

---@param tabnr integer
---@param layout table
M.add_win_info_to_layout = function(tabnr, layout)
  local type = layout[1]
  if type == "leaf" then
    layout[2] = M.get_win_info(tabnr, layout[2])
    if not layout[2] then
      return false
    end
  else
    local last_slot = 1
    local items = layout[2]
    for _, v in ipairs(items) do
      local ret = M.add_win_info_to_layout(tabnr, v)
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

local function set_winlayout(layout, visit_data)
  local type = layout[1]
  if type == "leaf" then
    local win = layout[2]
    win.winid = vim.api.nvim_get_current_win()
    if win.cwd then
      vim.cmd(string.format("lcd %s", win.cwd))
    end
    if win.current then
      visit_data.winid = vim.api.nvim_get_current_win()
    end
  else
    local winids = {}
    for i, v in ipairs(layout[2]) do
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
      set_winlayout(v, visit_data)
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
local function set_winlayout_data(layout, scale_factor)
  local type = layout[1]
  if type == "leaf" then
    local win = layout[2]
    local bufnr = vim.fn.bufadd(win.bufname)
    vim.api.nvim_win_set_buf(win.winid, bufnr)
    vim.api.nvim_win_set_cursor(win.winid, win.cursor)
    for k, v in pairs(win.options) do
      vim.api.nvim_win_set_option(win.winid, k, v)
    end
    local width_scale = vim.wo[win.winid].winfixwidth and 1 or scale_factor[1]
    vim.api.nvim_win_set_width(win.winid, scale(win.width, width_scale))
    local height_scale = vim.wo[win.winid].winfixheight and 1 or scale_factor[2]
    vim.api.nvim_win_set_height(win.winid, scale(win.height, height_scale))
  else
    for i, v in ipairs(layout[2]) do
      set_winlayout_data(v, scale_factor)
    end
  end
end

---@param layout table
---@param scale_factor number[] Scaling factor for [width, height]
---@return nil|integer The window that should have focus after session load
M.set_winlayout = function(layout, scale_factor)
  local ret = {}
  set_winlayout(layout, ret)
  set_winlayout_data(layout, scale_factor)
  return ret.winid
end

return M
