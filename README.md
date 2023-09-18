# resession.nvim

A replacement for `:mksession` with a better API

- **No magic behavior**. Only does what you tell it.
- Supports **tab-scoped sessions**.
- Extensive **customizability** in what gets saved/restored.
- Easy to write **extensions** for other plugins.

---

<!-- TOC -->

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
  - [load_extension(name, opts)](#load_extensionname-opts)
  - [get_current()](#get_current)
  - [detach(name, opts, target_tabpage)](#detachname-opts-target_tabpage)
  - [list(opts)](#listopts)
  - [delete(name, opts)](#deletename-opts)
  - [save(name, opts)](#savename-opts)
  - [save_tab(name, opts)](#save_tabname-opts)
  - [save_all(opts)](#save_allopts)
  - [load(name, opts)](#loadname-opts)
  - [add_hook(name, callback)](#add_hookname-callback)
  - [remove_hook(name, callback)](#remove_hookname-callback)
  - [default_buf_filter(bufnr)](#default_buf_filterbufnr)
  - [is_loading()](#is_loading)
- [Extensions](#extensions)
- [FAQ](#faq)

<!-- /TOC -->

## Requirements

- Neovim 0.8+

## Installation

resession supports all the usual plugin managers

<details>
  <summary>lazy.nvim</summary>

```lua
{
  'stevearc/resession.nvim',
  opts = {},
}
```

</details>

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
  local branch = vim.trim(vim.fn.system("git branch --show-current"))
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

To create an extension, create a file in your runtimepath at `lua/resession/extensions/myplugin.lua`. Add the following contents:

```lua
local M = {}

---Get the saved data for this extension
---@return any
M.on_save = function()
  return {}
end

---Restore the extension state
---@param data The value returned from on_save
M.on_pre_load = function(data)
  -- This is run before the buffers, windows, and tabs are restored
end

---Restore the extension state
---@param data The value returned from on_save
M.on_post_load = function(data)
  -- This is run after the buffers, windows, and tabs are restored
end

---Called when resession gets configured
---This function is optional
---@param data table The configuration data passed in the config
M.config = function(data)
  --
end

---Check if a window is supported by this extension
---This function is optional, but if provided save_win and load_win must
---also be present.
---@param winid integer
---@param bufnr integer
---@return boolean
M.is_win_supported = function(winid, bufnr)
  return true
end

---Save data for a window
---@param winid integer
---@return any
M.save_win = function(winid)
  -- This is used to save the data for a specific window that contains a non-file buffer (e.g. a filetree).
  return {}
end

---Called with the data from save_win
---@param winid integer
---@param config any
---@return integer|nil If the original window has been replaced, return the new ID that should replace it
M.load_win = function(winid, config)
  -- Restore the window from the config
end

return M
```

Then to activate it, users can add the extension to their call to `setup`:

```lua
require("resession").setup({
  extensions = {
    myplugin = {
      -- these args will get passed in to M.config()
    }
  }
})
```

For tab-scoped sessions, the `on_save` and `on_load` methods of extensions will be **disabled by default**. There is a special config argument always available that can override this:

```lua
require("resession").setup({
  extensions = {
    myplugin = {
      enable_in_tab = true,
    }
  }
})
```

Refer to [the quickfix extension](lua/resession/extensions/quickfix.lua) for a complete example.

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
  buf_filter = require("resession").default_buf_filter,
  -- Custom logic for determining if a buffer should be included in a tab-scoped session
  tab_buf_filter = function(tabpage, bufnr)
    return true
  end,
  -- The name of the directory to store sessions in
  dir = "session",
  -- Show more detail about the sessions when selecting one to load.
  -- Disable if it causes lag.
  load_detail = true,
  -- List order ["modification_time", "creation_time", "filename"]
  load_order = "modification_time",
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

`setup(config)` \
Initialize resession with configuration options

| Param  | Type    | Desc |
| ------ | ------- | ---- |
| config | `table` |      |

### load_extension(name, opts)

`load_extension(name, opts)` \
Load an extension some time after calling setup()

| Param | Type     | Desc                                |
| ----- | -------- | ----------------------------------- |
| name  | `string` | Name of the extension               |
| opts  | `table`  | Configuration options for extension |

### get_current()

`get_current(): string` \
Get the name of the current session


Returns:

| Type   | Desc |
| ------ | ---- |
| string | ?    |

### detach(name, opts, target_tabpage)

`detach(name, opts, target_tabpage)` \
Detach from a session

| Param          | Type                        | Desc |
| -------------- | --------------------------- | ---- |
| name           | `nil\|string`               |      |
| opts           | `nil\|resession.DetachOpts` |      |
| target_tabpage | `nil\|integer`              |      |

### list(opts)

`list(opts): string[]` \
List all available saved sessions

| Param | Type                      | Desc          |                                                     |
| ----- | ------------------------- | ------------- | --------------------------------------------------- |
| opts  | `nil\|resession.ListOpts` |               |                                                     |
|       | dir                       | `nil\|string` | Name of directory to save to (overrides config.dir) |

### delete(name, opts)

`delete(name, opts)` \
Delete a saved session

| Param | Type                        | Desc                                          |                                                     |
| ----- | --------------------------- | --------------------------------------------- | --------------------------------------------------- |
| name  | `nil\|string`               | If not provided, prompt for session to delete |                                                     |
| opts  | `nil\|resession.DeleteOpts` |                                               |                                                     |
|       | dir                         | `nil\|string`                                 | Name of directory to save to (overrides config.dir) |

### save(name, opts)

`save(name, opts)` \
Save a session to disk

| Param | Type                      | Desc           |                                                      |
| ----- | ------------------------- | -------------- | ---------------------------------------------------- |
| name  | `nil\|string`             |                |                                                      |
| opts  | `nil\|resession.SaveOpts` |                |                                                      |
|       | attach                    | `nil\|boolean` | Stay attached to session after saving (default true) |
|       | notify                    | `nil\|boolean` | Notify on success                                    |
|       | dir                       | `nil\|string`  | Name of directory to save to (overrides config.dir)  |

### save_tab(name, opts)

`save_tab(name, opts)` \
Save a tab-scoped session

| Param | Type                      | Desc                                               |                                                      |
| ----- | ------------------------- | -------------------------------------------------- | ---------------------------------------------------- |
| name  | `nil\|string`             | If not provided, will prompt user for session name |                                                      |
| opts  | `nil\|resession.SaveOpts` |                                                    |                                                      |
|       | attach                    | `nil\|boolean`                                     | Stay attached to session after saving (default true) |
|       | notify                    | `nil\|boolean`                                     | Notify on success                                    |
|       | dir                       | `nil\|string`                                      | Name of directory to save to (overrides config.dir)  |

### save_all(opts)

`save_all(opts)` \
Save all current sessions to disk

| Param | Type         | Desc           |     |
| ----- | ------------ | -------------- | --- |
| opts  | `nil\|table` |                |     |
|       | notify       | `nil\|boolean` |     |

### load(name, opts)

`load(name, opts)` \
Load a session

| Param | Type                      | Desc                   |                                                             |
| ----- | ------------------------- | ---------------------- | ----------------------------------------------------------- |
| name  | `nil\|string`             |                        |                                                             |
| opts  | `nil\|resession.LoadOpts` |                        |                                                             |
|       | attach                    | `nil\|boolean`         | Stay attached to session after loading (default true)       |
|       | reset                     | `nil\|boolean\|"auto"` | Close everthing before loading the session (default "auto") |
|       | silence_errors            | `nil\|boolean`         | Don't error when trying to load a missing session           |
|       | dir                       | `nil\|string`          | Name of directory to load from (overrides config.dir)       |

**Note:**
<pre>
The default value of `reset = "auto"` will reset when loading a normal session, but _not_ when
loading a tab-scoped session.
</pre>

### add_hook(name, callback)

`add_hook(name, callback)` \
Add a callback that runs at a specific time

| Param    | Type                                               | Desc |
| -------- | -------------------------------------------------- | ---- |
| name     | `"pre_save"\|"post_save"\|"pre_load"\|"post_load"` |      |
| callback | `fun()`                                            |      |

### remove_hook(name, callback)

`remove_hook(name, callback)` \
Remove a hook callback

| Param    | Type                                               | Desc |
| -------- | -------------------------------------------------- | ---- |
| name     | `"pre_save"\|"post_save"\|"pre_load"\|"post_load"` |      |
| callback | `fun()`                                            |      |

### default_buf_filter(bufnr)

`default_buf_filter(bufnr): boolean` \
The default config.buf_filter (takes all buflisted files with "", "acwrite", or "help" buftype)

| Param | Type      | Desc |
| ----- | --------- | ---- |
| bufnr | `integer` |      |

### is_loading()

`is_loading(): boolean` \
Returns true if a session is currently being loaded


<!-- /API -->

## Extensions

- [quickfix](lua/resession/extensions/quickfix.lua) (built-in)
- [aerial.nvim](https://github.com/stevearc/aerial.nvim)
- [overseer.nvim](https://github.com/stevearc/overseer.nvim)

## FAQ

**Q: Why another session plugin?**

A: All the other plugins use `:mksession` under the hood

**Q: Why don't you want to use `:mksession`?**

A: While it's amazing that this feature is built-in to vim, and it does an impressively good job for most situations, it is very difficult to customize. If `:help sessionoptions` covers your use case, then you're golden. If you want anything else, you're out of luck.
