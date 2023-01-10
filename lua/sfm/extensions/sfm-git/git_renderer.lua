local context = require "sfm.extensions.sfm-git.context"

local M = {}

local icons = {
  unstaged = "",
  staged = "S",
  unmerged = "",
  renamed = "",
  untracked = "U",
  deleted = "",
  ignored = "◌",
}

local git_status = {
  staged = { text = icons.staged, highlight = "SFMGitStaged" },
  unstaged = { text = icons.unstaged, highlight = "SFMGitDirty" },
  renamed = { text = icons.renamed, highlight = "SFMGitRenamed" },
  deleted = { text = icons.deleted, highlight = "SFMGitDeleted" },
  unmerged = { text = icons.unmerged, highlight = "SFMGitMerge" },
  untracked = { text = icons.untracked, highlight = "SFMGitNew" },
  ignored = { text = icons.ignored, highlight = "SFMGitIgnored" },
}

local git_status_to_icons = {
  ["M "] = { git_status.staged },
  [" M"] = { git_status.unstaged },
  ["C "] = { git_status.staged },
  [" C"] = { git_status.unstaged },
  ["CM"] = { git_status.unstaged },
  [" T"] = { git_status.unstaged },
  ["T "] = { git_status.staged },
  ["MM"] = { git_status.staged, git_status.unstaged },
  ["MD"] = { git_status.staged },
  ["A "] = { git_status.staged },
  ["AD"] = { git_status.staged },
  [" A"] = { git_status.untracked },
  ["AA"] = { git_status.unmerged, git_status.untracked },
  ["AU"] = { git_status.unmerged, git_status.untracked },
  ["AM"] = { git_status.staged, git_status.unstaged },
  ["??"] = { git_status.untracked },
  ["R "] = { git_status.renamed },
  [" R"] = { git_status.renamed },
  ["RM"] = { git_status.unstaged, git_status.renamed },
  ["UU"] = { git_status.unmerged },
  ["UD"] = { git_status.unmerged },
  ["UA"] = { git_status.unmerged },
  [" D"] = { git_status.deleted },
  ["D "] = { git_status.deleted },
  ["RD"] = { git_status.deleted },
  ["DD"] = { git_status.deleted },
  ["DU"] = { git_status.deleted, git_status.unmerged },
  ["!!"] = { git_status.ignored },
  dirty = { git_status.unstaged },
}

function M.git_status_renderer(entry)
  local status = context.git_status[entry.path]
  if status ~= nil and git_status_to_icons[status] ~= nil then
    return git_status_to_icons[status]
  end

  if status ~= nil and git_status_to_icons[status] == nil then
    -- print(status)
  end

  return {
    text = nil,
    highlight = nil,
  }
end

return M
