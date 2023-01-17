local path = require "sfm.utils.path"

local config = require "sfm.extensions.sfm-git.config"
local colors = require "sfm.extensions.sfm-git.colors"
local status = require "sfm.extensions.sfm-git.status"
local ctx = require "sfm.extensions.sfm-git.context"
local git_renderer = require "sfm.extensions.sfm-git.git_renderer"

local event = require "sfm.event"
local api = require "sfm.api"

local M = {}

local function on_git_status_done(git_root, git_statuses)
  ctx.set_statuses(git_root, git_statuses)

  if api.explorer.is_open then
    api.explorer.refresh()
  end
end

function M.setup(sfm_explorer, opts)
  config.setup(opts)
  colors.setup()
  status.setup(on_git_status_done)

  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      colors.setup()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    callback = function(tbl)
      if not api.explorer.is_open then
        return
      end

      local fpath = tbl["match"]
      status.update_git_status_async(path.dirname(fpath))
    end,
  })

  sfm_explorer:subscribe(event.ExplorerReloaded, function()
    local root = api.entry.root()
    status.update_git_status_async(root.path)
  end)

  sfm_explorer:subscribe(event.FolderOpened, function(payload)
    local fpath = payload["path"]
    status.update_git_status_async(fpath)
  end)

  -- indent(10), indicator(20), icon(30), selection(40), git_status(45), name(50)
  sfm_explorer:register_renderer("sfm-git", 45, git_renderer.git_status_renderer)
end

return M
