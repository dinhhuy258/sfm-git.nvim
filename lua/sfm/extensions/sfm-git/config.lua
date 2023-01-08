local M = {
  opts = {},
}

local default_config = {}

function M.setup(opts)
  M.opts = default_config

  if opts == nil then
    return
  end
end

return M
