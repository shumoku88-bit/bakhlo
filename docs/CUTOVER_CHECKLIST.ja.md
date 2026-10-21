# LOAM → Bakhlo：機能の棚卸しと乗り換え判定条件

## 対象と判定

**目標：LOAMの全ユーザー向け機能・回答・見た目・使い勝手と細部をBakhloで再現する。**
**予算配分・振替・消化・用途routing・Budget Windowだけは、実際に必要になるまで延期する。**
Daily Pace、支払い予定、隣接する非予算機能、盆栽の表示・成長も対象に含む。
以前の盆栽成長除外や現在よく使う機能だけという制限は適用しない。
Favaとhledgerへの出力はユーザー指定で互換・切替条件から除外。Print／診断や他形式は別途判定する。
LOAMの内部構造・研究用機能・証明装置・保存方式まで同じにする必要はない。
予算用の先回りしたAPI・形式・hookは作らない。独自の日本語化は未定だが、
LOAMに存在するlocale切替等の互換上必要な実動作を除外する理由にはしない。

機能の存在と、最初の切替日に必要な範囲は別。以下は互換性の棚卸しであり、全行を
一度に実装する指示でも、正データ切替の許可でもない。**普段の記帳と正データはまだLOAM。**

以下の表はBakhlo `b21b30c`＋当時の作業ツリーの共通panel変更と、LOAM `db631763`
のソース／TUI契約を基準とした**保存済み棚卸し**。前段のAttention／精算・Pace安全性、
Actual閲覧、共通viewportの限定検証を含むが、後続実装の現在進捗表ではない。
今回の方針更新では新しい対照実行・実機受入をしていない。旧上下Home、Notty並行版、
Daily v4・予算APIは非現行。限定コンバータ・既存Book CLI・型だけをDaily TUI接続に数えない。
実データの内容・使用件数は扱わない。

本人が乗り換え前に差分を見る要約は[乗り換え前のLOAM差分台帳](CUTOVER_DIFF_LEDGER.ja.md)。
画面別の不足・現在進捗・並行依頼の唯一の管理先は
[LOAM_UI_GAP_LEDGER.ja.md](LOAM_UI_GAP_LEDGER.ja.md)。この文書は生活操作と切替の判定条件を所有する。
同台帳は **F:機能・保持情報／O:操作・接続／V:見た目／Q:検証・安全性** を分ける。
見た目・スクショ待ちだけでは保存・回答・運用条件を満たさない。以下の過去の未接続記述で
現在の実装有無を判定せず、同台帳を確認する。表にない非予算機能も棚卸しから落とさない。

| 軸 | 確認すること |
| --- | --- |
| 表現・保存 | 必要な独立情報を保持し、再読込できるか |
| 画面接続 | 日常の入口から操作を最後まで行えるか。型・APIだけでは不可 |
| 回答一致 | 同じ合成入力からLOAMと同じ値・不明・拒否を返すか |
| 操作品質 | 選択、確認、取消、下書き、親への復帰、狭小端末、IMEが整っているか |
| 保存安全性 | 失敗・競合・再起動を扱えるか。画面の成功表示だけでは不可 |

「試用」は合成データ等の隔離コピーで操作できるという意味。**全行で運用認定は未**。
実装、self-check、固定したLOAM source／既存binaryとの対照実行、人間の実機受入を混同しない。
画面だけでなく保存内容、終了・再起動後の再読込、保存失敗・競合・結果不明時の停止と下書き保持を確認する。

## 1. 記帳・実績

| ID | 生活操作 | 基準時点のBakhlo Daily TUI | LOAMとの差・判定条件 |
| --- | --- | --- | --- |
| R01 | 支出・収入・同通貨振替 | 試用：符号付きPostingのRecord | 通貨別の正確な量・保存後再開を維持。全面的な操作一致は未認定 |
| R02 | 一取引の複数Posting | 試用：新規／予定支払いで行追加・削除 | LOAMの6行上限をモデルの制約としない。狭小表示・操作感を比較 |
| R03 | 合計検査と全体確認 | 試用：Preview後、選択したPublish＋Enterで発行 | Ctrl-SはPreviewのみ。空欄をゼロにせず、自動差額補完なし |
| R04 | 日付・金額・摘要・内訳の訂正 | 一部：同じIDで訂正、Postingキー・支払い対応を保持 | 既存Postingの構成変更、Exchange／Reversal関連の訂正は拒否 |
| R05 | 探す・詳細を見る | 一部：Actualの検索modal内live絞込、日付絞込、昇降順、2ペイン詳細 | 共通viewport・安全な数量列は合成／PTY検証。Locus絞込UI、画面内検索、独立Transaction detail・actions・復帰文脈は差が残る |
| R06 | 未分類を明示的に仮置き | 一部：許可済み通常Locusへ手入力 | unresolved語彙の追加確認・内訳補助は未同等 |
| R07 | 実際の返金・反転 | 試用：xの日付入力→専用exact inverse Preview→既存writer。元Actualを残す | 末尾／狭小gate、捕捉base・stale／失敗／unknown停止、coldは合成・PTYで限定検証。LOAMのr・対照表示／実機受入は別のO/V/Q課題 |
| R08 | Merchant／非Merchant分類 | 未接続 | Coreの検査はあるがDaily永続項目・入力なし |
| R09–R10 | 口座・費目の一覧／検索／選択 | 試用：許可済みID・表示名の候補 | 同名候補、長い文字、取消後の下書き・位置を比較 |
| R11–R12 | Focusと短命な補助pane | 一部：Calendar／Detail、Record／候補／Preview。Actual・Scheduledの共通panel | Actual／Scheduledの端・ページ・resize・draftは限定検証。Selected DayからCalendarへの親復帰、Help、他のmodalは別のO/Q課題 |
| R13 | 明示的な保存前確認 | 試用：Publish／Edit／Cancel | 全文が読めない極小Previewは発行拒否。閲覧・貼付で保存しない |

訂正後のDaily明細と、LOAMの永久Correction鎖は同じ保存形式ではない。
元データを別に保全し、必要なID・実際の返金・予定支払い対応を落とさないことが条件。

## 2. 支払い予定

| ID | 生活操作 | 基準時点のBakhlo Daily TUI | LOAMとの差・判定条件 |
| --- | --- | --- | --- |
| S01 | 単発予定の作成 | 試用：Record系のPlan入力・Preview | 単一S式のみ。純粋APIだけの段階から画面接続済み |
| S02 | 変更・日付付き取消 | 試用：単発Edit／Previewと、日付付き取消modal | paid／cancelledを再利用しない。取消modalのKeep初期選択・独立確認・狭小gateはEdit Previewと別に比較する |
| S03 | 予定を実績化 | 試用：Actual入力とpaid-byを同時保存 | 単一S式（唯一の形式） |
| S04 | 未払い・完了・月別を見分ける | 局部：Home sはcurrent-open List／単発detail／検索。枠・viewportはActualと共用 | Series Calendar、六か月Months、Series内Plan Detail、open／completedの併記は未接続。ListのT/PTY成功をそれらの実装済みと数えない |
| S05 | 次回／複数回／期限まで補充 | 未接続 | 実際の予定を確認して発行する操作が必要。周期から事実を捏造しない |
| S06 | Expected pace・未補充監視 | 未接続 | 観測設定と明示された予定を分離する |

`Ui_workspace.schedule_view`の型があるだけではSeries／Months対応に数えない。
予定がない日は「義務なし」ではなく、未供給・網羅性不明を維持する。

## 3. 残高・設定

| ID | 生活操作 | 基準時点のBakhlo Daily TUI | LOAMとの差・判定条件 |
| --- | --- | --- | --- |
| B01 | 口座×通貨の現在残高 | 一部：Current／Accounting表示、全文Print preview | 初期表示はAccountingでLOAMと異なる。会計集計の回答一致は未認定 |
| B02 | 検証した現在残高の入力 | 局部：一座標のObserve、Balancesからprefill、他座標の支持を保全 | LOAMは同時観測した全画像を入力する。単なる行追加不足とせず、画像更新の意味・複数座標・独立確認をF/O/Qで照合 |
| B03 | 過去時点の残高 | 未接続 | 現在量の支持だけで過去の完全性を主張しない |
| B04 | 新しいLocusの許可 | 試用：Manage Loci | 語彙追加とゼロ残高・会計分類は別 |
| B05 | AccountingRole設定 | 一部：初回割当のみ（未使用・未割当の科目）、置換と使用済み科目への割当は拒否（2026-10-21、LOAMと同じ） | 読込拒否・保存保証は未認定 |
| B06 | 名前・説明・一覧への掲載 | 一部：保持済みラベル、balance-view設定読取 | TUIでの表示名・説明・一覧設定編集は未接続 |
| B07 | 通貨・小数桁の追加 | 一部：供給済み通貨の正確な入力 | Daily経路の追加操作なし。既存量の解釈を変えない |
| B08 | 履歴支持の設定 | 一部：起点・観測・存在根拠を保持 | 過去の期間完全性とその管理は未同等 |

## 4. 外貨・精算

| ID | 生活操作 | 基準時点のBakhlo Daily TUI | LOAMとの差・判定条件 |
| --- | --- | --- | --- |
| F01 | 外貨の普通の記帳 | 試用：明示Measure・scale | 通貨を混ぜない。入力できることと外貨レポートは別 |
| F02 | 両替 | 局部：両通貨・数量modalから既存publisherへ、Exchangeキーを保存 | 独立Preview・候補・狭小全文確認・失敗時の復帰は未同等。RecordのPreview拒否をこのmodalの保証にしない |
| F03 | 原額を記帳通貨と別に保持 | 接続済み | Record Ctrl-O、Preview、同一保存操作、Actual詳細、再起動、訂正時保持 | 独立Preview・入力・保存を合成データで検査完了 |
| F04–F06 | 立替・部分精算・相殺・非支払減少 | 一部：commitment累計額の試用sidecar／操作 | ActualのEffectとの配分、独立した決済通貨・証拠・訂正／撤回は未同等 |

精算画面があることをLOAM Settlementの移植完了としない。
現在のsidecarは実取引から独立した試用残額管理で、物理残高を変更しない。

## 5. 集計・Attention・Daily Pace

| ID | 生活操作 | 基準時点のBakhlo Daily TUI | LOAMとの差・判定条件 |
| --- | --- | --- | --- |
| V01 | 日・月・年の収支Calendar | 一部：暦・Actual／open Scheduled件数 | role-aware In／Out、Month Flow、Unknown／Unavailable表示、Helpに差 |
| V02 | Income & Expense | 未接続 | Summary／Monthly／Daily／比較 |
| V03 | 会計残高・純資産 | 一部：BalancesのAccounting表示 | LOAM Reports／Balancesと独立照合が必要 |
| V04 | Stock–Flow | 未接続 | 明示期間・比較と根拠 |
| V05 | Transactions Flow | 未接続 | gross／net・寄与明細 |
| V06 | Daily Pace履歴／Locus推移 | 未接続 | LOAMの10d／30d／Month／Cycle／Previous Cycleと歴史支持が必要 |
| V07 | Multicurrency Spend | 未接続 | 原額・両替・記帳通貨を区別 |
| V08 | Liquidity | 接続：Commands→Reports and analysis→Liquidity。無条件forecast／known low-waterはUNKNOWN、明示した期限の条件付きselected-balance outlookだけ照会 | Scheduled網羅性は保存しない仮定であり証拠ではない。全選択座標のExact数量・単一Measureを要求し、選択純変動のある期限超過予定は全体拒否。日別net・期限inclusive・全点low-water、scaled Amount。合成Shell到達／描画を確認、native TUI・最新データ対照・本人受入は未実施（[証拠](VERIFICATION.md#liquidity-conditional-selected-balance-outlook-2026-10-21)） |
| V10 | Attention | 試用：期限あり／なし／不明、追加／解決／取り下げ | strict読込・保存結果・競合拒否を接続。LOAM canonical情報の移行は未認定 |
| V11 | 今日のDaily Pace／What-if | 一部：現在値、Pool編集、読み取り専用What-if | 履歴Trend未接続。期間は明示presetの一意な選択だけ。負数を丸めない |

Daily Paceは**予算ではない**。明示した同一通貨Poolの既知残高から期間末より前の
open予定の純流出を控除し、残日数で整数除算する。内部振替・未実績の予定収入で額を増やさない。
Calendarの選択日を今日に置き換えず、月末やAsset分類から条件を推測しない。
Poolの設定画面は`daily-pace.tsv`だけを更新し、全境界presetをbyte-exactに保全する。
`boundary-presets.tsv`はこの画面では編集しない。二ファイル同時保存の保証を新設しない。

## 6. 運用・出力

| ID | 生活操作 | 基準時点の状態／判定条件 |
| --- | --- | --- |
| O01 | 記帳・終了・再開 | 単一S式の既存保存・拒否テストを維持。永続Ack（P7）・電源断は未認定 |
| O02 | 確認・バックアップ復旧 | inspect／confirm／restore-copyあり。保持、別媒体、不一致候補の採用条件は未確定 |
| O03 | 外部会計形式への出力 | hledger出力はユーザー指定で対象外。他形式は別途判定。Daily経路には未接続で、S式が読めることを他形式の対応としない |
| O04 | Fava | ユーザー指定で対象外。運用切替の必須条件にしない |
| O05 | Print・診断 | Balancesの画面内Print previewあり。LOAMの同意付き通常端末出力とは未同等 |
| O06 | 別環境への導入 | 既存の隔離Bonsai環境が必要。standalone配布・新環境の復旧は未認定 |

## 既存の限定検証と次の順序

前段の安全性修正は既存の`daily_interaction_checks.ml`に合成回帰を追加した：

- Attention／精算の不正行・不正数量・重複・不正な参照を拒否し、空・ゼロへ置換しない。
- 読込失敗をUnavailableとして表示し、そのfamilyを保存しない。
- 協調writer lockで既存stateを再確認し、保存失敗・競合では入力と状態を残す。
- Daily Paceの未設定・不正・重複・混合Measure・曖昧な期間を拒否する。
- What-ifの負数と整数除算を保持する。Pool編集で期間presetを消さない。

検証入口は`./tools/check`、`./tools/tui --self-check`。native renderer検査を含むが、
全画面の実PTY比較・実機受入・LOAMの実行結果との全面一致を証明しない。
UIのみの変更は現在のCore CIに含まれないことにも注意する。

今後の順序と各段階の受入条件は [tasks/todo.md](../tasks/todo.md) を参照する。
source／既存binary基準・共通合成fixtureを固定し、共有入力geometry → Record lifecycle →
Actual／Selected Day → Scheduled → Balances／Observe → Pace／Trend →
Attention／Settlement／Exchange → 残るReports／設定／対象内の出力とその他の棚卸し不足へ進む。
一課題ごとに操作・必要情報・保存／再開・失敗例・対照実行・実機受入を分け、
画面別の判定はUI差分台帳だけに記録する。全sliceを今回実装する計画ではない。
中央controllerは画面が違っても競合するため依頼カードで編集fileと統合順を決める。
共有機構は実在する利用元のために使い、万能form／第二の会計エンジンは作らない。

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
