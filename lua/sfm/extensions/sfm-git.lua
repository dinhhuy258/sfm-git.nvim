local config = require "sfm.extensions.sfm-git.config"

local M = {}

function M.setup(sfm_explorer, opts)
  config.setup(opts)
end

return M
