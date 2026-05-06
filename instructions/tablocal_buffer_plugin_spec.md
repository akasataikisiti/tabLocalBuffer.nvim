# tablocal_buffer プラグイン仕様書

## 目的

既存の `tablocal_buffer.lua` を、再利用可能な Neovim プラグインとして独立させる。  
このプラグインは「タブごとに巡回対象バッファ集合を持ち、`bnext` / `bprevious` 相当の移動をタブローカル化する」ことを主目的とする。

この仕様書は、codex に実装させるための要件定義である。

## 現行実装から引き継ぐ中核仕様

### 1. タブごとのバッファ集合管理

- 各タブは `tablocal_buffers` という tabpage variable を持つ。
- 値は「そのタブで巡回対象とみなす buffer number の配列」。
- 重複は許可しない。
- 無効化されたバッファや除外対象バッファは、自動で配列から除去する。

### 2. 巡回対象バッファの既定ルール

現行挙動を既定値として維持する。

- `buflisted == 1` であること
- `buftype == ""` は許可
- `buftype == "terminal"` も例外的に許可
- それ以外の `buftype` は除外
- `filetype == "fugitive"` は除外
- バッファ名が `^fugitive://` に一致するものは除外

### 3. タブローカルな巡回

- `bnext` 相当の操作は、現在タブの `tablocal_buffers` 配列内だけで巡回する。
- `bprevious` 相当も同様。
- 末尾から先頭、先頭から末尾への循環を行う。
- 現在バッファが配列内に存在しない場合は、先頭の有効バッファへ移動する。
- 配列が空なら何もしない。

### 4. バッファの登録と削除

- `BufWinEnter` 時に、そのウィンドウのバッファが巡回対象なら現在タブの `tablocal_buffers` に追加する。
- `BufWipeout` 時に、全タブの `tablocal_buffers` から当該バッファを除去する。
- `setup` / `setting` 実行時に、既存タブ・既存ウィンドウを走査して初期状態を構築する。

### 5. タブ内の表示同期

タブの `tablocal_buffers` が外部操作やエディタ UI で更新された場合:

- タブ内ウィンドウ群のうち、巡回対象バッファを表示しているウィンドウが 1 つも無ければ、先頭の有効バッファを表示する。
- 巡回対象だがそのタブに属さないバッファを表示しているウィンドウがあれば、先頭の有効バッファへ差し替える。
- 巡回対象外バッファを表示しているウィンドウはそのままでよい。

### 6. 編集 UI

ユーザがタブごとのバッファ割り当てを編集できる一時バッファ UI を提供する。

- フローティングウィンドウで開く
- 内容は Lua の table を返す形式
- `groups = { ... }` と `unassigned = { ... }` を持つ
- `q` で閉じた場合は保存せず終了
- 通常に閉じた場合は内容を評価し、妥当なら適用する

編集テーブル例:

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

### 7. ラベル仕様

編集 UI およびマッピングで使うラベルは以下とする。

- 無名バッファ: `"[No Name:<bufnr>]"`
- 通常バッファ:
  - basename が一意なら `"file.lua"`
  - basename が重複するなら `"file.lua:<bufnr>"`

このラベルは UI 表示・入力の安定キーとして扱う。

### 8. グローバル順序

プラグインは「タブ順 + 各タブ内のバッファ順」に従うグローバル順序を計算できること。

- これは `bufferline.nvim` 連携のソートに使用する
- 同一バッファが複数タブに重複していても、最初に出現した位置を採用する

### 9. バッファ移送

現在ウィンドウのバッファを新規タブへ移動する操作を提供する。

期待挙動:

- 新規タブを末尾に作る
- 現在バッファを新規タブに表示する
- 旧タブ内でそのバッファを表示しているウィンドウは閉じる
- 旧タブの `tablocal_buffers` からそのバッファを除去する
- 新規タブの `tablocal_buffers` へ追加する
- 新規タブ作成時の一時空バッファは、未変更かつ不要なら削除してよい

## プラグインとしての成果物

### 推奨リポジトリ構成

```text
lua/tablocal-buffer/init.lua
lua/tablocal-buffer/config.lua
lua/tablocal-buffer/model.lua
lua/tablocal-buffer/labels.lua
lua/tablocal-buffer/navigation.lua
lua/tablocal-buffer/ui/editor.lua
plugin/tablocal-buffer.lua
README.md
doc/tablocal-buffer.txt
tests/...
```

補足:

- モジュール名は Lua の require 都合上 `tablocal_buffer` でもよい
- ただし公開名は README で統一すること
- 実装名の候補:
  - `require("tablocal_buffer")`
  - `require("tablocal-buffer")` は Lua 的に不自然なので非推奨

## 公開 API 仕様

### 必須公開関数

#### `setting(opts)`

ユーザ設定を受け取り、プラグインを初期化する主関数。  
ユーザ要望に合わせ、この名前を正式 API とする。

```lua
require("tablocal_buffer").setting({
  -- options
})
```

要件:

- 複数回呼ばれても壊れないこと
- 未指定項目は既定値を使うこと
- autocommand / command / keymap の重複定義を避けること

#### `setup(opts)`

任意だが推奨。`setting(opts)` のエイリアスとして提供する。

理由:

- Neovim プラグインの慣例に合わせられる
- `setting` を正式窓口にしつつ、他ユーザにも受け入れられやすい

#### `bnext_tablocal()`

現在タブ内で次の巡回対象バッファへ移動する。

#### `bprevious_tablocal()`

現在タブ内で前の巡回対象バッファへ移動する。

#### `move_current_window_to_new_tab()`

現在ウィンドウのバッファを新規タブへ移動する。

#### `get_buf_tabnr(bufnr)`

そのバッファがどのタブに所属しているかを返す。

- 見つからなければ `nil`

#### `get_global_buffer_order()`

`bufferline.nvim` などの連携用に、`bufnr => order` の map を返す。

### 任意公開関数

#### `open_editor()`

編集 UI を明示的に開く関数。

#### `is_cycle_candidate(bufnr)`

デバッグ・連携用途として公開してもよい。  
ただし内部実装扱いでもよい。

## ユーザコマンド仕様

以下を既定で提供する。

- `:TabLocalBnext`
- `:TabLocalBprevious`
- `:TabLocalEditTabBuffers`
- `:TabLocalBufferlineSort`
- `:TabLocalMoveToNewTab`

追加提案:

- `:TabLocalDebugState`
  - 現在の内部状態を inspect して表示する
  - 開発時に便利

## キーマップ方針

プラグインは**既定キーマップを一切登録しない**こと。  
キーマップはあくまでユーザが `setting()` で明示設定した場合のみ登録する。

必須要件:

- デフォルトではキーマップ登録を行わない
- キーマップは `setting()` の設定値に基づいてのみ登録する
- 未設定の項目はマップしない
- キーマップを設定しなくても、コマンドと関数 API は使える

設定例:

```lua
require("tablocal_buffer").setting({
  keymaps = {
    bnext = "<S-l>",
    bprevious = "<S-h>",
    move_to_new_tab = "st",
    open_editor = "<M-a>",
  },
})
```

補足:

- `keymaps = nil` または `keymaps = {}` の場合は何も登録しない
- `enabled = true/false` のような全体フラグは不要
- 「値がある項目だけ登録する」形の方が単純で誤解が少ない

## `bnext` / `bprevious` のコマンドライン置換

現行実装は `cnoreabbrev` で `bnext` / `bprevious` を置換している。  
これは便利だが副作用が大きいため、プラグイン化では設定式にする。

```lua
replace_builtin_bnext = false
```

要件:

- 既定値は `false`
- `true` の場合のみ `bnext` / `bprevious` を置換する
- 置換はコマンドラインで完全一致した場合のみ

## bufferline.nvim 連携

### 目的

タブローカルな所属順を `bufferline.nvim` の表示順に反映する。

### 仕様

- `bufferline.nvim` が無い場合は何もしない
- `:TabLocalBufferlineSort` で明示ソートを実行できる
- 編集 UI 適用後にも自動ソート可能にする

推奨オプション:

```lua
bufferline = {
  enabled = true,
  auto_sort_on_apply = true,
}
```

## 編集 UI の厳密仕様

### 表示

- フローティングウィンドウで開く
- サイズは画面比率ベースで決める
- border を持てる
- filetype は `lua`
- `nofile`, `wipe`, `noswapfile`

### 受理フォーマット

以下のいずれかを許可する。

```lua
return {
  groups = {
    { "a" },
    { "b" },
  },
  unassigned = {
    "c",
  },
}
```

または:

```lua
return {
  { "a" },
  { "b" },
}
```

### バリデーション

最低限以下を検証する。

- top-level が table
- `groups` が table、または top-level 配列形式
- 各 group が空でない table
- 各要素が string
- 同一ラベルが groups / unassigned 間で重複しない
- 存在しないラベルを参照しない

### 適用アルゴリズム

- 既存タブ群との対応付けは「ラベル重複数が最大の group を優先」で行う
- 新しい group 数が既存タブ数より多い場合は新規タブを作る
- 対応付かなかった既存タブには空配列を設定する
- `unassigned` のバッファはどのタブにも属さない状態として保持する
- 以前 groups または unassigned に存在し、今回消えたバッファは削除候補とする
- ただし以下は削除しない
  - modified バッファ
  - まだどこかの window で表示中のバッファ

## 内部データモデル

### タブ状態

各タブの状態は tabpage variable で持つ:

- key: `tablocal_buffers`
- value: `integer[]`

### 一時 UI 状態

編集バッファには以下を保存する:

- `tablocal_label_map`
- `tablocal_unassigned_set`

これにより、表示時と適用時でラベル解決の整合性を保つ。

## 設定仕様

## 推奨設定テーブル

```lua
require("tablocal_buffer").setting({
  keymaps = {
    bnext = "<S-l>",
    bprevious = "<S-h>",
    move_to_new_tab = "st",
    open_editor = "<M-a>",
  },
  commands = {
    enabled = true,
  },
  replace_builtin_bnext = false,
  bufferline = {
    enabled = true,
    auto_sort_on_apply = true,
  },
  editor = {
    width_ratio = 0.6,
    height_ratio = 0.6,
    border = "rounded",
  },
  cycle = {
    include_terminal = true,
    exclude = {
      filetypes = { "fugitive" },
      buftypes = { "help", "quickfix", "prompt", "nofile" },
      name_patterns = { "^fugitive://" },
      predicates = {},
    },
  },
})
```

## 巡回対象外条件の設定方法の提案

### 結論

ユーザに設定させる形としては、**宣言的なテーブル + 必要時のみ predicate 関数** が最もよい。

理由:

- 多くのユーザは `filetype` / `buftype` / バッファ名パターンで十分
- 宣言的設定なら README に書きやすい
- シリアライズしやすく、保守しやすい
- どうしても足りない場合だけ Lua 関数で逃がせる

### 推奨形

```lua
require("tablocal_buffer").setting({
  cycle = {
    include_terminal = true,
    exclude = {
      filetypes = { "fugitive", "neo-tree", "TelescopePrompt" },
      buftypes = { "help", "quickfix", "prompt", "nofile" },
      name_patterns = {
        "^fugitive://",
        "^term://",
      },
      predicates = {
        function(ctx)
          return ctx.bufname == ""
        end,
      },
    },
  },
})
```

### `ctx` の想定内容

`predicates` に渡す `ctx` は以下を持つ。

```lua
{
  bufnr = 12,
  buflisted = true,
  buftype = "",
  filetype = "lua",
  bufname = "/path/to/file.lua",
  modified = false,
}
```

### 判定順序

推奨:

1. 無効バッファなら除外
2. `buflisted` 条件を判定
3. 既定ルールを判定
4. ユーザ指定 `filetypes` / `buftypes` / `name_patterns` を判定
5. `predicates` のいずれかが `true` なら除外
6. それ以外は巡回対象

### 判定ロジック

- `exclude.filetypes`: 完全一致で除外
- `exclude.buftypes`: 完全一致で除外
- `exclude.name_patterns`: Lua pattern に一致したら除外
- `exclude.predicates`: いずれかが `true` を返したら除外

つまり **各条件は OR 条件** とするのが自然。

### 避けたい形

以下は避けた方がよい。

- 除外条件を 1 個の巨大関数だけで設定させる
  - 可読性が低い
  - README に書きづらい
  - 利用者間で共有しづらい
- DSL を独自設計する
  - 学習コストの割に効果が薄い
- 正規表現専用の複雑な条件木
  - 大半の利用者には過剰

### さらに良い API 案

宣言的設定をさらに単純化するなら、`exclude.rules` の配列に統一する案もある。

```lua
require("tablocal_buffer").setting({
  cycle = {
    exclude = {
      rules = {
        { filetype = "fugitive" },
        { filetype = "neo-tree" },
        { buftype = "help" },
        { buftype = "quickfix" },
        { name_pattern = "^fugitive://" },
        {
          predicate = function(ctx)
            return ctx.bufname == ""
          end,
        },
      },
    },
  },
})
```

ただし初期実装としては、以下の理由で `filetypes` / `buftypes` / `name_patterns` / `predicates` の 4 分割の方がよい。

- 実装が簡単
- README が読みやすい
- 補完しやすい
- 誤設定が少ない

したがって、**第一候補は 4 分割テーブル形式** とする。

## デフォルト設定要件

ユーザ未設定時は、現行 `tablocal_buffer.lua` に近い挙動を再現する。

```lua
local defaults = {
  keymaps = {},
  commands = {
    enabled = true,
  },
  replace_builtin_bnext = false,
  bufferline = {
    enabled = true,
    auto_sort_on_apply = true,
  },
  editor = {
    width_ratio = 0.6,
    height_ratio = 0.6,
    border = "rounded",
  },
  cycle = {
    include_terminal = true,
    require_buflisted = true,
    exclude = {
      filetypes = { "fugitive" },
      buftypes = {},
      name_patterns = { "^fugitive://" },
      predicates = {},
    },
  },
}
```

補足:

- `buftypes = {}` でも、既定ロジック側で `""` と `"terminal"` 以外を除外する
- つまりユーザ設定は「追加除外」として扱う

## 実装上の注意

### 1. `bufferline.nvim` はハード依存にしない

- `pcall(require, "bufferline")` で確認する
- 無ければ静かにスキップ、または warn 通知

### 2. 既存タブとの対応付けは壊しにくさを優先

- 編集 UI 適用時に、group index で単純対応しない
- overlap 最大で紐付けることで、並び替えに強くする

### 3. バッファ削除は慎重に行う

- `modified` は削除しない
- 表示中バッファは削除しない
- `nvim_buf_delete(..., { force = false })` を使う

### 4. タブ番号は動的値

- tabpage handle を主に使う
- tab number は表示用または補助情報用に留める

### 5. コマンド置換は opt-in

- `bnext` / `bprevious` の乗っ取りは既定無効
- plugin としては副作用を減らす

## テスト観点

最低限以下を自動テスト対象にする。

- 巡回対象判定
- `BufWinEnter` での登録
- `BufWipeout` での全タブ削除
- タブローカル巡回の循環
- 重名ラベル生成
- 編集 UI テーブルのバリデーション
- group 再割当の overlap ベース対応
- unassigned 維持
- 削除候補の安全判定
- `bufferline.nvim` 不在時に落ちないこと
- `setting()` 再実行時に autocommand / command / keymap が壊れないこと
  - keymap 未設定時に何も登録されないこと
  - 一部 keymap だけ設定した場合、その分だけ登録されること

## codex への実装依頼文に含めるべき要点

- 既存 `lua/myplugs/tablocal_buffer.lua` の挙動を基準にすること
- ただし plugin として副作用の強い部分は opt-in 化すること
- 公開 API は `setting(opts)` を正式名にすること
- `setup(opts)` は `setting(opts)` の alias として提供してよい
- 既定キーマップは作らず、`setting({ keymaps = ... })` で明示指定されたものだけ登録すること
- 除外条件設定は「宣言的テーブル + predicate 関数」で実装すること
- デフォルトでは現行挙動を維持すること
- `bufferline.nvim` は optional dependency とすること
- README と help doc も合わせて作ること

## 実装優先順位

1. コア状態管理
2. 巡回対象判定の設定化
3. タブローカル巡回 API / コマンド
4. 新規タブ移送
5. 編集 UI
6. bufferline 連携
7. README / help / tests
