local config = require "sfm.extensions.sfm-git.config"
local colors = require "sfm.extensions.sfm-git.colors"
local status = require "sfm.extensions.sfm-git.status"
local context = require "sfm.extensions.sfm-git.context"
local git_renderer = require "sfm.extensions.sfm-git.git_renderer"

local event = require "sfm.event"
local api = require "sfm.api"

local M = {}

local function on_git_status_done(git_statuses)
  context.git_statuses = git_statuses

  if api.explorer.is_open then
    api.explorer.refresh()
  end
end

function M.setup(sfm_explorer, opts)
  config.setup(opts)
  colors.setup()

  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      colors.setup()
    end,
  })

  sfm_explorer:subscribe(event.ExplorerOpened, function()
    local root = api.entry.root()
    status.get_status_async(root.path, on_git_status_done)
  end)

  sfm_explorer:subscribe(event.FolderOpened, function(payload)
    local path = payload["path"]

    status.get_status_async(path, on_git_status_done)
  end)

  -- indent(10), indicator(20), icon(30), selection(40), git_status(45), name(50)
  sfm_explorer:register_renderer("sfm-git", 45, git_renderer.git_status_renderer)
end

return M
