# tablocal_buffer.nvim

A Neovim plugin that keeps a per-tab set of buffers and makes `bnext` / `bprevious`-style navigation tab-local.

- Repository: `akasataikisiti/tabLocalBuffer.nvim`
- Author: `akasataikisiti`
- License: `MIT`

## Features

- Provides `require("tablocal_buffer").setting(opts)` as the official configuration entry point
- Does not register default keymaps; only keymaps specified in `keymaps` are registered
- Maintains each tab's `tablocal_buffers` with `BufWinEnter` / `BufWipeout`
- Moves the current buffer to a new tab with `:TabLocalMoveToNewTab`
- Safely detaches only the current buffer with `:TabLocalDetachBuffer` / `:TabLocalWriteDetachBuffer` / `:TabLocalDeleteBuffer`
- Provides a floating editor UI for editing per-tab buffer assignments
- Can use `bufferline.nvim` for global order calculation and sorting when available

## Installation

`lazy.nvim`:

```lua
{
  "akasataikisiti/tabLocalBuffer.nvim",
  config = function()
    require("tablocal_buffer").setting()
  end,
}
```

## Configuration Example

```lua
require("tablocal_buffer").setting({
  keymaps = {
    bnext = "<S-l>",
    bprevious = "<S-h>",
    move_to_new_tab = "st",
    open_editor = "<M-a>",
  },
  replace_builtin_bnext = false,
  bufferline = {
    enabled = true,
    auto_sort_on_apply = true,
  },
  editor = {
    keymaps = {
      add_empty_group = "<C-j>",
      delete_group = "<C-d>",
    },
  },
  cycle = {
    include_terminal = true,
    require_buflisted = true,
    exclude = {
      unnamed = false,
      filetypes = { "fugitive", "neo-tree" },
      buftypes = { "help", "quickfix", "prompt", "nofile" },
      name_patterns = { "^fugitive://" },
      predicates = {},
    },
  },
})
```

`setup(opts)` is an alias of `setting(opts)`.

Normal `[No Name]` buffers are included in the cycle by default. To exclude
them, set `cycle.exclude.unnamed = true`.

## Options

- `keymaps`
  Keymap definitions that call the normalized commands. Only specified entries are registered. The default is `{}`, which registers nothing.
- `keymaps.bnext`
  Normal-mode mapping for moving to the next tab-local buffer. Unset by default.
- `keymaps.bprevious`
  Normal-mode mapping for moving to the previous tab-local buffer. Unset by default.
- `keymaps.move_to_new_tab`
  Normal-mode mapping for moving the current buffer to a new tab. Unset by default.
- `keymaps.open_editor`
  Normal-mode mapping for opening the editor UI. Unset by default.
- `commands.enabled`
  Whether to define user commands. The default is `true`.
- `replace_builtin_bnext`
  Whether to replace command-line `:bnext` / `:bprevious` with `:TabLocalBnext` / `:TabLocalBprevious`. The default is `false`.
- `bufferline.enabled`
  Whether to enable `bufferline.nvim` integration. `sort_bufferline()` and sorting after applying the editor UI run only when this is `true`. The default is `true`.
- `bufferline.auto_sort_on_apply`
  Whether to automatically sort `bufferline.nvim` after applying the editor UI. The default is `true`.
- `editor.width_ratio`
  Width of the editor UI as a ratio of `vim.o.columns`. The default is `0.6`.
- `editor.height_ratio`
  Height of the editor UI as a ratio of `vim.o.lines`. The default is `0.6`.
- `editor.border`
  Border style for the editor UI floating window. The default is `"rounded"`.
- `editor.keymaps.add_empty_group`
  Normal-mode mapping in the editor UI for appending an empty group to `groups`. The default is `"<C-j>"`. Set it to an empty string to disable the mapping.
- `editor.keymaps.delete_group`
  Normal-mode mapping in the editor UI for deleting the group at the cursor. The default is `"<C-d>"`. Set it to an empty string to disable the mapping.
- `cycle.include_terminal`
  Whether to include `buftype == "terminal"` in the cycle. The default is `true`.
- `cycle.require_buflisted`
  Whether to usually include only `buflisted` buffers in the cycle. The default is `true`. Normal `[No Name]` buffers are included by default regardless of this value.
- `cycle.exclude.unnamed`
  Whether to exclude normal `[No Name]` buffers from the cycle. The default is `false`.
- `cycle.exclude.filetypes`
  List of `filetype` values to exclude from the cycle. The default is `{ "fugitive" }`.
- `cycle.exclude.buftypes`
  List of `buftype` values to exclude from the cycle. The default is `{}`.
- `cycle.exclude.name_patterns`
  Lua patterns matched against buffer names for exclusion. The default is `{ "^fugitive://" }`.
- `cycle.exclude.predicates`
  List of Lua functions that receive `ctx`. A buffer is excluded when any predicate returns `true`. The default is `{}`.

`ctx` passed to `cycle.exclude.predicates` contains the following values.

- `ctx.bufnr`
  Buffer number.
- `ctx.buflisted`
  Boolean value for `buflisted`.
- `ctx.buftype`
  `buftype` string.
- `ctx.filetype`
  `filetype` string.
- `ctx.bufname`
  Full path returned by `nvim_buf_get_name()`, or an empty string for unnamed buffers.
- `ctx.modified`
  Whether the buffer is modified.

## Commands

- `:TabLocalBnext`
- `:TabLocalBprevious`
- `:TabLocalEditTabBuffers`
- `:TabLocalBufferlineSort`
- `:TabLocalMoveToNewTab`
- `:TabLocalDetachBuffer`
- `:TabLocalWriteDetachBuffer`
- `:TabLocalDeleteBuffer`
- `:TabLocalDebugState`

## Public API

- `setting(opts)`
- `setup(opts)`
- `bnext_tablocal()`
- `bprevious_tablocal()`
- `move_current_window_to_new_tab()`
- `detach_current_buffer_from_tab()`
- `write_and_detach_current_buffer_from_tab()`
- `delete_current_buffer_from_tab()`
- `open_editor()`
- `get_buf_tabnr(bufnr)`
- `get_global_buffer_order()`
- `sort_bufferline()`
- `is_cycle_candidate(bufnr)`

## Editor UI

`:TabLocalEditTabBuffers` opens a floating buffer in a format that returns a Lua table. Closing it with `q` discards changes. Closing it normally applies the contents of `groups` and `unassigned`. In the editor UI, normal-mode `<C-j>` appends an empty group to `groups`. Inside `groups`, `<C-d>` deletes the group at the cursor. These mappings can be changed with `editor.keymaps`.

## Safely Detaching The Current Buffer

The behavior of existing `:q` / `:wq` / `:bd` commands is not changed. Instead, dedicated commands are available for detaching only the current buffer from its tab assignment.

- `:TabLocalDetachBuffer`
  Removes the current buffer from the current tab's assignment list and leaves it unassigned.
- `:TabLocalWriteDetachBuffer`
  Runs `:write`, then removes the current buffer from the current tab's assignment list.
- `:TabLocalDeleteBuffer`
  Removes the current buffer from the current tab's assignment list, then deletes the buffer itself.

```lua
return {
  groups = {
    { "init.lua", "README.md" },
    { "main.ts", "test.ts" },
  },
  unassigned = {
    "scratch.txt:18",
  },
}
```

## Tests

Run the headless test suite with:

```bash
nvim --headless -u NONE -i NONE -c "set rtp+=." -l tests/run.lua
```

## Help

See `:help tablocal_buffer` after installing the plugin.

## License

MIT License. See [LICENSE](LICENSE).
