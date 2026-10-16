# LOAMの機能・見た目・使い勝手をBakhloで再現する

## 範囲

Bakhloは未運用で、旧UIの後方互換性は不要。LOAMの全ユーザー向け機能・回答・英語表記・
画面構成・キー・戻る／確認・細部までを対象とし、見た目だけの改修で終わらせない。
**予算配分・振替・消化・用途routing・Budget Windowだけは、実際に必要になるまで延期する。**
Daily Pace、支払い予定、隣接する非予算機能、盆栽の表示・成長は対象。
以前の現在利用だけ・盆栽成長除外は適用しない。予算用の先回りしたAPI・形式・hookは作らない。

英語先行。Bakhlo独自の日本語化は未定であり、LOAMのlocale切替等の互換に必要な実動作とは分けて照合する。
Bonsaiを先行し、Nottyを後から追加する選択肢も残す。LOAMのsourceはコピーせず、既存OCaml／
Bonsai環境と既存の純粋API・publication／保存経路を使う。内部構造・保存方式・証明装置を揃える必要はない。
不足する会計意味・独立情報を推測や偽の値で埋めず、必要な情報保持と回答・拒否を実装する。
LOAMが正データと普段の記帳先のまま。原本や以前の私用候補の変更、LOAM build、
新依存、全家計移行・自動同期・運用切替をこの計画で許可しない。

画面ごとのF/O/V/Q差分・現在進捗・依頼カードは
[UI差分台帳](../docs/LOAM_UI_GAP_LEDGER.ja.md)だけで管理する。
この文書は作業の順序と端から端までの受入条件を所有し、第二の画面別進捗表を作らない。

## 現行の順序付き受入計画

以下は継続する作業順であり、全sliceを今回のターンで実装する指示ではない。
先行sliceの限定成功を後続画面へ流用せず、一つずつ実装から保存・対照実行・実機受入まで進める。
下記の未チェックは全体の受入未了を示す。既存の部分実装・限定検証を未実装へ戻す意味ではない。

### 全slice共通の受入証拠

- **実装**：日常の入口から対象選択・入力・確認・取消／確定・親復帰まで接続する。
  必要なID・対応・独立根拠を保持し、正確な量、不明／ゼロ、未対応／拒否を区別する。
- **self-check**：純粋計算・controller・描画geometryと必要な保存／再読込の合成回帰を残す。
  これだけでLOAMの実行一致や人間の使いやすさの受入済みとはしない。
- **対照実行**：固定したLOAM既存binaryとBakhloに、同じ意味の合成fixture・日付／設定・
  操作列・端末寸法を与える。回答、拒否、遷移、表示と保存後の再起動状態を照合する。
  ソースにあるだけの挙動、binaryで未確認の挙動、未実行は区別して残す。
- **手動受入**：通常・狭幅・低い端末、resize、長文・日本語／IME・巨大数量・空／不明のケースで、
  可視入力と実カーソル、候補・focus・選択追従、戻り位置、通知の安定、確認全文を実際に操作する。
- **保存・失敗**：閲覧／取消が非保存で、明示確定だけが保存すること、保存内容が終了・再起動後も
  同じ意味で復元することを確かめる。読込不正、保存失敗、stale／競合、結果不明では成功を偽らず、
  旧状態・必要な下書き・対応を守り、不明な保存を自動再試行しない。
  意図的な取消での下書き保持とcold restartでの永続化を混同しない。
- **記録**：各証拠の対象source／binary・fixture・操作・寸法・結果・未確認範囲を既存検証記録へ、
  画面別の到達段階はUI差分台帳へ記す。P7／電源断耐久・運用認定は別の未解決条件であり、
  UI受入や通常再起動の成功で閉じない。

### 実施順

1. [ ] **比較基準と共通合成fixtureを固定する。** Bakhlo／LOAMのsource commit・作業ツリー差分と、
   使用する既存LOAM binaryの識別情報／hashを記録する。sourceとbinaryが異なる場合は明示し、
   buildで黙って揃えない。同じ意味の合成明細・予定・観測・設定を両側の私用コピーへ用意し、
   正常・空・不明・拒否・訂正・返金・複数通貨・保存失敗を再現できる比較前状態を保全する。
   元データや私用取得内容をfixture・公開記録へ移さない。Home／Commands／各入口から
   LOAMのユーザー向け機能を棚卸しし、以下の列挙にない非予算項目もUI差分台帳へ関連付ける。
   2026-10-16: 現行ソース資料からLOAM `bb208173`／Bakhlo `6b676c5`の影響点をUI-01〜34へ反映し、absent-rootを80×24で限定比較した。別の新規合成rootsでfirst-run、wallet／food admission、JPY scale 0のRecord `paired snack`（wallet -37／food +37）、Preview／Publish、Actual表示とcold reopenを両UIで実行（[証拠](../docs/VERIFICATION.md#fresh-root-paired-record-and-cold-reopen-2026-10-16)）。これは単一の正常記帳ケースのみ。空／不明／拒否／訂正／返金／複数通貨／保存失敗fixture、LOAM source/binary対応、初期化Escape対照は未確認。全面受入は未了。
   UI-34 first-run実装を接続。interactive `--book FILE`のmissing sourceでは選択pathを初期destination、
   unreadable existing sourceではblank destinationにする。Measure identifier／scale 0–9を検査し、
   出力先・Measure・scale・履歴等を作らない意味をreview、2段目Enterだけが確定する。
   `Daily_book.empty`は明示的な空Locus policyとMeasure一つを作り、最初のLocusを既存Manage Lociで
   admission可能。`Daily_file.create_empty`はexclusive mode-0600・file sync/readback・parent sync・
   cold loadを行う。source／既存destinationは保全。20×5ではconfirm拒否、resize後に続行。
   `./tools/check`、`./tools/build-bonsai-tui`、`./tools/tui --self-check`成功。80×24合成PTYで
   jpy scale 2をreview→20×5 Enter拒否→80×24で作成→Home起動、`--check` cold reopenを確認。
   別PTYでunreadable sourceはblank destination、Escapeで非保存・source hash維持。非TTY missing
   `--book`は既存拒否を維持。既存destination拒否・bytes保全はself-checkで確認。
   fresh-rootの単一Record対照を実施済み。LOAM初期化Escape対照、人間のIME受入、P7／運用認定は未了。[UI-34証拠](../docs/VERIFICATION.md#first-run-empty-book-creation)／[paired証拠](../docs/VERIFICATION.md#fresh-root-paired-record-and-cold-reopen-2026-10-16)。
2. [ ] **共有機構を利用元横断で移行・受入する。** 責務・API・全利用元・受入条件は
   [TUI共有部品の責務設計と移行順序](../docs/TUI_LAYOUT_STABILITY_ROADMAP.ja.md) に従う。設計確定のみで実装済みにはしない。
   - 共有input／再帰Input metadataの純粋機構は実装・境界検査・native幅の直接smoke済み。既存Daily_form・tail・native widthを再利用。
   - Ui_formとstyled frame、Modal_form・Jump・Search overlay・Reversal Dateと直接利用元checksは移行済み。
     cursor_offsetとReversalの独立caret計算を削除。Core/native検査と合成tmux成功。LOAM対照・本人受入は未了。
   - RecordのColumns＋recursive caretを同時切替し、Scheduledの同じ入力表示・UTF-8文字移動・focus-following・notice予約・均一幅を接続済み。Sch.cursor_positionを削除し、renderer matrix（8寸法×3テーマ）へScheduled_createを追加・合格。
   - list/detailは既存Ui_panelを維持し、Actualのterminal_geometryをpanel_geometryへ統一、wide tx_heightのpage_size容量整合、
     controller経由のdrill-down/back復帰でAct.returned_from_detailを接続。復帰時の別browser上書きと詳細focus／scroll消失を修正し、限定回帰・合成PTYを確認。横断受入は未了。
   2026-10-17: paired Actual search at 80×24 returned one distinct record each for `paired` and `other`, zero for `zzzz`, and both after Escape. In the rebuilt Bakhlo binary, active `/paired` survived resize to 48×14 with full `+37 jpy`; `/other` at 48×14 showed full `+11 jpy`, and Escape plus restore to 80×24 showed both records. The 32×9 Description-only result is from the previous binary, not rerun after the fix. Authority hashes were unchanged ([evidence](../docs/VERIFICATION.md#paired-actual-search-2026-10-17)). Search/amount checks remain bounded, not full consumer acceptance.
   Actual長文検索のG-2限定成功は保持するが、G-1/G-3/G-4や全画面を完了扱いしない。
   幅0／1、長文・CJK、通知、通常／compact、resize、取消でpaintとcaret・保持値・draftを確認する。
   sessionごとのreview／保存gateを維持し、実装・対照実行・本人受入を別々に記録する。IMEは実機で別途受入する。
3. [ ] **Record lifecycleを端から端まで揃える。** 起動／親日付からの新規入力、候補・prefix検索、
   Posting追加／削除・差額補助、focus・キー・paste、Preview全文・末尾／狭小gate、
   Publish／Edit／Cancel、下書き再開・別操作との分離、確定後の親選択まで照合する。
   記帳→終了→再起動→Actualで同じ内容を確認し、失敗／競合で非保存・下書き保持を確認する。
4. [ ] **Actual／Selected Dayを揃える。** Loci／Actuals／Details、検索・対象日／scope・sort、
   選択・詳細scroll、Selected DayのActual／open予定・role-aware集計、親への復帰を確認する。
   訂正・日付変更・Merchant／原額・返金／反転等は、入口だけでなく必要情報・独立確認・
   保存後の同一性／対応と再起動まで照合する。未接続情報を表示だけで取り繕わない。
5. [ ] **Scheduledを揃える。** List／Series Calendar／Months／Plan Detail、単発作成、
   replacement・日付付きcancel、実績化、次回／複数回／期限までの補充、Expected paceを確認する。
   専用確認・tiny gate・取消初期選択、支払済み／取消済み拒否、Actualとの一括対応、
   再起動後のopen／completedと二重発行拒否を含める。予定の未供給を「義務なし」にしない。
6. [ ] **Balances／Observeを揃える。** 初期表示・Current／Accounting・履歴、数量の根拠と
   不明表示、同時観測画像・複数座標・既存支持の扱い、独立確認と保存後の再照会を照合する。
   正確なゼロ、存在のみ既知、根拠なし、失敗を区別する。Locus／role設定に必要な意味も接続する。
7. [ ] **Daily Pace／Trendを揃える。** 明示Pool・通貨・観測日・期間、現在値／What-if・負数、
   Pool／期間設定と履歴Trendの10d／30d／Month／Cycle／Previous Cycle、履歴支持・推移を照合する。
   予定控除・日数・整数演算、欠損／曖昧条件の拒否、設定取消・保存・再起動と既存preset保全を含める。
   Daily Paceを予算扱いして延期せず、月末や名前から条件を推測しない。
8. [ ] **Attention／Settlement／Exchangeを揃える。** Attentionの期限の意味・追加／解決／撤回、
   SettlementのActual／Effect配分・部分精算・相殺・非支払減少・独立した通貨／証拠・訂正、
   Exchangeの両数量・対応・専用Previewと復帰を照合する。累計sidecarだけを完全な精算としない。
   不正読込・参照欠損・保存失敗・競合と再起動を含め、複数ファイル原子性を勝手に保証しない。
9. [ ] **残るReports／setup／exportとその他の棚卸し不足を閉じる。** Income & Expense、
   Stock–Flow、Transactions Flow、Multicurrency Spend、Liquidity等の回答・期間・比較・寄与明細、
   Household setup、表示名／説明・一覧・通貨／scale・役割・期間設定、Help／Theme／locale、
   Print／診断・外部形式／Fava等の既存LOAM入口を照合する。盆栽の表示・成長も除外せず調べる。
   各項目の必要情報、設定／出力の保存先、同意・取消、再起動、失敗時の非破壊性まで確認し、
   派生出力を正データにしない。棚卸しの残りを再確認し、予算延期以外の無断除外を残さない。

## 過去の限定チェックポイント（現在の全面受入とは別）

以下のチェック済み行と検証記録は当時の範囲の証跡として保持する。
後続の実装有無・画面別進捗はUI差分台帳を参照し、旧方針の一時的な範囲限定を現行方針へ流用しない。

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
