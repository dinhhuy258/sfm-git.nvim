local M = {
  _statuses = {},
}

--- set git status fro the given roto
---@param git_root string
---@param statuses table
function M.set_statuses(git_root, statuses)
  M._statuses[git_root] = statuses
end

--- get git status from the given path
---@param path string
---@return table[string]
function M.get_statuses(path)
  for git_root, _ in pairs(M._statuses) do
    local status = M._statuses[git_root].direct[path]
    if status ~= nil then
      return status
    end

    status = M._statuses[git_root].indirect[path]
    if status ~= nil then
      return status
    end
  end

  return {}
end

return M
