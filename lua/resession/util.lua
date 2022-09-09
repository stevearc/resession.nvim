local config = require("resession.config")
local M = {}

---@param bufnr integer
---@return boolean
M.should_save_buffer = function(bufnr)
  if config.buffers.only_loaded and not vim.api.nvim_buf_is_loaded(bufnr) then
    return false
  end
  if not vim.tbl_contains(config.buffers.buftypes, vim.bo[bufnr].buftype) then
    return false
  end
  return true
end

return M
