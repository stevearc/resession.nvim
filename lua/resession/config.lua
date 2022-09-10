local M = {}

local default_config = {
  autosave = {
    enabled = false,
    -- How often to save (in seconds)
    interval = 60,
    -- Notify when autosaved
    notify = true,
  },
  -- Save and restore these options
  options = {
    "binary",
    "bufhidden",
    "buflisted",
    "cmdheight",
    "diff",
    "modifiable",
    "previewwindow",
    "readonly",
    "scrollbind",
    "winfixheight",
    "winfixwidth",
  },
  buffers = {
    -- Custom logic for determining if the buffer should be included
    filter = function(bufnr)
      if not vim.tbl_contains({ "", "acwrite", "help" }, vim.bo[bufnr].buftype) then
        return false
      end
      return true
    end,
  },
  windows = {},
  -- The name of the directory to store sessions in
  dir = "session",
  -- Configuration for extensions
  extensions = {
    quickfix = {},
  },
}

local autosave_timer
M.setup = function(config)
  local resession = require("resession")
  local util = require("resession.util")
  local newconf = vim.tbl_deep_extend("force", default_config, config)

  if newconf.options.save_all then
    newconf.options.include = options.all_options
  end

  for k, v in pairs(newconf) do
    M[k] = v
  end

  for ext_name, ext_config in pairs(M.extensions) do
    local ext = util.get_extension(ext_name)
    if ext and ext.config then
      ext.config(ext_config)
    end
  end

  if autosave_timer then
    autosave_timer:close()
    autosave_timer = nil
  end
  local autosave_group = vim.api.nvim_create_augroup("ResessionAutosave", { clear = true })
  if M.autosave.enabled then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = autosave_group,
      callback = function()
        if resession.get_current() then
          resession.save(nil, { notify = false })
        end
      end,
    })
    autosave_timer = vim.loop.new_timer()
    timer = vim.loop.new_timer()
    timer:start(
      M.autosave.interval * 1000,
      M.autosave.interval * 1000,
      vim.schedule_wrap(function()
        if resession.get_current() then
          resession.save(nil, { notify = M.autosave.notify })
        end
      end)
    )
  end
end

return M
