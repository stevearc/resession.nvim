local util = require("resession.util")
local M = {}

local function list_compact(list)
  local last_slot = 1
  for _, v in ipairs(list) do
    if v then
      list[last_slot] = v
      last_slot = last_slot + 1
    end
  end
  while #list >= last_slot do
    table.remove(list)
  end
end

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
  }
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

M.set_winlayout = function(layout)
  local type = layout[1]
  if type == "leaf" then
    local win = layout[2]
    local bufnr = vim.fn.bufadd(win.bufname)
    vim.api.nvim_win_set_buf(0, bufnr)
    if win.cwd then
      vim.cmd(string.format("lcd %s", win.cwd))
    end
  else
    for i, v in ipairs(layout[2]) do
      if i > 1 then
        if type == "row" then
          vim.cmd("vsplit")
        else
          vim.cmd("split")
        end
      end
      M.set_winlayout(v)
    end
  end
end

return M
