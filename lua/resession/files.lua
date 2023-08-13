local M = {}

local uv = vim.uv or vim.loop

---@type boolean
M.is_windows = uv.os_uname().version:match("Windows")

---@type boolean
M.is_mac = uv.os_uname().sysname == "Darwin"

---@type string
M.sep = M.is_windows and "\\" or "/"

---@param ... string
---@return boolean
M.any_exists = function(...)
  for _, name in ipairs({ ... }) do
    if M.exists(name) then
      return true
    end
  end
  return false
end

---@param filepath string
---@return boolean
M.exists = function(filepath)
  local stat = uv.fs_stat(filepath)
  return stat ~= nil and stat.type ~= nil
end

---@return string
M.join = function(...)
  return table.concat({ ... }, M.sep)
end

---@param dir string
---@param path string
---@return boolean
M.is_subpath = function(dir, path)
  return string.sub(path, 0, string.len(dir)) == dir
end

M.get_stdpath_filename = function(stdpath, ...)
  local ok, dir = pcall(vim.fn.stdpath, stdpath)
  if not ok then
    if stdpath == "log" then
      return M.get_stdpath_filename("cache", ...)
    elseif stdpath == "state" then
      return M.get_stdpath_filename("data", ...)
    else
      error(dir)
    end
  end
  return M.join(dir, ...)
end

---@param filepath string
---@return string?
M.read_file = function(filepath)
  if not M.exists(filepath) then
    return nil
  end
  local fd = assert(uv.fs_open(filepath, "r", 420)) -- 0644
  local stat = assert(uv.fs_fstat(fd))
  local content = uv.fs_read(fd, stat.size)
  uv.fs_close(fd)
  return content
end

---@param filepath string
---@return any?
M.load_json_file = function(filepath)
  local content = M.read_file(filepath)
  if content then
    return vim.json.decode(content, { luanil = { object = true } })
  end
end

---@param dirname string
---@param perms? number
M.mkdir = function(dirname, perms)
  if not perms then
    perms = 493 -- 0755
  end
  if not M.exists(dirname) then
    local parent = vim.fn.fnamemodify(dirname, ":h")
    if not M.exists(parent) then
      M.mkdir(parent)
    end
    uv.fs_mkdir(dirname, perms)
  end
end

---@param filename string
---@param contents string
M.write_file = function(filename, contents)
  M.mkdir(vim.fn.fnamemodify(filename, ":h"))
  local fd = assert(uv.fs_open(filename, "w", 420)) -- 0644
  uv.fs_write(fd, contents)
  uv.fs_close(fd)
end

---@param filename string
M.delete_file = function(filename)
  if M.exists(filename) then
    uv.fs_unlink(filename)
    return true
  end
end

---@param filename string
---@param obj any
M.write_json_file = function(filename, obj)
  ---@diagnostic disable-next-line param-type-mismatch
  M.write_file(filename, vim.json.encode(obj))
end

return M
