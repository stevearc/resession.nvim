local M = {}

local default_config = {
  buffers = {
    -- Only save buffers with these buftypes
    buftypes = { "", "acwrite", "help" },
    -- Save/load these buffer options
    options = { "buflisted" },
    -- Only save loaded buffers
    only_loaded = true,
  },
  windows = {
    -- Save/load these window options
    options = {
      "arabic",
      "breakindent",
      "breakindentopt",
      "cursorcolumn",
      "concealcursor",
      "conceallevel",
      "cursorbind",
      "cursorline",
      "cursorlineopt",
      "diff",
      "fillchars",
      "foldcolumn",
      "foldenable",
      "foldexpr",
      "foldignore",
      "foldlevel",
      "foldmarker",
      "foldmethod",
      "foldminlines",
      "foldnestmax",
      "foldtext",
      "linebreak",
      "list",
      "listchars",
      "number",
      "numberwidth",
      "previewwindow",
      "relativenumber",
      "rightleft",
      "rightleftcmd",
      "scroll",
      "scrollbind",
      "scrolloff",
      "showbreak",
      "sidescrolloff",
      "signcolumn",
      "spell",
      "statusline",
      "virtualedit",
      "winblend",
      "winhighlight",
      "winfixheight",
      "winfixwidth",
      "wrap",
    },
  },
  -- The name of the directory to store sessions in
  dir = "session",
  -- List of extensions
  extensions = {},
}

M.setup = function(config)
  local newconf = vim.tbl_deep_extend("force", default_config, config)
  for k, v in pairs(newconf) do
    M[k] = v
  end
end

---@return string
M.get_session_dir = function()
  local files = require("resession.files")
  return files.get_stdpath_filename("data", M.dir)
end

---@param name string The name of the session
---@return string
M.get_session_file = function(name)
  local files = require("resession.files")
  local filename = string.format("%s.json", name:gsub(files.sep, "_"))
  return files.join(M.get_session_dir(), filename)
end

return M
