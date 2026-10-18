# LOAM UI 差分・移行管理台帳

## 1. 読み方・比較基準

LOAMの**予算以外の全ユーザー向け機能・見た目・操作感・細部挙動**をBakhloへ揃えるための、画面別差分と受入判定の入口。
機能・保持情報・保存安全性は [CUTOVER_CHECKLIST.ja.md](CUTOVER_CHECKLIST.ja.md)、
描画・操作方針は [UI_DIRECTION.ja.md](UI_DIRECTION.ja.md)、
実際の検証範囲は [VERIFICATION.md](VERIFICATION.md) を参照する。同じ進捗表を新設しない。

- 対象：Home、Calendar、Record、Actual、Scheduled、Balances、Daily Pace／Trend、Attention、非予算Reports、設定・外貨・精算・出力を含む、LOAMの予算以外のユーザー向け機能。以下のUI IDは索引であって対象の上限ではない。未掲載の操作も棚卸しして追記する。
- 今は実装しない：予算配分・振替・消化・用途routing・Budget Window。必要になった時点で別途追加し、先行実装・予算用の拡張frameworkは作らない。Daily Pace・予定・非予算の残高／収支は除外しない。
- ユーザー指定の除外：Favaとhledgerへの出力。UI-02に残るFava ProjectionはLOAM側の棚卸し事実であり、実装・受入の対象ではない。他形式・Print／診断は別途判定する。
- 盆栽の成長等を以前の対象外指定だけで除外しない。LOAMの現物でユーザー向け挙動の有無を確認する。日本語UIの採用は未決定で、台帳内の日本語表示・入力は検証対象。
- 旧ソース棚卸し基準：Bakhlo `b21b30c`＋共通panel変更、LOAM `db631763`。この時点の記録は下記の現行比較 checkpoint で上書きせず、歴史的根拠として保持する。
- **現行ソース棚卸し checkpoint（2026-10-16）**：Bakhlo `6b676c5`、LOAM `bb208173`。LOAMは `db631763..bb208173` の `Loam/Tui` と `docs/TUI.md`／`docs/TUI_NON_BUDGET_WORKLIST.md` の差分を読み取り専用で確認（TUI 60ファイル変更）。現行契約から確認できた差分をUI-01〜33とUI-34へ対応づけた。さらにUI-34の未存在rootだけを使った80×24のpaired startup checkを実施し、既存binaryのhashと結果を[検証記録](VERIFICATION.md#first-run-comparison-2026-10-16)へ記録。これは初期化画面の限定比較であり、同じ意味のfinancial fixture・実データ対照・未記載挙動の網羅ではない。LOAM sourceとbinaryの一致も主張しない。
- 現行LOAMの影響点：盆栽Home／Calendarの詳細なrole-aware日次収支・help・復帰、Actualの初期scope／選択日切替、ScheduledのSeries Calendarと完了印、Reportsの11項目palette、Household setupの表示名・Balances表示対象・Daily Pace pool／cycle dates、first-run/unreadable-rootの明示的初期化。予算配分等・Budget Windowは引き続き対象外。詳細な対応先とBakhlo側の不足はUI-01〜04、12、23〜25、30、32〜34を参照。
- 最初の対照実行：Bakhlo `cfed583`＋Actual検索修正、LOAMソース `da4dfb65`。既存LOAM binaryのソース一致は未認定。binary hash・合成入力・操作列・結果は [VERIFICATION.md](VERIFICATION.md) のActual検索対照欄を参照する。
- LOAMの本番台帳・configを変更しない。運用切替・二重記帳・自動同期・storage研究の着手許可ではない。

### 差分は四種類に分ける

| 記号 | 種類 | 任せる内容 |
| --- | --- | --- |
| **F** | 機能・保持情報の不足 | API／モデル／永続項目／照会の設計・接続。見た目の修正では埋まらない |
| **O** | 操作・画面接続の差 | キー、focus、検索、確認、取消、下書き、戻り先、入口 |
| **V** | 見た目・配置の差 | 接続済み機能の枠・余白・整列・強弱・縮退。未実装機能を飾って代用しない |
| **Q** | 検証・安全性の残り | 同じ入力での回答／拒否、確定gate、失敗・再開、PTY、対照スクショ、人間の受入 |

複数の種類が同じ画面に残る。**Vが合格でもF/O/Qは完了しない**。
`試用接続`は入口から既存処理を試せること、`局部接続`は表記した部分だけ、
`未接続`は該当画面がないこと。型・表示名・routeの存在だけでは接続としない。

検証欄の `T` は既存の合成self-check、`P` は既存の合成native PTYの限定範囲。
今回ソースを確認したことと、テストを新しく実行したことを混同しない。
記載がない機能のテスト成功は推定しない。Actual検索の限定対照を全画面へ拡張しない。人間の実機受入・運用認定は未。

## 2. 共通の品質基準

| 基準 | 守ること |
| --- | --- |
| C-1 寸法 | 80×24／120×36と32×9／48×14。選択・リサイズ・長文・日本語でもcell幅と高さを守る |
| C-2 静かな表示 | 細い丸角枠、端末所有の配色、意味のあるfocusだけを強調。派手さを完成度にしない |
| C-3 安定した下部領域 | 操作案内・通知を確保。短い通知で揺らさず、長い拒否理由は隠さない |
| C-4 focusと選択 | 非active側も選択を保持。可視行に従うページ送り、末尾、戻り先、下書き再開 |
| C-5 数量 | 正確な符号・Measure・桁。長い値を途中で切らず詳細へ。異なる通貨、不明、ゼロを混同しない |
| C-6 確定と下書き | 閲覧・picker・Previewは保存しない。明示確定、全文確認、狭小拒否、競合／結果不明の停止を維持 |

LOAMの [TUI契約](../../loam/docs/TUI.md) と
[共有部品の点検方針](../../loam/docs/TUI_REFINEMENT_ROADMAP.md) を読む。
Bakhloの保存形式をLOAMと同じにする指示ではなく、永久Correction鎖の復活も要求しない。

### 操作単位の受入条件

各UI IDの作業は、入口から操作・確認・取消／確定・親への復帰までを一本の操作列にする。
保存する操作は再起動後の照合、保存しない操作は台帳bytesの不変も確認する。
同じ意味の合成データと同じ端末寸法で両方を実行し、以下を別々に記録する。

| 軸 | 合格の根拠 |
| --- | --- |
| F | 同じ入力に対する数量・対象identity・保持情報・回答／拒否が一致する |
| O | キー、focus、選択、検索、下書き、戻り先、確定／取消、失敗後の復帰が一致する |
| V | 同じ寸法・状態の実画面で配置・余白・強弱・省略・スクロール・caretを比較する |
| Q | 通常／空／長文・日本語／狭小・resize、対象の競合・保存失敗・結果不明を実行する |

`実装`→`自動検証`→`対照実行`→`本人の受入`を混同しない。全部の列が閉じるまで画面全体を完了としない。
LOAMの内部構造・保存形式・研究基盤の移植は目的ではない。比較中にLOAMが進んだら基準変更を明記し、
古い証拠を残したまま影響する操作だけ再比較する。先に全機能用の共通基盤を作らない。


## 3. 画面別差分（UI-01〜UI-33）

各行は依頼の全範囲ではなく、下の依頼カードで切るための入口。詳細な機能境界は機能判定表を優先する。
既存の視覚改修・監査は、そのスライスの成果として保持し、画面全体の互換合格へ拡張しない。

| ID | 面 | Bakhloの現行接続 | 残差の種類と内容 | 既存検証／担当メモ |
| --- | --- | --- | --- | --- |
| **UI-01** | Home／Calendar | 試用：固定盆栽Home、Day／Month／Year、期間内Actual／open予定のDetail | **F** role-aware日次収支・月年集計。**O** LOAM Bonsai Home↔Calendarの復帰、全文Help／key grammar等。**V/Q** 配置・縮退・同一操作対照と本人受入 | 現行LOAM：通常起動で6入口の盆栽Home、Calendarは日次role-aware money grid（wide）／週ナビ＋Detail（compact）、Actual／open予定／Pending根拠、全画面Help。BakhloはUI対照・同一収支根拠が未了 |
| **UI-02** | Commands | 試用：階層palette、実装済み入口（Transactions、Plans and attention、Reports and analysis、Household setup） | **O** 残るレポート等の入口差。**V/Q** 同一rectangle・選択・短い端末で対照 | 現行LOAMはReports/analysis 11項目とHousehold setupを公開。BakhloはHousehold setup（Theme, Manage Loci, Daily Pace pool/cycle dates, Balances visible accounts, Home）を接続。予算2項目は延期、残る非予算レポート等を継続追記 |
| **UI-03** | Actual一覧・検索・詳細 | 接続済み：3ペイン、Locus絞込、live検索、scope／sort、Detailsスクロール、Enter一回で選択明細、tx_height容量整合、Selected_dayからのdrill-back。復帰時の別browser上書きと詳細focus／scroll消失を修正 | **O/V/Q** 現行LOAMとのheader・pane・枠・footer、全操作・実IME／本人受入が残る | 現行LOAMはAll Current／newest-first、`f`で選択日／全件を切替。80×24の検索、48×14の完全な`+37 jpy`／`+11 jpy`、32×9の検索保持、長いCJK検索末尾／caret、5寸法の空台帳／0件表示を限定確認（[検索証拠](VERIFICATION.md#actual-empty-search-and-cjk-resize-follow-up)）。後続対照で検索確定＋scope／sort、空Enter拒否、一覧からEnter一回→32×9／48×14で親pane・検索・並び・選択復帰、明示`i`からのDetails復帰を確認。authority hash不変。[往復証拠](VERIFICATION.md#actual-single-enter-and-filtered-return)。全組合せ・Locus操作対照、他のcaret／寸法、IME、人間の受入は未了 |
| **UI-04** | Selected Day | 試用：選択日のActual／open予定とDetail。ActualからEnter一回で明細IDに追従し旧Selected Dayフィルタを解除、親Actualへ復帰。`d`日付訂正を接続。context行はroute日付＋Day表示 | **F** role-aware収支、Merchant／原額等。**O/V/Q** LOAMの専用Transaction detailとの画面差、混在一覧・空・狭小と対照受入 | T：同日複数明細＋旧filterでも選択IDを開く回帰を3寸法で確認。親復帰で別browserを上書きせずpane／scrollを保全（[往復証拠](VERIFICATION.md#actual-single-enter-and-filtered-return)）。背景Calendarの誤日付／zoomをcontextへ表示する不整合を修正、4寸法×3zoom×draft有無とnative resize／Record初期日を限定確認（[context証拠](VERIFICATION.md#selected-day-context-date-and-zoom)）。日付訂正の保存／cold／親ID追従。新規Recordは表示中の日を初期値とし取消／resume／保存／cold／親Actual復帰を確認（[記帳証拠](VERIFICATION.md#selected-day-record-date-and-return)）。全画面の受入ではない |
| **UI-05** | Record入力・Locus候補 | 試用：Date／Description／Measure／複数Posting、許可済み候補 | **O/V/Q** 対照受入・実機検証待ち（ブラッシュアップ完了）。**F/O** 原額（UI-07）は未接続 | T：Unicode、paste、構造制約、追加行、floating／極小。P02完了：Movement上部枠＋横並びマルチペイン化、狭小Fields縮退、Locus前方一致（LOAM isPrefixOf準拠）、Date入力ガード、draft誤再開防止、resolve_overlayによるカーソル位置・描画座標の完全同期（macOS IME安定化）。[80×24の単発Record対照](VERIFICATION.md#paired-record-happy-path-and-cancellation-2026-10-16)：入力・数量・cold一致、Ctrl-S／Esc後の下書き・配置差が残る。閲覧中Ctrl-Nは即破棄でなくKeep初期選択の確認へ変更。狭小拒否・不明結果の保持・非保存をchecksと合成PTYで限定確認（[証拠](VERIFICATION.md#retained-draft-discard-confirmation)） |
| **UI-06** | Record Preview | 試用：Publish／Edit／Cancel、exact全体確認、狭小確定拒否 | **V/Q** 対照受入・実機検証待ち（ブラッシュアップ完了）。全文gateを弱めない | T：巨大数量、キー／支払リンク、狭小・未読末尾の拒否。P02完了：Publication gate（recheck evidence + Locus admission）案内行、中画面縦3段レイアウト、枠線・ボタン整列、キャレット17カラム化、全文gate維持を実装・検証完了。単発Preview→取消非保存／Publishの[対照](VERIFICATION.md#paired-record-happy-path-and-cancellation-2026-10-16)、Edit／Cancelと[狭小gate対照](VERIFICATION.md#paired-record-editcancel-and-narrow-preview-gates-2026-10-16)を実施。LOAM既存binaryは32×9で確認本文が全て隠れたままPublishできたため、Bakhloの拒否を弱めない。[単独の保存失敗実機試行](VERIFICATION.md#record-native-pre-write-filesystem-failure-2026-10-16)ではBakhloのdraft／旧bytes保持と再試行停止を確認。LOAM保存失敗対照・表示順・幅・他モードは未受入 |
| **UI-07** | Original amount | 接続済み：Record Ctrl-O入力、Preview、同一保存操作、Actual詳細、再起動、訂正時保持、年別保存・バックアップを端から端まで接続 | **V/Q** 対照受入・実機検証待ち。換算値での推定・FX捏造なし | F03完了：application/original_amounts.*再利用、正数量・安定root制約、通常・取消・保存失敗・stale・結果不明・年越し検査合格 |
| **UI-08** | unresolved有効化 | 試用：Ctrl-Uによる貸借差額自動補完（suspense行追加・調整・削除）接続済 | **F/O** 未解決語彙の明示admission・元draftへの復帰。**Q** 拒否 | T：Ctrl-U差額ゼロ時削除、符号反転補完、Posting上限（6行）ガード、単一S式保存。LOAM Unresolved remainder仕様準拠 |
| **UI-09** | Actual Correction | 試用：Record系Edit／Preview、同一ID・Postingキー／構成／符号・支払対応保持 | **O** LOAMの表現可能範囲・操作対照。**V/Q** 注意枠、原内容と確認内容。対応外shapeは拒否 | T：符号／構成lock、ID・キー・payment link保持。日付訂正で並び順が変わっても同じID・詳細focusへ復帰し、検索対象外は通知。合成controllerでfilter／sort／Locus／scroll保持と対象外を検査、80×24 PTYで訂正保存・48×14縮小・cold確認。[証拠](VERIFICATION.md#actual-correction-publication-return)。LOAM対照・本人受入は未了 |
| **UI-10** | Actual日付変更専用 | 試用：Actual／Selected Dayの`d`→専用Date／Preview→既存置換writer。日付以外の明細・支払対応を保持 | **O/V/Q** LOAM対照・本人受入、関連shape全域の照合は未了。Records置換は既存制約で拒否 | T：暦検査、長いtarget末尾、tiny／paste／stale／Records／保存失敗、draft・キー・paid-plan保持、cold・親ID追従、8寸法×3テーマ。合成PTY：取消非保存、32×9拒否、80×24保存・終了再起動。[証拠](VERIFICATION.md#actual-date-only-correction) |
| **UI-11** | Reversal入力・確認 | 試用：x→専用Date／exact inverse Preview→既存writer。元Actualは残る | **O** LOAMのrとの入口差。**V/Q** 対照表示・実機受入。後続modal・P7には保証を拡張しない | T/P：固定target／base、元・逆Postingの正確な数量、末尾／狭小gate、取消／下書き、stale／失敗／unknown停止、cold、resize寸法。反転の限定sliceはP05で完了 |
| **UI-12** | Scheduled Series Calendar | **未接続**：Home sはcurrent-open List | **F/O** Series内の明示open／completed証拠、Calendar初期月・日付／完了印、継続・補充・coverage連携 | 現行LOAM Calendarは当月始まり、予定日＋`✓`で完了を識別し、共有Reviewからopen／completedの月内存在を再構成。取消・置換元・未成立の完了参照を混同しない。Bakhlo未接続、Series/coverageを推測しない |
| **UI-13** | Scheduled Plan Detail | 局部：単発occurrenceのExpected Effects／due／ID | **F/O** Series内の複数日・監視／継続文脈なし。**V/Q** 単発detailの対照 | T/P：Actual共用の枠・端・ページ・resize・focus・draft／取消復帰 |
| **UI-14** | Scheduled Months | 試用：`v`でList↔明示open予定の6か月board。2列×3段・月移動・件数・ID選択追従・exact詳細・compact/List復帰、既存作成／編集／完了／取消へ接続 | **O/V/Q** LOAM対照・本人受入、Series/coverageとのview cycleは未接続。周期／充足を推測しない | T：年跨ぎ・当月下限／9999上限・極端shift、Listのfilter/ID保持、split／巨大数量、カード内追従、狭小、取消cold。8寸法×3テーマ。合成PTY：120×36／80×24／48×14／32×9、親復帰・非保存。[証拠](VERIFICATION.md#scheduled-months-projection) |
| **UI-15** | Scheduled List | 試用：current-open予定一覧、選択・詳細・作成／編集／完了／取消操作 | **O/V/Q** 現行LOAMとの初期選択・filter・一覧整列・detail復帰・固定ナビを対照 | LOAM側のUI polish完了。機能有無と見た目／操作受入は別。Series Calendar (UI-12)・Months (UI-14)と混同しない |
| **UI-16** | Scheduled作成 | 試用（移行順3接続済み）：独立`scheduled_session.ml`。共有input_text、UTF-8 move_cursor、Ui_panel field windowing、1行notice予約・overflow、均一幅padding。Sch.cursor_position撤去。renderer matrix（8寸法×3テーマ）合格。Due、固定通貨、2〜6 Posting、Dateガード、Locus prefix、Ctrl-U、Preview gateと既存writer接続。Record draft分離 | **F/O** recurring／監視／補充は別。**V/Q** LOAM対照・実機受入が未完了 | LOAM作成UIは通常配置で共通floating surface化、narrow fallbackあり。作成後Expected pace選択と再読込は独立。Bakhloとの表示・操作比較、実機受入は未 |
| **UI-17** | Scheduled完了 | Bakhlo試用：既存PlanからActual作成・完了を接続 | **O/V/Q** 元Plan ID／期日保持、Actual日付・説明・Posting編集、確認全文・狭小拒否・resize・Cancel非保存・親復帰を対照 | LOAMはList／Selected Dayから共通floating completion form。完了後の次予定案内／Attentionは別遷移。Bakhlo既存対応の画面比較と操作受入は未 |
| **UI-18** | Scheduled取消 | 試用：`x`→取消日→独立Expected Effects Preview→Keep初期選択／明示Cancel→既存writer。取消planを保持 | **O/V/Q** LOAM対照・本人受入。既存dated-cancel契約のためLOAMと違い日付入力を残す。Recordsは拒否 | T：日付・末尾／狭小・paste・draft保持、stale／reload／保存失敗／Records拒否、Keep初期化、cold保持・再操作拒否。8寸法×3テーマ。合成PTY：80×24 Keep／確定／cold、32×9拒否。[証拠](VERIFICATION.md#scheduled-cancellation-preview) |
| **UI-19** | Scheduled置換 | 試用：単発planのEdit／Preview | **F/O** Series／monitoringとの連動なし。**V/Q** 元予定・置換内容・候補の対照 | T：Plan_edit、ID保持、paid／cancelled拒否 |
| **UI-20** | Scheduled batch amount | 試用：Scheduled／Selected Dayで`b`→新金額・開始日・終了日（任意）入力→同一正負Locus・通貨のopen予定候補一覧（初期非選択・`[ ]`）→Space/a/dで選択→Previewで置換前後の差分確認→Back（初期選択）／Publish all。全候補を1台帳へfoldして既存writerで1回のみ原子発行 | **O/V/Q** LOAM対照・実機受入。split予定は配分を推測せず個別編集として除外。Records形式は拒否 | T：金額・期間検査、開始日以降絞り込み、Space/a/d/e操作、split除外、未変更除外、Back初期選択、末尾・狭小gate、draft・stale・Records拒否、巨大EUR、原子保存・cold再読込。[証拠](VERIFICATION.md#scheduled-batch-amount-editing) |
| **UI-21** | Scheduled生成 | 試用：Scheduledで`g`→終了日（Through排他）・周期（Monthly／2m／3m／6m／Yearly）入力→指定期間の候補予定一覧（日付・金額・Locus構成）をプレビュー生成→Cancel（初期選択）／Publish all。全候補を一括で1台帳へ`B.put_plan ~replace:false`で原子追加発行。周期やシリーズ同一性は事実にしない | **O/V/Q** 実機受入・LOAM対照。Scheduled coverage（UI-23）の常時監視設定は別 | T：開始後期間計算、閏年・月末日クランプ、候補件数・日付・金額保持、Cancel初期選択、末尾・狭小gate、stale停止、原子的一括コミット・cold再読込。8寸法×3テーマ。合成PTY：g起動、Through入力、プレビュー確認、Cancel非保存（ハッシュ一致）、Publish allによる原子生成・5件追加、cold再読込。[証拠](VERIFICATION.md#scheduled-occurrence-generation) |
| **UI-22** | Scheduled継続／補充 | 試用：支払い完了後の独立Prompt（後日同一正Locus予定のKeep／Review／Add、またはDone／Defer／Add next）。期日は推測せず空日付で作成エディタを開く。DeferはAttention（Due_undetermined）へ保存 | **O/V/Q** LOAM対照・実機受入。Series監視cadenceや期間一括補充（UI-21）は別。周期やシリーズ同一性を推測しない | T：完了後Prompt、後日正Locus候補選定、Review末尾・寸法、Add空日付／独立作成・EUR量保持、Defer非同期Attention保存、stale／不確定ガード。8寸法×3テーマ。合成PTY：完了後Prompt、Keep非作成、Add次予定作成・Cancel保持、冷起動。[証拠](VERIFICATION.md#scheduled-continuation-awareness) |
| **UI-23** | Scheduled coverage設定 | 未接続 | **F/O/Q** Expected paceをreplaceable観測設定として保持・接続 | 予定authority／NotDueを捏造しない |
| **UI-24** | Balances Current | 試用：Current／Accounting、Detail・Print。UI-24-B2は現Measure候補picker（j/k・Space・Review・Edit／取消）、他Measure・過去選択保全、空選択0件／不正設定Unavailableを接続。初期座標・狭幅の完全金額／詳細cueは保全 | **O/V/Q** Current列見出し・80列上下配置、Accounting・Print／外部出力対照、全条件のruntime／本人受入。role保存安全境界は別 | 前段の4寸法対照を保持。B2は合成native検査、LOAM binaryとのpicker選択／Review／取消／保存・cold、狭幅追従／確定拒否を限定確認。[B2証拠](VERIFICATION.md#ui-24-b2-balances-picker-and-grouped-observation-2026-10-18)／[表示証拠](VERIFICATION.md#pace-history-and-narrow-balances-paired-2026-10-18) |
| **UI-25** | 非予算Reports | 局部接続：Commands→AnalysisからIncome & Expense、Transactions Flow、Stock–Flow。Stock–Flowは明示された`balance-view.tsv`座標のみ・単一Measure・ゼロ起点履歴＋独立支持を要求 | **F/O/V/Q** 現行LOAMの残りの対象内Report（Trend/Locus comparison、Balances/Accounting、Liquidity、Multicurrency Spend、Reports/Balances等）、比較・期間・操作・表示・安全性の差を個別照合。予算Reportは延期、Fava Projectionはユーザー指定で対象外 | LOAMは11項目のReports palette。Bakhloで入口がある上記3件以外の対象内Reportは未接続または未確認。Stock–Flowの旧smoke正確性証拠は撤回済み。現行検証成功・財務正確性認定なし |
| **UI-26** | Attention | 試用：LOAM準拠の期限管理・タスク一覧。Home期限バッジ（`[i] attention (! N overdue)` / `(today)` / `(N)`）、Due列・Matter二列整列、超過シグナル（`! YYYY-MM-DD`）、Add（`n` / 3状態: 日付指定・未定・期限なし）、Resolve（`r` / 完了）、Drop（`x` / 破棄）、右ペイン詳細・緊急度判定、`Tab`スクロール切替 | **V/Q** 実機受入・LOAM対照 | T：strict load、Unavailable、stale save／失敗draft保持、超過期限判定、Homeバッジ連動。合成PTY：Homeバッジ表示、n追加、超過signal表示、Tab詳細確認、r完了・x破棄、Home復帰・バッジ消去。[証拠](VERIFICATION.md#attention-administration) |
| **UI-27** | Settlements一覧 | 局部：commitmentの累計settled／extinguished／outstanding sidecar | **F/O** LOAMのActual／Effect配分・通貨・group／参照の保持と照会。**V/O/Q** 現行限定一覧の数量・page／端・対照 | T：不正／重複／参照、巨大数量、stale／cold。完全なSettlementではない |
| **UI-28** | Settlement action | 局部：累計Settle／Reduce／Retractの試用操作 | **F/O/Q** 実取引対応・独立証拠・訂正／撤回・Previewの全体差 | sidecar actionはActualを記帳しない。払込の代用にしない |
| **UI-29** | Exchange | 試用：両通貨・数量入力→独立Preview（`Publish Exchange` / `Edit`）→既存publisher | **O/V/Q** 入力候補・From／To横並び整列・LOAM最新geometryの実物比較と実機受入 | T：exact両数量、1段目Enter非保存Preview、狭小拒否、Esc入力復帰、Exchangeキー、cold readback（[証拠](VERIFICATION.md#locus-display-names--exchange-preview-gate-2026-10-17)）。LOAM対照・実機受入は未 |
| **UI-30** | Manage Loci／roles／display names | 試用：admit、明示role設定、display name／help編集（`l`/`e`およびHousehold setup `Account / category display names`）→Review→保存、一覧・detail表示 | **O/V/Q** LOAM対照・実機受入。role設定永続化の安全境界は別 | T：Locus label／help検証（最大80文字・制御文字拒否・未承認Locus拒否）、Review非保存・狭小拒否・Esc復帰・単一S式保存・cold再読込（[証拠](VERIFICATION.md#locus-display-names--exchange-preview-gate-2026-10-17)） |
| **UI-31** | Observe quantities | UI-24-B2：同時確認した複数座標をAdd→Preview→Publish、Editで行・未追加入力保持、取消非保存。既存Coreの一グループ更新で未指定観測を保全 | **O/V/Q** LOAMと異なるframed modal／小数入力、広い支持family・annual／Recordsの対照、実IME／本人受入。P7は別 | 合成UI coldで複数座標・ゼロ・負数・別通貨、重複／支持衝突／競合／古いbase拒否。実保存失敗のuncertain停止・reload後再送拒否。既存LOAM binaryでも複数行保存／cold・重複／ゼロ起点衝突を限定確認。[証拠](VERIFICATION.md#ui-24-b2-balances-picker-and-grouped-observation-2026-10-18) |
| **UI-32** | Print／export／外部表示 | 局部：Balancesの画面内Print previewのみ | **F/O/Q** 同意付き通常端末出力、対象内の外部format、Reports/Balances Print／再開。**V** 現行preview。Fava・hledger出力はユーザー指定で対象外 | codec読取をexport対応と数えない。LOAM Reports/Balances Printは画面内previewを超える別経路。外部format全般の除外は推定しない。O03〜O05 |
| **UI-33** | Daily Pace／Trend／設定 | 試用：現在量・明示Pool／一意period・What-if・Pool／境界Review、5プリセット、Braille整数グラフ。上段全幅グラフ＋下段History／Selected day、Spent／同日Pace diff列、予定支払い・反転を分ける日別活動と隣接日の整数内訳を接続 | **F** 今日一致・移動clamp・設定保護は検査済み。現在観測だけの過去Pace推測を修正し、全Pool座標のゼロ起点支持がなければunknown。dated支持・支払済み／取消済み予定を含む全履歴は未認定。**V/O/Q** 3ペイン・列整列は前進。LOAMと異なるcontext／footer／件数・詳細順序／focus・キー・単一点目盛り、実機IME／本人受入が残る | 2026-10-18の新規合成2組で対照：現在量74,500・予定12,000・Pace4,464、Spent1,000・同日差+3,464。current-onlyは1/10日だけ既知、ゼロ起点＋明示初期入金は10日分Pace／Spent／差が一致。120×36／80×24／48×14／32×9、未知日詳細・style・戻り・cold reopenを確認。旧F完了を全面認定に使わない。[新証拠](VERIFICATION.md#pace-history-and-narrow-balances-paired-2026-10-18)／[前段](VERIFICATION.md#daily-pace-paired-comparison-and-braille-graph-2026-10-18) |
| **UI-34** | First-run／Unreadable household | 局部：interactive `--book FILE`のmissing／unreadable first-run、空v3 book＋明示Measure／scale、既存Manage Lociから初Locus admission | **F/O/V/Q** LOAMのdirectory rootとBakhlo単一fileの差、LOAMの未存在root起動・初回設定全体・実機操作は未受入。Permission／失敗境界と運用保証も別途確認 | 80×24 PTYでreview→tiny拒否→resize→exclusive作成→Home／cold `--check`。unreadable sourceはblank先・Escape非保存。fresh-rootのpaired RecordではBakhlo first-run＋Locus admission・保存／coldを実行（LOAM側rootは`loam init`）。self-checkで既存target/source bytes保全・非TTY拒否。詳細：[first-run証拠](VERIFICATION.md#first-run-empty-book-creation)、[paired証拠](VERIFICATION.md#fresh-root-paired-record-and-cold-reopen-2026-10-16)、[契約](HANDOFF.md) |

UI-34限定更新（2026-10-17）：合成missing-rootの80×24対照で、両UIのreview Escが
入力値を保持して戻り、入力Escで非保存終了することを確認。Bakhloの即終了差を修正し、
BakhloのEditボタンと再reviewも非保存で確認（[証拠](VERIFICATION.md#paired-first-run-review-cancellation-2026-10-17)）。
別の既存unreadable合成rootの80×24対照では、両UIが新規先を空にし、別の未使用先のreview／
Esc復帰／取消を非保存で完了。元rootを新規先にするとLOAMはreview後、Bakhloはreview前に
既存先を拒否し、双方元bytes不変（[証拠](VERIFICATION.md#paired-existing-unreadable-root-first-run-2026-10-17)）。
別の合成unreadable sourceから、80×24で新規destinationのreview非保存→明示確定→Home→
cold reopenを両UIで確認。元入力・新規authorityのhashは再起動後も不変
（[証拠](VERIFICATION.md#paired-unreadable-source-creation-and-cold-reopen-2026-10-17)）。
32×9ではLOAMのreview→Esc→入力Esc、BakhloのResize／Escを非保存で比較。48×14では
Bakhloが保存先を隠したまま作成できる反例を修正し、修正版は拒否→80×24で全文確認後に
作成・48×14でcold reopen。LOAMは48×14の省略されたreviewから作成・cold reopen。
故障・IME・初回設定全体の受入は未了
（[証拠](VERIFICATION.md#paired-narrow-first-run-and-hidden-destination-gate-2026-10-17)）。

### ソース対照の入口

LOAM側はread-only参照。詳細な保持／writerは各sessionの先を読む。画面名が同じことだけで意味の一致を推定しない。

| 面 | Bakhlo入口 | LOAM入口（`loam/Loam/Tui/`） |
| --- | --- | --- |
| Home／Commands | `bonsai_daily.ml`、`daily_overlays.ml`、controllerのCalendar／Commands描画、`ui_commands.ml` | `Home.lean`、`HomeCommandPalette.lean`、`ReportPicker.lean` |
| Record／Actual／Selected Day | `record_session.ml`、`reversal_session.ml`、`date_correction_session.ml`、controllerのedit／reverse／date／Actual／Selected_day | `Record.lean`／`RecordSession.lean`、`ActualWorkspace.lean`、`SelectedDay.lean`／`SelectedDaySession.lean`、`ActualDateCorrection.lean`、`ActualReversal.lean`／`ActualReversalSession.lean`、`EventMerchant.lean` |
| Scheduled | `ui_workspace.ml`、`scheduled_months.ml`、`scheduled_session.ml`、`scheduled_cancellation_session.ml`、`scheduled_continuation_session.ml`、`scheduled_bulk_session.ml`、`scheduled_generation_session.ml`、`record_session.ml`、controllerのScheduled／cancel／bulk／generate | `ScheduledWorkspace.lean`／`ScheduledWorkspaceSession.lean`、`ScheduledCreation.lean`、`ScheduledCompletion.lean`、`ScheduledCancellation.lean`、`ScheduledReplacement.lean`、`ScheduledBulkEdit.lean`／`ScheduledBulkEditSession.lean`、`ScheduledGeneration.lean`／`ScheduledGenerationSession.lean` |
| Balances／Reports／Pace | `daily_overlays.ml`、`balance_view_data.ml`、`daily_pace_trend.ml`、controllerのbalance／pace／what-if／trend | `Balances.lean`、`BalanceViewSetupSession.lean`、`RoleBalances.lean`、`ReportsView.lean`／`ReportsSession.lean`、`DailyPaceTrend.lean`／`DailyPacePoolSetupSession.lean`／`CycleBoundarySetupSession.lean`、`DailyPaceWhatIf.lean` |
| Household setup／first-run | Bakhloの明示的初期化UIなし。既存config読込は`daily_interaction.ml`等 | `LocusLabelSetup.lean`／`LocusLabelSetupSession.lean`、`FirstRun.lean` |
| Attention／Settlement／Exchange | 各data module、controllerのform／action／一覧 | `AttentionAdministration.lean`／`AttentionAdministrationSession.lean`、`SettlementWorkspace.lean`、`SettlementAction.lean`、`Exchange.lean`／`ExchangeSession.lean` |

`Ui_workspace.set_locus`は現行controllerから呼ばれていない。旧`Groups`／`cycle_schedule_view`は削除し、`toggle_schedule_view`で実在するList／Monthsだけを切り替える。
またActual／Scheduled以外の一覧page／端は、汎用 `W.move_selection` の対象行と専用選択状態が一致しない箇所がある。
`handle`、`W.rows`、family専用move／selected、`workspace_rows`を一緒に照合する。共通frame導入だけで全画面の操作が揃ったとは扱わない。

### 優先して切る差分

1. **共有機構のO/V/Q**：[責務設計と移行順序](TUI_LAYOUT_STABILITY_ROADMAP.ja.md) に従い、共有input／再帰Input metadata→Ui_form＋styled frameと全form利用元（Modal_form・Jump・Search overlay・Reversal Date）→RecordのColumns＋recursive caretとScheduledの入力／UTF-8移動／focus／notice→list/detailのcapacity整合・controller復帰の順に移行する。UI-03の長文検索（G-2）の限定合格は保持し、G-1/G-3/G-4と全画面は未完了。横断受入後に以下の機能差分へ戻る。
   移行順1〜4は接続・限定検査済みだが、横断受入・LOAM対照・IME／本人受入は未了（[証拠](VERIFICATION.md#listdetail-capacity-and-drill-downback-cutover)）。Record lifecycle、Actual/Selected Day、Scheduledの機能不足も受入計画に残す。
2. **Recordの一連操作**：Home→入力／候補→Preview→修正／取消／確定→Actual→再起動。原額・Merchant等のF不足を装飾で隠さない。
3. **Actual／Selected Day**：Locus／検索／scope／sort／detail／親復帰。旧P04の実装完了だけでは現行geometry・操作一致を認めない。
4. **Scheduled**：作成／置換／取消／完了の安全な確認・cold照合から、Series／Months／監視・継続／一括操作へ。
5. **残る非予算機能**：Balances／Observe／roles、Pace／Trend、Attention／精算／Exchange、Reports／設定／出力、索引未掲載の操作を順に対照する。
   保持情報／query／writerが不足する場合は機能から実装し、架空の表示で穴埋めしない。P7／電源断は独立した未認定課題。

ファジー検索・wheel／clipboard等の追加改善は、必要性・現行LOAMとの差を確認して別依頼にする。
一般的な改善案があることだけで今回の必須機能にしない。

## 4. 並行作業の境界

**現状は画面単位でファイルが分離されていない。画面名が違うだけでは安全に同時編集できない。**

| 境界 | 主なファイル／関数（Bakhloからの相対path） | 扱い |
| --- | --- | --- |
| 中央controller | `tui/daily_interaction.ml` の `handle`、`workspace_rows`、`screen`、`overlay_screen`、`footer`、各form | Actual／Scheduled／Balances／Pace／Attention／Commands等が同居。編集・接続は一人ずつ統合 |
| Renderer／テーマ | `tui/bonsai_daily.ml` の `attributes`、`border_attributes`、`lines`／`render`、`tui/ui_preferences.ml` | 見た目を任せられるが全画面へ波及。input adapter／event-loopは同じ依頼に混ぜない |
| 既存描画・回答 | `tui/daily_overlays.ml` の `clip_text`／`wrap_text`／枠、`entry_lines`／`plan_lines`／残高、`bonsai_home_lines` | 幅・金額・会計回答・Homeが同居。担当関数を決め、file全体のformat／renameは禁止 |
| 共通panel | `tui/ui_panel.ml/.mli` の `capacity`／`window`／`move`／`frame` | Actual／Scheduled等が利用。API変更は専任統合。見た目担当が独自viewportを複製しない |
| 汎用modal | `tui/ui_form.ml/.mli` の `handle_input`／`render_rows` | 多数のoperationで共有。見た目とSubmit／Cancel規則を分離。Record Previewのgateとは別 |
| 反転owner | `tui/reversal_session.ml/.mli` のDate／Preview／gate | 捕捉したtarget・book・baseで描画し、意図だけを返す。逆Actualの構築・ID・publicationは既存writer。共通formへ確定判断を移さない |
| Record owner | `tui/record_session.ml/.mli` の `screen`／field描画、`handle`／`review_geometry` | Record・訂正・予定作成／変更／完了で共有。paint変更は可能、寸法／gate変更は安全レビューが必要 |
| 選択・draft入力 | `tui/ui_workspace.ml/.mli`、`tui/ui_input.ml/.mli`、`tui/daily_form.ml`、`tui/posting_draft.ml` | stable identity・filter・caret／pasteを保持。行番号や見た目で対象を再解釈しない |
| family／保存境界 | `tui/attention_data.*`、`settlement_data.*`、`locus_roles.*`、`daily_actions.ml`、`daily_file.ml`、`sexp/`、`application/`、`lib/` | 見た目依頼の編集対象外。safe load／writer／semantic修正は別担当・別根拠 |
| 検証／build | `tui/daily_interaction_checks.ml`、`record_session_checks.ml`、`bonsai_daily.ml` self-check、`tools/build-bonsai-tui` | 共用ファイル。増分test／module登録は統合時に調整。UIはCore CIだけでは検査されない |

### 協調ルール

1. 依頼カードに **UI ID＋差分種別＋担当＋編集するfile／関数＋触らない境界＋根拠** を書く。
   着手時に該当カード／行だけを `作業中（担当: pit名）` にする。この台帳の更新自体も同時に行わない。
2. 同じcheckout・同じfileを複数pitが同時編集しない。read-only比較・調査は並行可。
   編集を並行するなら別worktree等の分離した作業ディレクトリ・branchを使い、共有fileの接続・merge・最終testは一人が統合する。
   同じcheckoutでbranchだけ切り替えても隔離されない。未コミットの共通panel差分も渡し、HEADだけを共有しない。
   同じcheckoutのCore／UI buildは生成先へ影響するため、buildも同時実行しない。PTYでは検証対象binaryとsource manifestを固定する。
   分離先に既存の隔離build環境があるか確認する。新依存installやglobal設定変更を当然の手順にしない。
3. 共通APIを変える前に利用元を確認し、先に統合担当へ相談する。component／writerのコピーを画面ごとに増やさない。
   無関係な一括format・cleanup・別pitの未確認変更のcommitはしない。
4. 比較成果は画像だけでなく、入力・寸法・キー列・期待／実際・ソース位置を添える。
   未接続、拒否、比較用binary／入力の欠損は未検証のまま報告し、fake表示で進捗を作らない。
5. `実装済み`、`T/P成功`、`対照成功`、`人間の受入`を分けて返す。各画面のF/O/Qが残る間はVだけで完了にしない。
   指摘がなければ「比較した範囲で差なし」でよい。コード修正や新しい共通部品を必ず作る必要はない。

## 5. そのまま渡せる依頼カード

以下は依頼候補（担当・状態は各カードに記載、記載なしは未割当）。P05の反転sliceはユーザー承認によりpitが限定完了。
今回はReversal専用session、中央controllerの反転接続、合成回帰、UI build登録と進捗文書に限定する。
PTYで縮小直後の確定が古い寸法で判定される例を得て、`bonsai_daily.ml` の `app`／`Terminal_event` を最新のdynamic input寸法へ修正した。
Record／共通form／writer／rendererのpaintは変更しない。
既存担当のUI-01／02は本人と範囲を確認してから割り振る。
コード編集の許可範囲は、この表と依頼時の合意の狭い方。見た目／比較担当にもAGENTSと意味の契約を渡す。

| カード | 対象／依頼 | 編集範囲・接続担当 | 完了条件／禁止事項 |
| --- | --- | --- | --- |
| **P01 見た目** | UI-01／02の接続済みHome／Commandsを対照。余白・強弱・配色・選択を仕上げる | Renderer／Home描画の合意した関数のみ。Commandsのcontroller変更は提案を統合担当へ | 4寸法、三テーマ、通知あり／なしの対照。Calendar収支や未接続reportを作らない。前段Antigravityの変更を保全 |
| **P02 Record面（ブラッシュアップ完了: antigravity）** | UI-05／06／08の入力・候補・Previewの見た目／操作を対照しLOAM一致 | `record_session.ml`、`daily_interaction.ml`、`bonsai_daily.ml`、`record_session_checks.ml` | 完了（コミット: 7ba68de, 12a8f13, de7cc92, 43e03e0, 5a41147, 6316822）。前方一致、Ctrl-U suspense補完、Date保護、resolve_overlay一元管理。実機受入待ち |
| **P03 読み取り比較（過去のsource調査完了: antigravity）** | 当時のUI-03／04仕様をP04の入力へ整理 | `ActualWorkspace.lean` の3ペイン・検索・scope／sort・詳細等を抽出した記録 | 現行LOAMとの全仕様一致・実行比較の完了ではない。source/binary更新時は対象操作を再比較する |
| **P04 Actual接続（接続済み、受入未了）** | 3ペイン・Locus絞込・検索・詳細・resizeの既存実装を対照 | `actual_workspace.ml/.mli`、controller、既存checks | 旧antigravityの接続成果を保持。後続の長文検索は限定対照済み。現行geometry・全操作・実IMEの一致はUI-03に残し、「実装完了」を全面互換へ拡張しない |
| **P05 確認の安全性（反転slice限定完了: pit）** | UI-11のDate／exact inverse Preview・狭小gate／失敗復帰を接続。対照実行・受入は未 | 専用session、中央controller、frontendの最新寸法伝達、回帰。P04との同時編集は禁止 | writerは既存inverse検査を維持。read-only Preview、末尾、tiny拒否、競合／不確定、draftを確認。UI-18／29／31は後続の別課題 |
| **P06 機能設計調査** | UI-12／14／22／23の明示予定と監視設定・Series／Monthsの不足を整理 | read-only調査／設計案だけなら並行可。実装file・保存単位は調査後に決める | open／completed／cancelled・欠損Actual・coverageを区別。監視cadenceを予定事実やNotDueにしない |
| **P07 roles安全境界** | UI-24／30のrole parse／load／save拒否を独立に調べる | `locus_roles.*`と関連parser／controller利用元の調査。修正の接続は中央担当と調整 | 不正→空／false成功・stale write・draft／reload・coldを扱う。口座名／signからrole推測しない。Balancesの見た目依頼とは別 |
| **P08 共有機構移行（純粋input実装・検査済み、画面cutover未）** | 共有input／再帰metadata→全form利用元→Record/Scheduled→list/detail整合。[責務設計](TUI_LAYOUT_STABILITY_ROADMAP.ja.md) が契約を所有 | `daily_overlays`の3 helperと既存checksのみ実装。共有API・全consumer・中央controller・rendererの接続は一人が統合 | native self-checkと直接smoke済み。次はUi_form＋styled frameと全直接利用元のcutover・cursor_offset削除。RecordのColumnsとrecursive caretは同時切替。ScheduledのUTF-8移動・notice・focus、Actualのcapacityとcontroller復帰も受入。保存gate・独立draft・固定baseはlocal維持。G-1/G-3/G-4・IME・全overlayは未合格 |
| **P09 Scheduled作成独立化（完了: antigravity）** | UI-16のScheduled作成セッション独立化・Recordドラフトからの分離・LOAM完全一致 | `scheduled_session.ml/.mli`、`scheduled_session_checks.ml/.mli`、`daily_interaction.ml` | 完了（コミット: 07b922e）。Description排除、Due日付・通貨・Postings（2〜6行）、Dateガード、Locus前方一致、Ctrl-U suspense貸借補完、狭小端末確定拒否（previewCapacity < 2）、resolve_overlay統合 |

**すぐ並行にしやすい組合せ**：P01の限定paint、P02のRecord描画、P03のread-only比較、P06の設計調査。
P01／P02が共通rendererやgeometryまで変更するなら分離をやめ、統合順を先に決める。
P04／P05は異なる画面でも中央fileが重なるため、同時編集しない。

### 依頼文テンプレート

```text
BakhloのLOAM互換作業。docs/LOAM_UI_GAP_LEDGER.ja.md のカード Pxx をお願いします。
対象: UI-xx の [F/O/V/Q]。担当: [pit名]。
基準: [双方のrevision＋未commit差分＋比較binary]。
編集してよいfile／関数: [...]。触らない境界: [...]。
LOAM本番、writer・意味・未実装機能のfake表示は変更しない。
既存共通部品を使い、API変更／範囲拡大は先に相談する。
合成入力、80×24／120×36／32×9／48×14で確認。
成果: 差分・根拠・画像path・キー列・tests・未確認点。共有fileは統合担当へ渡す。
着手／終了時の台帳更新は統合担当と順序を合わせる。
```

## 6. 比較・検証の手順

1. 双方のrevision、作業ツリー差分、既存binary、入力、terminal／theme、寸法と操作列を固定する。
   **同じ意味の合成入力を用意できなければソース比較まで**。LOAMをbuild／installして穴埋めしない。
2. 画像・ANSI transcriptは `scratch/ui-shots/<task>/loam/` と `.../bakhlo/` 等、各担当固有のignored場所へ。
   公開fixtureへ私用台帳を流用しない。私用copyを使う場合も元台帳、config、旧試用と画像を保全し、内容を公開出力へ出さない。
   `./ui --demo`はBakhlo合成入口であり、LOAM側に同一入力が自動供給されるという意味ではない。
3. 通常2寸法＋極小2寸法で、空／日本語／長文／巨大数量／通知／resize／focusと、対象画面のconfirm／cancel／returnを確認する。
   見た目担当も安全警告・不明・符号・currency・caretを隠さない。画像の画素一致だけを目標にしない。
4. 実装変更時は `./tools/check` と `./tools/tui --self-check`、変更したpathの小さい回帰、必要なsynthetic PTYを実行する。
   共通部品変更では直接利用元も検査する。docsだけの変更はlink・ID・source対応を検査し、未実行testを合格にしない。
5. 比較成功・人間の受入・残るF/O/Qを台帳へ戻す。V/Qの限定完了は記録してよいが、未接続の面を完了にしない。

原本のrefresh・運用切替・migration・耐久Saved／P7の認定はこのワークフローに含めない。
