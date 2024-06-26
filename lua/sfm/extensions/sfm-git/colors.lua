local M = {}

local function create_highlight_group(hl_group_name, link_to_if_exists, fg, bg, gui)
  local success, hl_group = pcall(vim.api.nvim_get_hl_by_name, hl_group_name, true)
  if not success or not hl_group.foreground or not hl_group.background then
    for _, link_to in ipairs(link_to_if_exists) do
      success, hl_group = pcall(vim.api.nvim_get_hl_by_name, link_to, true)
      if success then
        local new_group_has_settings = bg or fg or gui
        local link_to_has_settings = hl_group.foreground or hl_group.background
        if link_to_has_settings or not new_group_has_settings then
          vim.cmd("highlight default link " .. hl_group_name .. " " .. link_to)

          return
        end
      end
    end

    local cmd = "highlight default " .. hl_group_name
    if bg then
      cmd = cmd .. " guibg=#" .. bg
    end
    if fg then
      cmd = cmd .. " guifg=#" .. fg
    else
      cmd = cmd .. " guifg=NONE"
    end
    if gui then
      cmd = cmd .. " gui=" .. gui
    end
    vim.cmd(cmd)
  end
end

function M.setup()
  create_highlight_group("SFMGitStaged", { "GitGutterAdd", "GitSignsAdd" }, "5faf5f", nil, nil)
  create_highlight_group("SFMGitUnstaged", {}, "ff8700", nil, "italic,bold")
  create_highlight_group("SFMGitRenamed", { "GitGutterChange", "GitSignsChange" }, "d7af5f", nil, nil)
  create_highlight_group("SFMGitDeleted", { "GitGutterDelete", "GitSignsDelete" }, "ff5900", nil, nil)
  create_highlight_group("SFMGitMerge", { "GitGutterDelete", "GitSignsDelete" }, "ff5900", nil, nil)
  create_highlight_group("SFMGitNew", { "GitGutterAdd", "GitSignsAdd" }, "5faf5f", nil, nil)
end

return M
