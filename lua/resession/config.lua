local M = {}

local default_config = {
  -- Set this to save a session automatically when quitting vim
  -- Can be a string or a function that returns a string
  autosave_name = false,
  buffers = {
    buftypes = { "", "acwrite", "help" },
    options = { "buflisted" },
    only_loaded = true,
  },
}

M.setup = function(config)
  local resession = require("resession")
  local newconf = vim.tbl_deep_extend("force", default_config, config)
  for k, v in pairs(newconf) do
    M[k] = v
  end

  local autosave_group = vim.api.nvim_create_augroup("ResessionAutosave", { clear = true })
  if newconf.autosave_name then
    vim.api.nvim_create_autocmd("VimLeave", {
      group = autosave_group,
      callback = function()
        local name = newconf.autosave_name
        if type(name) == "function" then
          name = name()
        end
        resession.save(name)
      end,
    })
  end
end

return M
