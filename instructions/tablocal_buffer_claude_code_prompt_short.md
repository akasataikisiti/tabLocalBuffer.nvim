# codex 向け実行用短縮プロンプト

以下をそのまま codex に渡してください。

---

`tablocal_buffer.lua` をもとに、独立した Neovim プラグインを実装してください。

詳細仕様は以下を参照してください。

- `tablocal_buffer_plugin_spec.md`
- `tablocal_buffer_claude_code_prompt.md`

今回は実装まで進めてください。README と help doc も作成してください。可能ならテストも追加してください。

## 最重要要件

- 公開設定関数は `require("tablocal_buffer").setting(opts)` にする
- `setup(opts)` は alias として提供してよい
- 既定キーマップは一切登録しない
- キーマップは `setting({ keymaps = ... })` で明示指定されたものだけ登録する
- 巡回対象外条件は `cycle.exclude.filetypes / buftypes / name_patterns / predicates` で設定可能にする
- `bnext` / `bprevious` の置換は opt-in にする
- `bufferline.nvim` は optional dependency にする

## 維持したい機能

- タブごとの `tablocal_buffers` 管理
- タブローカルな `bnext` / `bprevious`
- `BufWinEnter` で登録、`BufWipeout` で全タブから削除
- 現在バッファを新規タブへ移動する機能
- フローティング編集 UI
- `bufferline.nvim` 用のグローバル順序計算

## コマンド

以下を実装してください。

- `:TabLocalBnext`
- `:TabLocalBprevious`
- `:TabLocalEditTabBuffers`
- `:TabLocalBufferlineSort`
- `:TabLocalMoveToNewTab`

## コミット方針

- コミットはかなり小さい論理単位で分ける
- 後から人間が見て何をしたか分かる単位で刻む
- 1 つの処理追加、1 つの責務分離、1 つの設定追加ごとに分ける意識で進める
- コミットメッセージは日本語
- 形式は「タイトル + 空行 + 詳細本文」
- 詳細本文には「何を」「なぜ」変えたかを書く
- 各コミット前に、その変更範囲に応じた確認を行う
- 中間コミットでも `require` 不能や明確な破綻状態を避ける

コミットメッセージ例:

```text
巡回対象判定を設定可能に変更

filetype・buftype・名前パターンによる除外設定を追加。
既存の固定判定を設定駆動に整理し、fugitive 除外をデフォルト設定へ寄せた。
```

## 最後に報告してほしいこと

- 作成・変更したファイル一覧
- 公開 API 一覧
- `setting()` の設定例
- コミット一覧と各コミットの意図
- 各コミットで実施した確認内容
- 未実装事項や注意点

---

