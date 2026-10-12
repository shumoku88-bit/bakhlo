# LOAM 互換の英語 UI を Bakhlo で再現する

## 範囲

Bakhlo は未運用で、旧 UI の後方互換性は不要。現行 LOAM の英語表記・画面構成・キー操作・
戻る／確認の流れを基準に、同じ見た目と使い勝手を再現する。英語版を先に作り、
日本語UIを用意するかは未定。Bonsaiを先行し、Nottyを後から追加する選択肢も残す。
旧UIの復活は不要。LOAMの知見とBonsaiネイティブな能力を生かし、綺麗で派手ではない
モダンなTUIを、細部の操作感まで職人的に磨くことを目指す。Homeと基本的なRecordの改善を再開。
元の LOAM データ、私用候補、会計意味論、記帳・確認・保存の境界は変更しない。
LOAM の実装をコピーせず、Bakhlo の既存 OCaml / Bonsai 環境で実装する。

Calendar Home・Day / Month / Year・選択日・独立した操作画面・階層 Commands を採用する。
既存の純粋APIと記帳／保存経路を利用し、会計機能がない箇所を推測で埋めない。

## 手順

- [x] 中断で残った未接続モジュールを統合し、英語TUIをビルド可能な状態へ戻す。
- [x] 英語先行・日本語未定・Bonsai先行／Notty排除なし・UI操作互換を現行方針へ明記。
- [x] LOAMの現行ラベル・画面遷移・キー・確定操作を、対応するBakhlo機能と照合して受入条件を確定。
- [x] 英語の固定文言に翻訳入口を設け、表示文字列に依存する判断を安定した原因／型へ置換。
- [x] Calendar Home、日付／zoom／Detail／選択日と階層Commandsを実装。
- [x] Record／候補／確認／Actual／Scheduled／Balances／Daily Paceを共通の画面階層へ接続。
- [x] 不要な旧Homeサマリー・独自キー・互換経路を削除し、現行手順書を更新。
- [x] 純粋な日付・言語境界・実セル幅・操作・保存拒否をself-checkで検証。
- [x] 合成PTYで代表操作列、狭い端末、resize、取消／確定／cold readを確認。
- [x] 最終diffと未接続機能をレビューし、達成範囲と残る差を記録。
- [x] 英語UIをコミット・pushし、PR #26をマージ（534c71f）。TUI対象のGitHub CIは未設定、ローカル検査は成功。
- [x] 再開指示を受け、LOAMの共通化リサーチを確認。今回の範囲はHomeと基本Recordに限定。

## Home / Recordの仕上げ

- [x] Homeの余白・選択日・近接Detail・小端末の優先表示を整える。
- [x] Record / Previewを中央ペイン化し、小端末では入力可能な全画面へ畳む。
- [x] ネイティブ描画で枠・本文・フォーカスを分離し、操作の性質を枠色だけで伝える。
- [x] 下書き保持・保存ゲート・実セル幅・32×9 / 48×14 / 80×24・resizeを合成データで検証。
- [x] 実画面とdiffをレビューし、結果と未達範囲を記録して安全なチェックポイントにする。

### レビュー

Homeは空の大枠を縮め、80列付近で近接Detail、広幅で自然な高さの左右配置へ変更。
Recordは一つの入力枠へ整理し、中央表示でも親の日付を残す。極小端末の入力・下書きは継続可能。
枠・左右pane・選択日・実カーソルをBonsai Viewで局所的に組み立てる。データ内の`|`や`│`は
カーソル／枠として着色しない。会計の検査・publisher・元データは変更していない。

共通化判断は **KEEP**（既存の物理的な枠・セル幅処理）、**INLINE**（Home配置／Record入力）と
**DEFER**（別編集画面を含む汎用フォーム）。操作別のドメイン分岐を共有描画へ移していない。

`./tools/check`、最終`./tools/tui --self-check`、`git diff --check`成功。
3テーマ・8寸法の描画、狭い日曜選択、literal文字のスタイル、全警告、7故障＋7SIGKILLを検査。
最終合成PTY `scratch/ui-polish-final.rdDXLu`で80×24／48×14／32×9、長い日本語入力、70桁数量、
resize、Ctrl-S非保存、Edit／Cancel／Esc保持、Publishとcold readを確認。
通常入力とechoは復帰。既知のEXTPROCのみ消える差は再現し、完全なtermios一致は保証しない。
ユーザーの「キリのいいところまで」に従い次機能は停止。見た目の最終受入と全面LOAM互換は未達。

## 削除・置換の判断

旧 UI の操作別名や画面を維持するための互換経路は増やさない。
現在はBonsai先行。旧Notty画面・比較ベンチ・レイアウト試作・旧フォーム／閲覧経路は削除済み。
これはNottyを将来の実装対象から外す決定ではない。
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
先行実装と最終的な選択を混同しない。Bonsai先行をNotty排除、日本語未定を実装予定、
共通化の候補を共通化の必須方針へ勝手に格上げしない。

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
