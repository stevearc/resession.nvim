local layout = require("resession.layout")
local util = require("resession.util")

describe("add_win_info_to_layout", function()
  local old_get_win_info = layout.get_win_info
  after_each(function()
    layout.get_win_info = old_get_win_info
  end)
  it("Returns nested structure", function()
    layout.get_win_info = function(tabnr, winid)
      return { win = winid }
    end
    local ret = layout.add_win_info_to_layout(0, {
      "col",
      {
        { "leaf", 1 },
        { "leaf", 2 },
      },
    })
    assert.are.same({
      "col",
      {
        { "leaf", { win = 1 } },
        { "leaf", { win = 2 } },
      },
    }, ret)
  end)

  it("Compacts structure when buffers are skipped", function()
    local wins = {
      1,
      false,
      3,
    }
    layout.get_win_info = function(tabnr, winid)
      return wins[winid]
    end
    local ret = layout.add_win_info_to_layout(0, {
      "col",
      {
        { "leaf", 1 },
        { "leaf", 2 },
        { "leaf", 3 },
      },
    })
    assert.are.same({
      "col",
      {
        { "leaf", 1 },
        { "leaf", 3 },
      },
    }, ret)
  end)
end)
