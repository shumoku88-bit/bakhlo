# TUI共有部品の責務設計と移行順序

## 目的と根拠

LOAMのユーザー向け機能・見た目・操作感・細部をBakhloで再現する。予算だけは必要になるまで延期し、Daily Pace・予定を含む非予算機能は対象に残す。本書が共有UIの責務・契約・全利用元・移行順・横断受入の所有文書である。画面別の進捗は [UI差分台帳](LOAM_UI_GAP_LEDGER.ja.md)、順序は [受入計画](../tasks/todo.md)、実行証拠は [検証記録](VERIFICATION.md) に残す。新しい進捗表は作らない。

設計確定後の現在地：移行順1の純粋機構`input_text`／`input_cell`／`cursor_in_rows`と境界検査を実装済み。native幅で直接smokeと既存self-checkが成功した（[実行証拠](VERIFICATION.md#shared-input--recursive-metadata-slice)）。画面へのcutoverと以下の横断受入は未実行。fixture・config・build registration・依存・実データは変更していない。

Bonsai/Nottyを継続利用する。独自renderer、独自Unicode幅テーブル、Bonsaiに重ねるraw ANSI、汎用scene engine・状態frameworkは採用しない。旧ロードマップの「6重の防護壁」「真犯人」という原因断定、文字列結合の完全廃止、独自幅表での完全一致、先行auto-wrap制御追加という必須指示は撤去する。既存native合成・最終fit・差分描画を無視した刷新は行わない。

[幾何調査](TUI_GEOMETRY_RESEARCH.ja.md)は反例・外部調査・未検証境界の所有文書として維持する。G-1（フォームのpaint/cursor分離）とG-3（短いnoticeによる移動）は既存合成実行の反例、G-4（Recordのstyle損失）はsource確認。G-2（Actual長文検索）は後続修正済みの限定対照であり、全画面合格ではない。今回のsource照合は新しいruntime再現ではない。

| 根拠 | 確認済みの内容 |
| --- | --- |
| `tui/bonsai_daily.ml`: `lines` / `fit` / `app` | `Columns`をnative `V.hcat`で再帰合成し、最終fit、event適用時のdimensions、after-display cursor effectを既に使う。差分描画は幾何調査のNotty経路のsource確認を参照 |
| `tui/ui_panel.ml`: `capacity/window/move/frame` | 枠・可視容量・追従window・overflowを避けるoffset移動が既にある。幅6未満／高さ2未満は空文字行であり、全寸法の厳密幅保証ではない |
| `tui/ui_form.ml`: `render_rows/cursor_offset` | 寸法なしpaintと保持値全体の幅からのcursorが別計算。noticeなしでは行を確保しない |
| `tui/record_session.ml`: `combine_side_by_side` | 左右styleを一つへ潰す。既存のColumns利用例と異なる |
| `tui/scheduled_session.ml`: `field_row/cursor_position/handle` | paintは編集位置を使わずcursorは独立計算。Left/Rightの文字移動がbyte±1。UTF-8破損や実機症状のruntime再現は今回していない |
| `loam/docs/TUI_REFINEMENT_ROADMAP.md:64-78` | 行数削減でなく変更の局所化・呼出側前提・実利用・保守性を共有判断に使う |
| `loam/Loam/Tui/ModalSurface.lean`: `centered?/contentBounds/framedView` | 共有するのはsurface配置・枠。閾値とcontent・session意味は呼出側が所有 |
| `loam/Loam/Tui/EditorSession.lean`: `Step/runUntilPublished` | 同一editorへ拒否を返せる互換lifecycleだけを共有し、stale-state editorを無条件に統合しない |

LOAMのLean実装は既存調査の知見の参照だけとし、今回コード移植・LOAM build・原本読取はしない。端末auto-wrap、grapheme、macOS IME/preedit、live出力raceは未認定境界のまま。表示修正から保存文字列の正規化・切捨てや保存gate緩和を導かない。本番authorityと正データはLOAMのまま。

## 責務と共有判断

行数ではなく変更の局所化・呼出側前提・実利用・保守性で判断する。モデルやsessionを一つへ統合しない。

| 層・所有先 | 決定 | 共有する責務 | 共有しない責務 |
| --- | --- | --- | --- |
| `tui/daily_form.ml` | KEEP | UTF-8 scalar単位の既存編集、byte-offset cursor、insert/erase/move | 表示幅、label、field identity、validation、発行 |
| `tui/daily_overlays.ml` | KEEP＋表示機構を統合 | visible/clip/pad/wrap/tail、Input/Columns metadata、単一行の可視窓とcaret、再帰caret探索 | 保存値の変更、screen名分岐、focus移動、Enter/Escの意味 |
| `tui/daily_overlays.ml:locus_candidates` | KEEP | 許可済みLocusのprefix候補、exact token優先 | candidate index、候補確定後のfocus、Record/Scheduled固有入力規則。新しいpicker frameworkは作らない |
| `tui/ui_panel.ml/.mli` | KEEP＋styled contentの枠を既存geometryへ接続 | 枠・padding・capacity/window/move・content内のmetadata座標変換 | ID、query/filter、workspace state、publication判断 |
| `tui/ui_form.ml/.mli` | split geometryを切替 | 既存Text/Choice/Buttons配置、focus行の可視化、local notice、bounded paint/caretの一体化 | Record/Scheduled/Reversalのreview lifecycle、独立Previewや保存gate |
| `tui/daily_interaction.ml` | KEEP・重複caret式を撤去する設計 | global feedback・footer/body割当、sessionへの寸法供給、route/parent接続、surface配置とlocal→terminal座標 | childの保持値からcursor再計算、表示による会計判断 |
| 各session・workspace | KEEP LOCAL | field構成、対象ID、選択・query・sort、draft、戻り先、review gate、発行意図と拒否後の復帰 | 共有表示機構の複製 |
| `tui/bonsai_daily.ml` | KEEP | 実幅計算、native合成、最終fit、input adapter、after-display cursor | 会計・耐久保存・復旧、独自の幅表や第二renderer |

`Ui_workspace`と`Actual_workspace`のstateは統合しない。`Daily_interaction.open_route`はActualを新規作成し、`sync_actual_to_workspace`はbrowser側へ状態をコピーする。`Actual_workspace.returned_from_detail`は実装・宣言だけで利用元が未接続なので、ID維持復帰の成功根拠にしない。接続済みcontroller経由のdrill-down/back検証が必要である。

## 入力・描画契約

以下が共有入力・描画の契約。単一行inputの三つのAPIは実装済みで、フォーム／枠とconsumer移行は次の製品変更。新しいconfig・永続field・dependencyは設けない。

### 単一行input

表示機構を`Daily_overlays`へ集約する。Recordの`field_text`にある「byte cursorで左右を分ける→左をtail表示→挿入cellを予約→右をclip→同じ結果からcaretを返す」方式を再利用した。Actualの`search_line`はend-cursor＋blank挿入cellの既存受入例として維持する。保持値・placeholder・label・枠は呼出側所有とし、可視窓だけを共有する。追加したAPIは次の三つに限定する。既存consumerはまだ切り替えていない。

```ocaml
(* value windowのみ。label/borderを含まない。cursor=Noneは末尾。
   caretは既存呼出側の1cell glyph（Record "|"、Actual " "）を保つ。 *)
val input_text :
  width_of:(string -> int) -> width:int -> cursor:int option ->
  caret:string -> string -> string * int option

(* Input/Columnsのchild-local位置を親の幅へ一度だけ変換する。 *)
val input_cell : width:int -> style -> int option

(* 実際のpaint行に挿入cellが残る場合だけlocal座標を返す。 *)
val cursor_in_rows :
  width_of:(string -> int) -> width:int ->
  (style * string) list -> (int * int) option
```

`width_of`はfrontendの実cell幅、`width`はvalue窓または探索する親行の利用可能cell数。`cursor`は既存byte-offset、末尾のstring引数は保持値。`input_text`の戻り値は表示文字列と窓内caret列、`input_cell`はstyle内のInput/Columnsから求める親行内列、`cursor_in_rows`はpaint済みrows内の(column,row)である。表示幅0／挿入cellなしならcaretなし。保存値は変更しない。

mid-string編集は既存byte-offset契約のまま。Scheduledの文字移動は同一consumer移行で`Daily_form.move_cursor`へ接続する。Rightによる候補確定はScheduled localに残す。

### フォームと枠

寸法なし`Ui_form.render_rows`＋独立`cursor_offset`を最終的に廃止する。フォームは利用可能幅／高さと実`width_of`を受け、可視styled rowsとInput metadataを同じlayoutで決める。`Ui_panel`のcapacity/window/枠を再利用し、styled content経路でcaretをframe inset分だけ変換する。既存string-list一覧APIには実利用があるため維持し、全workspaceをフォーム用に移植しない。

現行`Panel.frame`は`panel_line`の2列とlist markerの2列を合わせcontent開始が列4、roomが幅−6。この`+4`をcontrollerへ再散在させない。短いsummary・choices/buttonsの構造とSubmit/Cancel意味は変更しない。

```ocaml
(* Ui_form.mli：width/heightは枠内のフォームcontentの利用可能cell数。
   focusとnoticeを含む可視行だけを返し、caretはInput metadataに含める。 *)
val render_rows :
  width:int -> height:int -> width_of:(string -> int) -> t ->
  (Daily_overlays.style * string) list

(* Ui_panel.mli：非選択のstyled form content用。現行frameの枠・capacity
   計算を内部共有し、blank markerを含むcontent insetでInputを一度変換する。 *)
val frame_rows :
  width_of:(string -> int) -> width:int -> height:int -> focused:bool ->
  title:string -> (Daily_overlays.style * string) list ->
  (Daily_overlays.style * string) list
```

`frame_rows`のwidth/heightは枠全体、focused/titleは枠の焦点・見出し、rowsは非選択のstyled contentである。既存`Ui_panel.frame`に同等APIはなく、string行へ戻すとInputが失われるため、この非選択経路だけを追加する。content幅は`max 0 (width - 6)`、content高は既存`capacity ~heading:false`。空／負寸法は空content・caretなし、枠の極小縮退は既存frameと同じとする。

`cursor_offset`は全直接利用元の同時cutover後に削除し、aliasを残さない。縦windowはsummary/fields/notice/buttonsを構成してから既存window機構でfocused field/buttonの行へ追従する。フォーム内geometryに保存拒否gateは持たせない。

### 合成と座標

既存`Columns`表現とnative合成を使い、Recordのstyle潰しだけを撤去する。新しいscene treeやside_by_side APIは作らない。左右各paneを宣言幅へpad/clipしてから合成し、Inputはchild-localのまま保持する。右caretの親位置は`left_width + 1 + child_column`、さらにoverlay originを一度だけ加算する。floating/full Recordの両方で再帰探索する。

行がclipされた・caret cellがcontent外の場合は隠し、borderへclampしない。最終rendererのfitだけで子pane不正を隠さない。literal `|`や枠文字からcaretを推測せずInput metadataを使う。

### 通知と容量

global feedbackはcontroller、local noticeは当該session/formが一度だけ確保する。noticeなしと1行noticeでorigin・field・buttonsを動かさない。長い重要警告はwrapと明示overflowを維持する。local noticeが増える場合の可視capacityはpaintとnavigation/reviewで同じ結果を使い、Record/Scheduled/Reversal固有の発行拒否条件を保持する。全sessionのfloating閾値は統一しない。

## 全利用元と波及範囲

generic formだけ直して終了せず、以下を共有機構単位で移行する。source照合による一覧であり、新しいruntime合格の一覧ではない。

| 利用元 | 現行接続／切替対象 | localに残すもの |
| --- | --- | --- |
| Record | `record_session.ml:field_text/combine_side_by_side/screen`、controllerのfloating/fullのInput探索、`record_session_checks.ml`のtop-level Input検査 | Date/Description/Measure/posting、候補・中間編集、draft、review_geometryとPublish gate |
| Scheduled作成 | `scheduled_session.ml:screen`内`field_row`、`cursor_position`、`handle`のbyte-step矢印、optional notice | Due・fixed Measure・posting数・候補確定・独立draft・Preview gate |
| Actual検索 | `actual_workspace.ml:search_line/cursor_position`とcontroller header | caption/query/filterと右端予約。G-2修正済みの挙動を退行させない |
| Jump | `daily_interaction.ml:resolve_overlay`のJump branch | 日付parser・適用・取消 |
| Search overlay | 同Search branch | query適用・解除、Actual inline searchとの差 |
| Modal_form | 同Modal_form branch、`ui_form.ml/.mli:render_rows/cursor_offset`、`daily_interaction_checks.ml`の既存form checks | Text/Choice/Buttons・field順序・Submit/Cancel |
| Reversal Date | `reversal_session.ml:screen/cursor_position`経由のUi_form直接利用 | 固定target/base・Date→Preview・正確なinverse・uncertainty停止 |
| 合成利用元 | Record、Actual `screen`、controller `workspace_rows.split_pane`とCalendar/detail合成、renderer `Columns`と既存native image/style検査 | workspaceの内容、配置policy、field/pane選択 |

Modal_formのcontroller索引：`cancel_plan_form`、`add_attention_form`、`resolve_attention_form`、`drop_attention_form`、`exchange_form`、`observe_quantity_form`、`what_if_form`、`configure_pace_form`、`balance_print_preview`（refused/previewの両Form.create）、`admit_locus_form`、`set_locus_role_form`、`add_settlement_form`、`action_settlement_form`。共通geometry変更をこれらのdomain dispatch改修へ広げない。

## 移行順序

依存順を以下に固定する。移行順1だけ純粋機構として実装・検査済み。画面別の合格を意味しない。

1. 共有input・再帰Input metadataの純粋機構を先に作る。既存`Daily_form`／`tail_text`／native widthを再利用し、独立した単一行・左右/nested Columnsの検査を揃えた。直接smokeは長文の縮小→途中編集→拡大とnested親座標を確認済み。
2. Ui_formとstyled frame接続を切り替え、Modal_form・Jump・Search overlay・Reversal Dateを同一移行で接続する。全直接利用元とchecksを移行し、`cursor_offset`と旧重複計算を消す。RecordやScheduledの保存gateを流用しない。
3. Record・Scheduledを同じ入力表示へ接続し、RecordのColumns＋recursive caretを同時に切り替える。ScheduledのUTF-8文字移動・focus-following・notice予約も同じconsumer群の合格条件にする。全operationを万能form/sessionへ統合しない。
4. list/detailは既存Ui_panelを維持し、Actualのnavigation用`terminal_geometry`とpaint用`panel_geometry`／wide `tx_height`のcapacity整合を実行確認する。source上の不一致候補を未再現のままバグ確定・無条件のscroll方式変更にしない。drill-down/backのcontroller接続も検査する。
5. 共有境界の利用元横断受入が通ってから、Record lifecycle、Actual/Selected Day、Scheduled、残る非予算機能の機能差分へ戻る。

共有API・中央controller・rendererは一人の統合担当が所有する。別画面でも同じfile/APIを同時変更しない。read-only比較は独立に並行できる。予算用hook・ストレージ・runtime採用は含めない。

設計の入口は [TUI README](../tui/README.md) と [UI方針](UI_DIRECTION.ja.md)、作業順は [tasks/todo.md](../tasks/todo.md)、差分とP08は [UI差分台帳](LOAM_UI_GAP_LEDGER.ja.md)、引継ぎは [HANDOFF](HANDOFF.md) へ接続する。全画面対応済みとはしない。

## 受入条件

### 今回の設計資料

製品を変えないのでbuild/self-check/PTYを新しく実行せず、新しいruntime・IME・performanceの成功を主張しない。read/grepで次を照合する。

1. `path=tui`、`pattern=render_rows|cursor_offset|combine_side_by_side|Columns \(|returned_from_detail`で全利用元表・API撤去対象を確認する。
2. `path=tui/daily_interaction.ml`、`pattern=let .*_form|Modal_form|Form\.create`でgeneric form索引を照合する。
3. Jump/Search/Scheduledのsplit geometryを漏らさず、Recordのstyle変更とrecursive cursorを同時に行う順序を読めること。表示機構とpublication責任を混同しないこと。
4. auto-wrap／独自幅表／renderer総刷新を採用済み、Ui_formだけで完了、テスト成功でIME受入済みと解釈する記述がないこと。
5. 上記6文書のMarkdown相対リンクをread-only検査する。コード・fixture・config・exports・build registration・テストは意図的に変更なし。

### 次の製品変更

| 既存検証owner | 具体的な入力・操作 | 必須の観測 |
| --- | --- | --- |
| `daily_interaction_checks.ml`と共有input検査 | 空、exact-fit、1cell超過、80文字ASCII＋日本語、literal `\|`／枠文字、start/middle/end編集、幅0／1 | 保持値不変。paint挿入cellとcursorが同じcontent内。可視cellがなければcursorなし |
| Ui_formとReversalのsession/controller検査 | labelあり／なし、summary、先頭／末尾field、Choice／Buttons、通知なし→短文→長い拒否、高さ超過 | 同じlocal layoutからpaint/caret。短文でorigin・入力・buttonsが不動。長い警告と焦点fieldへ到達可能 |
| controller overlay検査 | Modal_form／Jump／Search／Record floating/full／Scheduled作成／Reversal Date/Preview、親feedbackあり／なし | local→global座標とpaint一致。renderer fit前に子pane内。取消でroute/selection/query/draft保全 |
| `bonsai_daily.ml`既存native image/style検査 | 左Input＋右Active、右Input、nested Columns、CJK境界、3テーマ | 子styleとcaret保持。隣paneへfocus色が漏れずborder intent維持 |
| `scheduled_session_checks.ml`とcontroller | 2行／6行Posting、長Locus/Amount、CJK Left/Right、候補あり／なし、notice・resize | UTF-8境界を維持し編集位置が可視。Record draft非干渉。既存tiny/Preview gate不変 |
| Ui_panel・Actual/Scheduled/browser検査 | PageUp/Down、Home/End、filter/sort、detail scroll、resize、drill-down/back | paintしたcapacityと移動量一致。detail scrollで別identityへ移らない。実controllerの復帰を確認 |

通常80×24／120×36、compact48×14／32×9を全利用元で確認する。既存rendererの8寸法・3テーマは維持し、変更するlayout閾値の直前／直後だけ追加する。実幅はfrontendから渡す`width_of`で検査する。Actual独立self-checkの`String.length`をUnicode cell幅の証拠に使わない。`render_cases`には現在generic Modal_formとScheduled作成が含まれないため、実装時に既存case集合へ両方を追加する。

製品変更時はBakhloディレクトリで以下を実行する。既存隔離環境だけを使い、未準備なら依存をインストールせず前提不足を報告する。

```sh
./tools/check
./tools/build-bonsai-tui
./_build/daily-bonsai/_build/default/ui/bonsai_daily.exe --self-check
```

PTYは既存Expect手法を再利用し、古いscratch scriptのfixture/binaryをそのまま信用しない。新しい合成コピーで全input利用元の長文入力→縮小→編集→拡大→取消を実行し、pane内caret・親背景復帰・台帳bytes不変を確認する。保存確認は専用合成ケースだけで実行しcold readbackする。Recordの全文／末尾gate、Scheduled独立draft、Reversal固定base、stale/unknown停止を保持する。macOS IME/preedit・端末固有幅・P7をこの成功から認定しない。

実装時にsourceが進んでいれば実在する利用元・line hintへ更新し、解消済みgapは既存証拠を引用して移行対象から外す。異なるworkflowはLOCAL列へ残し万能sessionへ押し込まない。runtime未実行ならsource確認としてだけ記録する。
