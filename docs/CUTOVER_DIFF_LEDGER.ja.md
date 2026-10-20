# 乗り換え前のLOAM差分台帳

LOAMからBakhloへ普段の記帳を移す前に、**本人が「何が同じで、何が違い、何が足りないか」を一か所で確認する**ための台帳。
対象は普段使う5領域（記帳・予定・科目・残高・Daily Pace）と、乗り換えそのものに必要な運用条件。

- 画面ごとの詳細な F/O/V/Q 差分と作業カードは [UI差分台帳](LOAM_UI_GAP_LEDGER.ja.md)、実行した検証の中身は [検証記録](VERIFICATION.md)、切替の判定条件は [乗り換え判定](CUTOVER_CHECKLIST.ja.md) が持つ。この台帳はそれらを**乗り換え判断の視点で要約**し、根拠へリンクする。詳細を書き写さない。
- 「一致」は、最新の実データのコピーを使ってAIがLOAMとBakhloを並べて読み取り操作した結果、または同じ合成データで照合した結果。**本人の実機・日本語入力（IME）での確認ではない**。
- 家計の金額・科目名・件数はこの台帳に書かない。

## 判定の記号

| 記号 | 意味 |
| --- | --- |
| ✅ 一致 | LOAMと同じ答え・同じ操作を確認済み（根拠リンク先の範囲で） |
| 🟦 意図的な差 | Bakhloが安全側・設計上の理由で変えている。乗り換え後もこのまま |
| 🟨 差あり | 動くが見た目・操作がLOAMと違う。乗り換えは可能だが慣れが要る |
| 🟥 未実装 | LOAMにある機能がBakhloにない／つながっていない |
| ⬜ 未確認 | 実装はあるが、LOAMとの照合をまだしていない |

「乗り換え」列：**止める**＝これが残る間は乗り換えない、**要判断**＝本人が許容できるか決める、**なし**＝影響なし。

## 1. 記帳（Record／Actual）

| 項目 | 判定 | LOAMとの差 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| 支出・収入・振替の入力→Preview→保存→再起動 | ✅ 一致（合成） | 単発の入力・数量・再起動後の照合が一致 | なし | [Record対照](VERIFICATION.md#paired-record-happy-path-and-cancellation-2026-10-16) |
| 記帳の一行入力（クイック入力） | 🟨 実装（入力は前回実データ対照、枠・自動ロール配置は合成対照） | 過去履歴のサジェスト・雛形提案・選択・Preview遷移は前回の実データ対照で一致。2026-10-21に枠付きモーダル／枠内フッターとAccountingRole自動配置を接続。警告を覆う枠は縮退させる。合成取込→支払側Locus置換→Preview→コピー整理後のcoldを確認。既定日付はRecord表示日のまま。今回の最新実データ対照は未実施 | 要判断 | [入力証拠](VERIFICATION.md#record-quick-capture-as-in-loam-2026-10-20)、[枠の証拠](VERIFICATION.md#record-quick-capture-framed-modal-2026-10-21)、[ロール取込](VERIFICATION.md#comparison-accounting-role-capture-2026-10-21) |
| 狭い画面での保存確認 | 🟦 意図的な差 | LOAMは確認本文が隠れたまま保存できる。Bakhloは全文が見えるまで保存を拒否 | なし | [狭小gate](VERIFICATION.md#paired-record-editcancel-and-narrow-preview-gates-2026-10-16) |
| 未分類（貸借差額）の仮置き | ✅ 一致（合成・実データ） | Ctrl-Uで差額行を自動補完。suspense が未許可のときはLOAMと同じ確認画面を出し、Enterで科目だけを追加して下書きに戻り差額を埋める（本人判断 2026-10-20：LOAMと同じにする）。Bakhloの記帳枠は浮かぶ枠のため配置だけ違う | なし | UI-08 |
| Actual一覧・検索・詳細 | ✅ 一致（実データ・限定） | 見出し・3画面の配置・一覧と詳細の表記をLOAMへ揃え、実データ120×36・80×24の14通りで比較。違いは意図的な3点（詳細欄のMerchantなど補足行、下部案内の`[d] date [m] merchant`）と、Loci一覧の一部の並び（LOAMは訂正した記録を訂正時点へ移すが、Bakhloは同じIDのまま元の位置に保つため） | なし | UI-03, [Actual対照](VERIFICATION.md#actual-workspace-layout-and-details-parity-with-loam-2026-10-20) |
| 既存記録の訂正 | ✅ 一致（合成） | 同じIDで訂正。LOAMと同じく口座・符号・行の追加削除も変更可、日付は保持（日付は`d`）。口座を変えた行だけ識別キーを外し、支払いの対応は保つ（本人判断 2026-10-20：LOAMと同じにする）。`approved-loci` から外れた口座を含む明細の `c` 訂正は、メモのみでも両者とも拒否（120×36・80×24実データで確認） | なし | UI-09, [実データ試し保存・訂正比較](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |
| 日付だけの訂正 | ✅ 一致（実データ・限定） | `approved-loci` から外れた口座を含む保持済み明細も、両者とも同じ日付Preview（`Only the occurrence date changes.`）へ進む。Bakhloは隔離コピーで保存し、cold・whole-book照合で日付以外不変（120×36・80×24）。LOAMは今回Previewまで（保存は前回世代で確認）。入口はLOAMがTransaction detail経由、BakhloはActual一覧から直接 | なし | UI-10, [専用mutation証拠](VERIFICATION.md#retained-unapproved-locus-date-and-merchant-mutations-2026-10-20), [変更前の実データ差](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |
| 返金・取り消し（反転） | 🟨 差あり | Bakhloは `x`、LOAMは `r`。元の記録は残し、承認済み口座では保存、外れた口座を含む明細は両者とも拒否（120×36・80×24実データで確認） | 要判断 | UI-11, [実データ試し保存・訂正比較](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |
| 原額（外貨の元の金額） | ⬜ 未確認 | 入力・保存・再起動は接続済み（年越しは年別保存とともに削除）。LOAMとの照合が未了 | なし | UI-07 |
| Merchant分類 | ✅ 一致（実データ・限定） | `approved-loci` から外れた口座を含む保持済み明細も、両者とも同じMerchant／Nonmerchant Previewへ進む。Bakhloは隔離コピーでNonmerchantを保存し、cold・whole-book照合でMerchant以外不変（120×36・80×24）。LOAMは今回Previewまで | なし | R08, [専用mutation証拠](VERIFICATION.md#retained-unapproved-locus-date-and-merchant-mutations-2026-10-20), [変更前の実データ差](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |

## 2. 予定（Scheduled）

| 項目 | 判定 | LOAMとの差 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| Series Calendar（初期画面・月表・✓・!） | ✅ 一致（実データ） | 120×36・80×24で表の中身が一致。案内行は1行にまとめている | なし | [Series対照](VERIFICATION.md#scheduled-series-calendar-and-real-data-balances-2026-10-19) |
| シリーズのPlan Detail（予定と抜けた月） | ✅ 一致（実データ） | 全シリーズで一致。金額列の見出しは Amount（LOAMは Quanta） | なし | 同上 |
| 補充（e）のひな形選び | ✅ 一致（実データ） | 全シリーズで同じ予定をひな形に選ぶ | なし | [補充](VERIFICATION.md#series-calendar-replenishment-2026-10-19) |
| 補充（e）の入力画面 | 🟨 差あり | LOAM：次の1回／次のN回／日付指定。Bakhlo：終了日と周期を入れる生成画面 | 要判断 | 同上 |
| 周期の変更（p・m）・未定化（s） | ✅ 一致（選択画面は実データ、保存は合成） | Series CalendarとPlan Detailから `scheduled-coverage.tsv` を更新。実データのコピーへの保存照合はしていない | なし | [周期](VERIFICATION.md#series-calendar-pace-and-undecided-2026-10-19) |
| ListやMonthsからの監視追加、予定作成直後の周期選択 | 🟥 未実装 | 監視していない予定を新しく監視に入れるには、今は監視済みシリーズの予定が必要 | 要判断 | UI-23 |
| 予定の支払い完了 | ⬜ 未確認 | 接続済み（Plan Detail・Listから）。LOAMとの照合未了 | 要判断 | UI-17 |
| 予定の取り消し | 🟦 意図的な差 | Bakhloは取消日を入力する（既存の日付付き取消の契約） | なし | UI-18 |
| 予定の置換・一括金額変更 | ⬜ 未確認 | 接続済み、照合未了 | なし | UI-19, UI-20 |
| Months・List | 🟨 差あり | 両方あり。LOAM現行との配置・操作照合が未了 | なし | UI-14, UI-15 |
| 予定がない日 | 🟦 意図的な差 | 「義務なし」とは表示しない（網羅性は不明のまま） | なし | S06 |

## 3. 科目（Loci）

| 項目 | 判定 | LOAMとの差 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| 新しい科目の追加 | 🟨 差あり（実データ・読み取りのみ） | LOAMのManage Lociは開くとすぐ追加フォーム（新しいトークン入力＋登録済み一覧の確認、Tabで初回の役割割当、Shift-Tabで履歴の完全性（Complete Since））。Bakhloは一覧＋詳細の画面で、`n`で追加の小窓を開き、追加と同時に役割も選べる（LOAMは追加時にラベル・役割を作らない）。一覧の並び（登録順）と件数は一致。保存は比較していない | 要判断 | UI-30, B04, [Loci対照](VERIFICATION.md#manage-loci-paired-comparison-and-list-paging-2026-10-21) |
| 科目一覧の表示・移動 | 🟨 差あり | 2026-10-21にBakhloのPageDown/End/PageUpが先頭へ戻る不具合を修正（LOAMはこれらのキーを無視、Bakhloはページ移動・末尾選択）。80×24ではBakhloの一覧からラベル列が`…`で消え、詳細欄が単語の途中で折り返す。LOAMはトークンとラベルを表示 | なし | 同上 |
| 表示名・説明の変更 | ⬜ 未確認 | 編集→Review→保存。照合未了 | なし | UI-30 |
| 会計上の役割（AccountingRole） | 🟨 差あり | 設定はできる。LOAMの初回分類・使用済み科目の制約とは違う | 要判断 | B05 |
| Balancesに出す科目の選択 | ✅ 一致（合成） | 選択・Review・保存・再起動を合成で確認 | なし | [B2](VERIFICATION.md#ui-24-b2-balances-picker-and-grouped-observation-2026-10-18) |

## 4. 残高（Balances）

| 項目 | 判定 | LOAMとの差 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| 現在残高の金額・通貨・状態 | ✅ 一致（実データ） | 表示中の全口座で一致（2026-10-20の保存方式変更後も120×36・80×24で再確認） | なし | [Balances対照](VERIFICATION.md#scheduled-series-calendar-and-real-data-balances-2026-10-19), [再確認](VERIFICATION.md#latest-data-check-of-the-2026-10-20-storage-work-2026-10-20) |
| 一覧の見た目 | 🟨 差あり | Bakhloは表示名＋ID、見出しは Amount（スケール適用後の金額）。LOAMはIDと Quanta | なし | UI-24 |
| 選択した残高の詳細・下部案内 | 🟨 差あり | 項目と並び順が違う | なし | UI-24 |
| 確認した残高の入力（Observe） | 🟨 差あり | 複数口座を同時に入力・Preview・保存できる。入力欄の形がLOAMと違う。差分追加した明細が観測に反映済みと扱われず二重計上されるCore不具合を修正（合成で確認、2026-10-20） | なし | UI-31, [Observe修正](VERIFICATION.md#observation-after-incremental-record-2026-10-20) |
| Accounting表示 | ⬜ 未確認 | あり。LOAMとの照合未了 | 要判断 | B01, V03 |
| 印刷・端末への出力 | 🟨 差あり | 画面内のPrint previewのみ。LOAMの同意付き端末出力はない | 要判断 | UI-32 |

## 5. Daily Pace

| 項目 | 判定 | LOAMとの差 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| 今日のPace | ✅ 一致（実データ） | 120×36・80×24で一致（2026-10-20の保存方式変更後も再確認。グラフも同日にLOAMの描き方へ揃えた） | なし | [実データ対照](VERIFICATION.md#latest-real-data-copy-and-paired-observation-2026-10-19), [再確認](VERIFICATION.md#latest-data-check-of-the-2026-10-20-storage-work-2026-10-20) |
| 過去のPace（5期間のHistory・選択行） | ✅ 一致（実データ） | bounded-history根拠を取り込み、全期間で一致 | なし | [履歴対照](VERIFICATION.md#bounded-history-support-and-real-data-pace-history-2026-10-19) |
| 選択日の詳細欄 | ✅ 一致（実データ） | 並び順・文言を揃え、120×36・80×24の実データ15通りで詳細欄が一致（スクロール後を含む）。Bakhloは予定支払いの戻り行と、Paceが不明な日の当日の動きを追加で表示（意図的）。一部の日だけ分かるときにLOAMが出す「History partial」案内行は出さない（意図的。同じ注意はグラフ上の「k/n supported days … unknown days stay gaps」、履歴の`unknown`、詳細欄の「Supported: k/n days」に出ている。本人判断 2026-10-20） | なし | UI-33, [詳細欄対照](VERIFICATION.md#daily-pace-selected-day-detail-matches-loam-2026-10-20) |
| グラフの描き方 | ✅ 一致（実データ） | LOAMの描き方（目盛り・`┤`軸・`┄`格子・点字の補間・●／◆）へ移植し、実データ120×36・80×24の14通りで画面が見出し1行以外一致。Bakhloは極端に大きい金額でもグラフを描く（LOAMは描画を断る）。その後、選んだ日の位置に縦線を出す独自の追加あり（LOAMのTrendグラフにはない） | なし | UI-33, [グラフ対照](VERIFICATION.md#daily-pace-chart-follows-loam-chart-2026-10-20) |
| 目標（`[t] target`） | ✅ 一致（実データ） | 目標ペース計画（候補表・最短日・日付指定の計画・今日の仮想支出・推移グラフ）を実装。実データ6通りでLOAMと内容一致（入力欄のキャレット表示と操作案内の位置だけ違う）。Bakhloは円以外の単位でも動く。本人判断（2026-10-20）：必要 | なし | UI-33, [Target対照](VERIFICATION.md#daily-pace-target-plan-2026-10-20) |
| 内訳（`[?] why`） | ✅ 一致（実データ） | 今日のPaceの内訳（Pool残高と根拠・控除される予定・残額と割り算）を実装。実データでLOAMと内容一致（操作案内は画面下に表示）。本人判断（2026-10-20）：必要 | なし | UI-33, [Why対照](VERIFICATION.md#daily-pace-why-2026-10-20) |
| 直前の周期の境界がないとき | 🟦 意図的な差 | LOAMはPrevious Cycleへ切り替えて unavailable と表示。Bakhloは今の期間のまま、理由（Daily Pace range unavailable）を案内欄に出す。どちらも前の周期の数字は出さない。本人判断（2026-10-20）：Bakhloのままでよい | なし | UI-33 |
| What-if（購入シミュレーション） | ✅ 一致（実データ） | LOAMと同じく入力するとその場で購入後ペース・1日の変化・残額が出る読み取り専用画面に作り直した（旧フォームとSimulateボタンは削除）。実データ8通りで入力欄のキャレット以外一致。Bakhloは円以外の単位（小数を含む）でも動く | なし | V11, [What-if対照](VERIFICATION.md#daily-pace-what-if-follows-loam-2026-10-20) |
| Pool設定 | ✅ 一致（実データ） | LOAMと同じく、残高が確定している口座だけを一覧から選ぶ方式に作り直した（旧：口座名のカンマ区切り入力）。実データで画面が一致し、違いは候補1件の並び位置（LOAM内部の記録保持順に依存）だけ。Bakhloは確認画面が全部見えないと保存しない、以前のプールから外れる口座の名前を示す、エラー文を省略せず折り返す | なし | V11, [Pool対照](VERIFICATION.md#daily-pace-pool-picker-follows-loam-2026-10-20) |

## 6. 乗り換えそのものに必要な条件

| 項目 | 判定 | 内容 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| 全家計データの移行 | 🟥 未実装 | 今の変換は比較用の限定コピー。取り込めない区画（Capacity・Routing等）の扱いと、元データの保全を決めていない | **止める** | [乗り換え判定](CUTOVER_CHECKLIST.ja.md#切替は別の判断) |
| 年度の切替（単一帳簿での年またぎ） | ✅ 解決（設計変更） | 年別ファイル分割を廃止し、1冊の帳簿（スナップショット＋追記ログ、200件以上で終了時にまとめ直しと `.prev` 保持）に統一（2026-10-20実データコピーでも追記・200件まとめ直しを確認） | なし | [年別廃止](VERIFICATION.md#records-and-annual-files-removed-2026-10-20), [実データ試し保存・訂正比較](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |
| 保存の確認・電源断（P7） | 🟥 未実装 | 保存完了の永続的な確認と電源断時の安全性が未検証 | **止める** | O01 |
| バックアップと復旧の手順 | 🟨 差あり | `--inspect-recovery`／`--discard-torn-tail`／`--restore-copy-from` とまとめ直し時の `.prev` 保持はある。長期履歴のGit運用や採用手順は未確定 | 要判断 | O02 |
| 本人の実機・日本語入力での確認 | ⬜ 未確認 | Macの端末で本人が触って確認していない | **止める** | — |
| 切替日と記帳先 | ⬜ 未確認 | 本人が明示して決める。二重記帳・自動同期はしない | **止める** | [乗り換え判定](CUTOVER_CHECKLIST.ja.md#切替は別の判断) |
| Fava・hledger出力 | 🟦 意図的な差 | 本人の指定で対象外 | なし | — |

## 更新の決まり

- 差を見つけた・直した・照合したら、同じ作業の中でこの台帳の該当行を更新する（判定・差の内容・根拠リンク）。行を消さずに判定を変える。
- 「✅ 一致」には、どのデータ（実データ／合成）で、どの画面サイズで確かめたかを根拠先に残す。
- 本人が「この差は許容する」と決めた行は「乗り換え」列を「なし（本人了承 YYYY-MM-DD）」にする。
- 最終更新：2026-10-20（実データコピーでの試し保存・200件まとめ直し・外れた口座の訂正比較後）。
