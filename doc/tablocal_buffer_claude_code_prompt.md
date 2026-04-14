# codex 向け実装依頼プロンプト

以下をそのまま codex に渡してください。

---

Neovim 用の Lua モジュール `tablocal_buffer.lua` を、再利用可能な独立プラグインとして作り直してください。

実装にあたっては、既存ファイルの挙動をベースにしつつ、プラグインとして配布しやすい形に整理してください。  
仕様の詳細は以下の要件に従ってください。

## 参照元

- 既存実装: `tablocal_buffer.lua`
- 仕様書: `tablocal_buffer_plugin_spec.md`

## ゴール

「タブごとに巡回対象バッファ集合を持ち、`bnext` / `bprevious` 相当の移動をタブローカル化する」Neovim プラグインを作成してください。

単なる移植ではなく、以下を満たすように整理してください。

- プラグインとして独立して使える構成にする
- 設定 API を明確にする
- デフォルト副作用を減らす
- README と help doc を付ける
- 可能ならテストも付ける

## 最重要要件

### 1. 公開 API

正式な設定関数は `setting(opts)` にしてください。

例:

```lua
require("tablocal_buffer").setting({
  -- options
})
```

加えて、慣例対応として `setup(opts)` も用意して構いません。  
その場合は `setup(opts)` は `setting(opts)` の alias にしてください。

### 2. 既定キーマップは作らない

これは重要です。

- プラグインは**デフォルトでキーマップを一切登録しない**でください
- キーマップは `setting({ keymaps = ... })` でユーザが明示指定した場合のみ登録してください
- 未指定項目はマップしないでください

期待形:

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

### 3. 巡回対象外条件は設定可能にする

現行実装の巡回対象判定をベースにしつつ、ユーザが `setting()` で除外条件を設定できるようにしてください。

推奨形は以下です。

```lua
require("tablocal_buffer").setting({
  cycle = {
    include_terminal = true,
    require_buflisted = true,
    exclude = {
      filetypes = { "fugitive", "neo-tree", "TelescopePrompt" },
      buftypes = { "help", "quickfix", "prompt", "nofile" },
      name_patterns = { "^fugitive://" },
      predicates = {
        function(ctx)
          return ctx.bufname == ""
        end,
      },
    },
  },
})
```

`predicates` に渡す `ctx` は少なくとも以下を持たせてください。

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

判定は「どれかに引っかかったら除外」で構いません。

## 維持したい既存挙動

### タブごとのバッファ集合管理

- 各タブは `tablocal_buffers` という tabpage variable を持つ
- 値は巡回対象バッファの `bufnr` 配列
- 重複は持たない
- 無効・除外対象バッファは随時掃除する

### デフォルトの巡回対象判定

ユーザ設定が無い場合、現行に近い挙動にしてください。

- `buflisted == 1`
- `buftype == ""` は許可
- `buftype == "terminal"` も許可
- それ以外の `buftype` は除外
- `filetype == "fugitive"` は除外
- `^fugitive://` は除外

### タブローカル巡回

- `bnext_tablocal()` は現在タブの `tablocal_buffers` 内だけを巡回
- `bprevious_tablocal()` も同様
- 循環する
- 現在バッファが一覧内に無ければ先頭へ寄せる
- 一覧が空なら何もしない

### バッファ登録・削除

- `BufWinEnter` で現在タブに登録
- `BufWipeout` で全タブから削除
- 初期化時に既存ウィンドウから状態を bootstrap する

### バッファ移送

現在ウィンドウのバッファを新規タブへ移動する API を実装してください。

期待動作:

- 新規タブを末尾に作る
- 現在バッファを新規タブに表示
- 旧タブ内でそのバッファを表示しているウィンドウを閉じる
- 旧タブの配列から除去
- 新規タブの配列へ追加

### 編集 UI

現行のフローティング編集 UI を引き継いでください。

最低限必要な内容:

- `:TabLocalEditTabBuffers` で開ける
- Lua table を編集して閉じると適用される
- `q` で閉じた場合は保存しない
- `groups` と `unassigned` を扱える
- ラベルは basename ベースで、重複時は `:<bufnr>` を付ける

## コマンド

以下のユーザコマンドを実装してください。

- `:TabLocalBnext`
- `:TabLocalBprevious`
- `:TabLocalEditTabBuffers`
- `:TabLocalBufferlineSort`
- `:TabLocalMoveToNewTab`

任意で以下も歓迎です。

- `:TabLocalDebugState`

## `bnext` / `bprevious` 置換

現行実装には `cnoreabbrev` による `bnext` / `bprevious` 置換がありますが、これは副作用が強いので opt-in にしてください。

要件:

- デフォルトでは無効
- `replace_builtin_bnext = true` の時だけ有効

## bufferline.nvim 連携

`bufferline.nvim` は optional dependency にしてください。

要件:

- 無ければ落ちない
- `:TabLocalBufferlineSort` でソートできる
- 編集 UI 適用後に自動ソートするオプションを持てる

## 推奨構成

以下のように責務分割してください。

```text
lua/tablocal_buffer/init.lua
lua/tablocal_buffer/config.lua
lua/tablocal_buffer/model.lua
lua/tablocal_buffer/labels.lua
lua/tablocal_buffer/navigation.lua
lua/tablocal_buffer/ui/editor.lua
plugin/tablocal_buffer.lua
README.md
doc/tablocal_buffer.txt
tests/...
```

多少の差異は構いませんが、責務は分離してください。

## デフォルト設定の期待値

概ね以下の思想で実装してください。

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

## 実装上の注意

- autocommand / command / keymap を多重登録しないでください
- `setting()` を複数回呼んでも壊れないようにしてください
- バッファ削除は慎重に行ってください
  - modified は削除しない
  - 表示中バッファは削除しない
- `bufferline.nvim` は `pcall(require, "bufferline")` で扱ってください
- group と既存タブの対応付けは、現行どおり overlap 最大優先でよいです

## 最低限ほしい成果物

1. Lua プラグイン本体
2. README
3. help doc
4. 可能ならテスト

## コミット戦略

この作業では、コミットをまとめすぎないでください。  
**後から人間がコミット履歴を読んだときに、何をしたのかが即座に分かる粒度**で、小さく刻んでください。

方針:

- かなり小さい単位でコミットする
- できれば 1 つの処理追加、1 つの責務分離、1 つの設定追加、1 つのドキュメント追加ごとにコミットする
- 「大きなリファクタ 1 個」ではなく、意味のある作業単位に分ける
- 機械的な区切りではなく、人間が履歴を追いやすい論理単位で分ける
- 動作が壊れやすい箇所は、実装と検証可能な単位で閉じてからコミットする

Neovim プラグイン開発としての推奨コミット単位:

1. 骨格作成
2. 設定 API 追加
3. 巡回対象判定の切り出し
4. タブローカル状態管理
5. `bnext` / `bprevious` 実装
6. バッファ移送処理
7. 編集 UI
8. `bufferline.nvim` 連携
9. コマンド登録
10. README
11. help doc
12. テスト

上記はあくまで目安です。  
実際には、さらに細かく分けられるなら分けてください。

悪い例:

- 「tablocal_buffer プラグインを実装」
- 「いろいろ修正」
- 「README など更新」

良い例:

- 「設定 API の雛形を追加」
- 「巡回対象判定を設定可能に変更」
- 「タブごとの buffer 管理モデルを分離」
- 「編集 UI の Lua table 検証を追加」
- 「bufferline ソート連携をオプション化」

### コミットメッセージ形式

コミットメッセージは**日本語**で書いてください。  
また、**タイトルと詳細本文を分けて**ください。

形式:

```text
<短いタイトル>

<詳細説明 1 行目>
<詳細説明 2 行目>
...
```

要件:

- タイトルだけで大枠が分かること
- 詳細本文で「何を」「なぜ」変えたかが分かること
- 後から人間が `git log` / `git show` を見て理解しやすいこと
- 日本語として自然であること
- 省略語や曖昧語を避けること

例:

```text
設定 API の雛形を追加

setting() と setup() の公開入口を追加。
複数回呼び出しても再登録で壊れない初期化方針の土台を入れた。
```

```text
巡回対象外条件を設定可能に変更

filetype・buftype・バッファ名パターンによる除外設定を追加。
既存の fugitive 除外をデフォルト設定へ寄せ、判定ロジックを設定駆動に整理した。
```

```text
編集 UI の適用前バリデーションを追加

groups と unassigned の入力検証を追加。
重複ラベルや不正なテーブル構造を適用前に弾けるようにした。
```

### コミット時の注意

- コミット前に、そのコミットの説明が 1 文で言える状態にしてください
- 1 つのコミットに unrelated な変更を混ぜないでください
- README / help / テストは、実装と密結合なら同一コミットでもよいですが、可能なら分けてください
- リネーム、責務分割、挙動変更、設定追加、ドキュメント追加は分離を優先してください

### コミットごとの検証方針

各コミットは、**その時点でできる範囲の確認を行ってから**作成してください。  
理想は、履歴のどの地点を見ても「途中だが意味が通り、極端には壊れていない」状態です。

要件:

- 各コミット前に、そのコミットで影響する範囲の確認を行う
- テストがある場合は、関係するテストを優先して実行する
- テストが無い段階でも、少なくとも Lua の構文やロード可能性は確認する
- 実装途中のコミットでも、できるだけ Neovim プラグインとして破綻しない状態を保つ
- 「最後にまとめて直す」前提の壊れた中間コミットは避ける

推奨:

1. 小さい変更を入れる
2. その変更に関係する最小限の確認をする
3. 必要なら微修正する
4. その単位でコミットする

確認内容の例:

- Lua ファイルの構文確認
- `require("tablocal_buffer")` が通るか確認
- `setting()` の呼び出しで落ちないか確認
- コマンド登録が二重化しないか確認
- 対象ロジックのテスト実行
- 既存テストがあるなら回帰確認

もしプロジェクト内にテスト基盤があるなら、以下の方針を優先してください。

- 変更範囲に近いテストを先に回す
- 節目のコミットでは関連テスト一式を回す
- 最終段階では可能な範囲で全体確認を行う

### 各コミットで build / load 可能状態を維持する方針

Neovim プラグイン開発では、履歴の途中で `require` 不能な状態が混ざると追跡しづらくなります。  
そのため、各コミットで以下を強く意識してください。

- モジュール分割の途中でも、公開入口は壊さない
- ファイルを分割するときは、先に受け皿を作ってから移す
- 大きな rename と大きな挙動変更を 1 コミットに混ぜない
- README や help doc を後回しにしてもよいが、コード本体はロード不能にしない

避けたい例:

- 片方のモジュールだけ作って require パスが未接続のままコミットする
- 公開 API 名を変えたのに入口側がまだ古いままの状態でコミットする
- テストが落ちると分かっているが後で直す前提でコミットする

望ましい例:

- 旧実装を残したまま新モジュールを追加して接続し、動作を保ってから次の責務へ進む
- 設定 API を先に安定させ、その後に内部実装を差し替える
- 編集 UI、bufferline 連携、ドキュメントを段階的に積む

### 最終報告でほしいこと

最終報告では、実装内容に加えて以下もまとめてください。

- どの単位でコミットを分けたか
- 各コミットの意図
- 必要なら推奨コミット順
- 各コミット前に何を確認したか

## 作業手順

以下の順で進めてください。

1. `lua/myplugs/tablocal_buffer.lua` を読み、現行仕様を把握
2. `AI_output/tablocal_buffer_plugin_spec.md` を満たすように責務分割
3. プラグインとして実装
4. README / help doc 作成
5. テスト可能なら追加
6. 上記方針に従って、小さい論理単位でコミットする
7. 各コミットで可能な範囲の確認を行い、壊れた中間状態を避ける
8. 最後に、どのファイルを作成・変更したか、設定例、コミット単位の要約をまとめて報告

## 最終報告でほしい内容

- 追加・変更したファイル一覧
- 公開 API 一覧
- `setting()` の設定例
- 現行実装からの差分
- 未実装事項や注意点
- コミット一覧と各コミットの意図
- 各コミットで実施した確認内容

---

必要であれば、まず `lua/myplugs/tablocal_buffer.lua` の責務分割案を提示してから実装に入ってください。ただし、基本的にはそのまま実装まで進めてください。
