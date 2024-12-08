local M = {}

M.on_save = function()
  return {
    background = vim.o.background,
    colorscheme = vim.g.colors_name,
  }
end

M.on_post_load = function(data)
  vim.o.background = data.background
  vim.cmd.colorscheme({ args = { data.colorscheme } })
end

return M
