# LOAM 互換の英語 UI を Bakhlo で再現する

## 範囲

Bakhlo は未運用で、旧 UI の後方互換性は不要。現行 LOAM の英語表記・画面構成・キー操作・
戻る／確認の流れを基準に、同じ見た目と使い勝手を再現する。英語版を先に作り、
後から日本語カタログを追加して切替可能にする。言語で会計処理や操作状態を分岐させない。
元の LOAM データ、私用候補、会計意味論、記帳・確認・保存の境界は変更しない。
LOAM の実装をコピーせず、Bakhlo の既存 OCaml / Bonsai 環境で実装する。

Calendar Home・Day / Month / Year・選択日・独立した操作画面・階層 Commands を採用する。
既存の純粋APIと記帳／保存経路を利用し、会計機能がない箇所を推測で埋めない。

## 手順

- [x] 中断で残った未接続モジュールを統合し、英語TUIをビルド可能な状態へ戻す。
- [x] 英語先行・後の日本語切替・UI操作互換を現行方針へ明記。
- [x] LOAMの現行ラベル・画面遷移・キー・確定操作を、対応するBakhlo機能と照合して受入条件を確定。
- [x] 英語の固定文言に翻訳入口を設け、表示文字列に依存する判断を安定した原因／型へ置換。
- [x] Calendar Home、日付／zoom／Detail／選択日と階層Commandsを実装。
- [x] Record／候補／確認／Actual／Scheduled／Balances／Daily Paceを共通の画面階層へ接続。
- [x] 不要な旧Homeサマリー・独自キー・互換経路を削除し、現行手順書を更新。
- [x] 純粋な日付・言語境界・実セル幅・操作・保存拒否をself-checkで検証。
- [x] 合成PTYで代表操作列、狭い端末、resize、取消／確定／cold readを確認。
- [x] 最終diffと未接続機能をレビューし、達成範囲と残る差を記録。
- [ ] 英語UIのチェックポイントをコミット・pushし、PRのCI状態を確認してマージ。
- [ ] その後、レスポンシブな入力／確認枠・3色の枠線・固定2段ナビの共通部品を設計。

## 削除・置換の判断

旧 UI の操作別名や画面を維持するための互換経路は増やさない。
起動先はBonsai一本。旧Notty画面・比較ベンチ・レイアウト試作・旧フォーム／閲覧経路を削除。
有用な保存・復旧反例は維持し、旧UIの固定キーだけの検査は新しい操作契約の検査へ置換。
Calendarに必要な役割別金額が供給されない場合は、Unavailable等で区別し、架空のIn/Outを出さない。

## 前段の共通描画の証跡

調査時点では両 worktree は clean。変更前の OCaml build / tests は成功。
LOAM の参照は `docs/TUI_NON_BUDGET_WORKLIST.md`、`docs/TUI.md` と共通 Layout。
記帳・保存の根拠や不明とゼロの区別を presentation から独自に作らない。
旧 renderer 名引数と ASCII 枠を削除・置換。入力下書きの日付が今日の Daily Pace を
変えてしまう問題を修正し、合成の回帰確認を追加。
両 frontend の全 self-check は成功。最後の列整列修正後も Bonsai / Notty を再ビルド・検証。
日本語の実セル幅、値の列位置、巨大数量の全文、通知優先、pane の非重複、表示領域不足時の
確定拒否、今日と下書き日付の分離を回帰検証。`git diff --check` も成功。
実 TTY は合成台帳だけで、37 JPY の入力・プレビュー・Enter の非保存・Esc の下書き保持・
明示 Ctrl-S 保存、詳細・picker・テーマ、100×30 / 80×24 / 64×20 と保存停止時の通知を確認。

tmux の終了後に EXTPROC フラグだけが消える場合があり、未変更 HEAD の別ビルドでも
同じ差を再現した（通常入力・終了は成功）。この UI 変更での新規回帰ではないが、完全な
端末属性復元の保証はできない。端末 lifecycle の修正を今回の表示統一へ混ぜていない。
合成 PTY の画面・属性証跡は `/private/tmp/bakhlo-ui-pty.RfYmib`。
LOAM worktree は変更なし。私用台帳の内容を読まず、本番移行・依存追加・commit はしていない。

## 方針修正の教訓

「loam互換のUI」は配色・枠だけへの移行ではない。ユーザーが示した英語表記、画面構成、
操作の習慣を受入条件に含める。見た目の部分改修をUI互換の完成として報告しない。

## 英語UIのチェックポイント（2026-10-12）

`./tools/check`、`./tools/tui --self-check`、`git diff --check`が成功。
実セル幅・3テーマ・7寸法、Previewと巨大数量／日本語のActual・Selected Day・Scheduled・
Balance詳細、7段階の故障注入と7段階のSIGKILL反例を確認。
合成PTYで英語Calendar／Commands、長い日本語メモ、70桁数量、Edit／Cancelの非保存、
Publish選択時のEnterのみ保存、140×40→48×14→80×24→140×40のリサイズ、cold readを確認。
この試験の3セッションは端末属性も一致。証跡はignoredの `scratch/loam-ui-native.0LHLXL`。
Records予定支払いの「liveでは完了、coldでは未完了」の既存反例を合成台帳で再現。
対応リンクの同時発行と既存明細置換が未対応なRecordsは、append前に明示拒否する。
bytes・cold状態・LSN・Ackの不変と、対応可能な通常Records追記のcold readを回帰検査した。
Record外のbracketed pasteからHome／Commandsの操作を実行しないことも検査。

日本語切替、役割別収支カレンダー、完全なSeries管理、Attention、履歴Trendは未実装。
現段階は英語UIの土台であり、全面的なLOAM互換・Jane Street品質・POSIX非依存・
例外排除・フローティング編集枠や3色枠線の完成を意味しない。
