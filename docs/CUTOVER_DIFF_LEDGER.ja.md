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
| 支出・収入・振替の入力→Preview→保存→再起動 | ✅ 一致（合成） | 単発の入力・数量・再起動後の照合が一致 | なし | [Record対照](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#paired-record-happy-path-and-cancellation-2026-10-16) |
| 記帳の一行入力（クイック入力） | 🟨 実装（入力は前回実データ対照、枠・自動ロール配置は合成対照） | 過去履歴のサジェスト・雛形提案・選択・Preview遷移は前回の実データ対照で一致。2026-10-21に枠付きモーダル／枠内フッターとAccountingRole自動配置を接続。警告を覆う枠は縮退させる。合成取込→支払側Locus置換→Preview→コピー整理後のcoldを確認。既定日付はRecord表示日のまま。今回の最新実データ対照は未実施 | 要判断 | [入力証拠](VERIFICATION.md#record-quick-capture-as-in-loam-2026-10-20)、[枠の証拠](VERIFICATION.md#record-quick-capture-framed-modal-2026-10-21)、[ロール取込](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#comparison-accounting-role-capture-2026-10-21) |
| 狭い画面での保存確認 | 🟦 意図的な差 | LOAMは確認本文が隠れたまま保存できる。Bakhloは全文が見えるまで保存を拒否 | なし | [狭小gate](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#paired-record-editcancel-and-narrow-preview-gates-2026-10-16) |
| 未分類（貸借差額）の仮置き | ✅ 一致（合成・実データ）＋Attentionで可視 | Ctrl-Uで差額行を自動補完。suspense が未許可のときはLOAMと同じ確認画面を出し、Enterで科目だけを追加して下書きに戻り差額を埋める（本人判断 2026-10-20：LOAMと同じにする）。Bakhloの記帳枠は浮かぶ枠のため配置だけ違う。2026-10-22からsuspenseの記帳があるときAttentionに1行を出し、Measure別の記録済み純額（残高ではなく記帳の合計）・Actual件数・最古の日付と経過日数を示す（純額0のMeasureは列挙せず、純額が全て0なら1行も出さない）。suspenseは口座ではなく役割も持たず（Manage Lociの`r`でも追加でも拒否）、Balancesの会計ビューには未解決の役割として現れてNet Worthは不明のままになる。Actualの`c`で訂正して解消する | なし | UI-08, UI-26 |
| Home（入口） | 🟦 意図的な差（試置き） | 2026-10-22の本人判断（試置き）でHomeの`Enter`はActual（今日のCycle窓）を開くようにした。`g`は従来どおりCalendar、下部の案内も`[Enter] actual`へ更新、Actualの`Esc`でHomeへ戻る。Calendarは`g`に残す（本人の判断が立つまで削除しない）。試置きのあいだActualは`f`でToday/Cycle/Month/Allを切り替えられる | なし（本人了承 2026-10-22：試置き） | [Home遷移の証拠](VERIFICATION.md#actual-by-day-opened-from-home-2026-10-22) |
| Actual一覧・検索・詳細 | 🟦 意図的な差（試置き・実データと合成） | 2026-10-22の本人判断（試置き）でActualを日別グループ化へ替えた。日付ごとの見出し（曜日・件数・表示中の行のEXPENSE-role合計をMeasure別、共有の金額整形。科目で絞っても件数と合計は同じ行を指す）とその下に字下げした記録、初期選択は今日の日（その日がなければ直前の最新日）。`f`でToday/Cycle/Month/All、`[`/`]`で前の/次の窓（CycleとMonthは報告と同じboundary-presets.tsv、範囲外の窓は拒否）。役割のないeffectがある日は合計を`+?`でpartial表示、accounting-roles.tsvが読めないときは合計を出さず原因を示す通知1行だけ（一覧は動く）。日付順以外の並びでは日見出しを出さない。検索/詳細/並べ替え/記録の操作（c/d/x/m/e/n）は従来どおり。端末が30行未満では詳細欄を閉じて一覧を広げ、`i`で開く。Calendarの`a`は選んだ日を含むCycle窓でその日を選んで開く。CalendarはHomeの`g`に残す（本人の判断が立つまで）。LOAMとの前列表示の照合は未実施 | なし（本人了承 2026-10-22：試置き） | UI-03, [Actual対照](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#actual-workspace-layout-and-details-parity-with-loam-2026-10-20), [日別グループ化の証拠](VERIFICATION.md#actual-by-day-opened-from-home-2026-10-22) |
| 既存記録の訂正 | ✅ 一致（合成） | 同じIDで訂正。LOAMと同じく口座・符号・行の追加削除も変更可、日付は保持（日付は`d`）。口座を変えた行だけ識別キーを外し、支払いの対応は保つ（本人判断 2026-10-20：LOAMと同じにする）。`approved-loci` から外れた口座を含む明細の `c` 訂正は、メモのみでも両者とも拒否（120×36・80×24実データで確認） | なし | UI-09, [実データ試し保存・訂正比較](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |
| 日付だけの訂正 | ✅ 一致（実データ・限定） | `approved-loci` から外れた口座を含む保持済み明細も、両者とも同じ日付Preview（`Only the occurrence date changes.`）へ進む。Bakhloは隔離コピーで保存し、cold・whole-book照合で日付以外不変（120×36・80×24）。LOAMは今回Previewまで（保存は前回世代で確認）。入口はLOAMがTransaction detail経由、BakhloはActual一覧から直接 | なし | UI-10, [専用mutation証拠](VERIFICATION.md#retained-unapproved-locus-date-and-merchant-mutations-2026-10-20), [変更前の実データ差](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |
| 返金・取り消し（反転） | 🟨 差あり | Bakhloは `x`、LOAMは `r`。元の記録は残し、承認済み口座では保存、外れた口座を含む明細は両者とも拒否（120×36・80×24実データで確認） | 要判断 | UI-11, [実データ試し保存・訂正比較](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |
| 原額（外貨の元の金額） | ⬜ 未確認 | 入力・保存・再起動は接続済み（年越しは年別保存とともに削除）。LOAMとの照合が未了 | なし | UI-07 |
| Merchant分類 | ✅ 一致（実データ・限定） | `approved-loci` から外れた口座を含む保持済み明細も、両者とも同じMerchant／Nonmerchant Previewへ進む。Bakhloは隔離コピーでNonmerchantを保存し、cold・whole-book照合でMerchant以外不変（120×36・80×24）。LOAMは今回Previewまで | なし | R08, [専用mutation証拠](VERIFICATION.md#retained-unapproved-locus-date-and-merchant-mutations-2026-10-20), [変更前の実データ差](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |

## 2. 予定（Scheduled）

| 項目 | 判定 | LOAMとの差 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| Series Calendar（初期画面・月表・✓・!） | ✅ 一致（実データ） | 120×36・80×24で表の中身が一致。案内行は1行にまとめている | なし | [Series対照](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#scheduled-series-calendar-and-real-data-balances-2026-10-19) |
| シリーズのPlan Detail（予定と抜けた月） | ✅ 一致（実データ） | 全シリーズで一致。金額列の見出しは Amount（LOAMは Quanta） | なし | 同上 |
| 補充（e）のひな形選び | ✅ 一致（実データ） | 全シリーズで同じ予定をひな形に選ぶ | なし | [補充](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#series-calendar-replenishment-2026-10-19) |
| 補充（e）の入力画面 | 🟦 意図的な差（選択画面は実データで一致） | LOAMソース参照で次の1／3／6回・排他的な補充期限、周期固定、観測日による候補除外と存在しない月末日の明示入力を接続。exact数量・初期Cancel・Preview末尾／狭小／stale gateを維持。通常gは変更しない。2026-10-21実データ120×36：選択画面（元予定・known through・周期・4択）がLOAMと一致し、次の3回の最初の日付も一致。**差**：LOAMは1回ごとに編集フォーム→個別Previewへ進み（金額などを1件ずつ直せる）、Bakhloは全件を1つのPreviewで元予定と同じ内容のまま作る。LOAMにある「Only reviewed explicit dates will be created.」の案内は選択画面にない（BakhloはPreviewに表示） 本人判断（2026-10-21）：まとめて確認する今の方式のままにする（回ごとに違う金額は保存後に`r`で直す） | なし（本人了承 2026-10-21） | UI-12, UI-21, [補充の合成証拠](VERIFICATION.md#scheduled-replenishment-input-and-explicit-dates-2026-10-21) |
| 周期の変更（p・m）・未定化（s） | ✅ 一致（選択画面は実データ、保存は合成） | Series CalendarとPlan Detailから `scheduled-coverage.tsv` を更新。実データのコピーへの保存照合はしていない | なし | [周期](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#series-calendar-pace-and-undecided-2026-10-19) |
| ListやMonthsからの監視追加、予定作成直後の周期選択 | ✅ 一致（List／Monthsは実データ）＋⬜ 作成直後は合成のみ | 2026-10-21、List／Monthsの予定欄でLOAMと同じく`p`・`m`（周期を選んで監視）、`s`（未定）、`e`（監視済みならそのまま補充、未監視なら周期を選んでから補充）を接続。編集はLOAMと同じ`r`（Ctrl-eも可）。実データ120×36で`p`の選択画面・Escの案内・`e`の補充画面がLOAMと一致。2026-10-21、予定作成直後の周期選択もLOAMと同じく接続（この回だけ／5周期／未定、Escは監視を変えず、作成を始めた画面へ戻る。完了後の「次の予定を追加」では出さない）。LOAMとの並べた照合は未実施（保存を伴うため） | 要判断 | UI-23, [List監視](VERIFICATION.md#scheduled-list-and-months-monitoring-keys-2026-10-21), [作成直後](VERIFICATION.md#scheduled-expected-pace-after-creation-2026-10-21) |
| 予定の支払い完了 | ⬜ 未確認 | 接続済み（Plan Detail・Listから）。LOAMとの照合未了 | 要判断 | UI-17 |
| 予定の取り消し | 🟦 意図的な差 | Bakhloは取消日を入力する（既存の日付付き取消の契約） | なし | UI-18 |
| 予定の置換・一括金額変更 | ⬜ 未確認 | 接続済み、照合未了 | なし | UI-19, UI-20 |
| Months・List | 🟨 差あり（局部整合・合成確認） | LOAMソース参照でListの日付／ID昇順・Loci／日付filter・列・固定focus／8件page・Enter完了と詳細復帰、Monthsのカード・inline詳細を整合。scale付きAmount・検索／全文詳細は保持。共有Shell外枠は変更せず、両binaryの実行対照・本人受入は未実施 | なし | UI-14, UI-15, [合成証拠](VERIFICATION.md#scheduled-months-and-list-local-parity-2026-10-21) |
| 予定がない日 | 🟦 意図的な差 | 「義務なし」とは表示しない（網羅性は不明のまま） | なし | S06 |

## 3. 科目（Loci）

| 項目 | 判定 | LOAMとの差 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| 新しい科目の追加 | 🟨 差あり（実データ・読み取りのみ） | LOAMのManage Lociは開くとすぐ追加フォーム（新しいトークン入力＋登録済み一覧の確認、Tabで初回の役割割当、Shift-Tabで履歴の完全性（Complete Since））。Bakhloは一覧＋詳細の画面で、`n`で追加の小窓を開き、追加と同時に役割を選ぶ（必須。LOAMは追加時にラベル・役割を作らない）。一覧の並び（登録順）と件数は一致。保存は比較していない | 要判断 | UI-30, B04, [Loci対照](VERIFICATION.md#manage-loci-paired-comparison-and-list-paging-2026-10-21) |
| 科目一覧の表示・移動 | 🟦 意図的な差 | 画面の形はBakhloの一覧＋詳細を維持（本人判断 2026-10-21）。PageDown/End/PageUpが先頭へ戻る不具合を修正（LOAMはこれらのキーを無視、Bakhloはページ移動・末尾選択）。80×24でもトークンとラベルを表示し（狭いときは役割列を省き詳細に表示）、詳細欄は単語の区切りで折り返す | なし | 同上 |
| 表示名・説明の変更 | ⬜ 未確認 | 編集→Review→保存。照合未了 | なし | UI-30 |
| 会計上の役割（AccountingRole） | 🟦 意図的な差（合成＋実データの写し） | 初回割当のみ・置換は拒否はLOAMと同じ。2026-10-22から、使用済みでも役割のない科目には割り当てられ（LOAMは拒否）、追加時は役割の選択が必須（LOAMは追加時に役割を作らない）。一覧の見出しに役割のない科目の数を表示し、suspenseはその数に含めない（本人判断 2026-10-22）。suspenseには役割を割り当てられず（`r`でも追加でも拒否。追加の拒否はRecordの「未解決の記帳を有効化」（Ctrl-U）を案内する）、未解決の保留としてActualの訂正で解消する | なし | B05, [役割必須](VERIFICATION.md#manage-loci-a-role-is-required-on-admission-and-may-go-to-a-used-locus-2026-10-22) |
| Balancesに出す科目の選択 | ✅ 一致（合成） | 選択・Review・保存・再起動を合成で確認 | なし | [B2](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#ui-24-b2-balances-picker-and-grouped-observation-2026-10-18) |

## 4. 残高（Balances）

| 項目 | 判定 | LOAMとの差 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| 現在残高の金額・通貨・状態 | ✅ 一致（従来の実データ照合） | 2026-10-20時点の回答は一致。2026-10-21のUI-24表示変更は計算を変えず、合成でexact／presence-only／unsupported／zeroと別通貨を確認。新表示の最新実データ再対照は未実施 | なし | [Balances対照](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#scheduled-series-calendar-and-real-data-balances-2026-10-19), [再確認](VERIFICATION.md#latest-data-check-of-the-2026-10-20-storage-work-2026-10-20), [UI-24表示](VERIFICATION.md#balances-current-list-detail-and-key-guide-2026-10-21) |
| 一覧の見た目 | ✅ 一致（実データ）＋🟦 Amount表記 | ID＋Amount／Measure／State。誤読防止のためLOAM raw Quantaとは異なり、Measureの小数スケールを正確に適用（12345 quanta→123.45 eur、JPYは74,500 jpy）。正数の「+」は付けない。80列上下／広幅左右、選択印・位置表示を維持。狭幅は通貨名を優先し、通貨名も収まらなければ数値を出さず詳細へ誘導。最新実データ120×36・80×24で行（ID・金額・Measure・状態）がLOAMと一致（見出しAmount／Quanta、Shell共通の見出し行、80×24で一覧枠が1行高い点のみ違う、2026-10-21） | なし | UI-24, [表示検証](VERIFICATION.md#balances-current-list-detail-and-key-guide-2026-10-21) |
| 選択した残高の詳細・下部案内 | ✅ 一致（実データ）＋🟦 追加キー | Locus→Measure→Amount→State→不明の説明→中立座標の説明。Amountは一覧と同じ正確なスケール適用額（LOAM raw Quantaとの差は誤読防止）。muted／indent、既存の追加キーw/v/c/o/SpaceとShellの共通header／最終行の差は維持。最新実データ120×36・80×24で詳細の並び・内容が一致（Amount表記以外） | なし | UI-24, [表示検証](VERIFICATION.md#balances-current-list-detail-and-key-guide-2026-10-21) |
| 確認した残高の入力（Observe） | 🟨 差あり | 複数口座を同時に入力・Preview・保存できる。入力欄の形がLOAMと違う。差分追加した明細が観測に反映済みと扱われず二重計上されるCore不具合を修正（合成で確認、2026-10-20） | なし | UI-31, [Observe修正](VERIFICATION.md#observation-after-incremental-record-2026-10-20) |
| Accounting表示 | ✅ 一致（実データ・120×36）＋🟨 長い行の省略 | 2026-10-21、Bakhloが登録済み科目（approved-loci）だけを数えていたため、記帳に使われているが未登録の科目（開始残高のEquityなど）が抜け、Equity欄とBalance Sheetが違っていた不具合を修正。LOAMと同じく記帳・残高根拠のある座標を数え、並びもトークン順に。120×36の実データで役割ごとの行・小計・Known Net Worthが一致。同日、LOAMと同じ構成（Measureごとの在高・Balance Sheet／Net Worthの可否、Evidence details、Answerability Map、次に必要な根拠、全残高の支持一覧）に揃え、件数・行がLOAMと一致。Bakhloは右に詳細欄があるため、長い説明行は一覧欄で`…`省略される。80×24は未照合。同日、増分記帳直後の科目欠落と訂正後の旧科目残留を修正（cold／Fullとの合成照合、最新実データ再対照は未実施） | なし | B01, V03, [Accounting対照](VERIFICATION.md#accounting-represents-evidence-coordinates-2026-10-21)、[記帳後の科目修正](VERIFICATION.md#accounting-uses-current-entry-coordinates-after-publication-2026-10-21) |
| 印刷・端末への出力 | 🟨 差あり | 画面内のPrint previewのみ。CurrentのPreviewは一覧・詳細と同じID＋Measureスケール適用後の正確なAmount（正数の「+」なし）。全文・上限・非保存取消を維持。LOAMの同意付き端末出力はない | 要判断 | UI-32, [UI-24表示](VERIFICATION.md#balances-current-list-detail-and-key-guide-2026-10-21) |

## 5. Daily Pace

| 項目 | 判定 | LOAMとの差 | 乗り換え | 根拠 |
| --- | --- | --- | --- | --- |
| 今日のPace | ✅ 一致（実データ） | 120×36・80×24で一致（2026-10-20の保存方式変更後も再確認。グラフも同日にLOAMの描き方へ揃えた） | なし | [実データ対照](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#latest-real-data-copy-and-paired-observation-2026-10-19), [再確認](VERIFICATION.md#latest-data-check-of-the-2026-10-20-storage-work-2026-10-20) |
| 過去のPace（5期間のHistory・選択行） | ✅ 一致（実データ） | bounded-history根拠を取り込み、全期間で一致 | なし | [履歴対照](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#bounded-history-support-and-real-data-pace-history-2026-10-19) |
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
| 全家計データの移行 | ✅ 手順あり・実データでリハーサル済み（本番は未実施） | 2026-10-21本人決定：切替日にLOAMを止め、その時点を一度だけ取り込み、照合後に記帳先を切り替える（二重記帳・同期なし）。移すもの：現在の明細・反転・日付訂正・予定と完了・Locus許可・役割・残高根拠・設定・Attention。LOAMの記録（Git管理のフォルダ）にだけ残すもの：訂正の途中経過、取消／置換した予定、予算（Capacity・Routing・purpose-catalog・cycle-funding。予算は使っていない）。切替時、BakhloのデータのそばにLOAMの記録の場所と切替日の案内を置く。2026-10-21、変換をリポジトリの`migrate/`へ移し、Attention・Merchant・元の金額・両替に対応（[証拠](VERIFICATION.md#loam-import-in-the-repository-2026-10-21)）。同日、切替日の取込手順`./tools/import-loam LOAMのフォルダ 新しいBakhloのフォルダ`を追加し、実データのコピーでリハーサル（[証拠](VERIFICATION.md#cutover-import-command-and-rehearsal-2026-10-21)）。本番の実行は切替日に本人が決める | なし | [乗り換え判定](CUTOVER_CHECKLIST.ja.md#切替は別の判断) |
| 年度の切替（単一帳簿での年またぎ） | ✅ 解決（設計変更） | 年別ファイル分割を廃止し、1冊の帳簿（スナップショット＋追記ログ、200件以上で終了時にまとめ直しと `.prev` 保持）に統一（2026-10-20実データコピーでも追記・200件まとめ直しを確認） | なし | [年別廃止](VERIFICATION.md#records-and-annual-files-removed-2026-10-20), [実データ試し保存・訂正比較](VERIFICATION.md#real-data-trial-saves-exit-compaction-and-unapproved-locus-correction-comparison-2026-10-20) |
| 保存の確認・電源断（P7） | 🟨 対策済み・実機の電源断は未試験 | 2026-10-21、保存はmacOSのドライブキャッシュまで書き切る`F_FULLFSYNC`を使い、書き切ってから保存完了を表示（1回約21 ms、本人承認）。途中で切れた最後の記録は書込を止めて明示操作で直す。実際に電源を落とす試験はしていない（[証拠](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/VERIFICATION.md#durable-save-flush-p7-2026-10-21)） | なし | O01 |
| バックアップと復旧の手順 | 🟨 復元未検証 | `--inspect-recovery`／`--discard-torn-tail`／`--restore-copy-from` とまとめ直し時の `.prev` 保持はある。普段の終了時にGitへcommit・push。2026-10-21、stage／commit／upstream／pending-log／pushの失敗を警告・異常終了にし、失敗時のローカル保持と次回再送を合成Gitで確認。実際の非公開バックアップからの復元は未実施 | 要判断 | O02, [終了時バックアップ](VERIFICATION.md#household-backup-failures-are-visible-2026-10-21) |
| 本人の実機・日本語入力での確認 | 🟨 本人判断で乗り換え | 2026-10-21、本人が「普段使いできそう」と判断して乗り換え。画面ごとの体系的な受入は未実施 | なし | — |
| 切替日と記帳先 | ✅ 決定（2026-10-21） | 2026-10-21に本人が決定し乗り換え。記帳先は`../bakhlo-data`、LOAMは凍結した記録。取込後の照合は[証拠](VERIFICATION.md#cutover-2026-10-21) | なし | [乗り換え判定](CUTOVER_CHECKLIST.ja.md#切替は別の判断) |
| Fava・hledger出力 | 🟦 意図的な差 | 本人の指定で対象外 | なし | — |

## 更新の決まり

- 差を見つけた・直した・照合したら、同じ作業の中でこの台帳の該当行を更新する（判定・差の内容・根拠リンク）。行を消さずに判定を変える。
- 「✅ 一致」には、どのデータ（実データ／合成）で、どの画面サイズで確かめたかを根拠先に残す。
- 本人が「この差は許容する」と決めた行は「乗り換え」列を「なし（本人了承 YYYY-MM-DD）」にする。
- 最終更新：2026-10-22（Actualの日別グループ化とHomeの`Enter`遷移を試置きした後）。
