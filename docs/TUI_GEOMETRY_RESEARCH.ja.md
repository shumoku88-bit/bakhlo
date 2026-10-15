# TUIの幾何・カーソル・描画安定性の調査

調査日: 2026-10-14。**研究記録。UI改修・ライブラリ導入・運用切替の決定ではない。**

## 1. 問いと調査範囲

Bakhloで報告された「画面外へのはみ出し」「カーソル移動に伴う意図しない動き」を、
LOAMの実装と外部TUIの手法から調べる。見た目の装飾ではなく、入力・描画・カーソル・
端末サイズの整合を対象にする。保存／会計の意味、新機能、全画面の互換化は対象外。

証拠を区別する:

- **再現**: 現行Bakhloモジュールを使う合成入力の実行結果。
- **ソース確認**: 実装や既存テストを読んだ結果。実端末上での受入ではない。
- **未検証候補**: ソースから見える懸念。報告症状の原因や実害とはまだ断定しない。
- **提案**: 次の小さな改修／確認案。実装済み・採用済みとは扱わない。

ローカル調査対象:

- Bakhlo `cfed58304f9f58c329f6e36352981fed60a6ec66`。
- LOAM `9155805026b18041a2aea1f21890c8b92af7ddc1`。読取のみ。ビルド・実行・ソース移植なし。
- Bakhloの生成UIソースと対応するtracked UIソースの一致を確認し、既存native binaryの
  `--self-check`が成功。全Coreテストや新しいpaired PTY／目視比較は実行していない。
- 独立したOCaml反例probeをignored `scratch/ui-quality-probe-jar8o1/`へ保存。
  既存の隔離compiler／ライブラリ／生成objectを使い、合成fixtureのみ。
  publicationは呼ばず、合成book作成以外の家計データ書込みはしない。
  このscratchのobjectは現在の生成buildに依存し、永続回帰テストの代わりではない。

後続のActual検索修正でG-2を対処した。32×9と120×36の既存LOAM binaryとの対照、
4寸法の合成回帰の証拠は [検証記録](VERIFICATION.md) の「Actual search paired-runtime slice」を参照。
以下の反例表は調査時点の記録。G-1／G-3／G-4まで修正済みとはしない。


## 2. Bakhloで確認した反例

| ID | 証拠 | 観測 | 所有箇所 |
| --- | --- | --- | --- |
| G-1 | 再現 | 80×24の汎用フォームで長文入力。paneの右端（exclusive）72に対し物理cursor x=79。描画された末尾の`\|`は消えている | `tui/ui_form.ml`の`render_rows`／`cursor_offset`、`daily_interaction.ml`の`resolve_overlay` |
| G-2 | 再現 | Actual検索を32×9で40文字入力するとcursor=(50,1)。端末内にも収まらない | `tui/actual_workspace.ml`の`cursor_position`、controllerの検索header |
| G-3 | 再現 | 入力とaction buttonsを持つ汎用フォームに短いnoticeを入れるとheight=5→6、origin_y=8→7、cursor_y=9→8 | `ui_form.ml`の`render_rows`、`daily_interaction.ml`のフォーム高さ算出 |
| G-4 | ソース確認 | Recordの横並び合成が左右のstyleを一つに潰す。左Input以外はどちらかのActive／Focused_frameを行全体へ適用。既存の`Columns`を使っていない | `tui/record_session.ml`の`combine_side_by_side` |

G-1: `resolve_overlay`が位置情報を集めること自体は有効。しかし文字列をpanel内へclipした後も、
`cursor_offset`は保持値全体の幅を返し、最後の検査はterminal boundsだけ。
「同じ関数で返している」ことと「同じ可視入力geometryから導いている」ことは別。

G-2: controller側headerは行をclipする一方、Actual側cursorはquery全体の幅。
短い検索なら一致するが、長い検索では描画と物理cursorが分離する。

G-3: noticeの有無が行数に直結し、中央配置の原点も変わる。
Recordは空notice行を予約しており、別probeでは短いnotice前後のaction行は21→21だった。
Bakhlo全体に安定化がないのではなく、汎用フォームに行き渡っていない。
長い警告に必要な拡張／スクロールは、短い通知による不要な移動とは分ける。

G-4: 選択／focusの描画範囲が広がる原因候補。実機上の報告症状との対応は未確認。
`Columns`を利用するならcursorの探索も子paneのInputと原点を扱う必要がある。
styleだけ変更して物理cursorを消す修正は不完全。

## 3. LOAMの既存対策と移植できる境界

| 手法 | 狭い所有箇所（`../loam/`） | Bakhloへの意味 |
| --- | --- | --- |
| display columnでclip／pad、固定rectangle、paneごとのstyled cells保持 | `Loam/Tui/Layout.lean`: `framedPanel`／`sideBySide` | 内容長や隣のfocusで枠／style範囲を変えない |
| 本文より先にfooter寸法を確保し、空feedback行を残す | `Layout.lean`: `fitWithFooter`、`Record.lean`: `editingFooter` | G-3へ適用。長い重要警告は隠さない |
| 描画したactive runからcursor位置を導出し、terminal内へ制限 | `RecordSession.lean`: `focusedCursorPosition?`／`placeFocusCursor` | G-1/G-2では可視入力窓とcursorを同じ結果から得る |
| floating rectangleの変更後に親を復元する | `ModalSurface.lean`: `repaintOverParent` | 古い枠や背景の欠けを残さない。Bonsaiでは全体image合成との整合で判断 |
| 出力直前にlive tty寸法を再確認し、stale frameもclip | `Terminal.lean`: `visibleBounds`／`emitDirtyDiff`／`emitDirtyRegion` | layoutだけでなく物理出力の境界を検査する |
| 右端の1列を予約し、auto-wrapを無効化／終了時復元 | `Layout.lean`: `contentWidth`、`Terminal.lean`: `enter`／`leave` | 幅の見積もり不一致で全画面がスクロールしない保険 |
| dirty rowsだけを送る、modalはregion外を消さない | `Runtime.lean`／`Terminal.lean`: `dirtyRegionAnsi` | 領域所有を守る。Bakhloのrenderer作り直しを意味しない |

**注意**: LOAMのcursor導出は現在のRecordでactive styleの終端を拾う方式。
汎用的な正しさの保証や、grapheme／IME実機の完全対応ではない。
Runtimeの定理はWidget／Cellモデルの整合であり、実端末の文字幅／ANSI表示との一致は別。

## 4. Bakhloが既に持つもの

`tui/bonsai_daily.ml`の`fit`は最終imageの幅・高さを制限し、`resolve_overlay`はpane原点を集める。
Bonsaiのaction適用はlive input dimensionsを使う。Recordには可視caretと長文tail、
共有panelにはselection-following windowがある。これらを捨てて第二のscreen engineを作らない。

隔離環境のBonsai_term→Notty_async→Notty-communityもソース確認:

- `bonsai_term/driver.ml`はview描画の後にlifecyclesを起動。
- `notty-community/notty.ml`の`Tmachine.refresh`は前imageとの差分と
  synchronized outputのcapabilityを利用し、描画中のcursorを隠して最後に復元する。
- 調査した起動／終了経路にはLOAMのようなauto-wrap無効化／復元が見当たらない。
  これだけで物理はみ出しを断定せず、実端末と最終列の出力を別途確認する。

「Bakhloは差分描画がない」「Bonsaiそのものが原因」とは結論しない。

## 5. 外部ライブラリ: 実際に参考になる手法

### 5.1 対象版と読み方

2026-10-14に公式GitHub release／tag／sourceを取得。scratchへの資料取得のみで、
Rust／Goのビルド・ベンチマーク・サンプル実行・依存インストールはしていない。
以下は**ソース確認**であり、異なる言語／端末の品質や性能を実測比較した結果ではない。

| 対象 | 固定版／commit | 役割 |
| --- | --- | --- |
| Ratatui | `ratatui-v0.30.2` / `e665c36cb14752a61cd777fbd06dbef8474f2add` | Rustのframe／buffer／widget基盤 |
| gum | `v2.0.2` / `879f048103adf0214b85943b52d8d65b08d772c5` | shell向けのinput／filter／choose等のコマンド。長寿命家計アプリのframeworkではない |
| Bubble Tea | `v2.0.10` / `d5bfd5c2ff7480a6b94536c1cf4e73569b8d523e` | gumのevent／terminal runtime。v1のstandard rendererではなくv2のcursed rendererを確認 |
| Bubbles | `v2.1.1` / `d2b2217d6352ce04183623d66d4266115419733c` | gumのtextinput／viewport |
| Lip Gloss | `v2.0.5` / `5bd778d050f0a5a130e7cf041917927496dbe722` | gumの文字幅・装飾・配置 |

下3つはgumの`go.mod`に指定された版を確認。資料はignored
`scratch/tui-library-research-1J275a/`。採用候補の順位ではなく、手法の参照対象。

### 5.2 Ratatui

**R-1: 文字列でなく、graphemeを載せたcell bufferを境界にする。**

`Buffer::set_stringn`はgrapheme列を走査し、controlを除き、右端までのremaining widthで制限する。
2列以上のsymbolは後続cellをresetする。`diff_iter`も全角→半角／半角→全角の置換で
隠れるcellと残るcellを区別する。`set_style`は指定regionとbufferのintersectionだけを変更する。
G-4には、まず既存Bonsaiのpane styleを保持することで同じ境界を得られる。
新しいOCaml cell rendererを作る理由にはならない。

**R-2: 1 frameでは寸法を一つに固定し、cursorは描画後に置く。**

`Frame::area`はrender callback内で変化せず、resize eventの寸法を混ぜないよう明記。
`Terminal::try_draw`はautoresize→frame作成→render→diff→cursor→buffer swap／flushの順。
`resize`はbufferとdiff baselineを更新し、横縮小ではwrap残像を避けるclearも行う。
Bakhloにも同じdimensions引数とafter-display cursorの土台があり、必要なのはその徹底。
「frame内の一貫性」と「出力前にlive ttyへ再制限」は補完関係で、どちらか一方ではない。

**R-3: 選択によるgeometry変更を明示的に防ぐ。**

`HighlightSpacing::Always`は選択marker用の幅を常時確保する。Listは`ListState.offset`を保持し、
selectedが可視範囲から外れるとき／指定scroll paddingに必要なときだけoffsetを調整する。
Bakhloの`Panel.frame`もmarker幅は保持するが、`window`のselectedあり経路は毎回
selectedからstartを導出し、渡されたscrollを使わない。常に末尾追従する動きが必要か、
普通の上下移動で既存の可視窓を保ちたいかを区別して受入する。全面的なscroll方式変更は未決定。

**R-4: bufferとcursorを別々に検査する。**

`TestBackend`には`assert_buffer`／`assert_buffer_lines`と`assert_cursor_position`がある。
Bakhloも既存Notty image検査＋controllerのcursor検査を使える。
画像が収まる検査を通ってもG-1/G-2が残るため、両方の関係を検査するのが重要。

限界: `Frame::set_cursor_position`は渡された座標を記録するだけで、pane内へ自動clampしない。
bufferを直接indexするcustom widgetもboundsを誤ればpanicしうる。
ライブラリ移行だけでアプリ側geometryミスが消えるわけではない。

一次資料（固定commit）:

- [Buffer: bounded grapheme出力とmulti-width diff](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/buffer/buffer.rs)
- [Frame: frame寸法とcursor](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/terminal/frame.rs)
- [render順序](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/terminal/render.rs)、[resize](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/terminal/resize.rs)
- [List: offset／scroll padding](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-widgets/src/list/rendering.rs)、[marker用の固定余白](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-widgets/src/table/highlight_spacing.rs)
- [TestBackend](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/backend/test.rs)

### 5.3 gumとCharmの基盤

**C-1: 入力欄自身が可視窓・focus・cursorを所有する。**

Gum `input.Update`はWindowSizeMsgでprompt／padding／最終列を引いてtextinput幅を設定する。
Bubbles textinputは保持value、編集位置pos、可視窓offset／offsetRight、focusを分け、
`handleOverflow`で横スクロールし、`View`はその窓を描く。
real cursorを使う場合の`Cursor()`と親pane原点の加算も明示的なAPIになっている。
G-1/G-2へ取り入れるのはこの**入力欄単位のgeometry所有**。保持値の単純な末尾clipと、
全体文字列からの別cursor計算を併存させない。

ただし、調査版のtextinput内部は`[]rune`とRuneWidthも使い、`Cursor()`には位置のwidth clampがある。
Ratatuiと同じ意味で「全編集操作がgrapheme単位」とは言えない。
またgumはvirtual cursorも使う。見た目のcursorがあることはmacOS IME anchorの正しさを証明しない。
Bakhloの日本語入力では実cursorを含む実機確認を省かない。

**C-2: layout寸法は装飾込み、clipは描画上だけにする。**

Lip GlossのWidthはANSIを除いた表示幅、Heightは物理行数を扱い、MaxWidth／MaxHeightは描画を制限する。
gum `filter`はinput／header／help／paddingを引いてviewport寸法を決め、selectionに応じてscrollする。
文字数・byte数・表示列数を混ぜず、border／padding／markerも可視容量へ算入する考え方が有効。
Gumの表示上の切詰めやpaste sanitizerを、家計値の切捨て／黙った修正として移植しない。

**C-3: dirty diffと、画面が途中状態を見せないことは別。**

Bubble Tea v2はsynchronized output（mode 2026）の応答を見て有効化し、rendererは1更新の出力を
まとめて囲む。非対応時は描画中cursorを隠し、最後に復元するbest effort。
変更行だけ送っても、端末がその途中を表示すればちらつく。この境界はLOAMの改善候補。
BakhloのNottyは既にsync start/endを持つため、追加のraw ANSIで二重管理しない。

**C-4: 文字幅方式も端末との契約。**

Bubble Tea v2はUnicode core（mode 2027）の応答に応じてgrapheme width方式へ切り替える。
単に「文字幅libraryを良くすれば全端末で正しい」とは扱わない。
SSH／tmux／fontによる差と、対応しない端末でのfallbackを別に確認する。
このmodeやcapability検出を直ちにBakhloへ追加する判断はしていない。

一次資料（固定commit）:

- [gumの目的](https://github.com/charmbracelet/gum/blob/879f048103adf0214b85943b52d8d65b08d772c5/README.md)、[依存版](https://github.com/charmbracelet/gum/blob/879f048103adf0214b85943b52d8d65b08d772c5/go.mod)
- [input: 可視幅算出](https://github.com/charmbracelet/gum/blob/879f048103adf0214b85943b52d8d65b08d772c5/input/input.go)、[filter: viewport容量／selection](https://github.com/charmbracelet/gum/blob/879f048103adf0214b85943b52d8d65b08d772c5/filter/filter.go)
- [Bubbles textinput: overflow／View／Cursor](https://github.com/charmbracelet/bubbles/blob/d2b2217d6352ce04183623d66d4266115419733c/textinput/textinput.go)
- [Lip Gloss width／height](https://github.com/charmbracelet/lipgloss/blob/5bd778d050f0a5a130e7cf041917927496dbe722/size.go)、[MaxWidth／MaxHeight](https://github.com/charmbracelet/lipgloss/blob/5bd778d050f0a5a130e7cf041917927496dbe722/style.go)
- [Bubble Tea capability応答](https://github.com/charmbracelet/bubbletea/blob/d5bfd5c2ff7480a6b94536c1cf4e73569b8d523e/tea.go)、[描画／cursor／sync／width方式](https://github.com/charmbracelet/bubbletea/blob/d5bfd5c2ff7480a6b94536c1cf4e73569b8d523e/cursed_renderer.go)

## 6. LOAMにも残る穴・未検証境界

LOAM側の追跡: [#1992 — live output origins, grapheme geometry and atomic painting](https://github.com/shumoku88-bit/loam/issues/1992)。
ユーザーの依頼で起票。source確認と実行未検証の区別、検査順序、既存auditとの関係を記載し、
UI実装・依存追加・本番データ変更は行っていない。

### L-1: scalar幅の加算とgrapheme幅は同じではない（ソース確認）

`Layout.charWidth`はcode pointごとの幅を加算し、`Kernel.Cell.glyph`もChar。
例: `👩‍💻`は算術上2+0+2=4列となる。grapheme対応端末で一般に2列のsymbolと一致しない。
`Terminal.backspaceText`は最後のCharを一つ落とすので、複合emojiや結合文字を途中で分ける。
Bakhloの`Daily_form`もUTF-8 code point単位、現行Nottyの幅もscalar hintの加算が土台。

Ratatuiのgrapheme bufferは参考になるが、最初に必要なのは小さな境界検査:
分解濁点（`か`+U+3099）、`e`+U+0301、ZWJ emoji、skin tone、flag、全角↔ASCII置換、
各列端でのclip／cursor／Backspace／左右移動。通常の日本語文字で成功した検査とは分ける。
Bakhloは可視窓の計算だけ改善しても最終Notty imageのwidth方式との不一致が残りうる。
保存文字列をnormalize／変更することは、この表示対策から許可されない。

### L-2: dirty diffだけではframeの見え方はatomicにならない（ソース確認／改善候補）

調査したLOAM Terminalの出力経路にmode 2026のframe囲いはない。
行差分出力と最後のcursor移動が別flushになるため、端末が途中状態を見せる境界が残る。
ちらつきの実害は未測定。BakhloにはNottyのsync囲いが既にあるのでLOAMより欠けるとは言えない。

改善するなら、capability／fallback／例外時にsync解除が残るかを含む限定PTY・実機検査。
全画面再描画や独自rendererへ置換する話ではない。

### L-3: live boundsへのclipと、region原点の安全性は別（ソース上の反例）

`Terminal.visibleBounds`はframe寸法をlive ttyへ縮める。しかし`dirtyRegionAnsi`は
available幅が0になっても`cursorTo row left`を送る。例えばbounds.width=32、left=40のstale modalで
changed row=0なら、contentWidth=31、available=0なのに`ESC[1;41H`という画面外の座標を作る。
これはsource式からの導出で、今回Lean／LOAMを実行して確かめた結果ではない。
また`placeCursor`自体にはlive tty確認がなく、Recordは受け取ったboundsでclampする。

modal右端がresizeで画面外になるrace、描画とcursor配置の間のshrinkを独立に確認する必要がある。
端末が座標をclampする場合でも意図したanchorになるとは限らない。
これは「LOAMはresize対策がない」ではなく、既存対策の最終出力境界に残るseam。
Ratatuiのframe一貫性も、この物理raceを自動的に解決する保証ではない。

## 7. 取り入れる順序（提案、まだ実装しない）

| 順位 | 最小の仕事 | 触る範囲／確認 | 判断 |
| --- | --- | --- | --- |
| 1 | G-1/G-2: 可視入力窓とcursorを同じ結果から計算。long queryもinput領域内へ | `ui_form`／`actual_workspace`／controller＋既存checks | 具体的な反例あり。最初の修正候補 |
| 2 | G-3: 空notice領域を確保し、短いnoticeでorigin／入力／buttonsを動かさない | form paint／overlay geometry＋checks | Recordの既存対策を必要範囲で再利用 |
| 3 | G-4: pane styleとcursor metadataを保つ | Record合成／rendererの既存`Columns`／cursor探索 | 見た目だけでなくInput metadataも同時に確認 |
| 4 | L-3と同種の出力境界: bounds／origin／cursorのlive整合、auto-wrapと終了復元 | 既存runtimeの担当範囲を確認してPTY＋実機 | raw ANSIをBonsaiへ重ねない。LOAMの変更は別途承認 |
| 5 | L-1: grapheme反例で現行rendererの限界を測る | text／caret／imageの小さな検査 | 依存追加やcell model変更は結果を見て別判断 |
| 6 | 通常上下移動でviewportが必要以上に動かないか、frame／cursor出力がちらつかないか | selection offset／sync／IMEの操作受入 | R-3/C-3を参考。無条件の方式変更やperformance claimなし |

保留するもの: Ratatui／gumを製品へ導入する、Rust／Go subprocessやFFI frontendを増やす、
万能form／第二のgeometry engine、fuzzy search／mouse／animation等の新機能、
全Unicode対応や端末capability frameworkを先に作る。今回の反例を直すためには不要。

### 検査する観測

既存のcontroller／session／native image checksへ必要な反例を移す。新しいtest pipelineは不要。

- 通常80×24／120×36、compact48×14／32×9。長いASCII／日本語、入力末尾／左右移動／Tab。
- 物理cursorが**端末内だけでなく入力paneの可視領域内**にある。描画caret cellと一致する。
  入力窓が0列／0行ならcursorを隠し、値とdraftは保つ。
- 通知なし↔短いnotice、候補なし↔あり、selection／focusあり↔なしで枠と予約領域を比較する。
- 操作で変わってよい領域だけを比較対象から除き、背景／隣pane／footerの不用意な変化を検出する。
  正当に連動するdetail／候補更新や、compactでのfocused pane切替は失敗扱いしない。
- 開いたままのresize、floating↔compact、戻ったときの選択／draft／背景復元。
- ANSI出力ではcursor命令だけでなく最終列のglyph出力／wrap、diff baselineの無効化、
  screen／cursor／modeの終了復元も確認する。実端末／IME確認を別に残す。
- preview容量を変えた場合は全文到達／tiny拒否／末尾gateを再検証する。
  表示上のclipを保存値の切捨て、見えない情報の確定許可として使わない。

## 8. 限界・保全

本番データ、LOAMの正データ／設定／source、既存private比較copyは変更していない。
新依存、Rust／Goの導入、UI入口変更、Nottyへの切替、release／pushは行っていない。
合成反例は報告された全症状の再現ではない。実端末・font・IME・SSH/tmux・連続resize、
power-loss／P7、完全な機能互換／人間の受入は未確認。
