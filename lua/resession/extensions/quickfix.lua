local M = {}

M.on_save = function()
  return vim.tbl_map(function(item)
    return {
      filename = item.bufnr and vim.api.nvim_buf_get_name(item.bufnr),
      module = item.module,
      lnum = item.lnum,
      end_lnum = item.end_lnum,
      col = item.col,
      end_col = item.end_col,
      vcol = item.vcol,
      nr = item.nr,
      pattern = item.pattern,
      text = item.text,
      type = item.type,
      valid = item.valid,
    }
  end, vim.fn.getqflist())
end

M.on_load = function(data)
  vim.fn.setqflist(data)
end

M.is_win_supported = function(winid, bufnr)
  return vim.bo[bufnr].buftype == "quickfix"
end

M.save_win = function(winid)
  return {}
end

M.load_win = function(winid, config)
  vim.api.nvim_set_current_win(winid)
  vim.cmd("copen")
  vim.api.nvim_win_close(winid, true)
  return vim.api.nvim_get_current_win()
end

return M
