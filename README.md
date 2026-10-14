# Bakhlo（バフロ）

OCamlで作るパーソナル家計簿。記帳と支払い予定を土台に、各種残高・今日の目安・
必要なレポートで家計のやりくりをする。人間が読める正データを大切にし、AIなしで動く普通の道具を目指す。

**開発中。普段の記帳と正データはまだLOAM。元データを変更せず、まずBakhlo用の候補を試す。**

## 大事にすること

- 金額を整数の最小単位で正確に扱い、異なる通貨を勝手に合算しない。
- 残高が不明なことと、明示的にゼロであることを区別する。
- 入力ミスの訂正と、実際の返金・取消を区別する。
- 正データは訂正済みの明細でよい。修正前は元データやバックアップで別に残せる。
- 普段はTUI等で編集する。正データの手読み・手編集のしやすさより、長期の保存費用・
  復元/移行の確実さと短く直接的な実装を優先する。読取・診断可能なテキストは大切にする。

永久の訂正ログ、LOAMの全内部構造、教科書化、複数バックエンドは必須条件にしない。
必要な予定・残高照会・レポートは作る。**bakhloでは予算配分・予算振替・予算消化管理を実装しない。**
Daily Paceと支払い予定は維持する。試用中の旧予算データは移行せず再作成する。
まず現在よく使う操作を実装し、追加機能は必要になってから。安定したID、独立した根拠・対応、
原本保全と明示的な移行を守り、後の追加を妨げる情報削減を避ける。汎用拡張frameworkは先に作らない。

## 今できること

- 独立した数量・取引検査と、根拠のある残高／不明の回答。
- 限定された普通の記帳形式のS式読取と、新しい候補ファイルへの書出し。
- 新しい家計簿S式をBonsai_termの画面で読み、記帳・終了・再起動・編集・予定の支払いを試せる。
  編集前の内容は別バックアップに残し、正データの明細IDは保つ（まだ試用保存）。
- 金額・日付入力の柔軟化（PR UX-2のパーサを維持）: 全角・半角数字、正しい3桁カンマ区切り、小数通貨、グレゴリオ暦厳守の日付入力（`-`, `/`, `.` 対応）。新UIの日付移動はHome / Calendarの暦ナビ・`t`（今日）・`/`（jump）を使う。
- 入力エラー表示と下書き保護（PR UX-1の検査境界を維持し、新UIの表記は英語）: 不備や不確定時に入力と下書きを保護し、安全に停止する。
- レコード形式（Records）の耐久追記保存と高速インデックス化（PR 5, PR 6）。
  Recordsでは予定完了リンクの同時保存と既存明細の置換が未対応のため、両操作を追記前に拒否する。
  予定の支払い・既存明細の訂正を試す場合は単一S式の試用コピーを使う。
- 単一S式のDaily台帳で、単発予定の作成・変更・日付付き取消を画面から試せる（Recordsは拒否）。
  取消済み予定は残し、支払い済み／取消済みの再支払いを拒否する。
- `Daily_book.daily_pace`でLOAM Home `d`相当の今日の目安を計算し、英語のDaily Pace画面で設定・現在の量・予定控除を表示する。
  対象口座・通貨・観測日・期間末は明示する。現在値・What-ifとPool編集は接続済み、履歴Trendは未接続。
  Pool未設定・不正・混合通貨、期間未設定・不正・曖昧な選択は拒否し、口座や月末を推測しない。
  Pool編集は`daily-pace.tsv`だけを保存し、全`boundary-presets.tsv`を保全する。赤字をゼロに丸めない。
- Daily画面の両替、数量観測、Manage Loci／明示役割設定、Attention、限定的な精算残額管理を試せる。
  Attention／精算の不正・読込失敗は空やゼロにせずUnavailableとして表示する。
  保存失敗・協調writer競合では入力と旧状態を残す。これらのsidecarは全家計移行・耐久保存認定ではない。
- Daily台帳はv1〜v3とRecords v1を読み、単一S式ではv3を書く。旧試用の予算APIとv4は削除済み。
- `record` で単一通貨の支出・収入・振替を記録できる。
- v3 Bookでは `exchange` で両替元と両替先の通貨・数量を明示した両替を記録でき、
  受け取った現地通貨は通常の `record --measure` で使える。
- `record` の上書き経路はまだ実データの耐久保存として未確認。元データには使わない。

現在の `bakhlo 1/2/3 ordinary-quantity` Bookは訂正関係を保持する既存形式で、
支払い予定やLOAM全体を表せる形式ではない。新しい `bakhlo-daily` は別形式で、
訂正済み明細・予定・独立した数量根拠を扱う。`record` / `exchange` CLIとは混用しない。
形式を変える場合は明示的に変換し、古いファイルを残す。

## ビルドと試用

```sh
./tools/bootstrap
./tools/check
./tools/opam exec -- dune exec bakhlo -- --help
./tools/opam exec -- dune exec bakhlo -- inspect-current-sexp --summary \
  examples/ordinary-sexp/initial.sexp wallet jpy food jpy
./tools/opam exec -- dune exec bakhlo -- exchange --help
```

[合成データの短い例](examples/ordinary-sexp/README.md)で読取・候補作成を試せる。
`examples/ordinary-sexp/travel.sexp` はJPY→EUR両替、EUR支出、帰国時の逆両替を試すための
合成データ。両替レートを推測したり、異なる通貨を合算したりしない。
カード利用を外貨で記録して後日JPY決済と対応づける機能はこのPRの範囲外。
セットアップはリポジトリ内だけで行う。

### 日々の画面を試す

LOAMと同じコピー元のデータで見比べるローカル入口は次のとおり。

```sh
./ui --refresh  # LOAMを閉じてから、最新の比較コピーを作る
./ui            # Bakhloの比較コピーを開く
./ui loam       # 同じ取得時点のLOAMコピーを別の端末で開く
```

親の`moko`からは`./bakhlo/ui`。`--refresh`は正データに書き込まず、既存の私用変換試行を使って
対応済みの訂正済み明細・現在／支払済み予定・数量根拠を新しい比較用S式へ変換する。
日付だけの追記ではなく、過去明細の訂正・日付変更・予定支払いも検査して全体を再生成する。
差分は前回取込（初回は既存候補）との比較として私用ファイルへ残し、前回コピーや試用編集は上書きしない。
未対応のActual証拠や変換不備は拒否し、元の全householdとconfigは私用取得コピーに保持する。
これは全家計移行・完全バックアップ・正データ切替ではない。

比較コピーは`scratch/loam-comparison`内、テーマ設定は同じ場所の`ui-config`へ隔離する。
両UIの試用保存先もコピーだけで、通常のLOAM正データには保存しない。
LOAM側は既存の実行ファイルだけを使い、ビルド・インストールしない。
`q`で終了。比較コピーが未取得／不正でも合成データや正データへ自動フォールバックしない。
合成データだけを試す場合は`./ui --demo`（`scratch/ui-preview`を再利用）。

隔離環境を使う。起動は既存の`tools/tui`へ委ね、依存を新規インストールしない。
別の試用を作る場合は、合成データを新しい場所へコピーする（既存ファイルは置換しない）。

```sh
umask 077
mkdir scratch/my-daily-trial
./tools/tui --copy-from examples/daily-book.sexp --book scratch/my-daily-trial/book.sexp
./tools/tui --book scratch/my-daily-trial/book.sexp
```

英語のHome / CalendarからDay / Month / Yearを`z`で切り替え、`/`で日付へ移動する。
`Tab`／`w`でCalendarとDetail、`Space`で階層型Commands。`r`でRecord、`a`でActual、
`s`でScheduled、`b`でBalances、`d`で現在のDaily Paceへ進む。
RecordはDescriptionから入力し、許可済みLocus候補と符号付きPostingを使う。
Enter／Ctrl-SでPreviewを開き、Publish / Edit / Cancelを選ぶ。**Publishを選んでEnterだけが記帳する**。
Esc／Cancelは下書きを保持する。起動時に台帳がなければ拒否し、空台帳へ置き換えない。
[操作・対応範囲・保存の限界](tui/README.md)も参照。

### UIの方針

LOAMの見た目と使い勝手をBakhloでも再現する。Calendar HomeのDay / Month / Year、
階層型Commands、共通する記帳・明細・予定・残高・Daily Paceの入口と画面内操作、
確認・取消・親画面への復帰をLOAMに揃える。新UIはまずLOAMと同じ英語表記で作り、
日本語UIを用意するかは未定。Bonsaiを先行して実装し、後からNotty版を作る選択肢も残す。
共通部品化は目的にせず、LOAMで蓄積した共通化のリサーチも確認して必要な範囲を判断する。

控えめな配色、細い丸角枠、整列と余白、フォーカスだけの強調、下部の通知と操作も揃える。
狭い端末でも選択対象と正確な金額を読めるようにする。英語UIの土台は接続したが、
LOAMのrole-aware収支カレンダー、完全なSeries管理、履歴Trend、広い非予算Reportsと日本語切替は未実装。
原額・Merchantと、実取引への配分を持つ完全な精算対応も未接続。
具体的な対象と規則は[UI方針](docs/UI_DIRECTION.ja.md)を参照。
テーマは初期値のTerminal（端末の明暗・配色に追従）とオリジナルのBakhlo Light／Darkを
Space → Commands → Themeで直接切り替える（Household setup内からも開ける）。↑/↓でプレビュー、Escで取消、
EnterでUI設定へ保存し次回起動でも復元する。台帳データは変更しない。

Bakhloはまだ実運用前なので、旧UIとの互換性を維持するための仕組みは残さず整理できる。
予算機能の復活や新しい会計上の仮定、LOAMの正データの変更、普段の記帳先の切替は含まない。

## コードを見る場所

- `lib/`：識別子・金額・取引の小さな型。
- `application/`：検査と数量の問い合わせ。
- `sexp/`：既存Bookと、新しい `Daily_book` の純粋な読取・更新。
  `Year_read` は[年度版の検証境界](docs/YEAR_READ_BOUNDARY.ja.md)のみ。
  信頼できる選択状態の実供給源は未実装で、本番用の年度別読込・保存ではない。
- `tui/`：Bonsai_termの英語UI、共有の操作・表示と、明示的なファイル入出力。
- `cli/`、`presentation/`、`bin/`：引数・表示・入出力。
- `loam_read/`：限定された読み取り専用LOAM入力。完全な移行アダプタではない。
- `test/`：既存のOCamlテスト。

## 次の作業と参考

まず[現在の引継ぎ](docs/HANDOFF.md)を見る。
[機能・保証台帳](docs/CAPABILITY_LEDGER.ja.md)では、LOAMで蓄積した会計上の知見と、
Bakhloのコア実装・Daily保存・TUI接続・運用認定を別々に確認できる。
[LOAMの機能棚卸し・乗り換え判定表](docs/CUTOVER_CHECKLIST.ja.md)で、
現在の対応範囲と切替前に必要な生活操作を選ぶ。
まず記帳・予定管理・各種残高・LOAM Daily Paceと、必要になったレポートでの実運用を目指す。
[LOAM互換の見た目と使い勝手](docs/UI_DIRECTION.ja.md)は英語UIの土台を実装済みで、合成台帳で日常操作を確認する。
次の第一研究候補は[暦年別S式](docs/YEAR_PARTITIONED_SEXP_RESEARCH.ja.md)。
原則1月1日〜12月31日を1ファイルとし、当年＋必要な期首根拠で日常操作を扱えるか調べる。
分析期間・実際に採択した支給日の年金サイクルは年度境界と独立させる。繰越の失効、
年度間参照、年度切替・複数ファイルの原子性/復旧は未解決で、**本番方式の採用ではない**。
[論理設計](docs/CANONICAL_DATA_DESIGN.ja.md)は意味・保持境界、
[長期保存調査](docs/LONG_TERM_STORAGE_STUDY.ja.md)は既存費用を所有する。
[Irmin Phase 1](docs/IRMIN_STORAGE_RESEARCH.ja.md)・[Phase 2](docs/IRMIN_PHASE2_RESULTS.ja.md)は保存済み。
HEAD途中書込み故障とdurable Saved未確立のため本体導入を保留し、SQLiteは比較候補として残す。
現在の実装は単一S式等のまま。年度分割の実装・正データ切替はまだ行わない。
電卓機能（UX-3）は [電卓入力設計メモ](docs/UX3_CALCULATOR_INPUT_DESIGN.ja.md) に整理済みだが未実装。
家計正データは引き続きLOAMが管理し、本番データは変更しない。

- [意味の契約](docs/SEMANTIC_CONTRACT.md)
- [開発手順](docs/DEVELOPMENT.md)
- [現在の実装・実験の設計資料](docs/ARCHITECTURE.md)
- [検証記録と限界](docs/VERIFICATION.md)
- [電卓入力設計メモ (PR UX-3候補)](docs/UX3_CALCULATOR_INPUT_DESIGN.ja.md)

実データ・秘密情報はGitに入れない。試作の成功だけで本番移行や公開はしない。
