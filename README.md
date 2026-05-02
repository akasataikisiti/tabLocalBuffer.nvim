# tablocal_buffer.nvim

タブごとに巡回対象バッファ集合を持ち、`bnext` / `bprevious` 相当の移動をタブローカル化する Neovim プラグインです。

- Repository: `akasataikisiti/tabLocalBuffer.nvim`
- Author: `akasataikisiti`
- License: `MIT`

## 特徴

- `require("tablocal_buffer").setting(opts)` を正式な設定入口として提供
- 既定キーマップは登録せず、`keymaps` で指定されたものだけ登録
- `BufWinEnter` / `BufWipeout` ベースで各タブの `tablocal_buffers` を維持
- `:TabLocalMoveToNewTab` で現在バッファを新規タブへ移送
- `:TabLocalDetachBuffer` / `:TabLocalWriteDetachBuffer` / `:TabLocalDeleteBuffer` で現在バッファだけを安全に外せる
- フローティング編集 UI でタブごとのバッファ割当を編集
- `bufferline.nvim` があればグローバル順序計算とソートに利用可能

## インストール

`lazy.nvim`:

```lua
{
  "akasataikisiti/tabLocalBuffer.nvim",
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

`setup(opts)` は `setting(opts)` の alias です。

`[No Name]` の通常バッファは既定で巡回対象に含まれます。除外したい場合は
`cycle.exclude.unnamed = true` を指定してください。

## 設定項目

- `keymaps`
  正規化済みコマンドを呼ぶキーマップ定義です。指定した項目だけ登録されます。デフォルトは `{}` で、何も登録しません。
- `keymaps.bnext`
  次のタブローカルバッファへ移動するノーマルモードマップです。デフォルトは未設定です。
- `keymaps.bprevious`
  前のタブローカルバッファへ移動するノーマルモードマップです。デフォルトは未設定です。
- `keymaps.move_to_new_tab`
  現在バッファを新規タブへ移すノーマルモードマップです。デフォルトは未設定です。
- `keymaps.open_editor`
  編集 UI を開くノーマルモードマップです。デフォルトは未設定です。
- `commands.enabled`
  ユーザコマンドを定義するかどうかです。デフォルトは `true` です。
- `replace_builtin_bnext`
  コマンドラインで入力した `:bnext` / `:bprevious` を `:TabLocalBnext` / `:TabLocalBprevious` に置き換えるかどうかです。デフォルトは `false` です。
- `bufferline.enabled`
  `bufferline.nvim` 連携を有効にするかどうかです。`true` のときだけ `sort_bufferline()` と編集 UI 適用時のソートが動作します。デフォルトは `true` です。
- `bufferline.auto_sort_on_apply`
  編集 UI の適用後に `bufferline.nvim` を自動ソートするかどうかです。デフォルトは `true` です。
- `editor.width_ratio`
  編集 UI の幅を `vim.o.columns` に対する比率で指定します。デフォルトは `0.6` です。
- `editor.height_ratio`
  編集 UI の高さを `vim.o.lines` に対する比率で指定します。デフォルトは `0.6` です。
- `editor.border`
  編集 UI のフローティングウィンドウの border 指定です。デフォルトは `"rounded"` です。
- `editor.keymaps.add_empty_group`
  編集 UI 上で `groups` 末尾に空の group を追加するノーマルモードマップです。デフォルトは `"<C-j>"` です。空文字にすると登録しません。
- `editor.keymaps.delete_group`
  編集 UI 上でカーソル位置の group を削除するノーマルモードマップです。デフォルトは `"<C-d>"` です。空文字にすると登録しません。
- `cycle.include_terminal`
  `buftype == "terminal"` を巡回対象に含めるかどうかです。デフォルトは `true` です。
- `cycle.require_buflisted`
  通常は `buflisted` のバッファだけを巡回対象にするかどうかです。デフォルトは `true` です。通常の `[No Name]` バッファはこの値にかかわらず既定で巡回対象に含めます。
- `cycle.exclude.unnamed`
  通常の `[No Name]` バッファを巡回対象から除外するかどうかです。デフォルトは `false` です。
- `cycle.exclude.filetypes`
  巡回対象から除外する `filetype` の一覧です。デフォルトは `{ "fugitive" }` です。
- `cycle.exclude.buftypes`
  巡回対象から除外する `buftype` の一覧です。デフォルトは `{}` です。
- `cycle.exclude.name_patterns`
  バッファ名に対して Lua パターンで除外する条件です。デフォルトは `{ "^fugitive://" }` です。
- `cycle.exclude.predicates`
  `ctx` を受け取る Lua 関数の一覧です。どれかが `true` を返すとそのバッファを除外します。デフォルトは `{}` です。

`cycle.exclude.predicates` の `ctx` には次の値が入ります。

- `ctx.bufnr`
  バッファ番号です。
- `ctx.buflisted`
  `buflisted` の真偽値です。
- `ctx.buftype`
  `buftype` の文字列です。
- `ctx.filetype`
  `filetype` の文字列です。
- `ctx.bufname`
  `nvim_buf_get_name()` で取得したフルパス、または無名バッファでは空文字です。
- `ctx.modified`
  バッファが変更済みかどうかです。

## コマンド

- `:TabLocalBnext`
- `:TabLocalBprevious`
- `:TabLocalEditTabBuffers`
- `:TabLocalBufferlineSort`
- `:TabLocalMoveToNewTab`
- `:TabLocalDetachBuffer`
- `:TabLocalWriteDetachBuffer`
- `:TabLocalDeleteBuffer`
- `:TabLocalDebugState`

## 公開 API

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

## 編集 UI

`:TabLocalEditTabBuffers` は Lua テーブルを返す形式のフローティングバッファを開きます。`q` で閉じた場合は破棄され、通常に閉じた場合は `groups` と `unassigned` の内容が適用されます。編集 UI 上では、ノーマルモードの `<C-j>` で `groups` 末尾に空の group を追加できます。`groups` 内では `<C-d>` でカーソル位置の group を削除できます。これらは `editor.keymaps` で変更できます。

## 安全に現在バッファを外すコマンド

既存の `:q` / `:wq` / `:bd` の挙動は変更しません。代わりに、現在バッファだけをタブ所属から外す専用コマンドを使えます。

- `:TabLocalDetachBuffer`
  現在バッファを現在タブの所属一覧から外し、未所属状態にします。
- `:TabLocalWriteDetachBuffer`
  `:write` 後に現在バッファを現在タブの所属一覧から外します。
- `:TabLocalDeleteBuffer`
  現在バッファを現在タブの所属一覧から外し、その後バッファ自体を削除します。

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

## License

MIT License. See [LICENSE](LICENSE).
