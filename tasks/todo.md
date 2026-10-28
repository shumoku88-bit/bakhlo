# LOAMの機能・見た目・使い勝手をBakhloで再現する

作業の順序と未完了だけを置く。画面別の差分・進捗は[UI差分台帳](../docs/LOAM_UI_GAP_LEDGER.ja.md)、
普段使い5領域の要約は[カットオーバー差分台帳](../docs/CUTOVER_DIFF_LEDGER.ja.md)、実行証拠は
[検証記録](../docs/VERIFICATION.md)。完了済みの記録と旧計画（#42再構築、CI段階、Home／Record
仕上げ、各sliceのレビュー）は`032a876:tasks/todo.md`にある。

## 優先順位

普段使いの5領域（Record、Scheduled、Loci、Balances、Daily Pace）の差を先に閉じ、
次に残るLOAM機能・画面を再現する。予算配分・振替・消化・routing・Budget Windowは必要になるまで延期。

## コード品質レビュー（2026-10-27）

- [x] Core・保存・TUIを分担して読み、責務・命名・重複・失敗処理・テストを現物で確認する。
- [x] 既存の合成チェックを実行し、静的な所見と実行で確認した事実を区別する。
- [x] 良い点と改善候補をコード位置付きでレビューし、優先順位と確認範囲を記録する。実装変更は行わない。

### レビュー結果

対象は remote HEAD と一致する `086c3aa`。純粋な計算、検査済みbookの抽象型、cold reloadとの
生成テスト、TUIの依存境界は良好。改善候補は以下の順。新規の実装作業への承認ではない。

1. Scheduled差額補完の別実装を修正する（`scheduled_session.ml:192`）。機械整数で計算し、
   カンマ入力を無視し、既存suspenseを含めた合計で置換・削除する。公開handle経由の合成入力で
   誤った通知・下書き変更を再現。Previewの検証は誤った保存を拒否する。既存テストは検出しない。
2. 保存結果・復旧証拠の扱いを整理する（`shell_publication.ml:28`、`shell_files.ml:74`）。
   同じwriterでもObserve／roles／Attentionは通常記帳と別経路。保存成立不明のexpectedを捨てる。
3. `Daily_file`の公開面を絞る。`.mli`がなく、session構築や低水準置換まで外から利用可能。
   設定とSettlementの置換手順も重複（`shell_files.ml:41`、`settlement_file.ml:40`）。
4. `Daily_book`の金額入力を独立した純粋モジュールへ寄せる。小数処理の重複と、文字列による
   エラー分岐を整理する。`Daily_overlays`に混在する会計役割・集計・盆栽の責務も整理候補。
   Recordのaction整数・複数optionによる画面状態も型で明示する候補。
5. 旧設計の`sexp`／`Book_log`という名前、未使用の識別子型を必要な箇所から整理する。

`./tools/check`、`./tools/tui --self-check`、`./tools/format --check`成功。
実データ・LOAM対照・端末/IME・電源断は対象外で未実施。コード変更・commit・pushなし。
詳細な実行範囲は[検証記録](../docs/VERIFICATION.md#code-quality-review-2026-10-27)。

## コードを磨く（2026-10-27、moko承認）

目的は、既存の意味と操作を守りながら、処理を探しやすく、同じ規則を一箇所で読み取れ、
間違った状態を作りにくいコードにすること。保存形式・依存追加・実データの変更は行わない。

- [x] Scheduled差額補完：金額解析をPreviewと共有し、任意精度で計算する。既存差額行の
  再計算・反復操作・カンマ・巨大整数・不正入力の下書き保持を回帰テストで確認する。
- [x] Core金額入力：入力文法・表示・小数処理を純粋な専用モジュールへまとめ、公開APIと
  成功値・拒否理由を保つ。既存の生成/入力テストで検証する。
- [x] Record状態：Reviewの操作をvariantで表す。画面段階のoptionの関係を調べ、
  無理のない範囲で暗黙の状態の約束を型へ移す。既存の操作・描画回帰で検証する。
- [x] 保存境界：通常記帳・Observe・roles/Attentionの成立不明の証拠と復旧経路を揃える。
  Daily_fileの公開面と設定/Settlement置換の共通化は、同じ意味を保てる範囲で絞る。
- [x] 統合レビュー：正確なdiff、全体check/self-check/整形、変更画面の最新コピー対照、
  原本非変更を確認する。台帳・検証記録を更新する。
- [x] 検証した単位でcommit/pushし、該当CIを確認する。

### 実装レビュー

金額の文法は専用の純粋モジュールへ、差額補完はPreviewと同じ解析へ、Recordの有限な選択は
variantへ整理した。保存sessionはprivate recordで内容・パス・revisionの個別差替えを禁止。
Observe／roles／Attentionも成立不明のrevisionを保持し、保存成立の確認と無関係なRecordの
保持を実ファイルの故障注入で検証した。設定／Settlementは置換機構だけを共有した。

全体check・self-check・整形・全体privacy scan成功。最新の同一コピー世代を通常幅と狭幅で
旧Bakhlo／LOAM／新Bakhloへ開き、Bakhlo前後26画面は候補IDを除き一致。原本／コピー非変更。
Recordの全phase統合、全エラー型の再設計、Daily_overlaysの分割、旧名前の一括変更は今回に
含めていない。今回の変更と別の設計判断として扱い、将来用の仕組みは増やしていない。

4つの実装commitをmainへpush済み。最終実装`21cfb92`と一致する
[CI](https://github.com/shumoku88-bit/bakhlo/actions/runs/40486524266)で、Linuxのbuild・全回帰・
PTY入力/resize/非保存検査がすべて成功。後続の完了記録は文書のみの変更。

## 旧設計の名前を取り除く（2026-10-27、続き）

前回見送った「旧名前の整理」の続き。意味・形式・画面は変えない。

- [x] `Records`・`Book_log`を`Daily_book`へ畳み込み（`change`・`apply`）、未使用の識別子型を削除。
- [x] `sexp/`（S式を持たない）を`household/`（`bakhlo_household`）へ改名。テスト用bookも`*.txt`。
- [x] `Daily_actions`の基底revision検査を一箇所に。空の`legacy_shared_literals`を削除。
- [x] push後、該当SHAのCIを確認する（`08383f6`、[run 40489301603](https://github.com/shumoku88-bit/bakhlo/actions/runs/40489301603) 成功）。

- [x] `get`／`get_id`（例外を投げる汎用補助）を本番から除く。座標は`Daily_draft.coordinate`が
  `result`で返し、起動時の検査は`Shell_state.initial`に明示、テスト補助はscenario fixtureへ。

- [x] `Daily_overlays`を分割：会計役割は`Locus_roles`へ一本化（表示ラベルとファイル用トークン）、
  Balancesの行は`screens/balances/balance_items`（`.mli`付き）、盆栽はHome画面へ。未使用の
  `progress_bar`を削除。

- [x] Recordの段階を一つの`phase`型に（Quick／Form／Original／Enabling／Review）。確認中の貼り付けが
  裏のフォームに入っていた不具合も解消。

- [x] macOSでCtrl-Oが端末ドライバ（VDISCARD）に取られ原額入力が開かなかった：起動中だけ外し、終了時に元へ戻す。
[検証記録](../docs/VERIFICATION.md#old-names-removed-from-the-household-book-and-shell-2026-10-27)。

### 次の候補（未着手、急ぎなし）

- [x] Income & Expenseの比較：今の2本並びのままでよい（moko、2026-10-28）。
- [x] `Daily_overlays`を`Book_display`（`.mli`付き、帳簿の値の表示だけ）へ。描画部品は`Ui_render`から直接使う。
  Record一覧の金額の桁区切りも`format_money`へ一本化（2026-10-28）。
- [x] `Daily_`接頭辞の見直し（2026-10-28、moko承認の名前と順番）：`Day`（日付の規則も一つに）、`Line_edit`、
  `Command_line`、`Book_file`（`today`は`Clock`へ。`new_id`は乱数の読み手を共有するので残す）、`Book`、`Draft`
  （`format_message`は`Ui_text`へ）、`Publication`（`include Draft`をやめ`.mli`付き。`Publish`は画面の意図の
  コンストラクタと重なるので避けた）。`Daily_pace_*`は家計の言葉なのでそのまま。
- [x] `Daily_txt`を消した（2026-10-28、moko承認）：`Book`は会計区分とAttentionを型で持つのに、
  `Daily_txt`が旧ファイル形式（accounting-roles.tsv・attention.loam）の文字列へ印字し、Shellが`Locus_roles`・
  `Attention_data`へ解析し直し、保存時にまた解析する往復がある。`Locus_roles.role`は`Book_txt.role`と同じ、
  `Attention_data`の項目も`Book_txt`の`item`/`close`とほぼ同じ。画面が`Book`の型を直接使い、保存は`Book.change`に
  すれば、文字列の書式・解析と`Book_file`の`sidecars`がなくなる。保存の意味に触れるので、cold reload照合を先に広げる。
  → `Book.change`に`Set_roles`/`Set_attention`（cold reload照合を先に拡張）、TUIの役割・Attentionの型は`Book_txt`の型、
  Loci画面は`Save_roles`、`Book_file`の`sidecars`と文字列書式・解析を削除、`Book.read`/`Book.print`。旧・新バイナリで
  同じ操作をした合成コピーはバイト一致。
- [x] 役割とAttentionは帳簿と一緒に受理済みなので、`Screen.env`の`accounting_roles`/`attention`から`result`と`Lazy`を外し、
  約10画面の「役割を読めない」分岐と、その不可能な状態を作っていたチェックを消した（2026-10-28、moko承認）。
  I&Eの「役割のない科目」の見出しから`accounting-roles.tsv`を外した。
- [x] Locus追加と役割設定を1回の保存にまとめた（2026-10-28、moko依頼）：`Add_locus { token; role }`、途中で失敗すると
  役割のないLocusが残る2回目の保存と、その「役割は保存されていない」表示がなくなった。
- [x] 型のEffect（`lib/`）とbook.txtの二重構造（2026-10-28調査、(B)をmoko承認・実施）：`lib/`（334行）の規則
  （空ID・0金額・不釣り合い・鍵の重複）はbook.txtの受理（`bad-token`・`zero-amount`・`unbalanced`・`duplicate-key`）が
  すべて、より厳しく持つ。`Book`は読むたびにpostingを型のEffectへ、保存のたびに戻し、`Event.create`・
  `Movement.validate`で受理の一部をもう一度行う（AGENTS.mdの「第二の受理エンジンを作らない」に反する形）。
  型の区別はEffectの中だけで、`Book`のAPI・予定・IDは文字列。つなぎの`lstr`/`mstr`/`quanta`は本番で88か所
  （`Book`にも同じ定義）。型が実際に働くのは、Draftの事前チェック（何行目が0か等の表示）、Daily Paceの
  プール座標、5か所のEffect組み立て。`Bakhlo_domain`を使うのは本番46・テスト22ファイル。
  方向：(A) `Book`のAPIも型で揃える、(B) entryをbook.txtの形（文字列と整数）にして`lib/`を消す。
  → (B)を5段で実施：`Book`の二重受理をやめる、entryのeffectsを`Book.posting`（=`Book_txt.posting`）に、
  座標を`Book.coordinate`に、`lib/`と関連テストを削除（行ごとの下書きチェックは`Posting_draft.movement_fault`）。
- [x] 今日の機械的な置換の後始末（2026-10-28）：14個の`book_of_text`は各ファイルの`get (B.read …)`に、30か所の
  `x.Bakhlo_household.Book.amount`は`x.B.amount`に、`sidecar_integration_checks`は`save_safety_checks`に。存在しない
  `docs/RECONSTRUCTION_TEST_MAP.ja.md`を指していた15個のシナリオの見出しを、そのファイルが確かめる内容に。
- [x] 「受理済み」の通貨の型（2026-10-28、パイロットは設計段階で中止、コードなし）：`Book_txt`の値（`T.t`とposting）は
  手で組み立てられ、書いた文字列を読み直したときだけ受理される設計（生成テストもそう作る）。postingに受理済みの型を
  入れると、確認なしの生成口（保証が崩れる）か、`Book`境界の変換（今日消したもの）のどちらかが要る。先にやったこと：
  隣り合う文字列だった`parse_amount`/`parse_signed_amount`の通貨をラベル`~measure`に（`ff0f7b3`）。`format`が知らない
  通貨で例外を出す経路は、現状の呼び出し元を調べた限りない（通貨はすべて帳簿由来か、外部入力は手前で拒否）。
  再挑戦するなら「手で組む値」と「受理済みの帳簿」の型を分ける設計から。手順・基準・設計案は
  [受理済みの型の調査書](../docs/ADMITTED_TYPES_STUDY.ja.md)（人でも別のAIでも、そこから始められるように書いた）。
- [x] 精算画面の金額を通貨の桁数で表示（`b78c1f2`）：1,050.00 EURが「105000 eur」と出て、残額の初期値「105000」は
  105000.00として読まれ拒否されていた。帳簿に無い通貨は最小単位に「?」を付け、詳細欄で説明する。
- [ ] TUIのコード量（2026-10-27計測：本体約28,000行、テスト・シナリオ約16,300行。コアは約3,500行）を
  減らせるか調べる。まず測る：画面ごとに似た処理（枠・行の描画、スクロール、一覧の選択、狭幅の処理など）が
  どれだけ重なっているかを数え、削る価値の大きい順に並べてmokoに見せる。例：`record_session.ml`の
  `sub_border`／`inner_line`と`Ui_panel`。共通化は今いる利用者で正当化できるものだけ（`tui/README.md`）。
  - 調査結果（2026-10-28、本体25,321行・テスト16,289行）：画面固有の処理が大半で、大きな重複はない。
    削る価値の順に (1) 一覧の上下移動：20ファイルが矢印・j/kを自前で処理し、共有のキー表が2つあって
    食い違う（`Ui_input.motion_delta`は素のu/dでページ、`Report_frame.scroll_move`はCtrl-u/dとg/G）。
    LOAMの画面ごとのキーを確かめてからでないと揃えられない。(2) テストだけが使う公開値42個と、どこも
    使わない公開値3個（`Locus_roles.role_to_string`／`role_of_string`、`Actual_workspace.shown_total`は
    内部でだけ使用）。(3) 小さな重複：Scheduledの`grouped`（`format_money`と同じ）、`clamp_index`が2箇所、
    Recordの`sub_border`は`Ui_render.panel_border ~inset:0`と通常幅で同じ文字列。(4) `.mli`のない21モジュール
    （3,841行、主にshell）は未使用の値をコンパイラが指摘できない。
  - [x] (3)と(2)の不要な3個を片付けた（2026-10-28）：`grouped`は`format_money`へ、`clamp_index`は`Ui_panel`に一つ
    （`Ui_form`の3箇所も）、3個は非公開に。Recordの`sub_border`／`sub_bottom`は残す：題名が幅いっぱいになる
    約30セル以下で`panel_border`と切り詰め方が違い、LOAMに合わせた狭幅のRecord枠が変わるため。
  - (1)のLOAM確認（2026-10-28、LOAMソースを読んだだけ）：LOAMにも画面共通のキー表はない。行は↑↓・j/k・J/K、
    ページはPgUp/PgDn（Selected Day・Balances・Attention・Trend・Whyと各ヘルプはCtrl-U/Dも、Actual・
    Scheduledの一覧はなし）、端はHome/End。素のu/d/g/Gは画面ごとの操作（日付訂正、監視解除、I&Eの表示切替）。
    Bakhloの`motion_delta`の呼び出し元はCtrl付きのu/dしか渡さないので、素のu/dで動く画面はない。
    Reportsの`g`/`G`＝端はBakhloの選択（ヘルプに記載、I&Eの表示切替は`t`）。揃えるならLOAMの和集合
    （J/KとCtrl-U/Dを全一覧へ）で、Actual・Scheduled一覧などにキーが増える。
    → 今のままにする（moko、2026-10-28）：キー操作を変えず、行数もあまり減らないため。

## 要判断

- [ ] LOAMのComplete Since（履歴の完全性の記録）をパリティ一覧に入れるか（Daily Paceの過去日に関わる）。
- [ ] パフォーマンス最適化の追加着手時期（[調査書](../docs/PERFORMANCE_AND_GADT_STUDY.ja.md)）。金額列幅の早期終了・キー内の重複解決削減・可視行だけの文字列化は `7a7dc9e` で実装済み。残る全件走査・sort の費用を分解してから次を判断する。日付インデックスは範囲抽出費用が支配する場合に検討。追加GADT化は推奨せず、起動最適化の保留を維持。

## 未完了

- [ ] Trend / Locus comparisonのマウスでの選択（LOAMのclick/drag/wheel scrub。描画とキー操作は2026-10-24にLOAMへ揃えた）。
- [ ] Accountingの一覧欄で長い説明行が`…`省略される（詳細欄と並ぶため）。80×24で照合。
- [ ] Daily Pace：同じ端末寸法でcontext／Trend／History／Selected day／feedback／操作案内、
  グラフと日付軸・件数・選択・scroll・戻りを揃え、同じ入力で4寸法・全5期間・known／partial／
  unavailable・resize・coldをLOAMと対照する。
- [ ] Scheduled保存操作で owner→intent→Shell→単一writer→owner結果 を検証する。

## 受入領域（各画面の詳細は差分台帳）

各sliceは、入口から入力・確認・取消／確定・親復帰まで接続し、合成回帰、LOAM既存binaryとの
同じ入力での対照、保存→再起動の同一性、失敗・競合時の非保存と下書き保持を確かめる。
実装・self-check・対照実行・本人／IME受入・P7は別々に記録する。

1. [ ] Record lifecycle（新規・候補・Posting追加削除・差額補助・Preview全文／狭小gate・下書き再開）
2. [ ] Actual／Selected Day（検索・scope・sort・詳細、訂正・日付変更・Merchant／原額・返金／反転）
3. [ ] Scheduled（List／Series Calendar／Months／Detail、作成・置換・取消・実績化・補充・Expected pace）
4. [ ] Balances／Observe（Current／Accounting・履歴、根拠と不明、複数座標観測）
5. [ ] Daily Pace／Trend（Pool・期間、What-if、履歴支持、予定控除、設定の保存と保全）
6. [ ] Attention／Settlement／Exchange（期限・解決、部分精算・相殺、両数量と専用Preview）
7. [ ] 残るReports・Household setup・Help／Theme／locale・Print／診断・盆栽の表示と成長
