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
  local statuses = {}

  for git_root, _ in pairs(M._statuses) do
    local git_statuses = M._statuses[git_root].direct[path]
    if git_statuses ~= nil then
      for status, _ in pairs(git_statuses) do
        statuses[status] = true
      end
    end

    git_statuses = M._statuses[git_root].indirect[path]
    if git_statuses ~= nil then
      for status, _ in pairs(git_statuses) do
        statuses[status] = true
      end
    end
  end

  return statuses
end

return M
