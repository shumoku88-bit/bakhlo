# Issue #42 TUI 再構築 — 実装指示書（引き継ぎ）

作成: 2026-10-19。ブランチ `reconstruct/issue-42`（main には未マージ）。
前提文書: `AGENTS.md`、`docs/TUI_OWNERSHIP.md`（構造と既知欠陥）、`tasks/todo.md`。

## 0. 目的（変えないこと）

画面ごとに「状態・入力・遷移・描画・viewport・テスト」を所有させ、中央 Shell を
薄い仲介役（ルーティング、グローバルキー、画面間通信、保存調停、競合/不確実性処理、
Record 下書き保持）にする。**新機能・意味変更は禁止。** exact quantity、unknown≠zero、
fail-closed、single writer、atomic publication、Record Preview 全文、狭端末拒否、
下書き保持、annual storage を保つ。LOAM 原本・私的家計データに触れない。
migration/cutover/権限変更なし。新依存なし。Python 禁止（OCaml/shell/Expect）。
P7/IME/人手受け入れを主張しない。

## 1. 現状（2026-10-19 Selected Day owner 移行後）

完了した移行（push/CI の資格は下記と `docs/VERIFICATION.md` を参照）:

| 画面 | 所有者 | 場所 |
|---|---|---|
| Daily Pace | `Daily_pace_screen` | `tui/screens/pace` |
| Balances | `Balances_screen` | `tui/screens/balances` |
| Income&Expense / Transactions Flow / Stock–Flow | `*_screen` | `tui/screens/reports` |
| Attention / Settlements / Loci | `*_screen` | `tui/screens/{attention,settlements,loci}` |
| Observe / Exchange（任意 route 上の editor） | `*_screen` | `tui/screens/{observe,exchange}` |
| Record 系 editor session 8種 | `Record_editors` | `tui/screens/editors` |
| Actual | `Actual_screen`(+`Actual_workspace`) | `tui/screens/actual` |
| Scheduled List/Months | `Scheduled_screen`(+`Scheduled_months`) | `tui/screens/scheduled` |
| Selected Day | `Selected_day_screen` | `tui/screens/day` |
| Calendar/Home + ambient Search | `Calendar_home_screen` | `tui/screens/calendar` |

共通部品: `tui/book/record_browser.ml`（行identity・filter・順序・identity追従選択、純粋）、
`tui/book/record_lines.ml`（Actual/Scheduled 一行表示）。
プロトコル `tui/protocol/screen.mli`: `route` 型、request に `Open_route / Back / Quit /
Set_calendar / Open_observe / New_plan / Record_action{action;target} / New_record /
Drill{day;entry} / Publish / Stop_writes / Save_*` 等、`env.calendar` は Shell の焦点日。

中央に**残っているもの**（`daily_interaction*.ml` 合計1398行、基準 efda2a3 は約4469行）:
- Commands/Themes、discard確認、annual rollover、publication executor、Record保持と画面間調停。
- 年度来歴がactive route上で古くなった場合のUnavailable frameはShellの安全境界として保持。
- `Ui_workspace`はroute/calendar/measureのみ（record-target型aliasも除去、Shellは`Screen.record_target`を使う）。pane/browser/scroll mirrorなし。
- `C.selected`はCalendar ownerのtarget問い合わせだけを行う。c/e等のglobal fallbackはtarget=None。
- 他ownerのIgnored入力から開ける旧Searchと隠れたnavigationはCalendar ownerが保持し、
  ambient検索中のfooterは元routeのものを表示する。無作用化・意味変更はしない。

CI: `gh workflow run tui.yml|core.yml --ref reconstruct/issue-42` で手動起動できる
（branch push では自動起動しない）。`a1885fa` で run 39149879420 (TUI) / 39149881823 (Core)
を実行し、**両方 success**（matching SHA `a1885fa`、PTY 4寸法を含む TUI workflow）。
以降のコミットでも同様に手動起動して SHA 一致の結果を確認すること。
Registry 準備変更 `77bc95f` も Core run 39150877353 / TUI run 39150918791 が
matching SHA で両方 success。Selected Day 移行後のCI資格とは別。

## 2. 検証手順（各スライスで毎回）

```sh
./tools/build-bonsai-tui --test > /tmp/t.log 2>&1; echo rc=$?      # TUI 全チェック
grep -o 'PASS:.*' /tmp/t.log | sort | cmp - tasks/issue42/pass-base.txt && echo SAME-34
./tools/opam exec -- dune build --root . @tools/arch/runtest       # arch_check: ok
./tools/check                                                       # Core
find tui -name '*_checks.ml' -o -name '*fixture.ml' -o -name 'scenarios.ml' | xargs cat \
  | grep -oE '"[a-z][a-z0-9]*(-[a-z0-9]+)+"' | sort > /tmp/l-now.txt
comm -23 tasks/issue42/labels-base.txt /tmp/l-now.txt              # 空であること（ラベル消失なし）
```
- 34 PASS 行が `pass-base.txt` と完全一致、ラベル消失ゼロ、arch ok、Core ok で初めてコミット。
- テストを書き換える時は**条件の強さを保つ**（中央 mirror を読む assert → owner の問い合わせ関数に置換。
  `true` になるだけの assert を残さない。例: 旧 `overlay = No_overlay` は `no_modal` に置換済み）。
- 失敗時は `grep -E -A6 "^File|failed|exception" /tmp/t.log` でまず見る。
- コミット末尾: `Co-Authored-By: ...` の帰属行（使用モデルのもの）。push は branch のみ。
  **main への push/merge はユーザーの明示承認が必要。**

## 3. 次の作業（順番に、1スライス=1コミット）

### 3.1 Registry を route 述語化（完了: `77bc95f`）
`tui/shell/screen_registry.ml`:
- `route : W.route option` → `owns : W.route -> bool`（例 `owns = (( = ) W.Actual)`、editor は `fun _ -> false`）
- `enter : focus_day:string -> 'a -> 'a` → `enter : W.route -> focus_day:string -> 'a -> 'a`
  （既存は `(fun _ -> X.enter)` / `(fun _ ~focus_day:_ t -> t)` で包む）
- `for_route route = List.find_opt (fun (Owner o) -> o.owns route) all`、`enter route` は route を渡す。
- 挙動変化なし → 検証してコミット。

### 3.2 Selected Day（完了 `e190f22`、以下は移植契約の参照）
状態: `{ day; browser : Record_browser.t; pane : List|Detail; scroll; search : string option; parent : string option }`
- `enter (Selected_day d) ~focus_day` → `day=d; pane=List; scroll=0; search=None; parent=None`。
  **browser（query/locus/day/order）は訪問をまたいで保持**（旧 `workspace.selected_day` と同じ）。
- `rows book t = RB.all_rows book |> List.filter (date = t.day) |> RB.visible ~book t.browser`、
  選択は `RB.sync` で identity 追従。`drill ~entry ~parent t` = browser の query/locus/day を空にし
  `selected_id = Some (Actual_row, entry)`、`parent = Some "Actual"`。
- 入力（旧 `daily_interaction.ml` から忠実移植）:
  - Esc/q: Detail→List(scroll 0)、List→`Screen.Back`（Shell の `back` が drill_parent=Actual を処理）
  - g→`Open_route Loci`、b→Batch、d→Correct_date、m→Classify_merchant、c/e/Ctrl-e→Edit、
    x→行が Plan なら Cancel / Entry なら Reverse / なしなら Stay、r/n→`New_record`、/→検索
  - Tab/w/Shift-Tab: pane 反転, scroll 0。i/Enter: Detail, scroll 0
  - j/k: Detail なら `scroll = max 0 (scroll±1)`、List なら選択移動 scroll 0
  - Page/Ctrl-u/d: `step = ±max 1 (snd geometry.screen - 8)`、List→選択移動、Detail→scroll+=step
  - Home: scroll 0 + 先頭選択（Detail でも）。End: scroll `max_int/4` + 末尾選択
  - それ以外は `Ignored`（Space→Commands 等は Shell）
  - 検索 overlay は Scheduled と同じ（title "Search Actual / Scheduled", notice "Enter apply; Esc clear",
    pane_width `min 54 (max 8 (body_w-4))`）。共通化するなら `Record_browser.search_form` に。
- 描画: `Ui_panel.split`、左 title `Printf.sprintf "Day %s (%d)" day n`、左行
  `snd (Record_lines.actual_table ~width_of ~width:left_width book rows)`（空なら "No records in this view."）、
  右 title "Selected Record"、右行 entry_lines/plan_lines を `width-6` で wrap（`O.wrap_text`）。
  header title `tr "Selected Day"`、subtitle `Screen.Text (day ^ "   " ^ tr "Day" ^ tr " view")`。
  footer List: `"j/k select  Enter/i/Tab Detail  c Correct  d Date  x Reverse  m Merchant  e Extend  b Batch  g Loci  r Record"` +
  parent ありなら `"Space Commands  q/Esc Actual  Ctrl-r reload"` なしなら `"Space Commands  q/Esc Home  Ctrl-r reload"`。
  footer Detail: `["j/k scroll  Page Up/Down page  Home/End range"; "q/Esc back  Space Commands  Ctrl-r reload"]`。
- `book_changed ~after` = synced + scroll 0（旧 finish_publication の sync と同じ）。`reloaded` = scroll 0。
- Shell: `Screen.Drill` 処理を `open_route` 後に `Selected_day_screen.drill` を呼ぶ形へ。
  `C.selected` から Selected Day を外し、中央の Selected Day 用 arm（g/b/d/m と view の分岐・footer）を削除。
  `Ui_workspace.selected_day` を削除。
- テスト修正: `scenarios/actual_integration_checks.ml` の
  `workspace.selected_day`（137行付近で stale filter を注入している箇所は `with_browser` 相当の
  check 用関数を mli に用意）、`W.rows ... moved.workspace = []`、`C.selected direct`、
  render fixture の `detail (W.Selected_day ...)`（owner の `i` キーで detail を開く）。
  `interaction_check_fixture.ml` に `day_rows / day_id / day_detail ...` を追加し、
  `selected_target` に Selected_day 分岐を追加。

### 3.3 Calendar/Home（完了 `7d54c6a`、CI Core 39152231758 / TUI 39152237812 success。以下は維持する契約）
- 焦点日/zoom は Shell 所有の `env.calendar`。画面は `Set_calendar` request で変更を依頼
  （`update_calendar` の `Refused`→message、`Open_day`→`Open_route (Selected_day d)`）。
- Calendar の描画（`calendar_rows`, `calendar_frame`, `detail_frame`, 120列/72列分岐、
  `Calendar_dates` スタイル置換）と `home_rows`、Detail の選択（`W.detail` browser）を画面へ移す。
- Calendar の Esc: Detail→List、zoom≠Day なら zoom を1段戻す（Year→Month→Day）、それ以外 Home。
  t=Today、z=Cycle_zoom、/=Jump overlay（Jump も画面所有へ）、h/l/j/k=Cal 移動、Enter=Drill/Selected Day。
  a/s/b/d/i/o の画面遷移は `Open_route` / `Open_observe`。
- Home: Esc/q→`Quit`、g/Enter→Calendar、a/s/b/d/i/o 同上、footer の Attention badge。
- 注意: Page/Home/End の中央ロジック（`snd dimensions - 8` ステップ等）は Home/Calendar にも
  効いている。移植時に route 条件を正確に再現すること。
- `Ui_workspace`はroute/calendar/measureに縮小済み。新規ownerの純粋checksと既存scenarioの
  assertionを維持し、34 PASS一致・ラベル消失なし・arch/Coreを確認。
- Homeの`/`はJumpでなくSearch。queryは後のCalendarへ保持する。
- Escだけzoomを戻しmessageを保持、qはzoomを保持してHome。普通の移動はblocked以外のmessageを消す。
- 他routeへのentryでshared browser選択は空rowsにsync、Selected Dayではbrowserを保持。
  Actualへのdrill returnはentry通知のみでsyncしない。publication/reloadは旧route境界の同期を維持。
- annual.noticeはlazyでHome paintだけがforce。Homeはheaderなしのbody全高を描く。

### 3.4 Shell 仕上げ（一部完了 `59a7d10`、CI Core 39182025928 / TUI 39182023522 success）
完了:
- Shell の record action 対象を `Screen.record_target`（Entry/Plan）に統一。`Ui_workspace` の
  row/family alias、`*_selected` ラッパー、未使用 helper（`browser_pane_widths`, `print_motion` 等）を削除。
- Actual / Scheduled session の純粋 checks を `tui/screens/actual/test`・`tui/screens/editors/test`
  へ移動（app runner が native 幅関数を渡す）。Actual fixture の ID は store 非依存の決定的 ID
  （重複時は `put_entry ~replace:false` が失敗するので弱くならない）。
- arch rule 5: Shell は `Record_browser` を直接/別名経由で使えない。負例 2 件 + コメント/文字列の正例を `test/arch.t` に追加。

残り:
- `daily_interaction{,_state,_context,_view}.ml` を Shell の責務（routing, global keys, Commands/Themes,
  discard 確認, annual rollover, publication executor, Record 保持, 年度来歴 Unavailable frame）
  ごとに整理し、名前も実態に合わせる（例 `shell.ml`, `shell_publication.ml`）。**挙動は変えない**。
- `docs/TUI_OWNERSHIP.md` の最終化（Enforcement 節に rule 5、Tests 節にテスト配置）。
- 計測: 中央行数の推移（4469 → 1398）、代表ビルド時間の before/after（efda2a3 と現 HEAD、同一マシン）。
- 各コミットで CI を matching SHA で手動起動し成功確認（PTY 4寸法は TUI workflow 内）。
- Issue #28/#38/#39/#40/#41/#42 は重複 issue を作らず #42 にコメントで集約。
- main への統合はユーザー承認後（AGENTS.md は main 直コミット方針だが、本件は大規模な隔離作業）。

## 4. 既知の欠陥・挙動変化（記録済み、意図的に未修正）
`docs/TUI_OWNERSHIP.md` 参照。要点: accounting-roles 読取で unreadable が空 roles になる、
Settlements/Loci の Esc が常に Home・Page/Home/End が先頭リセット、print preview が Done で閉じない、
finish_publication が保持中 Record 下書きを消す、owner editor は Ctrl-R 以外全入力を取る
（Balances picker で Ctrl-Q/N 不可）、IncExp の j/k が Calendar 選択を動かさない。
Scheduled の `/` 検索中の Ctrl-R: owner editor 扱い（`reload_in_modal = true`）で
reload される。旧中央 Search overlay は Ctrl-R を消費していた（Selected Day / Calendar は旧挙動を維持）。
意図した変更ではないので、揃えるなら Scheduled の検索を `reload_in_modal = false` 相当にし回帰を追加。
新たに見つけたら同ファイルへ追記（修正は別スライス、意味変更ならユーザーに確認）。

## 5. はまりどころ
- TUI は別 dune project（`tui/dune-project` は build-bonsai-tui が生成、`implicit_transitive_deps false`）。
  新しい screen library は `tui/shell/dune`・`tui/scenarios/dune`・`tui/shell/test/dune` に追加。
- テスト fixture は `scratch/examples/daily-book.sexp` に実体コピーされる（sandbox の symlink は writer が拒否）。
- 中央 `sync` は scroll を 0 にする。owner へ移す時、v/f/検索/publication 後の scroll リセットを忘れない。
- Shell の reload は route owner の `reloaded` も呼ぶ（Scheduled で導入）。
- `Ignored` を返すと owner の状態更新は捨てられる。状態を変えるなら `Stay` を返す。
- perl で一括置換する時は区切りに `#` を使う（`|` はエスケープ事故が起きた）。置換数を必ず出力して確認。
