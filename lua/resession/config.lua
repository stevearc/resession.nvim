local M = {}

local default_config = {
  buffers = {
    buftypes = { "", "acwrite", "help" },
    options = { "buflisted" },
    only_loaded = true,
  },
}

M.setup = function(config)
  local newconf = vim.tbl_deep_extend("force", default_config, config)
  for k, v in pairs(newconf) do
    M[k] = v
  end
end

return M
