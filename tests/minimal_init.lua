vim.cmd([[set runtimepath+=.]])
vim.cmd([[runtime! plugin/plenary.vim]])

vim.o.swapfile = false
vim.bo.swapfile = false

local resession = require("resession")
local util = require("resession.util")

resession.setup()

util.get_session_dir = function(name, dirname)
  return "./tests/fixtures/sessions"
end

vim.o.directory = "tests/fixtures/files"

vim.g.mapleader = " "
vim.keymap.set('n', '<leader>sss', resession.save)
vim.keymap.set('n', '<leader>ssl', resession.load)
vim.keymap.set('n', '<leader>ssd', resession.delete)
