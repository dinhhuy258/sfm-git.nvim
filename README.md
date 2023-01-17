# sfm-git.nvim

The sfm-git extension is a plugin for the [sfm](https://github.com/dinhhuy258/sfm.nvim) plugin that integrates git functionality to the sfm file explorer.

![image](https://user-images.githubusercontent.com/17776979/212691148-3701bf85-bee8-4ad5-9174-fca7c713af22.png)

## Installation

To install the `sfm-git` extension, you will need to have the [sfm](https://github.com/dinhhuy258/sfm.nvim) plugin installed. You can then install the extension using your preferred plugin manager. For example, using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
{
  "dinhhuy258/sfm.nvim",
  requires = {
    { "dinhhuy258/sfm-git.nvim" },
  },
  config = function()
    local sfm_explorer = require("sfm").setup {}
    sfm_explorer:load_extension "sfm-git"
  end
}
```

## Configuration

The `sfm-git` plugin provides the following configuration options:

```lua
local default_config = {
  icons = {
    unstaged = "",
    staged = "S",
    unmerged = "",
    renamed = "",
    untracked = "U",
    deleted = "",
    ignored = "◌"
  }
}
```

You can override the default configuration in `load_extension` method

```lua
sfm_explorer:load_extension("sfm-git", {
  icons = {
    unstaged = "",
    staged = "S",
    unmerged = "",
    renamed = "",
    untracked = "U",
    deleted = "",
    ignored = "◌"
  }
})
```

## Highlight Values

The `sfm-git` plugin uses the following highlight groups to colorize the git icons in the explorer tree:

- `SFMGitStaged`: Used to colorize the git icon for files and folders that have been added to the git index (staged) but not committed yet.
- `SFMGitUnstaged`: Used to colorize the git icon for files and folders that have been modified but not added to the git index (unstaged).
- `SFMGitRenamed`: Used to colorize the git icon for files and folders that have been renamed but not committed yet.
- `SFMGitDeleted`: Used to colorize the git icon for files and folders that have been deleted but not committed yet.
- `SFMGitMerged`: Used to colorize the git icon for files and folders that have been merged in a branch.
- `SFMGitNew`: Used to colorize the git icon for files and folders that are new and not yet tracked by git.
- `SFMGitIgnored`: Used to colorize the git icon for files and folders that are ignored by git.
