local M = {}

local default_config = {
  -- Options for automatically saving sessions on a timer
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
    "filetype",
    "modifiable",
    "previewwindow",
    "readonly",
    "scrollbind",
    "winfixheight",
    "winfixwidth",
  },
  -- Custom logic for determining if the buffer should be included
  buf_filter = require("resession").default_buf_filter,
  -- Custom logic for determining if a buffer should be included in a tab-scoped session
  tab_buf_filter = function(tabpage, bufnr)
    return true
  end,
  -- The name of the directory to store sessions in
  dir = "session",
  -- Show more detail about the sessions when selecting one to load.
  -- Disable if it causes lag.
  load_detail = true,
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

  for k, v in pairs(newconf) do
    M[k] = v
  end

  for ext_name, ext_config in pairs(M.extensions) do
    if ext_config then
      local ext = util.get_extension(ext_name)
      if ext and ext.config then
        ext.config(ext_config)
      end
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
        resession.save_all({ notify = false })
      end,
    })
    autosave_timer = vim.loop.new_timer()
    autosave_timer:start(
      M.autosave.interval * 1000,
      M.autosave.interval * 1000,
      vim.schedule_wrap(function()
        resession.save_all({ notify = M.autosave.notify })
      end)
    )
  end
end

return M
