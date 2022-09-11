# resession.nvim

A replacement for `:mksession` with a better API

🚧 Under Construction! 🚧

**Q: Why another session plugin?**

A: All the other plugins use `:mksession` under the hood

**Q: Why don't you want to use `:mksession`?**

A: While it's amazing that this feature is built-in to vim, and it does an impressively good job for most situations, it is very difficult to customize. If `:help sessionoptions` covers your use case, then you're golden. If you want anything else, you're out of luck.

## TODO

- [ ] tab-scoped sessions
- [ ] documentation
- [ ] make filepaths relative so sessions are portable

## Requirements

- Neovim 0.5+

## Installation

resession supports all the usual plugin managers

<details>
  <summary>Packer</summary>

```lua
require('packer').startup(function()
    use {
      'stevearc/resession.nvim',
      config = function() require('resession').setup() end
    }
end)
```

</details>

<details>
  <summary>Paq</summary>

```lua
require "paq" {
    {'stevearc/resession.nvim'};
}
```

</details>

<details>
  <summary>Neovim native package</summary>

```sh
git clone --depth=1 https://github.com/stevearc/resession.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/pack/resession/start/resession.nvim
```

</details>

## Quick start

```lua
local resession = require('resession')
resession.setup()
-- Resession does NOTHING automagically, so we have to set up some keymaps
vim.keymap.set('n', '<leader>ss', resession.save)
vim.keymap.set('n', '<leader>sl', resession.load)
vim.keymap.set('n', '<leader>sd', resession.delete)
```

Now you can use `<leader>ss` to save a session. When you want to load a session, use `<leader>sl`.

## Guides

### Automatically save a session when you exit Neovim

```lua
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    -- Always save a special session named "last"
    resession.save("last")
  end,
})
```

### Periodically save the current session

When you are attached to a session (have saved or loaded a session), use this config to periodically re-save that session in the background.

```lua
require('resession').setup({
  autosave = {
    enabled = true,
    interval = 60,
    notify = true,
  },
})
```

### TODO

- [ ] Auto-create one session per dir
- [ ] Auto-create one session per dir/git branch
- [ ] Tab-local session
- [ ] Extensions

## API

TODO
