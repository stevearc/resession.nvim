# resession.nvim

A replacement for `:mksession` with a better API

🚧 Under Construction! 🚧

- **No magic behavior**. Only does what you tell it.
- Supports **tab-scoped sessions**.
- Extensive **customizability** in what gets saved/restored.
- Easy to write **extensions** for other plugins.

## TODO

- [ ] documentation
- [ ] nvim-tree extension

<!-- TOC -->

- [TODO](#todo)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Guides](#guides)
  - [Automatically save a session when you exit Neovim](#automatically-save-a-session-when-you-exit-neovim)
  - [Periodically save the current session](#periodically-save-the-current-session)
  - [Create one session per directory](#create-one-session-per-directory)
  - [Create one session per git branch](#create-one-session-per-git-branch)
  - [Use tab-scoped sessions](#use-tab-scoped-sessions)
  - [Saving custom data with an extension](#saving-custom-data-with-an-extension)
- [Setup options](#setup-options)
- [API](#api)
  - [setup(config)](#setupconfig)
  - [get_current()](#get_current)
  - [detach()](#detach)
  - [list(opts)](#listopts)
  - [delete(name, opts)](#deletename-opts)
  - [save(name, opts)](#savename-opts)
  - [save_tab(name, opts)](#save_tabname-opts)
  - [save_all(opts)](#save_allopts)
  - [load(name, opts)](#loadname-opts)
- [FAQ](#faq)

<!-- /TOC -->

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

### Create one session per directory

Load a dir-specific session when you open Neovim, save it when you exit.

```lua
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Only load the session if nvim was started with no args
    if vim.fn.argc(-1) == 0 then
    -- Save these to a different directory, so our manual sessions don't get polluted
      resession.load(vim.fn.getcwd(), { dir = "dirsession", silence_errors = true })
    end
  end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    resession.save(vim.fn.getcwd(), { dir = "dirsession", notify = false })
  end,
})
```

### Create one session per git branch

Same as above, but have a separate session for each git branch in a directory.

```lua
local function get_session_name()
  local name = vim.fn.getcwd()
  local branch = vim.fn.system("git branch --show-current")
  if vim.v.shell_error == 0 then
    return name .. branch
  else
    return name
  end
end
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Only load the session if nvim was started with no args
    if vim.fn.argc(-1) == 0 then
      resession.load(get_session_name(), { dir = "dirsession", silence_errors = true })
    end
  end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    resession.save(get_session_name(), { dir = "dirsession", notify = false })
  end,
})
```

### Use tab-scoped sessions

When saving a session, only save the current tab

```lua
-- Bind `save_tab` instead of `save`
vim.keymap.set('n', '<leader>ss', resession.save_tab)
vim.keymap.set('n', '<leader>sl', resession.load)
vim.keymap.set('n', '<leader>sd', resession.delete)
```

This will save only the current tabpage layout, but will save _all_ of the open buffers. You can provide a filter to exclude buffers. For example, if you are using `:tcd` to have tabs open for different directories, this will only save buffers in the current tabpage directory:

```lua
require("resession").setup({
  tab_buf_filter = function(tabpage, bufnr)
    local dir = vim.fn.getcwd(-1, vim.api.nvim_tabpage_get_number(tabpage))
    return vim.startswith(vim.api.nvim_buf_get_name(bufnr), dir)
  end,
})
```

### Saving custom data with an extension

TODO

## Setup options

<!-- Setup -->

```lua
require("resession").setup({
  -- Options for automatically saving sessions on a timer
  autosave = {
    enabled = false,
    -- How often to save (in seconds)
    interval = 60,
    -- Notify when autosaved
    notify = true,
  },
  -- Save and restore these options
  options = {
    "binary",
    "bufhidden",
    "buflisted",
    "cmdheight",
    "diff",
    "filetype",
    "modifiable",
    "previewwindow",
    "readonly",
    "scrollbind",
    "winfixheight",
    "winfixwidth",
  },
  -- Custom logic for determining if the buffer should be included
  buf_filter = function(bufnr)
    if not vim.tbl_contains({ "", "acwrite", "help" }, vim.bo[bufnr].buftype) then
      return false
    end
    return vim.bo[bufnr].buflisted
  end,
  -- Custom logic for determining if a buffer should be included in a tab-scoped session
  tab_buf_filter = function(tabpage, bufnr)
    return true
  end,
  -- The name of the directory to store sessions in
  dir = "session",
  -- Configuration for extensions
  extensions = {
    quickfix = {},
  },
})
```

<!-- /Setup -->

## API

<!-- API -->

### setup(config)

Initialize resession with configuration options
| Param  | Type    | Desc |
| ------ | ------- | - |
| config | `table` |   |

### get_current()

Get the name of the current session

### detach()

Detach from the current session

### list(opts)

List all available saved sessions
| Param | Type                      | Desc          |                                                     |
| ---- | ------------------------- | ------------- | --------------------------------------------------- |
| opts | `nil\|resession.ListOpts` |               |                                                     |
|      | dir                       | `nil\|string` | Name of directory to save to (overrides config.dir) |

### delete(name, opts)

Delete a saved session
| Param | Type                        | Desc          |                                                     |
| ---- | --------------------------- | ------------- | --------------------------------------------------- |
| name | `string`                    |               |                                                     |
| opts | `nil\|resession.DeleteOpts` |               |                                                     |
|      | dir                         | `nil\|string` | Name of directory to save to (overrides config.dir) |

### save(name, opts)

Save a session to disk
| Param | Type                      | Desc           |                                                      |
| ---- | ------------------------- | -------------- | ---------------------------------------------------- |
| name | `nil\|string`             |                |                                                      |
| opts | `nil\|resession.SaveOpts` |                |                                                      |
|      | attach                    | `nil\|boolean` | Stay attached to session after saving (default true) |
|      | notify                    | `nil\|boolean` | Notify on success                                    |
|      | dir                       | `nil\|string`  | Name of directory to save to (overrides config.dir)  |

### save_tab(name, opts)

Save a tab-scoped session
| Param | Type                      | Desc           |                                                      |
| ---- | ------------------------- | -------------- | ---------------------------------------------------- |
| name | `string`                  |                |                                                      |
| opts | `nil\|resession.SaveOpts` |                |                                                      |
|      | attach                    | `nil\|boolean` | Stay attached to session after saving (default true) |
|      | notify                    | `nil\|boolean` | Notify on success                                    |
|      | dir                       | `nil\|string`  | Name of directory to save to (overrides config.dir)  |

### save_all(opts)

Save all current sessions to disk
| Param | Type         | Desc           |   |
| ---- | ------------ | -------------- | - |
| opts | `nil\|table` |                |   |
|      | notify       | `nil\|boolean` |   |

### load(name, opts)

Load a session
| Param | Type                      | Desc                   |                                                             |
| ---- | ------------------------- | ---------------------- | ----------------------------------------------------------- |
| name | `nil\|string`             |                        |                                                             |
| opts | `nil\|resession.LoadOpts` |                        |                                                             |
|      | attach                    | `nil\|boolean`         | Stay attached to session after loading (default true)       |
|      | reset                     | `nil\|boolean\|"auto"` | Close everthing before loading the session (default "auto") |
|      | silence_errors            | `nil\|boolean`         | Don't error when trying to load a missing session           |
|      | dir                       | `nil\|string`          | Name of directory to load from (overrides config.dir)       |

**Note:**
<pre>
The default value of `reset = "auto"` will reset when loading a normal session, but _not_ when
loading a tab-scoped session.
</pre>


<!-- /API -->

## FAQ

**Q: Why another session plugin?**

A: All the other plugins use `:mksession` under the hood

**Q: Why don't you want to use `:mksession`?**

A: While it's amazing that this feature is built-in to vim, and it does an impressively good job for most situations, it is very difficult to customize. If `:help sessionoptions` covers your use case, then you're golden. If you want anything else, you're out of luck.
