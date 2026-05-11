# tabLocalBuffer.nvim

タブごとに巡回対象バッファ集合を持ち、`bnext` / `bprevious` 相当の移動をタブローカル化する Neovim プラグインです。

- Repository: `akasataikisiti/tabLocalBuffer.nvim`
- License: MIT

![Demo](assets/output.gif)

## 特徴

- `require("tablocal_buffer").setting(opts)` を正式な設定入口として提供
- 既定キーマップは登録せず、`keymaps` で指定されたものだけ登録
- `BufWinEnter` / `BufWipeout` ベースで各タブのバッファリストを維持
- `:TabLocalMoveToNewTab` で現在バッファを新規タブへ移送
- `:TabLocalDetachBuffer` / `:TabLocalWriteDetachBuffer` / `:TabLocalDeleteBuffer` で現在バッファだけを安全に外せる
- フローティング編集 UI でタブごとのバッファ割当を編集
- `bufferline.nvim` があればグローバル順序計算とソートに利用可能

## Why?

Neovim の `:bnext` / `:bprevious` はすべてのバッファをまたぐ単一のグローバルリストを巡回します。複数のタブを異なる作業文脈で使っていると、関係のないファイルをまたいで移動することになります。tabLocalBuffer.nvim は各タブに独自のバッファリストを持たせることで、ナビゲーションをそのタブの文脈に閉じます。

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

## 設定

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
      save_and_close = "s",
      add_empty_group = "<C-j>",
      delete_group = "<C-d>",
      dedup_groups = "<C-l>",
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

`[No Name]` の通常バッファは既定で巡回対象に含まれます。除外したい場合は `cycle.exclude.unnamed = true` を指定してください。

### 設定項目

- `commands.enabled` — ユーザコマンドを定義するかどうか。デフォルト: `true`。
- `replace_builtin_bnext` — `:bnext` / `:bprevious` を `:TabLocalBnext` / `:TabLocalBprevious` に置き換えるかどうか。デフォルト: `false`。
- `editor.width_ratio` — 編集 UI の幅を `vim.o.columns` に対する比率で指定。デフォルト: `0.6`。
- `editor.height_ratio` — 編集 UI の高さを `vim.o.lines` に対する比率で指定。デフォルト: `0.6`。
- `editor.border` — 編集 UI のフローティングウィンドウの border 指定。デフォルト: `"rounded"`。
- `cycle.include_terminal` — `buftype == "terminal"` を巡回対象に含めるかどうか。デフォルト: `true`。
- `cycle.require_buflisted` — `buflisted` のバッファだけを巡回対象にするかどうか。デフォルト: `true`。
- `cycle.exclude.unnamed` — `[No Name]` バッファを除外するかどうか。デフォルト: `false`。
- `cycle.exclude.filetypes` — 除外する `filetype` の一覧。デフォルト: `{ "fugitive" }`。
- `cycle.exclude.buftypes` — 除外する `buftype` の一覧。デフォルト: `{}`。
- `cycle.exclude.name_patterns` — バッファ名に対して除外条件を指定する Lua パターンの一覧。デフォルト: `{ "^fugitive://" }`。
- `cycle.exclude.predicates` — `ctx` を受け取る Lua 関数の一覧。どれかが `true` を返すとそのバッファを除外。デフォルト: `{}`。

`ctx` のフィールド: `bufnr`、`buflisted`、`buftype`、`filetype`、`bufname`、`modified`。

## 使い方

### 編集 UI

`:TabLocalEditTabBuffers` は Lua テーブル形式のフローティングバッファを開きます。`q` で閉じると破棄され、`s` または通常に閉じると `groups` と `unassigned` の内容が適用されます。

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

### バッファの安全な取り外し

既存の `:q` / `:wq` / `:bd` の挙動は変更しません。現在バッファだけをタブ所属から外す専用コマンドを使えます。

- `:TabLocalDetachBuffer` — 現在バッファを現在タブの一覧から外し、未所属状態にする。
- `:TabLocalWriteDetachBuffer` — `:write` 後に現在バッファを現在タブの一覧から外す。
- `:TabLocalDeleteBuffer` — 現在バッファを現在タブの一覧から外し、その後バッファ自体を削除する。

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

## キーマップ

既定ではキーマップは登録されません。`keymaps` オプションで指定してください。

- `keymaps.bnext` — 次のタブローカルバッファへ移動。
- `keymaps.bprevious` — 前のタブローカルバッファへ移動。
- `keymaps.move_to_new_tab` — 現在バッファを新規タブへ移動。
- `keymaps.open_editor` — 編集 UI を開く。
- `editor.keymaps.save_and_close` — 編集 UI の内容を適用して閉じる。デフォルト: `"s"`。空文字で無効化。`q` は保存せず閉じる用途として予約。
- `editor.keymaps.add_empty_group` — 編集 UI 上でカーソル位置の group の直後に空の group を挿入。デフォルト: `"<C-j>"`。空文字で無効化。
- `editor.keymaps.delete_group` — 編集 UI 上でカーソル位置の group を削除。デフォルト: `"<C-d>"`。空文字で無効化。
- `editor.keymaps.dedup_groups` — 複数の group に重複して存在するバッファを整理し、最初に現れた group だけに残す。重複削除後に空になった group は削除される。デフォルト: `"<C-l>"`。空文字で無効化。なお `<C-l>` は Neovim 組み込みの `nohlsearch|diffupdate` 動作を編集 UI 内で上書きする。

## Bufferline 連携

`bufferline.nvim` がインストールされている場合、グローバルバッファ順序をソートに利用できます。

- `bufferline.enabled` — `bufferline.nvim` 連携を有効にするかどうか。デフォルト: `true`。
- `bufferline.auto_sort_on_apply` — 編集 UI の適用後に自動ソートするかどうか。デフォルト: `true`。

手動でソートするには `:TabLocalBufferlineSort` を使います。

## License

MIT License. See [LICENSE](LICENSE).
