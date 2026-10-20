# 日々の画面（試用）

LOAMの見た目と操作へ揃える英語UI。現在の`./tools/tui`は先行実装のBonsai_term環境を使う。
旧Notty画面、両画面比較ベンチ、独立したBonsai配置試作は削除した。NottyライブラリはBonsai描画と
native renderer検査で引き続き使う。新依存・global環境変更は行わず、通常DuneビルドはUI依存不要。

まずLOAMと同じ英語表記で作る。日本語UIは未定で、後からNotty版を作る選択肢も残す。
`Ui_text.tr`は現在の英語表示文言の入口で、日本語対応の実装約束ではない。
科目名・メモ等のユーザーデータは翻訳しない。
[UI方針](../docs/UI_DIRECTION.ja.md)、[UI差分管理台帳](../docs/LOAM_UI_GAP_LEDGER.ja.md)も参照。LOAMの正データ・普段の記帳先は変更しない。

## GitHub Actionsでの限定検証

trackedなBonsai UIの変更をmainへpushすると、`/.github/workflows/tui.yml`がLinuxの隔離OxCaml環境でnative buildと`--self-check`を試す。通常の`./tools/tui`は従来どおりローカルの隔離Bonsai試用環境を使用する。CI専用の`BAKHLO_BONSAI_CI=1`でのみGitHub runnerの別switchを使用する。

初回のBonsai native/self-checkはActions run `39094690207`で合格。固定依存cacheも次のrun `39096625299`で保存できた（cache hitによる速度改善は未測定）。`tools/ci_tui_pty.py`でLinux実PTYの4寸法（120×36／80×24／48×14／32×9）、キー／resize／Ctrl-Q／authority bytesを検査する工程を追加した。**PTY新工程のActions実行・結果は未確認の段階**。Mac実IME／フォント、LOAMの実行対照、P7・運用認定は別。Core CIとBonsai TUI CIの合格も独立している。

## 起動

Bakhloディレクトリから日々の確認は`./ui --daily`（親のmokoからは`./bakhlo/ui --daily`）。
普段のLOAMで記帳した内容から新しい比較コピーを取得し、成功時だけBakhloを開く。LOAMは開いたままでよい。
非対話端末では取得前に拒否し、取得失敗時も古いコピーを開かない。
`./ui`は選択済みコピーの再訪、`./ui --refresh`は取得のみ。別の端末の`./ui loam`で同じ取得時点のLOAMコピーを開ける。
毎回の取得は新しいコピーを作り、両UIの試用編集は以前のコピーに保存したまま次のコピーへ合流しない。
取得・変換は既存のignoredな私用Daily converterに依存する限定ローカル手順で、単独の移行ツールや正データへの書込みではない。
未対応のActual証拠、不正な変換、取得中の変更は拒否し、前回の選択とコピーを保持する。
差分は日付フィルタではなく安定ID／全内容で比較し、新しい対応範囲の台帳全体を再生成する。
元のhouseholdとconfig、以前のコピー、変換外の家計証拠・旧版は私用scratchに保持する。
比較後は`./tools/compare clean-copies`で今回のLOAM中間コピーを削除し、Bakhloデータ・設定・過去の試用を残す。
削除後にLOAM側を再比較する場合は新しく取得する。
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

対話的な`--book FILE`で選択台帳がmissing／unreadableなら、別の未使用fileへの明示的な初期化を選べる。
missing pathは初期destination、existing sourceはblank destination。sourceを置換せず、出力先・最初の
Measure／scaleをreviewして2回目のEnterでだけ作成する。小さい端末ではreview確定を拒否し、resize後に
再確認する。reviewのEscape／Editは入力へ戻り、入力のEscapeのみ非保存で終了する。
非TTY、`--check`、Recoveryその他のload callerは引き続きfail-closed。
空台帳への自動fallbackはしない。
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

CommandsはTransactions、Plans and attention、Reports and analysis、Household setup（Theme、Manage Loci、Daily Pace / spendable accounts、Daily Pace / cycle dates、Balances / visible accounts、Home）。
実装済み入口だけを置き、削除したEnvelope budgetは置かない。
記帳中のSpaceや`q`は文字入力で、背面のコマンドを実行しない。
Actual / Scheduled / Selected Dayで選択・検索・詳細と復帰を共有する。別明細の訂正・支払いで
保持中の下書きを黙って置き換えない。
Actualは幅が足りる一覧でDate／Description／Amountを整列し、正確な符号・桁区切り・通貨を表示する。
複数の正負Postingは`split`、混合通貨は`multi`、収まらない金額は`see details`とし、数量を途中で切らない。
ActualはLoci／Actuals／Detailsの3ペインと画面内の`/`検索を接続済み。
検索は入力中に絞り込み、Enterで保持、Escで解除する。長文は可視末尾だけを表示し、
保持する検索値を切らない。日本語を含む末尾と実カーソルを同じ可視窓に収める。
`f`は日付scope、`s`はsort、Tab／h/lはpane、`i`はDetails。Actuals／DetailsのEnterは1回で選択明細のSelected Dayを開く。
同日の別明細や以前のSelected Day検索へ逸れず、明細IDで選択する。戻ると親Actualの検索・scope・sort・選択・paneを保持する。
ActualとScheduledの詳細はHome／Endで選択を変えず、ページ送りは可視行数に従う。
3ペイン全体の最新LOAMとの配置・操作一致は未認定。限定した検索対照と未達範囲はUI差分台帳を参照する。
Actualの`c`はCorrect、ScheduledのEnterは閲覧だけのDetail、`c`は明示的なComplete。
支払い入力を開く操作だけでは台帳を変更しない。

## Record / EditとPreview

新規Recordは一行のQuick captureから始める。Enterで説明候補を確定し、完成した入力は
既存のPreviewへ、不足があれば詳細フォームへ進む。Tabは詳細フォーム、Escは下書き保持。
通常寸法ではLOAMと同じ14行の枠内に入力・候補・操作案内をまとめ、狭小時は枠を外す。
家計簿の警告を覆わない位置へ移し、収まらなければ全画面表示へ縮退する。

Date、Description、Measure、符号付きPostingを入力する。科目名／IDを入力して許可済み候補を
選び、名前から口座・費目の役割を推測しない。複数行も一つのRecord下書きで扱う。
通常サイズでは親の日付を残す中央ペイン、狭い・短い端末では全画面へ畳む。
編集中の項目は表示位置が追従し、長い入力でも実セル幅に合わせてカーソル周辺を見せる。
通常入力は青系、訂正／完了はアンバー、Cancel選択はローズの枠のみで区別する。
Cancelは削除ではなく下書き保持。本文と背景は通常のトーンを維持する。
DateまたはMeasureだけを変更した場合も、Esc後の次回Record起動でその下書きを再開する（終了・再起動後には残らない）。

- `Tab`／`Shift-Tab`：項目。Enter：候補確定・次項目・Preview。
- `←→`／Home／End／Backspace：文字カーソルと削除。
- `↑↓`：Locus候補。`Ctrl-N`：行追加。`Ctrl-D`：行削除（新規・支払い入力）。
- `Ctrl-S`：Previewを開く。保存はしない。Esc／Cancel：下書きを保持して閉じる。
- PreviewのPublish / Edit / CancelはTab等で選ぶ。**Publishを選んでEnterだけが保存を要求する**。
  Editは入力へ、Cancelは下書きを保持して閉じる。PreviewのCtrl-Sや貼付では保存しない。
- 閲覧中の`Ctrl-N`：保持中の下書きの破棄確認。初期選択はKeep draftで、Enter／Escは保持。
  →でDiscard draftを選びEnterしたときだけ下書きを破棄する。台帳は書き換えない。
  狭小端末では拒否してKeepへ戻す。保存結果不明・復旧未確認の破棄拒否は維持する。
  記帳中の`Ctrl-N`は従来どおりPosting行追加であり、破棄ではない。

PreviewはID・日付・メモ・全Postingの符号付き数量・Measure・Locus ID・キー・支払い対応を表示する。
長文は折り返しとスクロール。極小端末では証拠を隠した確定を拒否する。
小端末で確認全文が収まらない場合はEndでも確定を拒否する。通常サイズの複数ページ確認は
最終ページへ移動してからPublishを選ぶ（Endは末尾へ移動するだけで保存しない）。数量は整数quantaと明示の
小数桁で扱い、丸め・通貨合算・為替推測はしない。差額ゼロは台帳検査や保存権限の代わりにならない。
訂正（`c`）はLOAMと同じく同じ明細IDのまま口座・金額・符号・行の追加削除を変更でき、日付は保つ（日付は`d`）。
口座を変えた行だけ識別キーを外し、他の行のキーと支払い対応は保つ。両替・返金対応付き明細の訂正は拒否する。単一S式のScheduled完了は実明細とpaid-byを同時更新し、支払い済み／取消済みを再利用しない。
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
合成操作・通常再起動は確認済み。LOAM対照・IME／本人受入・P7の認定ではない。

## Actualの反転

Actual／Selected Dayの`x`は専用のDate→Previewを開く。DateのEnter／Ctrl-Enterは確認だけで保存しない。
Previewには元ID・元日付・説明・反転日・元／逆Postingの完全な符号付き数量とMeasureを表示する。
`j/k`／↑↓、Page Up/Down、Home/Endで確認し、Publishを選んだEnterだけが既存writerへ意図を返す。
末尾未確認、狭小画面、短い画面に全文が収まらない場合は確定拒否。Endも保存ではない。
PreviewのEsc／e／Editは日付へ、q／Cancelは元の一覧・詳細へ戻る。日付側のEsc／qは取消。
保持したRecord draftがある間は反転を開かず、保存拒否では反転の日付・target・baseを残す。
Ctrl-rのreloadで世代が変わってもPreviewを新しいbaseへ更新しない。取消→reload→再選択が必要。
結果不明は停止し、reloadで既存candidateを確認しても自動再発行しない。

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
stale／結果不明は停止し、reloadで古い確認を有効化しない。
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
   - 狭小端末での確定拒否、競合（stale）停止の安全策を備える。

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
今日のTrendはCurrent／What-ifと同じ`Daily_book.daily_pace`の回答を使い、期限超過の未払い予定も控除する。過去日のPaceには全Pool座標のゼロ起点支持が必要。現在観測だけの台帳では過去日を`unknown`として残し、グラフの線を繋がない。独立に分かる当日の取引額まで不明やゼロに置換しない。
通常寸法では上段が全幅グラフ、下段がHistory／Selected day。上部のTodayは選択日と独立して今日の目安を表示し、今日の支持されたactivityがあり全文が収まればSpentと同日の差も表示する。期間名・選択位置／件数を表示する。48×14では短いHistory、32×9では日付と完全なPaceを優先する。`i`／Enter／Tabで詳細へ切り替え、広幅ではグラフとHistoryを残し、狭幅では詳細へ全幅を渡す。定数系列・単一点にもLOAM同様の余白付き目盛りを使う。Historyは各列の完全な値が収まる幅ならDay／Quanta/day／Spent／Pace diffを表示し、狭幅では日付とPaceに絞る。`Spent`はPoolの取引ごとの純流出から支払済み予定・同日反転の対を除いた予定外支出、`Pace diff`は同日のPace − Spentであり、前日比ではない。

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
  - 初回は今日を選ぶ。プリセット切替は同じ日付を保持し、新期間外なら端へ制限する。解決できない期間への切替は拒否し、直前の選択を保つ。`j/k`・↑↓も日付移動、Page Up/DownはHistoryの可視容量に従う。
- **詳細ペインの展開とスクロール (`Tab` / `i` / `Enter`)**:
  - 選択日のペース、予定外支出とPaceとの差、予定支払いと予定額との差、前日比と時間経過／残額変化の内訳、残日数・期間・Pool・予定控除を表示する。異なるサイクル・隣接しない日・不明なPaceの前日比内訳は拒否し、不明な残高をゼロ表示しない。
  - `j/k`・Page Up/Down・Home/Endで詳細文をスクロール。`h/l`は詳細内でも日付を移動し、`Esc`／`q`／Tab／`i`／Enterでタイムラインへ復帰する。Endの後やresize後も上へ戻れる。
- **シミュレーションと設定**:
  - `w`: What-if（読み取り専用）。購入額を入力するとその場で、現在Pace・残日数・保護済み予定と、購入後Pace／1日の変化／残額を3桁区切りで表示する。赤字は負数のまま、記帳・予約はしない。`Esc`／`q`で閉じる。
  - `t`: 目標ペース計画（読み取り専用）。目標の1日額（帳簿単位の整数）、任意の目標日（`26`・`11-02`・`YYYY-MM-DD`）、今日の仮想支出を入れると、目標日までの1日上限と合計・目標日のペースを示す。日付なしなら3／7／14／21／28／42日後の候補表と最短到達日を出し、`j/k`で描く候補を選ぶ。収入や新しい予定はない前提で、記帳・予約はしない。`Esc`／`q`で閉じる。
  - `?`: 今日のPaceの内訳（読み取り専用）。Poolの各残高とその根拠（recorded history／opening balance／observed／unsupported）、周期末までに控除される予定（日付・支払先・期限超過）、残り使える額と割り算の式を示す。`j/k`・Page・Home/Endでスクロール、`Esc`／`q`／`?`で閉じる。答えが出ない日は理由を示し、ゼロにしない。
  - `c`: 対象口座プール（`daily-pace.tsv`）の選択。残高が確定している口座だけを、残高の根拠ごと（記録の積み上げ→開始残高→観測）・出現順に一覧し、`j/k`で移動、Spaceで選択、Enterで確認画面、確認画面のEnterで保存する（LOAMと同じ）。
    確認画面の`Esc`／`e`は選択へ戻る。選択画面の`Esc`／`q`は閉じるが、同Measureの`c`／Household setupで選択途中から再開できる。
    確認画面の全行が欠けずに見えない端末では保存しない。以前のプールにあった確定していない口座は外れ、その名前を確認画面に示す。
    読めない・壊れた・別Measureの設定は理由を示して保存しない。
  - `b`: サイクル境界（`boundary-presets.tsv`）の編集（Commands → Household setup → Daily Pace / cycle dates と同一）。
## 収支レポート（Income & Expense）

`Space`（Commands）→ `Reports and analysis` → `Income & Expense` で開く。
指定した期間（月・給与年金サイクル・年・全期間）における収入・支出の内訳と収支差額（純貯蓄）を集計表示する。

- **期間プリセット切替 (`1`〜`5`)**:
  - `1`: Month（当月、例: `Month of 2026-10`）
  - `2`: Cycle（`boundary-presets.tsv`に基づく現行サイクル、例: `2026-10-15 .. 2026-12-15`）
  - `3`: Previous Cycle（直前の年金・給与サイクル）
  - `4`: Year（当年、例: `Year 2026`）
  - `5`: All Time（台帳全期間）
- **期間移動 (`[` / `]`)**:
  - `[`: 過去の月やサイクルへ移動。
  - `]`: 未来の月やサイクルへ移動。
- **表示項目**:
  - 通貨別に集計（異なる通貨を勝手に合算しない）。
  - 収入（Income）内訳と合計。
  - 支出（Expense）内訳と合計。定期予定の消込（Scheduled-linked）と通常の買い物を分離。
  - 純貯蓄（Net Savings = 収入 − 支出）。
  - 会計ロールが未割り当ての科目は「Unresolved Role Effects」として別枠で明示（勝手にゼロや収入にしない）。
- **印刷プレビュー (`p`)**:
  - レポート全体のプレビュー画面を開き、完了後に戻る。
- **詳細展開 (`Tab` / `i`)**:
  - 右ペインの計算根拠・ナビゲーション説明を展開。`Esc`/`q`でレポート一覧へ復帰。

## 資金移動レポート（Transactions Flow）

`Space`（Commands）→ `Reports and analysis` → `Transactions Flow` で開く。
指定した期間（月・給与年金サイクル・年・全期間）における科目・口座ごとの資金移動（インシデンス）を集計表示する。

- **期間プリセット切替 (`1`〜`5`)**:
  - `1`: Month（当月、例: `Month of 2026-10`）
  - `2`: Cycle（`boundary-presets.tsv`に基づく現行サイクル）
  - `3`: Previous Cycle（直前のサイクル）
  - `4`: Year（当年）
  - `5`: All Time（全期間）
- **期間移動 (`[` / `]`)**:
  - `[`: 過去の期間へ移動。
  - `]`: 未来の期間へ移動。
- **テーブル表示と整列**:
  - 粗動量（Gross Volume: `+In + |-Out|`）の降順にソート（最も資金の動きが大きかった科目が上位に並ぶ）。
  - カラム: `Coordinate`（科目/通貨）、`Net`（純増減）、`Gross`（総動意量）、`+In`（受入/増加）、`-Out`（払出/減少）、`Events`（取引件数）。
- **行選択 (`j` / `k`) と明細連動**:
  - 左ペインでカーソルを動かすと、右ペインにその科目を構成する取引明細一覧（Contributing Transactions: 日付、金額、摘要、ID）が即座に連動表示される。
- **印刷プレビュー (`p`)**:
  - レポート全体のプレビュー画面を開き、完了後に戻る。
- **詳細展開 (`Tab` / `i`)**:
  - 右ペインの明細スクロールへフォーカス切替。`Esc`/`q`でレポート一覧へ復帰。

## ストック・フロー残高表示（Stock–Flow）

`Space`（Commands）→ `Reports and analysis` → `Stock–Flow` で開く。これは選択した
追跡残高座標の期間内変動を表示する限定ビューで、収支照合や会計上のBalanced判定ではない。

- `1`〜`5`でMonth／Cycle／Previous Cycle／Year／All Timeを選び、`[`／`]`で期間を移動する。
- 対象は明示された`balance-view.tsv`の座標。空選択、重複、要求Measureと異なる座標を含む選択は拒否し、混在選択をMeasureで絞り込まない。通貨／Measureの切替はない。
- 選択座標の現行量が正確に支持され、かつ独立した過去Event証拠がある場合に限り表示する。過去残高はゼロ起点のEvent履歴から復元する。証拠不足、現行量不明、未対応座標は拒否し、archival snapshotや過去時点の独立保存残高とは扱わない。
- 始期／終期復元量、期間内の増加・減少・純変化、座標別内訳、現在の追跡量を表示する。これはIncome & Expenseとの照合でも、残高の正しさの証明でもない。
- `p`で画面内プレビュー、`Tab`で詳細表示を切替。

旧記録のsmoke出力には複数通貨とNet Savingsとの「Balanced」照合が記載されていたが、
その出力は無効な財務正確性証拠として撤回済みである。現行検証成功や財務正確性認定は主張しない。
LOAMとの完全一致も未認定。

## 生活事項・期限管理（Attention）

Homeで `i` または `Space`（Commands）→ `Attention` で開く。
忘れてはならない家計事項、手続き、請求書の支払い期限などを一元管理する。

- **Home画面の期限バッジ**:
  - 期限超過の未完了事項がある場合、Homeフッターに `[i] attention (! 1 overdue)` のように警告バッジが自動表示される。
  - 当日期限は `[i] attention (today)`、通常時は未完了件数 `[i] attention (N)` を表示。
- **二列テーブル表示（左ペイン）**:
  - `Due` 列と `Matter / Context` 列で整理。
  - 期限超過（Overdue）は `! YYYY-MM-DD` と目立つシグナルで明示。
  - 期限なしは `no due date`、時期未定は `due unknown` を表示。
- **生活事項の詳細と緊急度（右ペイン）**:
  - 選択中の事項について、説明全文、期限・緊急度（超過日数、当日、未定）、アイテムID、ライフサイクル状態を表示。
- **アクション (`n` / `r` / `x`)**:
  - `n`（New）: 新規事項の追加。期限は「期限なし」「時期未定」「日付指定」の3種類から選択。
  - `r`（Resolve）: 選択中の事項を「完了（Resolved）」として記録し、未完了一覧から消去。
  - `x`（Drop）: 選択中の事項を「破棄/中止（Dropped）」として記録し、未完了一覧から消去。
- **ナビゲーション**:
  - `j` / `k`: 事項の選択移動。
  - `Tab` / `i`: 詳細ペインへフォーカス切替（長文スクロール用）。
  - `q` / `Esc`: 詳細から一覧へ復帰、一覧からHomeへ復帰。

## BalancesのCurrent残高とAccounting表示

Homeで`b`を押すと、LOAM準拠の**Balances / Current**（現在の各口座・通貨の残高一覧）が開く。
`balance-view.tsv`で指定された順序で中立座標（Locus × Measure）を表示し、未設定時は承認済みLocusを表示する。
`c`で現在のMeasureの表示対象を編集し、選択内容を全文確認してから保存する。他Measureの選択は保持する。
空選択は「全件」へ置換せず、表示行なしになる。不正／読めない設定は空として扱わず拒否する。
保存先は選択された`balance-view.tsv`だけ。競合時は保存せず、再度開いて確認する。
先頭の選択は説明行ではなく最初の座標。狭幅では名前を先に縮め、符号・小数精度・3桁区切り・Measureを含む金額を完全に表示する。収まらない金額は`see details <Measure>`へ置き換え、未知・存在のみの行にもMeasureを残す。空選択の件数は`0–0 / 0`、詳細・Printでは省略前の値を保持する。72〜119列かつ本文高さ18行以上では上段に残高一覧、下段に選択詳細、120列以上は左右表示。合成4寸法PTYで確認済みだが、本人の実機受入は別。

- **一覧操作**:
  - `j/k`・`↑/↓`: 1行移動。
  - `Page Up/Down`・`Ctrl-u/d`: 画面単位のページ移動。
  - `Home`/`End`: 最初／最後の残高へジャンプ。
  - `Enter`・`i`・`Tab`／Shift-Tab・`h/l`: 一覧と選択した残高の詳細（Selected Balance）のfocusを切り替える。同じ座標なら詳細位置を保持し、別の座標へ移動したら先頭から表示する。
  - `Esc`・`q`: 詳細ペインから一覧ペインへ戻る。一覧ペインで`Esc`/`q`を押すとHomeへ戻る。
- **モード切替 (`v`)**:
  - `v`を押すと**Balances / Accounting**（資産・負債・純資産・収益・費用の会計分類表示）に切り替わる。
  - 再度`v`でCurrentへ戻る。同じLocus × Measureがあれば選択を保持し、なければ最初の座標へ移る。詳細のEnd後・resize後の上移動も実際の可視範囲へ制限する。
  - `w`は表示対象設定を編集するMeasureを切り替える。一覧自体は設定された全Measureを表示する。
- **表示対象の編集 (`c`)**:
  - 許可済み、または既存設定に残るLocusを候補一覧から選ぶ。`j/k`／`↑/↓`で移動、Spaceで追加／解除。追加は選択順の末尾へ入る。
  - Enterで確認、Esc／`e`／Editで選択を保持して一覧へ戻る。一覧のEsc／`q`は非保存取消。確認全文が表示できる寸法でのみSaveする。
- **印刷プレビュー (`p`)**:
  - 画面内Printプレビュー（見出し・改行込みで200行／32,768 UTF-8バイト上限）。`j/k`・Page Up/Down・Home/Endで全文を読み、Enter／Esc／`q`で閉じる。親の選択・詳細位置は保持し、台帳や通常端末のscrollbackへ出力しない。Currentの表示口座設定が不正・読込不可ならPrintを拒否する。
- **観測記録 (`o`)**:
  - 選択中のLocus・Measureを入力済み、現在の確定金額を入力例としてObserveを開く。Home／Commandsからも開ける。
  - 同時に確認した座標と数量を入力し、Enter／Addで一行ずつ追加。Tab／Shift-Tabで入力・Add／Preview／Cancelを選び、PreviewからPublish／Edit／Cancelへ進む。
  - Previewは全行を表示し、Edit（`e`）は追加済み行と未追加入力を保持、Esc／Cancelは非保存取消。見えていない行があれば確定を拒否する。
  - Publishだけが既存Core／writerで一グループを保存する。未指定座標の観測は保全し、再観測座標だけを新しいroot cutへ移す。不明はゼロにしない。
  - 重複・未承認・既存のゼロ起点／開始残高との衝突は全体を拒否する。競合／結果不明はPreviewを保持して停止し、再読込で古い観測を有効化しない。

## 対応範囲と差分

新UIはCalendar、階層Commands、英語Record、Actual / Scheduled / Selected Dayの閲覧と詳細、
既存検査・保存への接続を対象にする。LOAMの全会計機能を再実装したものではない。
role-aware収支カレンダー、完全なSeries／coverage管理・定期補充／監視、履歴Trend、原額・Merchant、
実取引への配分を伴う精算・後日カード決済、広いレポート群は未対応。
単一S式の予定作成（Scheduled `n`）・変更（`e`）・取消（`x`）・支払い（`c`）は接続済み。
Actual `x`は元明細を残す正確な反転の新規記帳。
CommandsからExchange（入力→全文Preview→確定）、Manage Loci／役割設定／表示名（`l`またはHousehold setup `Account / category display names`→Review→保存）、Attention、限定commitment精算へ進める。
Home／Calendar／Balances `o`はObserve。これらの存在は全LOAM互換を意味しない。
Balancesは既存照会で通貨別に表示し、不明・存在あり量不明・ゼロを区別する。
Daily Paceは明示pool・Measure・今日・期間末の既存計算を表示する。
`daily-pace.tsv`／`boundary-presets.tsv`がなければ未設定とし、条件を推測しない。
`w`は読み取り専用What-if、`c`はPool編集。未設定・不正・重複・混合Measureは計算しない。
明示された実日付・昇順境界を持つpresetが今日を含むものとして一意でなければ拒否する。
月末・Asset分類・全許可Locusから条件を補完せず、What-ifの負数もゼロに丸めない。
Pool編集は取得時点の旧設定と新設定をReviewし、選択ファイルのbytesを再確認して`daily-pace.tsv`だけを更新する。
別Measureを含む設定、不正／読めない既存設定は置換しない。書込み前の失敗・競合時は設定と下書きを保全する。
rename後の結果不明は保存成功とせず、現ファイルを確認する。自動rollbackや新しい保存形式は導入していない。
下書きはプロセス内のみ。競合後も取得時の旧bytesは自動更新しないため、新しい設定からやり直すには再起動が必要（下書きは消える）。
`boundary-presets.tsv`の他期間・過去境界は変更せず、この画面で期間末を編集しない。
Trendは現在台帳からの限定的な再構成表示で、ゼロ起点で裏付けられない過去日はUnavailableとなる。LOAMのdated bounded-history支持、支払済み／取消済み予定を含む全履歴の一致は未認定。期間比較は未対応。Calendar選択日を今日の観測日に置き換えない。
Daily_bookは単一S式v1〜v3・v5を読み、v3（期間付き履歴があればv5）を書く。旧予算v4・予算APIは非対応。
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
- shell_state：Shell state、初期化、route入場・同期、Record下書き保持とpublication結果処理。
- shell_record_actions：route ownerが明示Entry/Plan targetで要求したRecord操作のeditor起動・拒否理由。
- shell_files：画面設定ファイルの捕捉読取・admission付き原子的保存（ledger writer以外のShell I/O）。
- shell_publication：screen ownerが要求したledger publicationを単一writerで実行。
- shell_dispatch：Screen.env/geometry、owner入力・描画、request適用、reload、戻り、Commands。
- shell_input：paste guard、Record、modal owner、Shell overlay、Ctrl鍵、route owner、global鍵の順の入力dispatch。
- shell_view：header/feedback/footerの合成、overlay配置とterminal caret。
  依存はstate → record_actions／files／publication → dispatch → input／view。画面ごとの状態・入力・描画は`tui/screens/<s>`が持つ（`docs/TUI_OWNERSHIP.md`）。
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

帳簿ファイルは単一S式（snapshot）の後ろに保存1回ごとの記録行を追記する形式（`Bakhlo_sexp.Book_log`）。
保存は協調writerロック下で、読込時からファイルが変わっていない（inode・サイズ・更新時刻・末尾）ことを確かめ、
記録行1行を追記してfsyncし、末尾を読み戻す。操作は保存前にCoreで適用し、拒否なら何も書かない。
結果不明（追記中のI/O失敗）では記帳を止め、再読込でファイル末尾がその記録行と一致した場合だけ保存済みとする。
最後の行が改行で終わらない（保存中断）場合は書込みを止め、自動修復しない。確認してから明示的に切り捨てる。
終了時に記録が200件以上なら新しいsnapshotへ圧縮し、置き換え前のファイルを`.prev`として1世代残す
（一時ファイル→hard link→原子的rename。どの時点でも帳簿ファイルは旧または新のsnapshotで同じ帳簿）。
永続した発行後Ack証拠（P7）・電源断・別ホスト復旧は未認定。

```sh
./tools/tui --inspect-recovery --book FILE
./tools/tui --discard-torn-tail --book FILE
./tools/tui --restore-copy-from SOURCE --book FRESH_FILE
./tools/tui --check FRESH_FILE
```

inspectは本文を出さず、完全な記録数と中断された最後の行の有無だけを示す（なし=0、中断あり=3、照会失敗=1）。
discardは同じwriterロック下で再確認し、改行のない最後の1行だけを除く。完全な記録は変えない。
restore-copyは存在しない別パスへadmittedなbyte-exactコピーを作り、元を変更しない。
コピー成功は記帳先切替や済んだ支払いの再送ではない。
安定した親namespaceと協調writerが前提。電源断・媒体故障・悪意あるwriter・別ホスト復旧は未認定。
長期履歴（Git等）・別媒体コピーは運用側で用意する。私用データ・画面・ログをGitへ入れない。

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
