# LOAMの機能・見た目・使い勝手をBakhloで再現する

## Manage Lociの実データ対照と一覧のページ移動（2026-10-21）

- [x] 同一取得世代で120×36／80×24の読み取り対照。LOAMは追加フォームが入口、Bakhloは一覧＋詳細。差は台帳へ。[証拠](../docs/VERIFICATION.md#manage-loci-paired-comparison-and-list-paging-2026-10-21)
- [x] 一覧のPageDown/PageUp/Endが先頭へ戻る不具合を修正し回帰検査を追加。
- [ ] Attentionの`End`も同じ桁あふれ（`max_int`）で先頭へ戻る。別sliceで修正。
- [ ] 80×24でのラベル列消失・詳細の語中折返し、LOAM型の入口（追加フォーム／初回役割／Complete Since）を採るか要判断。

## 新規記帳の一行入力（クイック入力）をLOAMへ揃える（2026-10-20）

- [x] `Quick_capture`（説明・合計・Locus語・日付語、過去記録の雛形）を追加し、新規Recordの前段に接続。完成行はRecordのPreviewへ、それ以外は詳細フォームへ引き継ぐ。
- [x] 単体（LOAM `checkQuickCapture`相当）とShellシナリオ（cold）を追加、既存シナリオはTabで詳細フォームへ。`./tools/check`、`./tools/tui --self-check`、`git diff --check`成功。
- [x] 同一取得世代（`capture-1792510023-32503-293b919a`）のfresh paired comparisonを120×36と80×24で実施。サジェスト件数・順序、雛形提案、↓移動、Preview遷移・内訳一致を確認。原本不変、`clean-copies`完了。
- [x] クイック入力をLOAMの枠付きモーダル（枠内フッター）へ揃える（2026-10-21）。合成実画面で80×24／120×36の枠と48×14／32×9の縮退、Tab／Esc・日本語下書き保持を確認。警告が隠れる場合は枠を外し、警告を優先する。[証拠](../docs/VERIFICATION.md#record-quick-capture-framed-modal-2026-10-21)。
- [x] 枠付きモーダルをmainへcommit／pushし、同一SHAのCore／TUI CIを確認（`810abc9`、両方success）。
- [x] 比較環境での`accounting-roles.tsv`自動配置（2026-10-21）。家計簿内の必須AccountingRoleをそのまま配置し、欠落・不正・重複・識別子変形は旧CURRENTを保って拒否。合成取込→Quick capture支払側置換→Preview、コピー整理後coldを確認。[証拠](../docs/VERIFICATION.md#comparison-accounting-role-capture-2026-10-21)。
- [x] AccountingRole自動配置をmainへcommit／pushし、同一SHAのCore／TUI CIを確認（`97d8dbb`、両方success、workflow_dispatch）。比較取込そのものはローカル合成self-checkで検証。

## Daily Paceグラフで選択日の垂直ガイド線を表示（2026-10-20）

- [x] LOAMの`renderInRange`／`renderManyInRange`設計に合わせ、`Pace_chart.qualified_rows`に選択日の垂直ガイド線（`│`）および近傍水平ガイド線（`─`）の描画を追加。
- [x] 日付移動時に縦線が左右に追従し、データ欠落日（unavailable）でも選択位置が明示されることを確認。
- [x] `pace_integration_checks.ml`に垂直ガイド線の存在検査を追加し、`./tools/tui --self-check`および`./tools/check`がすべて成功することを確認（`2a6983c`）。

## Actual画面の配置・表示・詳細をLOAMへ揃える（2026-10-20）

- [x] Actual画面のlayoutをScreen.Workspaceに変更し、context_rows・LOAM table_row・amount_summary・detail_raw_lines・wide判定（98×16）をLOAM ActualWorkspaceに準拠させる。
- [x] Screen.envにdraft_retainedを追加し、保留中Record draftのWorkspace表示を接続。
- [x] モーダル画面（Record_editors等）のgeometryがルート画面のlayout（Screen.Workspace）を尊重するよう`owner_layout`を修正し、モーダルによるFeedback行の隠蔽を解消。
- [x] 単体テスト（actual_workspace_checks）、シナリオテスト（actual_integration_checks, publication_integration_checks, terminal_checks）を修正し、`./tools/tui --self-check`および`./tools/check`がすべて成功することを確認（`16d8cc6`）。

## approved-loci外の既存明細でd/mをLOAMへ揃える（2026-10-20・計画）

この限定sliceでは、保持済み明細のLocusが現在のapproved-lociから外れていても、LOAMと同じく
日付だけの変更とMerchant変更を行える専用mutation経路を追加する。汎用の`c`（memoだけの変更を含む）と
reversalは引き続きapproved-lociで拒否し、`put_entry`全体を迂回する広い例外は設けない。

計画の確認：2026-10-20、実装開始前にユーザー承認済み。追加判断：LOAMは挙動の参照だが、
確認したバグ・危険な挙動・低品質なUXまで再現しない。意図的に安全／正確にする差は明記して回帰検査する。

- [x] 現在のCore／Book_log／TUI interfaceを調べ、維持する不変条件と回帰検査を固定する。
- [x] incremental版と`Full`版に専用の日付mutationとMerchant固有更新を実装し、Book_log replayを接続する。identity・effect・link・original amountを保持する。
- [x] oracle／log／file／TUI回帰を追加し、approved-loci外の既存明細で`d`／`m`が成功し、`c`／`x`が拒否されることをcold reloadと失敗経路を含めて証明する。
- [x] `./tools/check`、`./tools/tui --self-check`、`git diff --check`を実行し、exact diffをレビューする。
- [x] `./tools/startup-probe`で対象mutationを計測する（109.5k件で日付4.14 ms／Merchant 4.03 ms）。
- [x] 同一取得世代のfresh paired comparisonを120×36と80×24で実施し、原本不変を確認して`clean-copies`を行う。
- [x] ledgers／evidence／HANDOFF／reviewをローカル実装結果に合わせて更新する。
- [x] exact diffを最終確認してcommit／pushし、matching SHAのCore／TUI CIを確認する（`9697382`、両方success）。

レビュー（ローカル実装時点）：専用operationにより日付だけを更新し、MerchantもEffectを再発行しない
metadata更新として扱う。`Daily_book.Full`とcold reloadの一致、専用log codec／失敗時非書込、TUIの
`d`／`m`成功と`c`／`x`拒否を合成fixtureで確認。`./tools/check`、`./tools/tui --self-check`、
`git diff --check`は成功。最新データ2寸法で両UIが同じ`d`／`m` Previewへ進み、Bakhlo隔離コピーの保存はcold／Fullと一致。LOAM側は今回Previewまで。

## AIが開発時に最新LOAMデータで比較する（2026-10-19・現在の指示）

ユーザーの意図は、本人用の起動コマンドではなく、AIが毎日の開発時に最新の記帳内容で
LOAMとBakhloを見比べて検証すること。以下を毎日の開発開始時とLOAM更新後の再開時に繰り返す。
同じ取得世代で開発前後を比較し、Coreの回答変更も対象とする。細かな操作ごとの再取得は不要。

- [x] AGENTS・README・HANDOFFへAI主体の比較手順と取得不能時の扱いを記載する。
- [x] source／remote／未コミット差分を確認し、`./tools/compare refresh`で正データを読み取りコピーする。LOAMは開いたままでよく、原本非書込・既存試用保全。コピー前後の原本変更では拒否して旧CURRENTを保つ。
- [x] 最新UIソースに対応する既存Bakhlo binaryと既存LOAM binaryを同一取得世代で比較する。80×24／120×36の読み取り操作とhousehold／config不変を確認。
- [x] 取得時点・対象操作・非公開内容を含まない差・限界を既存の検証欄／画面台帳へ記録する。
- [x] 比較後に今回のLOAM中間コピーと検証キャプチャを削除し、Bakhloデータ・原本・以前の試用を保持する。

合成回帰は継続するが、最新実データ比較・本人／IME受入・P7とは別。旧コピーや合成を最新比較の代用にしない。
実家計の新規操作・書込、定期自動同期、運用切替は含めない。`./ui --daily`は本人向けの任意補助として残す。

レビュー：常設手順を最新正データの読み取りコピーへ簡素化。プロセス起動だけでは拒否せず、新たなlock方式を追加しない。
以下の起動コマンド追加は実装履歴であり、このAI比較要件の完了ではない。今回の実データ比較結果は別途記録する。
旧手順での取得試行はLOAM起動中のため拒否された。ユーザーの追加指示で終了要件を撤廃し、正データのコピーで進める。
簡素化後の取得・変換は2026-10-19 19:14 JSTに成功。原本非書込・プロセス終了なし。
同じ最新データで80×24／120×36の両UI比較を実施。今日のPaceは一致、過去Paceの支持不足が残る。
Balancesの選択・詳細・戻り・resizeは確認したが、金額の意味的な対応は未受入。
今回のLOAM中間コピーと検証キャプチャは削除済み。取り込み済みBakhloデータ・原本・過去試用は保持。

## LOAMの日々の記帳を実機確認へ反映する（2026-10-19・旧手順の実装履歴）

ユーザーはLOAMで毎日記帳し、その最新内容をBakhloでも見ながら実機確認したい。
日々の入口を `./ui --daily` にまとめ、既存の停止取得・変換・比較コピー起動を順に実行する。
LOAM終了後に使用し、取得拒否では起動せず、旧コピー・試用編集・LOAM原本を保つ。
従来の `./ui` は選択済コピーの再訪、`./ui --refresh` は取得のみとして保持する。
計画の確認：本ターンで既存2コマンドを日々の1コマンドへまとめる方針を共有。

- [x] 既存capture/launcherの境界と私用converterの利用可否を、内容を公開せず確認する。
- [x] daily入口と取得→起動の順序、非TTY／取得失敗時の非起動を実装する。
- [x] 合成入力で日々の追加・過去訂正・予定支払い、失敗時の旧選択／試用編集保全と入口を検証する。
- [x] 操作案内・引継ぎ・検証記録とdiffをレビューしてcommit/pushする（`4837462`）。

レビュー：`./tools/compare self-check`と合成PTYの入口検査が成功。毎回新しい取得世代を開き、
前回の両UI試用編集は残すが合流しない。`4837462`のCore／TUI CIも成功。
実家計の取得・起動は今回未実施。

## 記帳の残る差（2026-10-20）

本人判断（2026-10-20）：訂正cはLOAMと同じく口座・行も変更可にする。反転はxのまま。Ctrl-UはLOAMの有効化フローにする。

- [x] Ctrl-U：suspense未許可時にLOAMの確認画面、Enterで科目追加→下書きに戻り差額を埋める。合成・実データ（読み取り）で対照。
- [x] Ctrl-Uのcommit／pushとmatching SHA CI（`f9ebb4a`、Core／TUIともsuccess）。
- [x] 訂正c：口座変更・行の追加削除・日付保持（同一ID、口座を変えた行だけキーを外す、支払linkは保持）。合成・実データ（読み取り）で対照。
- [x] 訂正cのcommit／pushとmatching SHA CI（`510e77e`、Core／TUIともsuccess）。
- [ ] 記帳の一行入力（LOAMの新しい入口）：要判断。

## Daily PaceのグラフとTargetをLOAMへ揃える（2026-10-20）

本人判断（2026-10-20）：partial案内行とPrevious Cycle境界なしは保留後、同日にBakhloのまま（意図的な差）と決定。グラフはLOAMと同じかより良く。`[t] target`は必要。

- [x] LOAM `Tui.Chart`を`Pace_chart`へ移植し、Trendグラフを置換。合成3寸法×10通り・実データ2寸法×7通りでグラフ行一致。
- [x] グラフのcommit／pushとmatching SHA CI（`28d876b`、Core／TUIともsuccess）。
- [x] `[t]` Target plan（読み取り専用：目標額・目標日・今日の仮想支出、候補表・最短日・推移グラフ）をLOAM `DailyPaceTarget`どおり実装し、合成・実データで対照する。
- [x] Targetのcommit／pushとmatching SHA CI（`7855f94`、Core／TUIともsuccess）。
- [x] `[?]` Why（今日のPaceの内訳）をLOAM `DailyPaceWhy`どおり実装し、合成・実データで対照する（本人判断：必要）。
- [x] Whyのcommit／pushとmatching SHA CI（`38b7155`、Core／TUIともsuccess）。
- [x] partial案内行とPrevious Cycle境界なしは意図的な差として閉じる（本人判断 2026-10-20：Bakhloのままでよい）。
- [x] What-ifをLOAM `DailyPaceWhatIf`どおりの即時更新・読み取り専用画面に置換し、合成・実データで対照する。
- [x] What-ifのcommit／pushとmatching SHA CI（`223e971`、Core／TUIともsuccess）。
- [x] Pool設定（`c`）をLOAM `DailyPacePoolSetup`の確定残高チェックリストに置換し、合成・実データで対照する（本人判断：やる）。
- [x] Pool設定のcommit／pushとmatching SHA CI（`3461305`、Core／TUIともsuccess）。

## Daily Pace選択日の詳細欄をLOAMへ揃える（2026-10-20）

- [x] LOAM `detailLines`（全期間版／partial版）の順序・文言・muted・indentへ`render_detail`を揃える。意図的な差（scheduled-linked行・不明日の既知activity・通貨スケール）は回帰で固定。
- [x] Core／TUI self-check、合成4寸法と最新実データ2寸法の対照、原本不変・clean-copies。
- [x] commit／pushとmatching SHA CI（`295e811`、Core／TUIともsuccess）。
- 残す差：partial時の`History partial`フィードバック行（Shell feedback契約の拡張が必要）、グラフ描画、`[?] why`／`[t] target`。

## Daily PaceをLOAMと同じ表示・回答へ揃える（2026-10-19）

ユーザー「loamと同じ表示になるまで開発したい」。前回の描画改善を全面互換の完了としない。
最初にDaily Paceを通し、次にBalancesと残る画面へ進む。基準main `cf196f9`、既存LOAM binaryと現在sourceを区別する。

- [x] LOAMの履歴回答をzero-origin／current anchorのみ／bounded-history／openingのみで対照し、同じavailable／unknown条件を実装する（bounded-historyはDaily v5で実データ全期間一致。opening-onlyはLOAM側の観察のみ）。
- [x] 各日の明示cycle、期限超過・支払済み・取消済み予定、反転・複数通貨、Previous Cycleを同じ現在真実で再構成する（合成回帰）。
- [x] 欠落するbounded-historyの独立根拠を、既存原本を保つ明示形式／読取変換で保持する。過去の試用budget v4は再解釈しない（Daily v5・比較取込で保持。年次／Records v1は拒否）。
- [ ] 同じ端末寸法のcontext／Trend／History／Selected day／feedback／操作案内、グラフと日付軸・件数・選択・scroll・戻りを揃える。
- [ ] 同じ合成入力と操作でLOAMとBakhloを4寸法対照し、全5期間・known／partial／unavailable・resize・coldを実行する。見た目だけ／グラフが出るだけを受入にしない。
- [ ] Core・architecture・native全検査・必要な保存／年別／backup回帰とmatching SHA CIを確認し、既存UI台帳・引き継ぎへ記録する。

計画の確認：本ターン冒頭でDaily Paceの計算根拠・表示・操作まで揃える方針を共有済み。
2026-10-19再開：ユーザーが合成データ・4寸法LOAM比較からの続行を承認。

- [x] 最新mainと既存合成fixture／harnessを確認し、現行Bonsai binaryをbuild・全self-checkする。
- [x] 新しい隔離コピーで両binaryを4寸法・5期間・detail／選択／resize／cold対照する（16 walks、別4 cold。欠落Previous Cycleは拒否差、明示Previous Cycleはcoldで対照）。
- [x] 既知／partial／unavailableの回答差と表示差、非書込証跡を既存検証欄へ記録する（bounded／openingはLOAMのみ。全面一致は未了）。

対照後の限定表示slice（計算・支持条件・保存gateは保持）：

- [x] TrendのSelected／change行、完全日付の両端ラベル、partial Historyの見出し／選択印だけをLOAMへ揃える。
- [x] narrow／partial／huge／negativeの既存条件を維持し、必要な表示回帰を追加する。
- [x] Core／architecture／native全self-check、限定paired 4寸法／coldを実行する（新規8 walks、支持2種のauthority/config不変）。
- [x] diff・既存証跡をレビューして小さい変更としてcommit／pushする（`d696d80`）。

Previous Cycleの拒否・Today contextの計算、target、grid／Braille、Detail全文の順序はこの表示sliceに含めない。

本人の実機／IME受入は最後に実画面で確認する別段階。根拠不足の推測・live原本変更・運用切替はしない。
調査上、`BAKHLO_CONFIG_HOME`はテーマ用であり、通常起動の家計configはbook隣を読む。参照先の混同を原因とした前ターンの断定は撤回。

レビュー：履歴再構成とLOAM workspace geometryに続き、Selected／change行・年付き日付軸・partial Historyを整合。
Core／arch／TUI全self-check、変更前16 walks＋別4 cold、変更後8 walksと合成原本不変を確認し、`d696d80`をmainへpush。
`d696d80`のmatching Core／TUI CIも成功。bounded-history形式・残る表示／操作差・本人受入は未了。詳細は既存VERIFICATION欄。

## Daily Pace / Balances の操作・表示対照（2026-10-19）

ユーザー「揃えよう」を受け、画面別owner移行後のmain `028a816`から進める。
今回の範囲はDaily Pace / Balancesの残る表示・操作差と、他画面保存時のRecord下書き消失。
LOAMの既存ソース・binaryを読み取り比較し、計算・支持条件・保存gateを保持する。

- [x] Daily Pace：期間context、選択位置／件数、広幅のTrend／Detail配置とfooterをLOAMと照合して揃える。
- [x] Balances：Current／Accountingの見出し・配置・選択・詳細・footerの差を照合して揃える。
- [x] 他画面の保存成功では保持中Recordを消さず、自身のRecord保存と区別する。回帰条件を追加する。
- [x] Core／architecture／native self-checkと合成4寸法PTY・LOAM対照・cold reopenを実行する。
- [x] 正確なdiffをレビューし、既存画面台帳・検証記録・引き継ぎを更新して、小さな単位でmainへcommit/pushする。

本人のMac／IME受入、全履歴・全Reports／Series・coverage、P7／運用切替はこの限定sliceの完了へ含めない。

レビュー：期間・今日の支出／差、広幅の親位置保持、狭幅Historyと操作案内、Currentの列・表示名・小数通貨・詳細往復を改善。
Core／arch／35 suitesと両binaryの4寸法、3種のcold新規プロセスで合成確認。未知値・全量・gateは保持。
下書き修正 `1c34695` と表示変更 `f5ac74a` はmainとmatching Core/TUI CI成功。表示の全面一致・本人受入は未了。
詳細は[検証記録](../docs/VERIFICATION.md#daily-pace--balances-interaction-parity-pass-2026-10-19)。

## #42 構造再構築（main統合済み・以下は移植途中の履歴）

2026-10-19に`18af340`までmainへ統合・matching Core/TUI CI成功。下の未チェック行を現在の未移植と読まない。
#42の残件は独立した#40。現状の構造は`docs/TUI_OWNERSHIP.md`、統合記録は`tasks/issue42/HANDOFF.ja.md`末尾を参照。

### Shell 仕上げスライス（2026-10-19）
- [x] Shell の対象を Screen.record_target に揃え、browser alias・未使用helperを除去する。
- [x] Actual / Scheduled session の純粋checksをownerのtest libraryへ移し、native幅関数・全条件を保持する。
- [x] Shell の Record_browser 禁止と直接／alias負例を追加し、責務・現行引継ぎ文書を整合する。
- [x] 34 PASS完全一致・ラベル消失なし・arch/Core・exact diffを確認し、証跡と限界を記録する。

### Calendar/Home owner slice（2026-10-19）
- [x] Calendar/Home の共有browser・pane・scroll・Jump/Searchをownerへ忠実移植し、中央mirrorを削除。
- [x] Home検索、Esc/q差、ambient検索、route/publication/reload同期、120/72列layoutを限定回帰で固定。
- [x] 34 PASS完全一致・ラベル消失なし・architecture/Coreを実行し、結果と残件を既存文書へ記録。

Calendar/Home sliceレビュー: `Calendar_home_screen`へ忠実移植し、`Ui_workspace`はroute/calendar/measureへ縮小。
既存34 PASS・ラベル・arch/Coreを維持。Home/ambient検索、Esc/q feedback、raw Page/End、route同期、
active年度来歴拒否を限定回帰で確認。次はShell/checks/architecture/実測の最終監査と新SHA CI。
main統合・全体完了・LOAM/IME/P7受入とは区別する（詳細は既存VERIFICATION欄）。

今回のユーザー依頼は既存機能を保った完成形への再構築。以下は従来の機能追加順に優先する。
新規Series／coverage等は保留。mainへ未検証版を統合しない。

- [x] OMP作業の現状確認と保全。開始HEAD efda2a3、remote main d39b354。
  tracked差分7件とuntracked source4件、全refs bundle、status/reflogを
  ignored `scratch/reconstruction-42/omp-preservation` と別tmpへ保存。bundle verify成功。
- [x] #28/#38/#39/#40/#41/#42をread-only確認。全てopen。
- [x] 方式比較：別TUI並存ではなく、既存Core/session/rendererを再利用し中央4層を縦ownerへ置換。
  第二実装の回帰負担を避け、旧branchは移行ごとに削除。単なる横分割は完成としない。
- [x] 基準確立：efda2a3でCore合格・native self-check PASS 34行（scratch/base-selfcheck.log）。
  OMP Pace ownerは再実装による挙動ドリフト（周期境界・年度guard・Pool文言・Commands遷移・
  グローバルキー喪失）のため不採用。旧controllerから忠実移植（bddbd9b）。
- [x] Dune層（store/kit/book/protocol/screens/shell/app）＋implicit_transitive_deps false。
  writerはCore workspaceの bakhlo.store。手書きmodule一覧とcopy_filesを廃止。
- [x] Screen契約（tui/protocol/screen.mli）。Pace・Balancesが契約で動作。Shellの画面別glue除去。
- [x] checksを製品binaryから分離：tools/tui --self-check = dune test。画面単体checksは純粋。
- [x] tools/arch（Core runtest）とtest/arch.tの負のテスト。docs/TUI_OWNERSHIP.mdが構造の正本。
- [ ] Scheduled保存操作でowner→intent→Shell→単一writer→owner結果を検証。
- [x] Reports3種を screens/reports へ移植（7600ad6）。Screen_registry で登録1箇所。
- [ ] 残る画面を tui/screens へ忠実移植：Attention → Settlements → Loci →
  Observe/Exchange → Scheduled(+各session) → Actual/Selected day → Calendar/Home。
  Publication要求（Screen.Publish＋結果の画面返却）を最初の保存系移行で導入。
  次の着手点：Attention_data/Settlement_data を純粋モデル(book)とファイルI/O(shell)に分割し、
  env に attention を渡す。Save_attention/Save_settlements 要求を追加（typed expected を維持）。
- [ ] 中央 daily_interaction*.ml を routing／Record保持／Shell overlay／publication だけの
  Shell へ縮退し、legacy_shared_literals を空にする。
- [ ] 全中央checksを画面・primitive・横断scenario・保存復旧へ移管しassertion対応を記録。
- [ ] CI：Core runtestでarch検査済み。tui.ymlのself-checkは --test 経由。実SHAで要確認。
- [ ] 旧経路・不要な互換層を除去し責務文書を更新。
- [ ] Core/native/self-check/4寸法PTY/保存・cold reloadを検証。
- [ ] 代表変更の局所性・再コンパイル・cold/warm時間を前後比較。
- [ ] 実装SHA一致のGitHub CIを確認し関連Issueの実装済／未了を整合。

完成条件は依頼の10項目すべて。P7／電源断・実IME・本人受入・完全LOAM対照は別資格。
詳細なF/O/V/Qは既存の差分台帳のみ。作業branchは `reconstruct/issue-42`。

### 再構築レビュー

開始時のOMP版は未検証で、native構文エラーに加えPoolの非空・admitted Locus拒否と
編集中base保持に後退の疑いを確認。保全済み原本と旧controllerを照合して修復する。
完了宣言なし。既存Core・保存契約・年度履歴は変更対象ではなく回帰検証対象。

## 範囲

Bakhloは未運用で、旧UIの後方互換性は不要。LOAMの全ユーザー向け機能・回答・英語表記・
画面構成・キー・戻る／確認・細部までを対象とし、見た目だけの改修で終わらせない。
**予算配分・振替・消化・用途routing・Budget Windowだけは、実際に必要になるまで延期する。**
Daily Pace、支払い予定、隣接する非予算機能、盆栽の表示・成長は対象。
以前の現在利用だけ・盆栽成長除外は適用しない。予算用の先回りしたAPI・形式・hookは作らない。
Favaとhledgerへの出力はユーザー指定で互換対象外。Print／診断や他の外部形式の扱いは別途照合する。

英語先行。Bakhlo独自の日本語化は未定であり、LOAMのlocale切替等の互換に必要な実動作とは分けて照合する。
Bonsaiを先行し、Nottyを後から追加する選択肢も残す。LOAMのsourceはコピーせず、既存OCaml／
Bonsai環境と既存の純粋API・publication／保存経路を使う。内部構造・保存方式・証明装置を揃える必要はない。
不足する会計意味・独立情報を推測や偽の値で埋めず、必要な情報保持と回答・拒否を実装する。
LOAMが正データと普段の記帳先のまま。原本や以前の私用候補の変更、LOAM build、
新依存、全家計移行・自動同期・運用切替をこの計画で許可しない。

画面ごとのF/O/V/Q差分・現在進捗・依頼カードは
[UI差分台帳](../docs/LOAM_UI_GAP_LEDGER.ja.md)だけで管理する。
この文書は作業の順序と端から端までの受入条件を所有し、第二の画面別進捗表を作らない。

## 現行の順序付き受入計画

現行の作業優先順位は **Daily Paceの表示完成 → Balancesの表示完成 → 残るLOAM機能・画面の体系的な再現**。
以下の番号は未了の受入項目の一覧として維持し、この優先順位を上書きしない。必要な共有機構だけを利用元に沿って直す。
機能完成・表示完成・実機受入を区別し、PTY成功や部分実装だけでユーザー未確認の画面を完成扱いにしない。

### CIによる検証の段階（2026-10-18）

- **段階1、合成self-check合格**：main pushでCore（通常OCaml 5.3）と、対象TUI/Coreソース変更でOxCaml + Bonsai_term native build／`./tools/tui --self-check`を実行する。Core run `39092086513` とTUI run `39094690207`でそれぞれ成功。固定registry revisionとBonsai_term sourceを維持し、Macの私用switchは変更しない。固定依存キャッシュは `4fe9f1d` で追加したが、CI run `39096625299`でcache保存は確認済み。再利用・速度改善は未確認。キャッシュhitでもTUI本体をビルドしself-checkを毎回走らせる。
- **段階2、部分接続・限定PTY検査済み**：`tools/ci_tui_pty.py` が合成fixtureで起動、キー、Balances、resize（120×36・80×24・48×14・32×9）、Ctrl-Q、authority bytes不変を自動検査する。run `39098165655`では4ケース全件PASS。ただし後続pushによってrun全体はcancelled、その後のrun `39098268276` は全ジョブ成功。新規プロセスによるcold再読込と同じexact残高表示も追加し、run `39098514176` で4寸法すべてPASS。依存cacheのexact hitも確認。**Record Preview狭小拒否／取消（限定PTY）**：run `39099170205`で、80×24の合成2 Postingの下書き→Preview→32×9 Publish拒否→80×24へ戻りEsc非保存→同じプロセスで下書き再開→終了、authority bytes不変を検証済み（[証拠](../docs/VERIFICATION.md#native-pty-record-preview-refusal-and-non-writing-cancellation-2026-10-18)）。**未接続**：Actual／Scheduledのより広いPTY操作、Previewの全行確認gate／正常Publish→cold再読込、保存失敗・結果不明、他通貨、実IME、LOAM binary実行一致。画面描画snapshotのみで受入としない。
- **段階3、別受入**：Mac実機IME／フォント／手触り、LOAM同一意味fixture・既存binaryとの比較、保存失敗／P7・実運用資格はCI greenと分ける。CI runnerではLOAM本番／私用台帳を取得しない。

### 全slice共通の受入証拠

- **実装**：日常の入口から対象選択・入力・確認・取消／確定・親復帰まで接続する。
  必要なID・対応・独立根拠を保持し、正確な量、不明／ゼロ、未対応／拒否を区別する。
- **self-check**：純粋計算・controller・描画geometryと必要な保存／再読込の合成回帰を残す。
  これだけでLOAMの実行一致や人間の使いやすさの受入済みとはしない。
- **対照実行**：固定したLOAM既存binaryとBakhloに、同じ意味の合成fixture・日付／設定・
  操作列・端末寸法を与える。回答、拒否、遷移、表示と保存後の再起動状態を照合する。
  ソースにあるだけの挙動、binaryで未確認の挙動、未実行は区別して残す。
- **手動受入**：通常・狭幅・低い端末、resize、長文・日本語／IME・巨大数量・空／不明のケースで、
  可視入力と実カーソル、候補・focus・選択追従、戻り位置、通知の安定、確認全文を実際に操作する。
- **保存・失敗**：閲覧／取消が非保存で、明示確定だけが保存すること、保存内容が終了・再起動後も
  同じ意味で復元することを確かめる。読込不正、保存失敗、stale／競合、結果不明では成功を偽らず、
  旧状態・必要な下書き・対応を守り、不明な保存を自動再試行しない。
  意図的な取消での下書き保持とcold restartでの永続化を混同しない。
- **記録**：各証拠の対象source／binary・fixture・操作・寸法・結果・未確認範囲を既存検証記録へ、
  画面別の到達段階はUI差分台帳へ記す。P7／電源断耐久・運用認定は別の未解決条件であり、
  UI受入や通常再起動の成功で閉じない。

### 実施順

1. [ ] **比較基準と共通合成fixtureを固定する。** Bakhlo／LOAMのsource commit・作業ツリー差分と、
   使用する既存LOAM binaryの識別情報／hashを記録する。sourceとbinaryが異なる場合は明示し、
   buildで黙って揃えない。同じ意味の合成明細・予定・観測・設定を両側の私用コピーへ用意し、
   正常・空・不明・拒否・訂正・返金・複数通貨・保存失敗を再現できる比較前状態を保全する。
   元データや私用取得内容をfixture・公開記録へ移さない。Home／Commands／各入口から
   LOAMのユーザー向け機能を棚卸しし、以下の列挙にない非予算項目もUI差分台帳へ関連付ける。
   2026-10-16: 現行ソース資料からLOAM `bb208173`／Bakhlo `6b676c5`の影響点をUI-01〜34へ反映し、absent-rootを80×24で限定比較した。別の新規合成rootsでfirst-run、wallet／food admission、JPY scale 0のRecord `paired snack`（wallet -37／food +37）、Preview／Publish、Actual表示とcold reopenを両UIで実行（[証拠](../docs/VERIFICATION.md#fresh-root-paired-record-and-cold-reopen-2026-10-16)）。これは単一の正常記帳ケースのみ。空／不明／拒否／訂正／返金／複数通貨／保存失敗fixture、LOAM source/binary対応、初期化Escape対照は未確認。全面受入は未了。
   UI-34 first-run実装を接続。interactive `--book FILE`のmissing sourceでは選択pathを初期destination、
   unreadable existing sourceではblank destinationにする。Measure identifier／scale 0–9を検査し、
   出力先・Measure・scale・履歴等を作らない意味をreview、2段目Enterだけが確定する。
   `Daily_book.empty`は明示的な空Locus policyとMeasure一つを作り、最初のLocusを既存Manage Lociで
   admission可能。`Daily_file.create_empty`はexclusive mode-0600・file sync/readback・parent sync・
   cold loadを行う。source／既存destinationは保全。20×5ではconfirm拒否、resize後に続行。
   `./tools/check`、`./tools/build-bonsai-tui`、`./tools/tui --self-check`成功。80×24合成PTYで
   jpy scale 2をreview→20×5 Enter拒否→80×24で作成→Home起動、`--check` cold reopenを確認。
   別PTYでunreadable sourceはblank destination、Escapeで非保存・source hash維持。非TTY missing
   `--book`は既存拒否を維持。既存destination拒否・bytes保全はself-checkで確認。
   fresh-rootの単一Record対照を実施済み。LOAM初期化の広い受入、人間のIME受入、P7／運用認定は未了。[UI-34証拠](../docs/VERIFICATION.md#first-run-empty-book-creation)／[paired証拠](../docs/VERIFICATION.md#fresh-root-paired-record-and-cold-reopen-2026-10-16)。
   2026-10-17: 初期化reviewのEscがBakhloだけ即終了していた差を修正。LOAMと同じく入力画面へ戻り、
   path／Measure／scaleを保持する。Editボタンも入力へ戻り、入力画面のEscのみ取消。合成missing-rootを
   80×24で両UI実行し、取消後のroot非存在とBakhlo再review非保存を確認。未読rootの作成／失敗経路、
   IME・他寸法の対照受入は未了（[証拠](../docs/VERIFICATION.md#paired-first-run-review-cancellation-2026-10-17)）。
   既存の読めない合成rootでは、両UIとも新規destinationを空にして開始し、別の未使用先のreview→Esc→
   入力復帰→Esc終了で元bytes不変・新規先なし。元rootをdestinationにするとLOAMはreview後、
   Bakhloはreview前に既存先を拒否し、双方元bytes不変。80×24限定、成功createや故障・IMEは未確認
   （[証拠](../docs/VERIFICATION.md#paired-existing-unreadable-root-first-run-2026-10-17)）。
   別の既存unreadable合成rootから両UIとも未使用先のreview非保存→明示create→Home→cold reopenに成功。
   元入力・新規authorityのhash不変、Bakhlo新規fileは0600。80×24限定で、故障・他寸法・IME・
   初回設定全体は未受入（[証拠](../docs/VERIFICATION.md#paired-unreadable-source-creation-and-cold-reopen-2026-10-17)）。
   32×9で両UIの初期化を取消し、destination非存在。48×14ではBakhloのreviewが保存先を`… more`に
   隠したまま作成できた反例を発見し、描画viewport全行の可視性を確定gateへ反映。修正版で48×14
   非保存拒否→80×24全文確認後に作成→48×14 cold reopen、LOAMは48×14 reviewから作成→cold reopen。
   LOAMのreviewは保存先を省略表示するため、その安全性を一致条件として採用しない。
   `./tools/tui --self-check`／`./tools/check`成功。32×9でのLOAM確定、故障／IME等は未確認
   （[証拠](../docs/VERIFICATION.md#paired-narrow-first-run-and-hidden-destination-gate-2026-10-17)）。
2. [ ] **共有機構を利用元横断で移行・受入する。** 責務・API・全利用元・受入条件は
   [TUI共有部品の責務設計と移行順序](../docs/TUI_LAYOUT_STABILITY_ROADMAP.ja.md) に従う。設計確定のみで実装済みにはしない。
   - 共有input／再帰Input metadataの純粋機構は実装・境界検査・native幅の直接smoke済み。既存Daily_form・tail・native widthを再利用。
   - Ui_formとstyled frame、Modal_form・Jump・Search overlay・Reversal Dateと直接利用元checksは移行済み。
     cursor_offsetとReversalの独立caret計算を削除。Core/native検査と合成tmux成功。LOAM対照・本人受入は未了。
   - RecordのColumns＋recursive caretを同時切替し、Scheduledの同じ入力表示・UTF-8文字移動・focus-following・notice予約・均一幅を接続済み。Sch.cursor_positionを削除し、renderer matrix（8寸法×3テーマ）へScheduled_createを追加・合格。
   - list/detailは既存Ui_panelを維持し、Actualのterminal_geometryをpanel_geometryへ統一、wide tx_heightのpage_size容量整合、
     controller経由のdrill-down/back復帰でAct.returned_from_detailを接続。復帰時の別browser上書きと詳細focus／scroll消失を修正し、限定回帰・合成PTYを確認。横断受入は未了。
   2026-10-18 #38仕上げ：controllerをState（状態／遷移／保存結果）、Context（問い合わせ／form／共通寸法）、入力dispatch、View（描画／配置）へ4分離し、既存挙動を維持。同じMacの前後実測では表示だけの再コンパイルが6→3 module、共有Contextは6→8、既存leafは7→10であり、全体のcold／warm／self-check高速化は未立証。詳細・読取入口は[検証記録](../docs/VERIFICATION.md#issue-38-final-audit-and-same-mac-development-measurements)。checks分割は費用対効果を判断して[#39](https://github.com/shumoku88-bit/bakhlo/issues/39)へ延期し、Scheduledの機能開発を待たせない。#38原条件の「複数の画面固有ownerへ抽出」は未達なのでopenを維持し、4分離を画面別分離済みとは扱わない。実装SHA `f80f39f79667c39c94453d287459109e57f169fb` のCore run `39107229334`／Bonsai TUI run `39107229537`はいずれもcompleted/success、native self-checkと4寸法PTY／Record Preview拒否を含む。証跡は[同SHAのCI検証欄](../docs/VERIFICATION.md#matching-commit-github-qualification)。
   2026-10-17: paired Actual search at 80×24 returned one distinct record each for `paired` and `other`, zero for `zzzz`, and both after Escape. In the rebuilt Bakhlo binary, active `/paired` survived resize to 48×14 with full `+37 jpy`; `/other` at 48×14 showed full `+11 jpy`, and Escape plus restore to 80×24 showed both records. The 32×9 Description-only result is from the previous binary, not rerun after the fix. Authority hashes were unchanged ([evidence](../docs/VERIFICATION.md#paired-actual-search-2026-10-17)). Search/amount checks remain bounded, not full consumer acceptance.
   Actual長文検索のG-2限定成功は保持するが、G-1/G-3/G-4や全画面を完了扱いしない。
   幅0／1、長文・CJK、通知、通常／compact、resize、取消でpaintとcaret・保持値・draftを確認する。
   sessionごとのreview／保存gateを維持し、実装・対照実行・本人受入を別々に記録する。IMEは実機で別途受入する。
3. [ ] **Record lifecycleを端から端まで揃える。** 起動／親日付からの新規入力、候補・prefix検索、
   Posting追加／削除・差額補助、focus・キー・paste、Preview全文・末尾／狭小gate、
   Publish／Edit／Cancel、下書き再開・別操作との分離、確定後の親選択まで照合する。
   記帳→終了→再起動→Actualで同じ内容を確認し、失敗／競合で非保存・下書き保持を確認する。
4. [ ] **Actual／Selected Dayを揃える。** Loci／Actuals／Details、検索・対象日／scope・sort、
   選択・詳細scroll、Selected DayのActual／open予定・role-aware集計、親への復帰を確認する。
   訂正・日付変更・Merchant／原額・返金／反転等は、入口だけでなく必要情報・独立確認・
   保存後の同一性／対応と再起動まで照合する。未接続情報を表示だけで取り繕わない。
5. [ ] **Scheduledを揃える。** List／Series Calendar／Months／Plan Detail、単発作成、
   replacement・日付付きcancel、実績化、次回／複数回／期限までの補充、Expected paceを確認する。
   専用確認・tiny gate・取消初期選択、支払済み／取消済み拒否、Actualとの一括対応、
   再起動後のopen／completedと二重発行拒否を含める。予定の未供給を「義務なし」にしない。
   **次のまとまった実装単位：明示監視ルール＋Series Calendar（UI-23→UI-12）**。単発作成、期間一括生成、完了後の継続Promptは接続済みであり、再実装しない。
   1. 選択済み明示occurrenceのanchor・正負Locus集合と、人が選んだ月cadence（1／2／3／6／12）をreplaceable監視設定として保存する。金額・名前・履歴から周期やSeries同一性を推測しない。既存config publicationの競合・不正読込・全文Review／tiny拒否を保つ。
   2. 監視ルールと検証済みopen／completed対応から月別Reviewを作り、予定日・完了印・期待月の未供給を区別する。取消／欠損Actual／不正完了参照を完了証拠にせず、`!`を予定authorityやNotDueへ昇格しない。
   3. List／Series Calendar／Monthsの選択・月窓・詳細・継続／補充へ接続し、合成の明示設定→保存→cold→月別欠損／完了表示と4寸法・拒否／競合を一単位で受け入れる。設定だけ／見た目だけでSeries完成としない。
6. [ ] **Balances／Observeを揃える。** 初期表示・Current／Accounting・履歴、数量の根拠と
   不明表示、同時観測画像・複数座標・既存支持の扱い、独立確認と保存後の再照会を照合する。
   正確なゼロ、存在のみ既知、根拠なし、失敗を区別する。Locus／role設定に必要な意味も接続する。
   2026-10-18: Daily Paceの表示sliceに続き、Balancesの初期座標／狭幅金額消失を修正。4寸法の合成対照・unknown詳細復帰・cold reopenを実行。広い受入は未了（[証拠](../docs/VERIFICATION.md#pace-history-and-narrow-balances-paired-2026-10-18)、画面別残差はUI-24）。
   **UI-24-B2（表示口座設定・複数座標観測）**：候補pickerの選択／Review／取消／現Measure保存と他Measure保全、ObserveのAdd→Preview→Publish／Editを接続。合成Core/native検査、既存LOAM binary対照、保存後cold再読込、重複／支持衝突／狭小／競合拒否と実保存失敗→結果不明→再送停止を確認（[証拠](../docs/VERIFICATION.md#ui-24-b2-balances-picker-and-grouped-observation-2026-10-18)）。この限定sliceの実装・検証であり、Balances全体・本人受入の完了ではない。
   **UI-24-V3＋responsive sprint**：80列上下配置と不正設定Print拒否をローカルCore/native self-checkと4寸法PTYで確認。Current／Accountingの座標保持、未知／巨大数量の通貨表示、End→Up／resize、全文スクロールできるPrintの行／バイト上限とEnter取消を追加。Observeの2座標Preview→狭小拒否→Edit→Publish→cold、表示口座のReview取消／保存→coldも合成確認。本人受入・完全なAccounting／外部出力・roles保存安全境界は未了（[証拠](../docs/VERIFICATION.md#daily-pace-and-balances-responsive-completion-sprint-2026-10-18)）。
7. [ ] **Daily Pace／Trendを揃える。** 明示Pool・通貨・観測日・期間、現在値／What-if・負数、
   Pool／期間設定と履歴Trendの10d／30d／Month／Cycle／Previous Cycle、履歴支持・推移を照合する。
   予定控除・日数・整数演算、欠損／曖昧条件の拒否、設定取消・保存・再起動と既存preset保全を含める。
   Daily Paceを予算扱いして延期せず、月末や名前から条件を推測しない。
   2026-10-18: History／日別内訳／上下配置を接続し、current-onlyの過去日推測を拒否。ゼロ起点支持あり／なしの合成対照と4寸法・cold reopenを確認。全面の履歴／実機受入は未了（[証拠](../docs/VERIFICATION.md#pace-history-and-narrow-balances-paired-2026-10-18)、残差はUI-33）。
   responsive sprint：Today表示、短い金額内訳、全幅詳細、選択日の期間切替保持、可視容量に沿うページ／端／resizeを接続・合成4寸法PTY確認。What-ifの金額・根拠を整列し非保存／負数計算を維持。LOAM既存binaryとのcurrent-only 80×24、zero-origin支持120×36の回答一致を確認。全面の履歴・IME／本人受入は閉じない。
   **未完了を維持**：dated bounded-history支持、支払済み／取消済み予定を含む過去Paceは今回未検証。UI-24-B2の成功で履歴受入を閉じない。
8. [ ] **Attention／Settlement／Exchangeを揃える。** Attentionの期限の意味・追加／解決／撤回、
   SettlementのActual／Effect配分・部分精算・相殺・非支払減少・独立した通貨／証拠・訂正、
   Exchangeの両数量・対応・専用Previewと復帰を照合する。累計sidecarだけを完全な精算としない。
   不正読込・参照欠損・保存失敗・競合と再起動を含め、複数ファイル原子性を勝手に保証しない。
9. [ ] **残るReports／setup／対象内の出力とその他の棚卸し不足を閉じる。** Income & Expense、
   Stock–Flow、Transactions Flow、Multicurrency Spend、Liquidity等の回答・期間・比較・寄与明細、
   Household setup、表示名／説明・一覧・通貨／scale・役割・期間設定、Help／Theme／locale、
   Print／診断・対象内の外部形式等の既存LOAM入口を照合する。Favaとhledger出力は除外。
   盆栽の表示・成長も除外せず調べる。各項目の必要情報、設定／出力の保存先、同意・取消、
   再起動、失敗時の非破壊性まで確認し、派生出力を正データにしない。棚卸しの残りを再確認し、
   予算延期と明示した二項目以外の無断除外を残さない。

## 過去の限定チェックポイント（現在の全面受入とは別）

以下のチェック済み行と検証記録は当時の範囲の証跡として保持する。
後続の実装有無・画面別進捗はUI差分台帳を参照し、旧方針の一時的な範囲限定を現行方針へ流用しない。

## 手順

- [x] 中断で残った未接続モジュールを統合し、英語TUIをビルド可能な状態へ戻す。
- [x] 英語先行・日本語未定・Bonsai先行／Notty排除なし・UI操作互換を現行方針へ明記。
- [x] LOAMの現行ラベル・画面遷移・キー・確定操作を、対応するBakhlo機能と照合して受入条件を確定。
- [x] 英語の固定文言に翻訳入口を設け、表示文字列に依存する判断を安定した原因／型へ置換。
- [x] Calendar Home、日付／zoom／Detail／選択日と階層Commandsを実装。
- [x] Record／候補／確認／Actual／Scheduled／Balances／Daily Paceを共通の画面階層へ接続。
- [x] 不要な旧Homeサマリー・独自キー・互換経路を削除し、現行手順書を更新。
- [x] 純粋な日付・言語境界・実セル幅・操作・保存拒否をself-checkで検証。
- [x] 合成PTYで代表操作列、狭い端末、resize、取消／確定／cold readを確認。
- [x] 最終diffと未接続機能をレビューし、達成範囲と残る差を記録。
- [x] 英語UIをコミット・pushし、PR #26をマージ（534c71f）。TUI対象のGitHub CIは未設定、ローカル検査は成功。
- [x] 再開指示を受け、LOAMの共通化リサーチを確認。今回の範囲はHomeと基本Recordに限定。

## Home / Recordの仕上げ

- [x] Homeの余白・選択日・近接Detail・小端末の優先表示を整える。
- [x] Record / Previewを中央ペイン化し、小端末では入力可能な全画面へ畳む。
- [x] ネイティブ描画で枠・本文・フォーカスを分離し、操作の性質を枠色だけで伝える。
- [x] 下書き保持・保存ゲート・実セル幅・32×9 / 48×14 / 80×24・resizeを合成データで検証。
- [x] 実画面とdiffをレビューし、結果と未達範囲を記録して安全なチェックポイントにする。

### レビュー

Homeは空の大枠を縮め、80列付近で近接Detail、広幅で自然な高さの左右配置へ変更。
Recordは一つの入力枠へ整理し、中央表示でも親の日付を残す。極小端末の入力・下書きは継続可能。
枠・左右pane・選択日・実カーソルをBonsai Viewで局所的に組み立てる。データ内の`|`や`│`は
カーソル／枠として着色しない。会計の検査・publisher・元データは変更していない。

共通化判断は **KEEP**（既存の物理的な枠・セル幅処理）、**INLINE**（Home配置／Record入力）と
**DEFER**（別編集画面を含む汎用フォーム）。操作別のドメイン分岐を共有描画へ移していない。

`./tools/check`、最終`./tools/tui --self-check`、`git diff --check`成功。
3テーマ・8寸法の描画、狭い日曜選択、literal文字のスタイル、全警告、7故障＋7SIGKILLを検査。
最終合成PTY `scratch/ui-polish-final.rdDXLu`で80×24／48×14／32×9、長い日本語入力、70桁数量、
resize、Ctrl-S非保存、Edit／Cancel／Esc保持、Publishとcold readを確認。
通常入力とechoは復帰。既知のEXTPROCのみ消える差は再現し、完全なtermios一致は保証しない。
ユーザーの「キリのいいところまで」に従い次機能は停止。見た目の最終受入と全面LOAM互換は未達。

## 削除・置換の判断

旧 UI の操作別名や画面を維持するための互換経路は増やさない。
現在はBonsai先行。旧Notty画面・比較ベンチ・レイアウト試作・旧フォーム／閲覧経路は削除済み。
これはNottyを将来の実装対象から外す決定ではない。
有用な保存・復旧反例は維持し、旧UIの固定キーだけの検査は新しい操作契約の検査へ置換。
Calendarに必要な役割別金額が供給されない場合は、Unavailable等で区別し、架空のIn/Outを出さない。

## 前段の共通描画の証跡

調査時点では両 worktree は clean。変更前の OCaml build / tests は成功。
LOAM の参照は `docs/TUI_NON_BUDGET_WORKLIST.md`、`docs/TUI.md` と共通 Layout。
記帳・保存の根拠や不明とゼロの区別を presentation から独自に作らない。
旧 renderer 名引数と ASCII 枠を削除・置換。入力下書きの日付が今日の Daily Pace を
変えてしまう問題を修正し、合成の回帰確認を追加。
両 frontend の全 self-check は成功。最後の列整列修正後も Bonsai / Notty を再ビルド・検証。
日本語の実セル幅、値の列位置、巨大数量の全文、通知優先、pane の非重複、表示領域不足時の
確定拒否、今日と下書き日付の分離を回帰検証。`git diff --check` も成功。
実 TTY は合成台帳だけで、37 JPY の入力・プレビュー・Enter の非保存・Esc の下書き保持・
明示 Ctrl-S 保存、詳細・picker・テーマ、100×30 / 80×24 / 64×20 と保存停止時の通知を確認。

tmux の終了後に EXTPROC フラグだけが消える場合があり、未変更 HEAD の別ビルドでも
同じ差を再現した（通常入力・終了は成功）。この UI 変更での新規回帰ではないが、完全な
端末属性復元の保証はできない。端末 lifecycle の修正を今回の表示統一へ混ぜていない。
合成 PTY の画面・属性証跡は `/private/tmp/bakhlo-ui-pty.RfYmib`。
LOAM worktree は変更なし。私用台帳の内容を読まず、本番移行・依存追加・commit はしていない。

## 方針修正の教訓

「loam互換のUI」は配色・枠だけへの移行ではない。ユーザーが示した英語表記、画面構成、
操作の習慣を受入条件に含める。見た目の部分改修をUI互換の完成として報告しない。
先行実装と最終的な選択を混同しない。Bonsai先行をNotty排除、日本語未定を実装予定、
共通化の候補を共通化の必須方針へ勝手に格上げしない。

## 英語UIのチェックポイント（2026-10-12）

`./tools/check`、`./tools/tui --self-check`、`git diff --check`が成功。
実セル幅・3テーマ・7寸法、Previewと巨大数量／日本語のActual・Selected Day・Scheduled・
Balance詳細、7段階の故障注入と7段階のSIGKILL反例を確認。
合成PTYで英語Calendar／Commands、長い日本語メモ、70桁数量、Edit／Cancelの非保存、
Publish選択時のEnterのみ保存、140×40→48×14→80×24→140×40のリサイズ、cold readを確認。
この試験の3セッションは端末属性も一致。証跡はignoredの `scratch/loam-ui-native.0LHLXL`。
Records予定支払いの「liveでは完了、coldでは未完了」の既存反例を合成台帳で再現。
対応リンクの同時発行と既存明細置換が未対応なRecordsは、append前に明示拒否する。
bytes・cold状態・LSN・Ackの不変と、対応可能な通常Records追記のcold readを回帰検査した。
Record外のbracketed pasteからHome／Commandsの操作を実行しないことも検査。

日本語切替、役割別収支カレンダー、完全なSeries管理、Attention、履歴Trendは未実装。
現段階は英語UIの土台であり、全面的なLOAM互換・Jane Street品質・POSIX非依存・
例外排除・フローティング編集枠や3色枠線の完成を意味しない。

## Issue #42 引き継ぎ (2026-10-19)

- 2026-10-19: #42 の再構築を main `18af340` に統合（main CI 両方 success）。#38/#39/#41 クローズ。#42 は #40 の修正待ちで open。

- 実装指示書: `tasks/issue42/HANDOFF.ja.md`（次は Registry 述語化 → Selected Day → Calendar/Home → Shell 仕上げ）。
- 検証基準: `tasks/issue42/pass-base.txt`（34 PASS）、`tasks/issue42/labels-base.txt`（assert ラベル）。

### Registry 述語化スライス

- [x] `Screen_registry` の route 所有判定を述語にし、enter に route を渡す。既存 owner の挙動は保つ。
- [x] TUI 全検査と34 PASS完全一致・ラベル消失なし・arch・Coreを確認する。
- [x] 差分をレビューし、検証結果と限界を記録する。main への統合は行わない。

レビュー: 固定 route は従来と同じ等値判定、floating editor は常に非所有。
既存 enter は追加の route 引数を無視して元の関数へ委譲する。次は Selected Day の owner 移行。
ローカル検査は合格。matching SHA のCI・実PTY・IME・P7の追加資格はこの準備変更では未確認。

### Selected Day owner スライス

- [x] 状態・検索・入力・描画を `screens/day` へ忠実移植し、中央の browser mirror を削除する。
- [x] Registry の modal reload 方針を明示し、検索中の Ctrl-Q/N/R の非実行を保つ。
- [x] fixture と既存assertionを owner 問合せへ移し、検索・Detail Home/End・再訪保持の回帰条件を追加する。
- [x] TUI 34 PASS完全一致・ラベル消失なし・arch・Coreと差分レビューを実施し証跡を更新する。

レビュー: 同期対象を Day owner へ移し、Calendar browser は保持する。入場直後の選択identity・
範囲補正と最初の移動を回帰確認した。従来の検索遅延・Ctrlキー消費・Detailでの選択変更／
未clamp offset・再訪filter/order保持を維持。次は Calendar/Home。Day実装SHAのCIは未実行。
