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
