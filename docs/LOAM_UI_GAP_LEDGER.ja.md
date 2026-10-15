# LOAM UI 差分・移行管理台帳

## 1. 読み方・比較基準

LOAMの**予算以外の全ユーザー向け機能・見た目・操作感・細部挙動**をBakhloへ揃えるための、画面別差分と受入判定の入口。
機能・保持情報・保存安全性は [CUTOVER_CHECKLIST.ja.md](CUTOVER_CHECKLIST.ja.md)、
描画・操作方針は [UI_DIRECTION.ja.md](UI_DIRECTION.ja.md)、
実際の検証範囲は [VERIFICATION.md](VERIFICATION.md) を参照する。同じ進捗表を新設しない。

- 対象：Home、Calendar、Record、Actual、Scheduled、Balances、Daily Pace／Trend、Attention、非予算Reports、設定・外貨・精算・出力を含む、LOAMの予算以外のユーザー向け機能。以下のUI IDは索引であって対象の上限ではない。未掲載の操作も棚卸しして追記する。
- 今は実装しない：予算配分・振替・消化・用途routing・Budget Window。必要になった時点で別途追加し、先行実装・予算用の拡張frameworkは作らない。Daily Pace・予定・非予算の残高／収支は除外しない。
- 盆栽の成長等を以前の対象外指定だけで除外しない。LOAMの現物でユーザー向け挙動の有無を確認する。日本語UIの採用は未決定で、台帳内の日本語表示・入力は検証対象。
- 旧ソース棚卸しの基準：Bakhlo `b21b30c`＋共通panel変更、LOAM `db631763`。この棚卸しや実装完了の記載を、現行LOAMとの実行一致へ読み替えない。
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
| **UI-01** | Home／Calendar | 試用：固定盆栽Home、Day／Month／Year、期間内Actual／open予定のDetail | **F** role-aware収支・月年集計。**O** Help等。**V/Q** Calendarの配置・縮退・対照受入 | T：Home／暦。前段Antigravity：葉／鉢・入口キーの彩色、Home固定footerを整理。対照スクショ待ち |
| **UI-02** | Commands | 試用：階層palette、実装済み入口 | **O** LOAMの未接続report等はまだ入口なし。**V/Q** 同一rectangle・選択・短い端末で対照 | T：階層・極小palette。前段Antigravity：タイトル／path・説明header、選択marker、固定help、不要counter除去。対照待ち |
| **UI-03** | Actual一覧・検索・詳細 | 接続済み：3ペイン、Locus絞込、live検索、scope／sort、Detailsスクロール、2段階Enter。長文検索は可視末尾・blank挿入cellと実caretを同じ計算へ修正 | **O/V/Q** 現行LOAMとのheader・pane配置・枠・空一覧／count・footer、全操作・実IME／本人受入が残る | T：既存workspace/controllerと4寸法の長文日本語検索・保持query・caret一致が成功。P：32×9／120×36で検索行・caret・Enter／EscをLOAM対照、両合成台帳bytes不変。検索だけの限定成功で画面全体の完了ではない |
| **UI-04** | Selected Day | 試用：選択日のActual／open予定とDetail | **F** role-aware収支。**O** 2段階 Enter による Actual からのドリルイン接続完了。**V/Q** 混在一覧・空・狭小 | T：drill／現行戻り先 |
| **UI-05** | Record入力・Locus候補 | 試用：Date／Description／Measure／複数Posting、許可済み候補 | **O/V/Q** 対照受入・実機検証待ち（ブラッシュアップ完了）。**F/O** 原額（UI-07）は未接続 | T：Unicode、paste、構造制約、追加行、floating／極小。P02完了：Movement上部枠＋横並びマルチペイン化、狭小Fields縮退、Locus前方一致（LOAM isPrefixOf準拠）、Date入力ガード、draft誤再開防止、resolve_overlayによるカーソル位置・描画座標の完全同期（macOS IME安定化） |
| **UI-06** | Record Preview | 試用：Publish／Edit／Cancel、exact全体確認、狭小確定拒否 | **V/Q** 対照受入・実機検証待ち（ブラッシュアップ完了）。全文gateを弱めない | T：巨大数量、キー／支払リンク、狭小・未読末尾の拒否。P02完了：Publication gate（recheck evidence + Locus admission）案内行、中画面縦3段レイアウト、枠線・ボタン整列、キャレット17カラム化、全文gate維持を実装・検証完了 |
| **UI-07** | Original amount | 未接続：Daily永続項目・入力なし | **F/O** 原額を記帳量と独立に保持／接続。換算値で捏造しない | 見た目だけの依頼不可。F03 |
| **UI-08** | unresolved有効化 | 試用：Ctrl-Uによる貸借差額自動補完（suspense行追加・調整・削除）接続済 | **F/O** 未解決語彙の明示admission・元draftへの復帰。**Q** 拒否 | T：Ctrl-U差額ゼロ時削除、符号反転補完、Posting上限（6行）ガード、単一S式保存。LOAM Unresolved remainder仕様準拠 |
| **UI-09** | Actual Correction | 試用：Record系Edit／Preview、同一ID・Postingキー／構成／符号・支払対応保持 | **O** LOAMの表現可能範囲・操作対照。**V/Q** 注意枠、原内容と確認内容。対応外shapeは拒否 | T：符号／構成lock、ID・キー・payment link保持 |
| **UI-10** | Actual日付変更専用 | 未接続：通常EditのDate変更はあるが専用入口／Previewなし | **O/Q** date-only操作と対象identity、対応可能なshape、全Effects不変・再読込の照合 | 「日付を一切変えられない」という意味ではない |
| **UI-11** | Reversal入力・確認 | 試用：x→専用Date／exact inverse Preview→既存writer。元Actualは残る | **O** LOAMのrとの入口差。**V/Q** 対照表示・実機受入。後続modal・P7には保証を拡張しない | T/P：固定target／base、元・逆Postingの正確な数量、末尾／狭小gate、取消／下書き、stale／失敗／unknown停止、cold、resize寸法。反転の限定sliceはP05で完了 |
| **UI-12** | Scheduled Series Calendar | **未接続**：Home sはcurrent-open List | **F/O** 明示open／completed証拠とread-side監視のSeries、初期表示、月窓・継続入口 | schedule_view型だけでは実装済みでない。S04〜S06 |
| **UI-13** | Scheduled Plan Detail | 局部：単発occurrenceのExpected Effects／due／ID | **F/O** Series内の複数日・監視／継続文脈なし。**V/Q** 単発detailの対照 | T/P：Actual共用の枠・端・ページ・resize・focus・draft／取消復帰 |
| **UI-14** | Scheduled Months | **未接続**：六か月board・月別projectionなし | **F/O** 月内の明示occurrenceを選ぶprojection。**V/Q** 数量・counts・Listへの縮退 | type Monthsは画面接続の根拠でない |
| **UI-16** | Scheduled作成 | **完了（コミット: 07b922e）**：独立セッション `scheduled_session.ml` 実装。LOAM `ScheduledPostingForm.lean` / `ScheduledCreation.lean` 準拠（Due日付、通貨固定、Locus/Amount、Description排除、2〜6行制限、Date入力ガード、Locus前方一致、Ctrl-U suspense貸借補完、狭小端末previewCapacity < 2確定拒否、`resolve_overlay` カーソル一元管理）。Recordドラフトとの完全分離・非干渉 | **F/O** recurring／監視設定・補充は別。 | T/P/V/Q完了：独立自己診断テスト `scheduled_session_checks.ml` パス。アトミックな `A.Plan_tx` 確定・取消保全 |
| **UI-18** | Scheduled取消 | 局部：日付modal→既存取消writer、取消planを保持 | **O/Q** LOAMのKeep初期選択・独立Preview・狭小確認との差。**V** 警告／対象 | T：取消保持／再操作拒否。RecordのPreview gateを継承しない |
| **UI-19** | Scheduled置換 | 試用：単発planのEdit／Preview | **F/O** Series／monitoringとの連動なし。**V/Q** 元予定・置換内容・候補の対照 | T：Plan_edit、ID保持、paid／cancelled拒否 |
| **UI-20** | Scheduled batch amount | 未接続 | **F/O/Q** checked候補の複数選択・全体Preview・既存writerとの原子性／拒否 | 先に安全な発行単位を決める。装飾のみ不可 |
| **UI-21** | Scheduled生成 | 未接続 | **F/O/Q** 明示候補・期間・個別review・保存単位。周期を事実にしない | S05。storage研究の別許可を代用しない |
| **UI-22** | Scheduled継続／補充 | 未接続 | **F/O/Q** 明示template・cadence・horizon・生成Preview・失敗 | Series／監視の意味を確認してから |
| **UI-23** | Scheduled coverage設定 | 未接続 | **F/O/Q** Expected paceをreplaceable観測設定として保持・接続 | 予定authority／NotDueを捏造しない |
| **UI-24** | Balances Current | 局部：Current／Accounting、Observe prefill、画面内Print | **O** 初期Accounting→LOAM Currentとの違い、一覧page／Home・EndのBalance選択への接続不足。**V** 座標／数量／支持状態。**Q/F** role境界・会計回答対照、過去支持 | T：unknownとzero、表示／設定順・Print。role側の読込／save safetyは別の未認定境界 |
| **UI-25** | 非予算Reports | 未接続：広いReports群。Pace／Balances入口は別行 | **F/O** Income & Expense、Transactions Flow、Stock–Flow、Trend、Liquidity、Multicurrency等のquery／入口／比較 | Budget Windowだけは必要になるまで延期。外部Fava／exportはUI-32も参照。固定の「9画面」と数えない |
| **UI-26** | Attention | 試用：due三状態、Add／Resolve／Drop、一覧・detail | **V/O/Q** 期限signal・action・一覧page／端と詳細端・対照。**F/Q** LOAM canonical情報との保持対応 | T：strict load、Unavailable、stale save／失敗draft保持。sidecarで全移行／P7を認定しない |
| **UI-27** | Settlements一覧 | 局部：commitmentの累計settled／extinguished／outstanding sidecar | **F/O** LOAMのActual／Effect配分・通貨・group／参照の保持と照会。**V/O/Q** 現行限定一覧の数量・page／端・対照 | T：不正／重複／参照、巨大数量、stale／cold。完全なSettlementではない |
| **UI-28** | Settlement action | 局部：累計Settle／Reduce／Retractの試用操作 | **F/O/Q** 実取引対応・独立証拠・訂正／撤回・Previewの全体差 | sidecar actionはActualを記帳しない。払込の代用にしない |
| **UI-29** | Exchange | 局部：両通貨・数量入力modal→既存publisher | **O/Q** 独立Preview・入力候補・狭小全文確認・失敗時の復帰。**V** From／To整列 | T：exact両数量、Exchangeキー、cold readback。LOAM最新geometryの実物比較は未 |
| **UI-30** | Manage Loci／roles | 局部：admit、明示role設定、一覧・detail | **F/O** label／説明／一覧設定編集、初回分類・使用済み制約。**Q** role load/save safety。**V** 現行一覧 | 語彙追加はzero残高や役割付与と別。roles安全修正を見た目依頼へ混ぜない |
| **UI-31** | Observe quantities | 局部：一座標を入力、他座標の支持は保全 | **F/O/Q** LOAMの同時観測した全画像入力との意味・複数座標・Preview差。**V** 現行入力 | T：quantity／coordinate・cold。LOAMと同じ観測画像更新とは認定しない |
| **UI-32** | Print／export／外部表示 | 局部：Balancesの画面内Print previewのみ | **F/O/Q** 同意付き通常端末出力、外部format、Fava・再開。**V** 現行preview | codec読取をexport対応と数えない。O03〜O05 |
| **UI-33** | Daily Pace／Trend | 局部：現在量・明示Pool／一意period・What-if・Pool-only編集 | **F/O** 履歴・期間切替・Trend・graphは未接続。**V/Q** 現在画面／設定の対照 | T：不正条件拒否、負数整数除算、preset保全。Braille graphの仕上げ待ちではない |

### ソース対照の入口

LOAM側はread-only参照。詳細な保持／writerは各sessionの先を読む。画面名が同じことだけで意味の一致を推定しない。

| 面 | Bakhlo入口 | LOAM入口（`loam/Loam/Tui/`） |
| --- | --- | --- |
| Home／Commands | `bonsai_daily.ml`、`daily_overlays.ml`、controllerのCalendar／Commands描画、`ui_commands.ml` | `Home.lean`、`HomeCommandPalette.lean` |
| Record／Actual／Selected Day | `record_session.ml`、`reversal_session.ml`、controllerのedit／reverse／Actual／Selected_day | `Record.lean`／`RecordSession.lean`、`ActualWorkspace.lean`、`SelectedDay.lean`／`SelectedDaySession.lean`、`ActualDateCorrection.lean`、`ActualReversal.lean`／`ActualReversalSession.lean`、`EventMerchant.lean` |
| Scheduled | `ui_workspace.ml`、`record_session.ml`、controllerのScheduled／cancel | `ScheduledWorkspace.lean`／`ScheduledWorkspaceSession.lean`、`ScheduledCreation.lean`、`ScheduledCompletion.lean`、`ScheduledCancellation.lean`、`ScheduledReplacement.lean` |
| Balances／Reports／Pace | `daily_overlays.ml`、`balance_view_data.ml`、controllerのbalance／pace／what-if | `Balances.lean`、`RoleBalances.lean`、`ReportsView.lean`／`ReportsSession.lean`、`DailyPaceTrend.lean`、`DailyPaceWhatIf.lean` |
| Attention／Settlement／Exchange | 各data module、controllerのform／action／一覧 | `AttentionAdministration.lean`／`AttentionAdministrationSession.lean`、`SettlementWorkspace.lean`、`SettlementAction.lean`、`Exchange.lean`／`ExchangeSession.lean` |

`Ui_workspace.set_locus`／`cycle_schedule_view`は現行controllerから呼ばれていない。
またActual／Scheduled以外の一覧page／端は、汎用 `W.move_selection` の対象行と専用選択状態が一致しない箇所がある。
`handle`、`W.rows`、family専用move／selected、`workspace_rows`を一緒に照合する。共通frame導入だけで全画面の操作が揃ったとは扱わない。

### 優先して切る差分

1. **共有機構のO/V/Q**：[責務設計と移行順序](TUI_LAYOUT_STABILITY_ROADMAP.ja.md) に従い、共有input／再帰Input metadata→Ui_form＋styled frameと全form利用元（Modal_form・Jump・Search overlay・Reversal Date）→RecordのColumns＋recursive caretとScheduledの入力／UTF-8移動／focus／notice→list/detailのcapacity整合・controller復帰の順に移行する。UI-03の長文検索（G-2）の限定合格は保持し、G-1/G-3/G-4と全画面は未完了。横断受入後に以下の機能差分へ戻る。
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
