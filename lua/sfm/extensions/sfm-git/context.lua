local M = {
  git_statuses = {
    direct = {},
    indirect = {},
  },
}

--- Get git status from the given path
---@param path string
---@return table[string]
function M.get_statuses(path)
  local status = M.git_statuses.direct[path]
  if status ~= nil then
    return status
  end

  return M.git_statuses.indirect[path] or {}
end

return M
