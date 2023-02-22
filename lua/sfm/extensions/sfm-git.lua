local event = require "sfm.event"
local api = require "sfm.api"

local config = require "sfm.extensions.sfm-git.config"
local colors = require "sfm.extensions.sfm-git.colors"
local status = require "sfm.extensions.sfm-git.status"
local ctx = require "sfm.extensions.sfm-git.context"
local renderer = require "sfm.extensions.sfm-git.renderer"

local M = {
  render_git_icons = true
}

local function on_git_status_done(git_root, git_statuses)
  ctx.set_statuses(git_root, git_statuses)

  if api.explorer.is_open then
    api.explorer.refresh()
  end
end

function M.setup(sfm_explorer, opts)
  config.setup(opts)
  renderer.setup()
  colors.setup()
  status.setup(on_git_status_done)

  vim.api.nvim_create_user_command("SFMGitToggle", function()
    if M.render_git_icons then
      M.render_git_icons = false
      sfm_explorer:remove_renderer("sfm-git")
      api.explorer.refresh()
    else
      M.render_git_icons = true
      sfm_explorer:register_renderer("sfm-git", 39, renderer.git_status_renderer)
      api.explorer.refresh()
    end
  end, {
    bang = true,
    nargs = "*",
  })

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
      status.update_git_status_async(api.path.dirname(fpath))
    end,
  })

  sfm_explorer:subscribe(event.ExplorerOpened, function()
    local root = api.entry.root()
    status.update_git_status_async(root.path)
  end)

  sfm_explorer:subscribe(event.ExplorerReloaded, function()
    status.reload_git_status_async()
  end)

  sfm_explorer:subscribe(event.ExplorerRootChanged, function()
    status.stop_watchers()
  end)

  sfm_explorer:subscribe(event.FolderOpened, function(payload)
    status.update_git_status_async(payload["path"], false)
  end)

  -- indent(10), indicator(20), icon(30), git_status(39), name(40)
  sfm_explorer:register_renderer("sfm-git", 39, renderer.git_status_renderer)
end

return M
