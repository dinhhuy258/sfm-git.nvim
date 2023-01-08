local event = require "sfm.event"
local config = require "sfm.extensions.sfm-git.config"
local status = require "sfm.extensions.sfm-git.status"
local api = require "sfm.api"

local M = {
  git_status = {},
}

local function git_status_renderer(entry)
  return {
    text = M.git_status[entry.path],
    highlight = nil,
  }
end

local function on_git_status_done(git_status)
  M.git_status = git_status

  if api.explorer.is_open then
    api.explorer.refresh()
  end
end

function M.setup(sfm_explorer, opts)
  config.setup(opts)
  local root_entry = sfm_explorer:get_root_entry()
  status.get_status_async(root_entry.path, on_git_status_done)

  sfm_explorer:subscribe(event.FolderOpened, function(payload)
    local path = payload["path"]

    status.get_status_async(path, on_git_status_done)
  end)

  sfm_explorer:register_renderer("sfm-git", 100, git_status_renderer)
end

return M
