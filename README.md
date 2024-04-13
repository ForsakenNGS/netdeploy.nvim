# netdeploy.nvim

This plugin allows for project-/folder-specific configuration(s) of FTP/SSH/... deploy targets. You can upload/download the active file with one simple command to/from a desired target.
![image](https://github.com/ForsakenNGS/netdeploy.nvim/assets/7613262/9155ac9e-38bd-43ae-b268-a50392ac76bd)

## Installation

- Make sure you have [plenary](https://github.com/nvim-lua/plenary.nvim) installed

Using [lazy](https://github.com/folke/lazy.nvim):

```
"ForsakenNGS/netdeploy.nvim"
```

Using [packer](https://github.com/wbthomason/packer.nvim):

```
use "ForsakenNGS/netdeploy.nvim"
```

## Getting Started

In order for the plugin to work, you need a `.netdeploy.lua` file in one of the active files parent directory. Usually this will be the project root, but you can define alternative deployment configurations for subdirectories as well. This file should look something like this:

```lua
return {
    remotes = {
        { name = "Live deployment", url = "ftp://live.example.com/deploy/path" },
        { name = "Staging deployment", url = "ftp://dev.example.com/deploy/path/for/staging" },
        { name = "Development deployment", url = "ftp://dev.example.com/deploy/path/for/development" },
    }
}
```

You can define as many remotes as you like. If there is more than one remote you will see a popup letting you choose which one you want to use.
(The first 9 can be selected using the 1-9 keys while the popup is open)
If no `name` is given the `url` will be displayed in the popup selection.

The `url` is a netrw comatible target (See [netrw-externapp](https://vimhelp.org/pi_netrw.txt.html#netrw-externapp)).
The path component is always relative to the path of the `.netdeploy.lua` configuration it is defined in.
So if you have the earlier example in your project root and upload the file `foo/bar.txt` it will result in the nvim commannd `:w "ftp://live.example.com/deploy/path/foo/bar.txt`.

By default you can use the follwing commands:
- `:NetDeployUpload` to upload the currently active file
- `:NetDeployDownload` to download the currently active file

It is recommended to put your login information in a safe location (e.g. using ssh keys from `~/.ssh/` or a `~/.netrc` file), but depending on the protocol it may be possible to include it in the url as well.
(See [netrw-nwrite](https://vimhelp.org/pi_netrw.txt.html#netrw-write))

To make things easier you should enable keybinds for the up- and download commands. In order to do that create a configuration file at `~/.config/nvim/after/plugin/netdeploy.lua` with one of the following contents:
- For the default keymaps (upload via `<leader><Up>`, download via `<leader><Down>`)
```lua
require("netdeploy").setup({ defaultKeybinds = true })
```
- For a custom keymap (In this example upload via `<leader>u`, download via `<leader>d`)
```lua
local netdeploy = require("netdeploy")
netdeploy.setup({})
vim.keymap.set('n', '<leader>u', netdeploy.upload, {})
vim.keymap.set('n', '<leader>d', netdeploy.download, {})
```

## Known limitations / TODOs

- [ ] TODO: Allow for a configurable (globally and per remote) confirmation dialog before uploading/downloading files
- [ ] TODO: Collision detection via file timestamps/contents (prevent accidentally overwriting other peoples changes)
- [ ] TODO: Add functions to batch-upload/-download files
  - [ ] All uncommited files from the git-repo
  - [ ] All files changed within a given commit(-range)
  - [ ] Whole folders from within the netrw overview
