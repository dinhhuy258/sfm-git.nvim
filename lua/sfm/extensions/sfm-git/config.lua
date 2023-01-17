local M = {
  opts = {},
}

local default_config = {
  icons = {
    unstaged = "",
    staged = "S",
    unmerged = "",
    renamed = "",
    untracked = "U",
    deleted = "",
    ignored = "◌",
  },
}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", default_config, opts or {})
end

return M
