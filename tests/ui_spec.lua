local resession = require("resession")
local layout = require("resession.layout")
local util = require("resession.util")

resession.setup()

describe("UI test", function()
  it("loads multiple files with swap files in different tabs", function()
    vim.o.swapfile = true

    resession.load("sess")
    assert.equal(2, #vim.api.nvim_list_tabpages())
    assert.equal(2, #vim.api.nvim_list_wins())
  end)
end)
