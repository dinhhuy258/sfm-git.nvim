local ctx = require "sfm.extensions.sfm-git.context"

local M = {}

local git_icons = {
  unstaged = "",
  staged = "S",
  unmerged = "",
  renamed = "",
  untracked = "U",
  deleted = "",
  ignored = "◌",
}

local git_status = {
  staged = { text = git_icons.staged, highlight = "SFMGitStaged", ord = 1 },
  unstaged = { text = git_icons.unstaged, highlight = "SFMGitUnstaged", ord = 2 },
  renamed = { text = git_icons.renamed, highlight = "SFMGitRenamed", ord = 3 },
  deleted = { text = git_icons.deleted, highlight = "SFMGitDeleted", ord = 4 },
  unmerged = { text = git_icons.unmerged, highlight = "SFMGitMerge", ord = 5 },
  untracked = { text = git_icons.untracked, highlight = "SFMGitNew", ord = 6 },
  ignored = { text = git_icons.ignored, highlight = "SFMGitIgnored", ord = 7 },
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
  ["DA"] = { git_status.unstaged },
  ["RD"] = { git_status.deleted },
  ["DD"] = { git_status.deleted },
  ["DU"] = { git_status.deleted, git_status.unmerged },
  ["!!"] = { git_status.ignored },
  dirty = { git_status.unstaged },
}

function M.git_status_renderer(entry)
  local icon_inserted = {}
  local icons = {}

  local statuses = ctx.get_statuses(entry.path)
  for status, _ in pairs(statuses) do
    local git_status_icons = git_status_to_icons[status]
    if not git_status_icons then
      print("[sfm-git] Unrecognized git state " .. status)
    else
      for _, icon in pairs(git_status_icons) do
        if not icon_inserted[icon] then
          table.insert(icons, icon)
          icon_inserted[icon] = true
        end
      end
    end
  end

  table.sort(icons, function(a, b)
    return a.ord < b.ord
  end)

  if vim.tbl_count(icons) ~= 0 then
    table.insert(icons, { text = " ", highlight = nil })
  end

  return icons
end

return M
