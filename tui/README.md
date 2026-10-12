# 日々の画面（試用）

LOAMの見た目と操作へ揃える英語UI。現在の`./tools/tui`は先行実装のBonsai_term環境を使う。
旧Notty画面、両画面比較ベンチ、独立したBonsai配置試作は削除した。NottyライブラリはBonsai描画と
native renderer検査で引き続き使う。新依存・global環境変更は行わず、通常DuneビルドはUI依存不要。

まずLOAMと同じ英語表記で作る。日本語UIは未定で、後からNotty版を作る選択肢も残す。
`Ui_text.tr`は現在の英語表示文言の入口で、日本語対応の実装約束ではない。
科目名・メモ等のユーザーデータは翻訳しない。
[UI方針](../docs/UI_DIRECTION.ja.md)も参照。LOAMの正データ・普段の記帳先は変更しない。

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

## 対応範囲と差分

新UIはCalendar、階層Commands、英語Record、Actual / Scheduled / Selected Dayの閲覧と詳細、
既存検査・保存への接続を対象にする。LOAMの全会計機能を再実装したものではない。
role-aware収支カレンダー、完全なSeries管理、Attention、両替入力、立替精算・後日カード決済、
観測更新、広いレポート群は未対応。Scheduledは既存の明示された単発予定を使う。
予定作成・変更・取消の純粋APIは既存だが、生活操作としてのUIは未接続。
Balancesは既存照会で通貨別に表示し、不明・存在あり量不明・ゼロを区別する。
Daily Paceは明示pool・Measure・今日・期間末の既存計算を表示する。
`daily-pace.tsv`／`boundary-presets.tsv`がなければ未設定とし、条件を推測しない。
履歴Trend・期間比較・設定編集は未対応。Calendar選択日を今日の観測日に置き換えない。
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
- daily_interaction：全体の遷移・英語表示・既存検査／publisherへの接続。
- daily_overlays / ui_text：cell幅・枠・完全な数量詳細と将来の言語カタログ入口。
- daily_actions / posting_draft / daily_file：既存の数量・検査・保存境界。
- bonsai_daily：実描画と入力adapter。会計計算は持たない。

## 保存と復旧の限界

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
