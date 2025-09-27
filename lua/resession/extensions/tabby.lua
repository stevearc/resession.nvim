-- resession.nvim extension to persist Tabby (nanozuki/tabby.nvim) tab names
local M = {}

-- Fallback if vim.g.TabbyTabNames is missing/empty
local function compute_tabby_json_fallback()
  local ok_api, api = pcall(require, "tabby.module.api")
  local ok_feat, tabname = pcall(require, "tabby.feature.tab_name")
  if not (ok_api and ok_feat) then
    return nil
  end

  local names = {}
  for _, tabid in ipairs(api.get_tabs()) do
    local num = api.get_tab_number(tabid)
    local raw = tabname.get_raw(tabid)
    if raw and raw ~= "" then
      names[tostring(num)] = raw
    end
  end

  if next(names) == nil then
    return nil
  end

  local ok_json, json = pcall(vim.json.encode, names)
  return ok_json and json or nil
end

--- Capture data for the session
---@param _ table
---@return table
M.on_save = function(_)
  local json = vim.g.TabbyTabNames
  if type(json) ~= "string" or json == "" then
    json = compute_tabby_json_fallback()
  end
  return { tabby_tab_names_json = json }
end

--- Restore data after session load
---@param data table|nil
M.on_post_load = function(data)
  if type(data) ~= "table" then return end
  local json = data.tabby_tab_names_json
  if type(json) ~= "string" or json == "" then return end
  vim.g.TabbyTabNames = json
  -- LSP false positive: vim.cmd is a callable table, but LuaLS mis-types it as plain table.
  ---@diagnostic disable-next-line:param-type-mismatch
  pcall(vim.cmd, "silent! redrawtabline")
end

return M
