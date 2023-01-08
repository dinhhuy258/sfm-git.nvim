local event = require "sfm.event"
local config = require "sfm.extensions.sfm-git.config"
local status = require "sfm.extensions.sfm-git.status"

local M = {}

function M.test()
  status.get_status_async(
    "/Users/dinhhuy258/.local/share/nvim/lazy/sfm-git.nvim/lua/sfm/extensions/",
    function(git_status)
      vim.notify(vim.inspect(git_status))
    end
  )
end

function M.setup(sfm_explorer, opts)
  config.setup(opts)
  sfm_explorer:subscribe(event.ExplorerOpen, function(payload)
    local bufnr = payload["bufnr"]
    local options = {
      noremap = true,
      silent = true,
      expr = false,
    }

    vim.api.nvim_buf_set_keymap(bufnr, "n", "t", "<CMD>lua require('sfm.extensions.sfm-git').test()<CR>", options)
  end)
end

return M
