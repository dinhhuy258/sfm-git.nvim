local M = {
  opts = {},
}

local default_config = {
  debounce_interval_ms = 1000,
  icons = {
    unstaged = "",
    staged = "",
    unmerged = "",
    renamed = "",
    untracked = "",
    deleted = "",
    ignored = "◌",
  },
}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", default_config, opts or {})
end

return M
