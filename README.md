# tablocal_buffer.nvim

タブごとに巡回対象バッファ集合を持ち、`bnext` / `bprevious` 相当の移動をタブローカル化する Neovim プラグインです。

## 特徴

- `require("tablocal_buffer").setting(opts)` を正式な設定入口として提供
- 既定キーマップは登録せず、`keymaps` で指定されたものだけ登録
- `BufWinEnter` / `BufWipeout` ベースで各タブの `tablocal_buffers` を維持
- `:TabLocalMoveToNewTab` で現在バッファを新規タブへ移送
- フローティング編集 UI でタブごとのバッファ割当を編集
- `bufferline.nvim` があればグローバル順序計算とソートに利用可能

## インストール

`lazy.nvim`:

```lua
{
  "yourname/tablocal_buffer.nvim",
  config = function()
    require("tablocal_buffer").setting()
  end,
}
```

## 設定例

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

`setup(opts)` は `setting(opts)` の alias です。

`[No Name]` の通常バッファは既定で巡回対象に含まれます。除外したい場合は
`cycle.exclude.unnamed = true` を指定してください。

## コマンド

- `:TabLocalBnext`
- `:TabLocalBprevious`
- `:TabLocalEditTabBuffers`
- `:TabLocalBufferlineSort`
- `:TabLocalMoveToNewTab`
- `:TabLocalDebugState`

## 公開 API

- `setting(opts)`
- `setup(opts)`
- `bnext_tablocal()`
- `bprevious_tablocal()`
- `move_current_window_to_new_tab()`
- `open_editor()`
- `get_buf_tabnr(bufnr)`
- `get_global_buffer_order()`
- `sort_bufferline()`
- `is_cycle_candidate(bufnr)`

## 編集 UI

`:TabLocalEditTabBuffers` は Lua テーブルを返す形式のフローティングバッファを開きます。`q` で閉じた場合は破棄され、通常に閉じた場合は `groups` と `unassigned` の内容が適用されます。

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

## テスト

以下で headless テストを実行できます。

```bash
nvim --headless -u NONE -i NONE -c "set rtp+=." -l tests/run.lua
```
