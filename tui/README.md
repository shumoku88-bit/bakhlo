# 日々の画面（試用）

LOAMの見た目と操作へ揃える英語UI。現在の`./tools/tui`は先行実装のBonsai_term環境を使う。
旧Notty画面、両画面比較ベンチ、独立したBonsai配置試作は削除した。NottyライブラリはBonsai描画と
native renderer検査で引き続き使う。新依存・global環境変更は行わず、通常DuneビルドはUI依存不要。

まずLOAMと同じ英語表記で作る。日本語UIは未定で、後からNotty版を作る選択肢も残す。
`Ui_text.tr`は現在の英語表示文言の入口で、日本語対応の実装約束ではない。
科目名・メモ等のユーザーデータは翻訳しない。
[UI方針](../docs/UI_DIRECTION.ja.md)、[UI差分管理台帳](../docs/LOAM_UI_GAP_LEDGER.ja.md)も参照。LOAMの正データ・普段の記帳先は変更しない。

## 起動

Bakhloディレクトリから`./ui`（親のmokoからは`./bakhlo/ui`）で、選択した比較コピーを開く。
LOAMを閉じて`./ui --refresh`で取得・更新し、別の端末の`./ui loam`で同じ取得時点のLOAMコピーを開ける。
取得・変換は既存の私用Daily変換試行に依存する限定ローカル手順で、正データへの書込みや全家計移行ではない。
起動中のLOAM、未対応のActual証拠、不正な変換、取得中の変更は拒否し、前回の選択とコピーを保持する。
別のタブ／ウィンドウのLOAMもHomeの`q`で終了する。停止拒否時は残っているPIDと端末名を表示する。
差分は日付フィルタではなく安定ID／全内容で比較し、新しい対応範囲の台帳全体を再生成する。
元のhouseholdとconfig、以前のコピー、変換外の家計証拠・旧版は私用scratchに保持する。
両UIの試用保存はそれぞれのコピーだけ。通常のLOAM正データや私用候補は上書きしない。
テーマ設定は`scratch/loam-comparison/ui-config`へ隔離する。欠損時に合成データや正データへ戻らない。
合成確認は`./ui --demo`（既存の`scratch/ui-preview`を再利用）。Homeの`q`で終了する。

別の試用は合成データを新しいignoredディレクトリへコピーする。既存試用を上書きしない。

```sh
umask 077
mkdir scratch/my-daily-trial
./tools/tui --copy-from examples/daily-book.sexp --book scratch/my-daily-trial/book.sexp
./tools/tui --book scratch/my-daily-trial/book.sexp
```

隔離環境なし・非TTY・未供給／不正な台帳は拒否し、空台帳へ置き換えない。
ABIが異なるため、現在のCore・台帳・UIソースを`_build/daily-bonsai`で再ビルドする。
生成先は追跡中のモジュールだけへ更新し、削除済み旧UIソースを残さない。

## Home / CalendarとCommands

HomeはCalendarと対象期間のActual / ScheduledのDetail。Day / Month / Yearを切り替え、
日付からSelected Dayへ進む。丸角枠、固定下部操作、折り返す通知、フォーカスと選択マーカーを使う。
80列付近ではコンパクトなCalendarの下にDetail、120列以上では左右に並べる。
極小端末ではフォーカス側を優先し、選択日を隠さない。収支の役割は推測せず、Actualとopen Scheduledの件数／存在を示す。

- `h/l`／`←→`：前後の日・月・年。`k/j`／`↑↓`：週・四半期・年の移動。
- `z`：Day / Month / Year。`t`：今日。`/`：日付・月・年へ移動（Enter適用、Esc取消）。
- `Tab`／`w`：Calendar / Detail。`Enter`：Year → Month → Day → Selected Day。
- `r`：選択日入りRecord。`a`：Actual。`s`：Scheduled。`b`：Balances / Current。`d`：Daily Pace。
- `Space`：階層Commands。`↑↓`／`j/k`で選択、`→`でグループ、Enterでグループ／画面を開く。
  `←`／`Esc`／`q`／Spaceで一階層戻る。右矢印だけでleafの画面を開かない。
- `q`：子から親へ、Home / DetailではCalendarへ、Home / Calendarで終了。
  閲覧中の`Ctrl-Q`：終了。`Ctrl-R`：明示的な再読込。

CommandsはTransactions、Plans and attention、Reports and analysis、Household setup。
実装済み入口だけを置き、削除したEnvelope budgetは置かない。
記帳中のSpaceや`q`は文字入力で、背面のコマンドを実行しない。
Actual / Scheduled / Selected Dayで選択・検索・詳細と復帰を共有する。別明細の訂正・支払いで
保持中の下書きを黙って置き換えない。
Actualは幅が足りる一覧でDate／Description／Amountを整列し、正確な符号・桁区切り・通貨を表示する。
複数の正負Postingは`split`、混合通貨は`multi`、収まらない金額は`see details`とし、数量を途中で切らない。
ActualはLoci／Actuals／Detailsの3ペインと画面内の`/`検索を接続済み。
検索は入力中に絞り込み、Enterで保持、Escで解除する。長文は可視末尾だけを表示し、
保持する検索値を切らない。日本語を含む末尾と実カーソルを同じ可視窓に収める。
`f`は日付scope、`s`はsort、Tab／h/lはpane、EnterはActuals→Details→Selected Day。
ActualとScheduledの詳細はHome／Endで選択を変えず、ページ送りは可視行数に従う。
3ペイン全体の最新LOAMとの配置・操作一致は未認定。限定した検索対照と未達範囲はUI差分台帳を参照する。
Actualの`c`はCorrect、ScheduledのEnterは閲覧だけのDetail、`c`は明示的なComplete。
支払い入力を開く操作だけでは台帳を変更しない。

## Record / EditとPreview

Date、Description、Measure、符号付きPostingを入力する。科目名／IDを入力して許可済み候補を
選び、名前から口座・費目の役割を推測しない。複数行も一つのRecord下書きで扱う。
通常サイズでは親の日付を残す中央ペイン、狭い・短い端末では全画面へ畳む。
編集中の項目は表示位置が追従し、長い入力でも実セル幅に合わせてカーソル周辺を見せる。
通常入力は青系、訂正／完了はアンバー、Cancel選択はローズの枠のみで区別する。
Cancelは削除ではなく下書き保持。本文と背景は通常のトーンを維持する。

- `Tab`／`Shift-Tab`：項目。Enter：候補確定・次項目・Preview。
- `←→`／Home／End／Backspace：文字カーソルと削除。
- `↑↓`：Locus候補。`Ctrl-N`：行追加。`Ctrl-D`：行削除（新規・支払い入力）。
- `Ctrl-S`：Previewを開く。保存はしない。Esc／Cancel：下書きを保持して閉じる。
- PreviewのPublish / Edit / CancelはTab等で選ぶ。**Publishを選んでEnterだけが保存を要求する**。
  Editは入力へ、Cancelは下書きを保持して閉じる。PreviewのCtrl-Sや貼付では保存しない。

PreviewはID・日付・メモ・全Postingの符号付き数量・Measure・Locus ID・キー・支払い対応を表示する。
長文は折り返しとスクロール。極小端末では証拠を隠した確定を拒否する。
小端末で確認全文が収まらない場合はEndでも確定を拒否する。通常サイズの複数ページ確認は
最終ページへ移動してからPublishを選ぶ（Endは末尾へ移動するだけで保存しない）。数量は整数quantaと明示の
小数桁で扱い、丸め・通貨合算・為替推測はしない。差額ゼロは台帳検査や保存権限の代わりにならない。
訂正は明細ID・Posting構成／キー・通貨／符号・支払い対応を保つ。構成変更や両替・返金対応付き
明細の訂正は拒否する。単一S式のScheduled完了は実明細とpaid-byを同時更新し、支払い済み／取消済みを再利用しない。
一行貼付は文字のみ、改行・制御入りは拒否する。競合・結果不明では下書きを保持して書込み停止し、警告を隠さない。

## Actualの日付だけの訂正

Actual／Selected DayでActualを選び、`d`で専用のDate編集を開く。
現在日付を初期入力し、既存の日付parserで正規化・暦検査する。
EnterはPreview、PreviewのEnterだけが保存。現在日付・変更先・対象IDを表示し、
`Esc`／`e`で編集へ、`q`で非保存の取消。長いIDはスクロールして末尾まで確認する。
狭小端末（editor幅46未満／高さ14未満）では確定を拒否する。
明細ID・メモ・全Posting／キー・支払済み予定の対応は保持し、日付だけを既存writerで置換する。
Selected Dayは元の日に残り、対象が移れば一覧から消える。親Actualへ戻ると同じIDを追従する
（scope／検索から外れた場合は既存のclamp／通知に従う）。
保持中のRecord draftがあれば開始を拒否。stale／結果不明は停止し、reloadで古い確認を有効化しない。
Records形式は既存Actualの置換をサポートしないため、非保存で拒否する。
合成操作・通常再起動は確認済み。LOAM対照・IME／本人受入・P7の認定ではない。

## Actualの反転

Actual／Selected Dayの`x`は専用のDate→Previewを開く。DateのEnter／Ctrl-Enterは確認だけで保存しない。
Previewには元ID・元日付・説明・反転日・元／逆Postingの完全な符号付き数量とMeasureを表示する。
`j/k`／↑↓、Page Up/Down、Home/Endで確認し、Publishを選んだEnterだけが既存writerへ意図を返す。
末尾未確認、狭小画面、短い画面に全文が収まらない場合は確定拒否。Endも保存ではない。
PreviewのEsc／e／Editは日付へ、q／Cancelは元の一覧・詳細へ戻る。日付側のEsc／qは取消。
保持したRecord draftがある間は反転を開かず、保存拒否では反転の日付・target・baseを残す。
Ctrl-rのreloadで世代が変わってもPreviewを新しいbaseへ更新しない。取消→reload→再選択が必要。
結果不明は停止し、reloadで既存candidateを確認しても自動再発行しない。Recordsの反転は拒否する。

## ScheduledのMonths表示

Scheduledの`v`でListとMonthsを切り替える。MonthsはListの絞り込みとは独立した全open予定を
日付・ID順で扱い、通常幅では2列×3段の月カードを表示する。各月の明示予定件数と
日・Locusの向き・数量を表示し、splitの合計や異通貨の合算、周期・予定の充足を推測しない。
空月の「No explicit plan」は「義務なし」ではない。
`h/l`／←→で月窓を移動し、起動時の当月より前には戻らない。
`j/k`／↑↓、Page Up/Down（8件）、Home/Endで予定を選ぶと、対象が見える月窓へ追従する。
過期限の予定も選択・詳細照会できるが、月窓は当月に留める。年末を跨ぎ、9999-12を越える月は作らない。
`i`／Tabは正確な全Postingをスクロールできる詳細、Escは月カードへ戻る。
MonthsのEnter／`c`は選択予定の支払い入力を開く（開くだけでは保存しない）。
`r`／`e`は既存の単発Edit、`x`は専用取消確認、`n`は単発作成。継続・coverage管理は未接続。
`v`でListへ戻ると元の検索・scope等を保ち、対象IDが見える場合は同じ予定を選ぶ。
元の絞り込みで対象が見えなければList側の選択を保持する。
狭幅・低い端末ではcompact案内と可能な範囲の詳細を表示し、`v`でListへ戻れる。
閲覧・月移動・切替は非保存。LOAMとの実行対照・本人受入は未了。

## Scheduledの取消

Scheduled／Selected Dayでopen予定を選び、`x`で取消日を入力する。
最初のEnterは独立Previewのみ。対象ID・期日・取消日・全Expected Effectsの符号付き数量を確認する。
Previewは**Keepが初期選択**で、Enterなら非保存で親へ戻る。
Tab／←→でCancel Scheduledを選び、確認後のEnterだけが既存writerへ取消を渡す。
`Esc`／`q`はKeep、`e`は取消日の再編集。長い対象・数量はj/k・Page・Home/Endで確認する。
末尾未確認・狭小、短い画面に全文が収まらない場合は確定拒否。Endは保存操作ではない。
取消済み予定はID・期日・数量を保持してopen一覧から外れ、Actualや残高は増減しない。
保持中のRecord draftがあれば開始を拒否する。保存拒否では取消日と対象を残し、選択をKeepへ戻す。
stale／結果不明は停止し、reloadで古い確認を有効化しない。Recordsは取消非対応のまま。
LOAMは対象だけの取消確認だが、Bakhloは既存のdated-cancel契約に従って取消日の入力を残す。
合成PTY・通常再起動は確認済み。LOAMとの実行対照・本人受入は未了。

## Scheduled完了後の補充・継続意識

予定の支払い完了が確定・保存された直後、次の予定の意図を確認する画面が開く。
完了した予定の正Locus集合と一致する後日のopen予定があれば、それを候補として表示する。
候補がある場合：
- **Keep as is**（初期選択）：何もしない。新しい予定は作らない。
- **Add another**：期日は自動入力せず、同じ金額・Locus構成の予定作成エディタを開く。
- **Review**：候補予定の詳細をスクロールして確認し、選択肢へ戻る。
候補がない場合：
- **Done**（初期選択）：何もしない。
- **Defer to Attention**：期限未定（Due_undetermined）の確認事項としてAttentionへ残す。
- **Add next**：期日は空で、同じ構成の予定作成エディタを開く。
これは事後意識のための確認であり、同一契約・定期周期・シリーズ同一性を勝手に推測しない。
Addによる新規予定作成は通常どおりPreviewを経て保存される。

## Scheduledの複数金額変更（一括編集）

ScheduledまたはSelected Dayでopen予定を選び、`b`を押すと一括金額変更画面が開く。
選んだ予定と同じ通貨・同じ正負Locus構成を持つ現在openの予定が候補となる。

1. **パラメータ入力**:
   - 新しい金額（正の十進数、選択予定の通貨単位）
   - 開始日（From、初期値は選択予定の期日）
   - 終了日（Through、省略時は開始日以降の全予定が対象）
   - Enterで候補一覧へ進む。
2. **候補選択**:
   - 候補はすべて初期状態で未チェック（`[ ]`）。
   - `Space`で1件選択／解除、`a`で全選択、`d`で全解除。
   - `j/k`・`Home/End`で移動、`e`でパラメータ再入力へ戻る。
   - 2行で釣り合わない分割Posting（split）を持つ予定は、配分を勝手に推測できないため候補から外され、個別編集を促す。
   - 金額変更のない予定は自動で除外される。
3. **差分プレビューと確定**:
   - EnterでPreview画面へ進み、変更前の金額・変更後の金額を全件確認する。
   - **Backが初期選択**（非保存で選択へ戻る）。
   - `Tab`／`←→`でPublish allを選び、末尾までスクロールしてEnterを押すことで、全件が**1回のトランザクションで原子的に保存**される。途中で一部だけ保存されることはない。
   - 狭小端末での確定拒否、Records形式の拒否、競合（stale）停止の安全策を備える。

## Scheduledの定期生成（期間展開）

Scheduledでopen予定を選び、`g`を押すと定期生成（Scheduled / Generate Plans）画面が開く。
選んだ予定をテンプレート（通貨・金額・Locus構成）として、指定期間の予定候補をまとめて作成する。

1. **パラメータ入力**:
   - 終了日（Through排他、初期値は6か月後）：指定日より前の予定が生成される。
   - 周期（Cadence）：Monthly（毎月）、Every 2 months（2か月ごと）、Every 3 months（3か月ごと）、Every 6 months（半年ごと）、Yearly（年1回）。
   - Enterで候補プレビューへ進む。
2. **プレビューと確認**:
   - 生成される全予定の番号・期日・金額・Locus構成を確認する。
   - 31日や2月末など、月によって存在しない日付は自動的にその月の月末日に安全にクランプされる。
   - **Cancelが初期選択**（非保存で終了）。
3. **確定と保存**:
   - `Tab`／`←→`でPublish allを選び、末尾までスクロールしてEnterを押す。
   - 全ての予定が新しい一意なIDを持ち、**1回のトランザクションで原子的に台帳へ追記**される。
   - 周期やシリーズ同一性は事実にせず、独立した単発予定として保存される。

## Daily Paceの推移（Trend）

Homeで`d`を押すと、今日の目安（Daily Pace）画面が開き、過去から現在に至る日々の消化ペース推移（Trend）を表示する。

- **期間プリセット切替 (`1`〜`5`)**:
  - `1`: 10d（過去10日間）
  - `2`: 30d（過去30日間）
  - `3`: Month（当月初日〜今日）
  - `4`: Cycle（`boundary-presets.tsv`に基づく現行サイクル）
  - `5`: Previous Cycle（直前の年金・給与サイクル）
- **グラフ表示切替 (`v`)**:
  - 折れ線（`line`）と散布図（`dots`）を相互に切り替える。
- **タイムライン日移動**:
  - `h`/`l`・`←`/`→`: 日付を前後に1日移動し、選択日の詳細を表示。
  - `Home`/`End`: 表示期間の最初／最後の日にジャンプ。
- **詳細ペインの展開とスクロール (`Tab` / `i` / `Enter`)**:
  - 選択日のペース、前日比増減、残日数、サイクル終了日（排他）、口座プール残高、予定控除額、終了日までの利用可能額を表示。
  - `j/k`・`PageUp/Down`で詳細文をスクロール。`Esc`/`q`でタイムラインへ復帰。
- **シミュレーションと設定**:
  - `w`: What-Ifシミュレーション（仮の支出影響の試算）。
  - `c`: 対象口座プール（`daily-pace.tsv`）の編集。

## BalancesのCurrent残高とAccounting表示

Homeで`b`を押すと、LOAM準拠の**Balances / Current**（現在の各口座・通貨の残高一覧）が開く。
`balance-view.tsv`で指定された順序で中立座標（Locus × Measure）を表示し、未設定時は承認済みLocusを表示する。

- **一覧操作**:
  - `j/k`・`↑/↓`: 1行移動。
  - `Page Up/Down`・`Ctrl-u/d`: 画面単位のページ移動。
  - `Home`/`End`: 最初／最後の残高へジャンプ。
  - `Enter`・`i`・`Tab`・`h/l`: 選択した残高の詳細（Selected Balance）を右ペインに表示・スクロール。
  - `Esc`・`q`: 詳細ペインから一覧ペインへ戻る。一覧ペインで`Esc`/`q`を押すとHomeへ戻る。
- **モード切替 (`v`)**:
  - `v`を押すと**Balances / Accounting**（資産・負債・純資産・収益・費用の会計分類表示）に切り替わる。
  - 再度`v`を押すと**Balances / Current**に戻る。
- **印刷プレビュー (`p`)**:
  - 画面内Printプレビュー（200行上限）を開き、CurrentまたはAccountingの全文を確認できる。
- **観測記録 (`o`)**:
  - 選択中の残高座標（Locus・Measure・確定金額）が自動入力されたObserveモーダルを開く。

## 対応範囲と差分

新UIはCalendar、階層Commands、英語Record、Actual / Scheduled / Selected Dayの閲覧と詳細、
既存検査・保存への接続を対象にする。LOAMの全会計機能を再実装したものではない。
role-aware収支カレンダー、完全なSeries／coverage管理・定期補充／監視、履歴Trend、原額・Merchant、
実取引への配分を伴う精算・後日カード決済、広いレポート群は未対応。
単一S式の予定作成（Scheduled `n`）・変更（`e`）・取消（`x`）・支払い（`c`）は接続済み。
Actual `x`は元明細を残す正確な反転の新規記帳。Recordsは対応外の変更・取消・反転を拒否する。
CommandsからExchange、Manage Loci／役割設定、Attention、限定commitment精算へ進める。
Home／Calendar／Balances `o`はObserve。これらの存在は全LOAM互換を意味しない。
Balancesは既存照会で通貨別に表示し、不明・存在あり量不明・ゼロを区別する。
Daily Paceは明示pool・Measure・今日・期間末の既存計算を表示する。
`daily-pace.tsv`／`boundary-presets.tsv`がなければ未設定とし、条件を推測しない。
`w`は読み取り専用What-if、`c`はPool編集。未設定・不正・重複・混合Measureは計算しない。
明示された実日付・昇順境界を持つpresetが今日を含むものとして一意でなければ拒否する。
月末・Asset分類・全許可Locusから条件を補完せず、What-ifの負数もゼロに丸めない。
Pool編集は選択ファイルのbytesを再確認し`daily-pace.tsv`だけを更新する。
`boundary-presets.tsv`の他期間・過去境界は変更せず、この画面で期間末を編集しない。
履歴Trend・期間比較は未対応。Calendar選択日を今日の観測日に置き換えない。
Daily_bookは単一S式v1〜v3とRecords v1を読み、単一S式ではv3を書く。旧予算v4・予算APIは非対応。
通常Bookのrecord / exchange CLIとは混用せず、未知フィールドを飛ばして保存しない。

## テーマと実装

- **Terminal (follow terminal colors)**（初期値）: 通常文字・背景は端末に委ね、端末のライト／ダークや
  カスタム配色をそのまま使う。HomeのフォーカスはANSIシアン、選択は反転と太字。
  編集枠も端末のANSI色（作成はシアン、変更は黄、取消は赤）を使い、固定RGB／256色を混ぜない。
  端末の明暗を推測する自動判定や、OSの外観設定には依存しない。
- **Bakhlo Light / Dark (original)**: 端末配色とは独立したオリジナルテーマ。
  本文・背景・選択・編集枠は固定xterm 256色を使う。24-bit SGRは出さない。

入力カーソルと枠線は本文の文字と分離して描画する。現在のBonsai属性APIにdimがないため、
補助表示は装飾と配置を抑えて区別する（LOAMのdim表示とは異なる）。
Space → Commands → Themeで直接変更する。Household setup内からも開ける。
↑/↓またはj/kでHomeを含む配色をプレビューし、Enterで確定して台帳とは別のUI設定へ保存する。
Esc／qは変更前の配色と元のCommands選択へ戻す。選択日・一覧・保持した下書き・安全上の警告は失わない。
保存先は`BAKHLO_CONFIG_HOME/ui-theme`、`$XDG_CONFIG_HOME/bakhlo/ui-theme`、
`$HOME/.config/bakhlo/ui-theme`の順。次回起動でも選択を復元し、設定不備ではTerminalへ戻る。
設定を保存できない場合はそのセッションだけ変更し、保存できなかったことを通知する。

- daily_calendar / ui_workspace / ui_commands：純粋な暦・画面・選択・階層ナビ。
- record_session / ui_input：一つの下書き・Previewと入力型。
- reversal_session：反転の日付と固定snapshotの元／逆Posting確認。ID割当・永続inverse構築・I/Oは持たない。
- daily_interaction：全体の遷移・英語表示・既存検査／publisherへの接続。
- daily_overlays / ui_text：cell幅・枠・完全な数量詳細と将来の言語カタログ入口。
- ui_panel：一覧・詳細の共通枠、可視行数、選択追従viewport、整数overflowを避ける端移動。
  ActualとScheduledの描画・ページ送りが同じ規則を使う。対象の意味・キー割当・保存判断は持たない。
- daily_actions / posting_draft / daily_file：既存の数量・検査・保存境界。
- bonsai_daily：実描画と入力adapter。会計計算は持たない。
  Resizeとキーが同じbatchに入るため、寸法はhandler内に捕捉せずstate_machine_with_inputのaction適用時に読む。

### 共通化の境界（KEEP / 統合 / LOCAL）

責務・API契約・全利用元・移行順・横断受入の所有文書は
[TUI共有部品の責務設計と移行順序](../docs/TUI_LAYOUT_STABILITY_ROADMAP.ja.md)。
現在は共有inputの純粋機構だけ実装・検査済み。以下の画面cutoverは未実行で、全画面対応済みではない。

- **KEEP**：`daily_form`のUTF-8 scalar編集とbyte-offset、`daily_overlays`の幅／clip／tailとLocus prefix候補、
  `ui_panel`の枠・capacity/window/move、Bonsai/Nottyのnative合成・実幅・fit・after-display cursor。
- **統合／切替**：`daily_overlays`に`input_text`／`input_cell`／`cursor_in_rows`を実装済み。
  value窓と1cell caretを一緒に計算し、再帰Columnsの子座標を親へ変換する。現行画面の利用元はまだ切り替えていない。
  `ui_form`の寸法なしpaint＋独立cursorをbounded styled rowsへ切り替え、`ui_panel`の既存geometryへ接続する。
  Modal_form・Jump・Search・Reversal Dateの全利用元を同時移行し、次にRecordのColumns＋recursive caretと
  Scheduledの入力・UTF-8移動・focus-following・notice予約を接続する。既存string-list一覧APIは維持する。
- **LOCAL**：field、ID、選択・query・sort、draft、候補確定・focus、戻り先、review lifecycle、
  発行意図・拒否後復帰は各session/workspaceに残す。Preview全文／末尾・狭小確定拒否を共通枠へ移さない。
  `Ui_workspace`と`Actual_workspace`のstateも統合しない。

controllerは寸法・surface配置・local→terminal変換、frontendは描画を所有する。
独自renderer／Unicode幅表、raw ANSIの二重管理、汎用scene engine・状態framework、新依存や保存経路は作らない。
Record/Scheduled接続後もlist/detailのpaint/navigation capacityとcontroller経由の復帰を受入し、
Actual長文検索の限定成功を全画面合格やIME受入へ拡張しない。

## 保存と復旧の限界

Attention／commitment精算は主台帳とは別の試用sidecar。未作成だけを空の試用として扱い、
不正行・不正数量・重複・読込失敗は拒否し、Unavailableと原因を表示する。
選択したsidecarはセッション中に固定し、Ctrl-Rで明示的に再読込する。
既存writer lockで状態を再確認し、同期した一時ファイルのrenameとreadbackを使う。
失敗・競合では成功表示を出さず、入力と旧状態を維持する。結果が不明なら再送せず、
Escでフォームを閉じCtrl-R／再起動で現在内容を確認する。壊れた原本は先に別コピーへ保全する。
主台帳との複数ファイル原子性、永続Ack／P7、電源断・別ホスト復旧の保証ではない。
役割設定sidecarは別の未認定境界で、この修正の保証を引き継がない。

単一S式は全文検査、協調writerロック、読込元との全文比較、同期したattempt / pending / before、
renameと読戻しを使う。beforeは残す。結果不明artifact・不正名・非通常ファイル・照会失敗では
cold open／再読込／新規でも書込み停止する。自動再送・採用・backup削除は行わない。
Recordsは既存append engineを使い、起動時に途切れた末尾書込みをrecoverする場合がある。
Recordsのpublisherは予定完了の対応リンクと既存Actualの置換を永続化するプロトコルが未対応。
この二つは書込み前に明示拒否し、実績だけの部分保存をしない。現在の予定支払い・訂正は単一S式台帳が対象。
永続した発行後Ack証拠（P7）は未解決。単一S式の復旧検査はその証明にならない。
結果不明では記帳を止め、現行・before・attempt・pendingを保全してから照会する。

```sh
./tools/tui --inspect-recovery --book FILE
./tools/tui --confirm-current-attempt ID --book FILE
./tools/tui --restore-copy-from SOURCE --book FRESH_FILE
./tools/tui --check FRESH_FILE
```

inspectは本文を出さず現在の全文一致のみ（未確認なし=0、確認必要=3、照会失敗=1）。
candidate-is-current／before-is-currentは過去の発行成否を推測しない。confirmは現在候補との完全一致を
同じwriterロックで再検査し、同期・読戻し後にそのattempt／一致pendingだけを除く。before・別試行を変えない。
restore-copyは存在しない別パスへadmittedなbyte-exactコピーを作り、元を変更しない。
コピー成功は記帳先切替や済んだ支払いの再送ではない。
安定した親namespaceと協調writerが前提。電源断・媒体故障・悪意あるwriter・別ホスト復旧は未認定。
backup保持件数・期間・別媒体・不一致候補の採用条件も未決定。私用データ・画面・ログをGitへ入れない。

## 検証

```sh
./tools/check
./tools/tui --self-check
./tools/compare self-check  # 合成入力だけでコピー・差分・取得拒否を確認
```

合成データで暦・階層操作・Record入力／Preview／Publish／Edit／Cancel、数量・支払い対応、競合・結果不明を検査する。
native rendererは実cell幅・全テーマ・通常／狭い／低い端末で寸法、pane前面・境界、警告、indexed色・
truecolor不使用、入力adapterを検査する。recovery_checksの故障注入・SIGKILL・cold拒否・照会・確認・復元は維持する。
既存の会計・codec検査も維持する。synthetic PTYは実入力・終了・通常入力への復帰を確認する。
既存のBonsai終了処理でEXTPROCだけが変わる場合があり、全termios属性の完全復元保証はない。
macOS Terminalのpixel・色味、人間のUX受入、実運用切替の認定は別。現在の結果は[作業記録](../tasks/todo.md)を参照。
