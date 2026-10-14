# LOAM → Bakhlo：非予算機能の棚卸しと乗り換え判定表

## 対象と判定

**目標：LOAMで現在使える非予算の日常機能について、回答・操作・仕上がりを揃える。**
Homeの盆栽の**成長**と、予算配分・振替・消化・用途routing・Budget Windowは対象外。
固定盆栽のHome、Calendar、Daily Pace、Attention、非予算Reportsは対象に含む。
LOAMの内部構造・研究用機能・証明装置を同じように実装するという意味ではない。

機能の存在と、最初の切替日に必要な範囲は別。以下は互換性の棚卸しであり、全行を
一度に実装する指示でも、正データ切替の許可でもない。**普段の記帳と正データはまだLOAM。**

基準はBakhlo `d2e2f5f` とLOAM `9dbe2496` の現行ソース、および今回の
Attention／精算sidecar・Daily Pace安全性修正。以前の表にあった旧上下Home、Notty並行版、
Daily v4・予算APIの記述は非現行。限定コンバータや既存Book CLIの能力をDaily TUI対応に数えない。
実データの内容・使用件数はこの表では扱わない。

| 軸 | 確認すること |
| --- | --- |
| 表現・保存 | 必要な独立情報を保持し、再読込できるか |
| 画面接続 | 日常の入口から操作を最後まで行えるか。型・APIだけでは不可 |
| 回答一致 | 同じ合成入力からLOAMと同じ値・不明・拒否を返すか |
| 操作品質 | 選択、確認、取消、下書き、親への復帰、狭小端末、IMEが整っているか |
| 保存安全性 | 失敗・競合・再起動を扱えるか。画面の成功表示だけでは不可 |

「試用」は合成データ等の隔離コピーで操作できるという意味。**全行で運用認定は未**。
テスト成功、LOAMとの実行一致、人間の実機受入を混同しない。

## 1. 記帳・実績

| ID | 生活操作 | Bakhloの現行Daily TUI | LOAMとの差・残る確認 |
| --- | --- | --- | --- |
| R01 | 支出・収入・同通貨振替 | 試用：符号付きPostingのRecord | 通貨別の正確な量・保存後再開を維持。全面的な操作一致は未認定 |
| R02 | 一取引の複数Posting | 試用：新規／予定支払いで行追加・削除 | LOAMの6行上限をモデルの制約としない。狭小表示・操作感を比較 |
| R03 | 合計検査と全体確認 | 試用：Preview後、選択したPublish＋Enterで発行 | Ctrl-SはPreviewのみ。空欄をゼロにせず、自動差額補完なし |
| R04 | 日付・金額・摘要・内訳の訂正 | 一部：同じIDで訂正、Postingキー・支払い対応を保持 | 既存Postingの構成変更、Exchange／Reversal関連の訂正は拒否 |
| R05 | 探す・詳細を見る | 一部：文字検索、日付絞込、昇降順、詳細 | Locus絞込の画面接続、LOAMの単一取引詳細・復帰文脈に差 |
| R06 | 未分類を明示的に仮置き | 一部：許可済み通常Locusへ手入力 | unresolved語彙の追加確認・内訳補助は未同等 |
| R07 | 実際の返金・反転 | 試用：元Actualを残す正確な逆Postingの新規記帳 | Recordsは拒否。LOAMの確認内容・再操作拒否・再開との比較が必要 |
| R08 | Merchant／非Merchant分類 | 未接続 | Coreの検査はあるがDaily永続項目・入力なし |
| R09–R10 | 口座・費目の一覧／検索／選択 | 試用：許可済みID・表示名の候補 | 同名候補、長い文字、取消後の下書き・位置を比較 |
| R11–R12 | Focusと短命な補助pane | 一部：Calendar／Detail、Record／picker／確認pane | 戻り先・一覧位置・可視行・Helpを画面ごとに確認 |
| R13 | 明示的な保存前確認 | 試用：Publish／Edit／Cancel | 全文が読めない極小Previewは発行拒否。閲覧・貼付で保存しない |

訂正後のDaily明細と、LOAMの永久Correction鎖は同じ保存形式ではない。
元データを別に保全し、必要なID・実際の返金・予定支払い対応を落とさないことが条件。

## 2. 支払い予定

| ID | 生活操作 | Bakhloの現行Daily TUI | LOAMとの差・残る確認 |
| --- | --- | --- | --- |
| S01 | 単発予定の作成 | 試用：Record系のPlan入力・Preview | 単一S式のみ。純粋APIだけの段階から画面接続済み |
| S02 | 変更・日付付き取消 | 試用：編集／取消フォーム | 支払い済み・取消済みを再利用しない。確認・復帰・失敗を比較 |
| S03 | 予定を実績化 | 試用：Actual入力とpaid-byを同時保存 | 単一S式のみ。Recordsは部分Actual追記前に拒否 |
| S04 | 未払い・完了・月別を見分ける | 一部：current-open一覧・詳細・検索 | 通常一覧はopenのみ。Series Calendar／Months、完了表示は未接続 |
| S05 | 次回／複数回／期限まで補充 | 未接続 | 実際の予定を確認して発行する操作が必要。周期から事実を捏造しない |
| S06 | Expected pace・未補充監視 | 未接続 | 観測設定と明示された予定を分離する |

`Ui_workspace.schedule_view`の型があるだけではSeries／Months対応に数えない。
予定がない日は「義務なし」ではなく、未供給・網羅性不明を維持する。

## 3. 残高・設定

| ID | 生活操作 | Bakhloの現行Daily TUI | LOAMとの差・残る確認 |
| --- | --- | --- | --- |
| B01 | 口座×通貨の現在残高 | 一部：Current／Accounting表示、全文Print preview | 初期表示はAccountingでLOAMと異なる。会計集計の回答一致は未認定 |
| B02 | 検証した現在残高の入力 | 試用：Observe、Balancesから選択座標をprefill | 別口座の観測・明示ゼロを保全。複数座標の同時観測UIは未同等 |
| B03 | 過去時点の残高 | 未接続 | 現在量の支持だけで過去の完全性を主張しない |
| B04 | 新しいLocusの許可 | 試用：Manage Loci | 語彙追加とゼロ残高・会計分類は別 |
| B05 | AccountingRole設定 | 一部：設定sidecarの編集と集計 | LOAMの初回分類・使用済み制約と未同等。読込拒否・保存保証も未認定 |
| B06 | 名前・説明・一覧への掲載 | 一部：保持済みラベル、balance-view設定読取 | TUIでの表示名・説明・一覧設定編集は未接続 |
| B07 | 通貨・小数桁の追加 | 一部：供給済み通貨の正確な入力 | Daily経路の追加操作なし。既存量の解釈を変えない |
| B08 | 履歴支持の設定 | 一部：起点・観測・存在根拠を保持 | 過去の期間完全性とその管理は未同等 |

## 4. 外貨・精算

| ID | 生活操作 | Bakhloの現行Daily TUI | LOAMとの差・残る確認 |
| --- | --- | --- | --- |
| F01 | 外貨の普通の記帳 | 試用：明示Measure・scale | 通貨を混ぜない。入力できることと外貨レポートは別 |
| F02 | 両替 | 試用：両通貨・数量を入力しExchangeキーを保存 | Dailyの画面接続済み。Preview・候補・狭小確認等の操作品質は未同等 |
| F03 | 原額を記帳通貨と別に保持 | 未接続 | ApplicationのOriginalAmountだけではDailyに保存できない |
| F04–F06 | 立替・部分精算・相殺・非支払減少 | 一部：commitment累計額の試用sidecar／操作 | ActualのEffectとの配分、独立した決済通貨・証拠・訂正／撤回は未同等 |

精算画面があることをLOAM Settlementの移植完了としない。
現在のsidecarは実取引から独立した試用残額管理で、物理残高を変更しない。

## 5. 集計・Attention・Daily Pace

| ID | 生活操作 | Bakhloの現行Daily TUI | LOAMとの差・残る確認 |
| --- | --- | --- | --- |
| V01 | 日・月・年の収支Calendar | 一部：暦・Actual／open Scheduled件数 | role-aware In／Out、Month Flow、Unknown／Unavailable表示、Helpに差 |
| V02 | Income & Expense | 未接続 | Summary／Monthly／Daily／比較 |
| V03 | 会計残高・純資産 | 一部：BalancesのAccounting表示 | LOAM Reports／Balancesと独立照合が必要 |
| V04 | Stock–Flow | 未接続 | 明示期間・比較と根拠 |
| V05 | Transactions Flow | 未接続 | gross／net・寄与明細 |
| V06 | Daily Pace履歴／Locus推移 | 未接続 | LOAMの10d／30d／Month／Cycle／Previous Cycleと歴史支持が必要 |
| V07 | Multicurrency Spend | 未接続 | 原額・両替・記帳通貨を区別 |
| V08 | Liquidity | 未接続 | 予定網羅性の仮定を明示し、無条件には不明 |
| V10 | Attention | 試用：期限あり／なし／不明、追加／解決／取り下げ | strict読込・保存結果・競合拒否を接続。LOAM canonical情報の移行は未認定 |
| V11 | 今日のDaily Pace／What-if | 一部：現在値、Pool編集、読み取り専用What-if | 履歴Trend未接続。期間は明示presetの一意な選択だけ。負数を丸めない |

Daily Paceは**予算ではない**。明示した同一通貨Poolの既知残高から期間末より前の
open予定の純流出を控除し、残日数で整数除算する。内部振替・未実績の予定収入で額を増やさない。
Calendarの選択日を今日に置き換えず、月末やAsset分類から条件を推測しない。
Poolの設定画面は`daily-pace.tsv`だけを更新し、全境界presetをbyte-exactに保全する。
`boundary-presets.tsv`はこの画面では編集しない。二ファイル同時保存の保証を新設しない。

## 6. 運用・出力

| ID | 生活操作 | 現在地／残る条件 |
| --- | --- | --- |
| O01 | 記帳・終了・再開 | 単一S式／Recordsの既存保存・拒否テストを維持。永続Ack（P7）・電源断は未認定 |
| O02 | 確認・バックアップ復旧 | inspect／confirm／restore-copyあり。保持、別媒体、不一致候補の採用条件は未確定 |
| O03 | 外部会計形式への出力 | Daily経路には未接続。S式が読めることをBeancount等の対応としない |
| O04 | Fava | 未接続。派生出力を正データにしない |
| O05 | Print・診断 | Balancesの画面内Print previewあり。LOAMの同意付き通常端末出力とは未同等 |
| O06 | 別環境への導入 | 既存の隔離Bonsai環境が必要。standalone配布・新環境の復旧は未認定 |

## 品質修正と次の順序

今回の安全性修正は既存の`daily_interaction_checks.ml`へ合成回帰を追加する：

- Attention／精算の不正行・不正数量・重複・不正な参照を拒否し、空・ゼロへ置換しない。
- 読込失敗をUnavailableとして表示し、そのfamilyを保存しない。
- 協調writer lockで既存stateを再確認し、保存失敗・競合では入力と状態を残す。
- Daily Paceの未設定・不正・重複・混合Measure・曖昧な期間を拒否する。
- What-ifの負数と整数除算を保持する。Pool編集で期間presetを消さない。

検証入口は`./tools/check`、`./tools/tui --self-check`。native renderer検査を含むが、
全画面の実PTY比較・実機受入・LOAMの実行結果との全面一致を証明しない。
UIのみの変更は現在のCore CIに含まれないことにも注意する。

次は一分野ずつ、**操作＋必要な情報＋保存／再開＋失敗例＋実機比較**で進める。
Record／Actual → Scheduled → Balances → Daily Pace／Attention → 残る非予算Reports・
外貨／精算・設定／出力を基本順とし、実際の困りごとで順序を変える。
共有の機構は実際の呼出元が必要とする範囲だけ使い、万能フォームや第二の会計エンジンを作らない。

## 切替は別の判断

限定された比較コピーの変換成功は、全家計情報の移行・完全バックアップではない。
必要な実績・返金・予定／支払いリンク・数量根拠・設定・Attention・外貨／精算根拠の
持ち越し範囲を確認し、元データと以前の試用を保全する。未変換を不存在にしない。
正データを二重記帳・自動同期しない。最後にユーザーが切替日と記帳先を明示して決める。

## 根拠の入口

- Bakhlo：[`Daily_book API`](../sexp/daily_book.mli)、[`操作`](../tui/daily_interaction.ml)、
  [`workspace`](../tui/ui_workspace.ml)、[`保存`](../tui/daily_file.ml)、
  [`回帰`](../tui/daily_interaction_checks.ml)、[`TUI guide`](../tui/README.md)。
- LOAM：[`TUI契約`](../../loam/docs/TUI.md)、[`非予算UI進捗`](../../loam/docs/TUI_NON_BUDGET_WORKLIST.md)、
  [`Commands`](../../loam/Loam/Tui/HomeCommandPalette.lean)、
  [`Daily Pace設定`](../../loam/Loam/Config/DailyPaceConfig.lean)、
  [`期間設定`](../../loam/Loam/Config/BoundaryPresetConfig.lean)、
  [`What-if`](../../loam/Loam/Tui/DailyPaceWhatIf.lean)。
- 会計上の保持境界と運用未認定は[`機能・保証台帳`](CAPABILITY_LEDGER.ja.md)、
  [`意味の契約`](SEMANTIC_CONTRACT.md)、[`現在の引継ぎ`](HANDOFF.md)を参照する。
