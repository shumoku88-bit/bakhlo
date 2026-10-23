# Bakhlo パフォーマンス・メモリ・GADT 調査書

**状態: 調査記録と実装後の現在地（2026-10-23）。** 調査自体は製品コード・保存形式・設定を変更せず、使い捨ての合成実験だけを行った。その後の製品への反映は別の変更として区別する。

- 実装後の証拠: [Actual All の最適化](VERIFICATION.md#actual-all-view-faster-list-moves-2026-10-23)（`7a7dc9e`）。金額列幅の早期終了・キー内の重複解決削減・可視行だけの文字列化は実装済み。
- 実装前の証拠: [Actual の CPU 計測と金額幅の実験](VERIFICATION.md#actual-cpu-baseline-and-bounded-width-experiment-2026-10-23)。測定基準は `edbcc63fb9b06986c6aa7859b5a92d12f7f84de1`、Darwin x86_64、OCaml 5.3.0。生データと測定ソースの識別は同節を参照。
- Core の更新: [entry-map 化の対照計測](VERIFICATION.md#entry-corrections-without-rebuilding-the-entry-list-2026-10-23)。訂正処理単体と、その後の全件リスト化を分ける。
- 初回の保存・読込・メモリ測定: [検証記録](VERIFICATION.md#performance-and-gadt-investigation-2026-10-23)。基準は `624f40a9c18f20a7b539230b6165d5eb68b7d317`。FS キャッシュは排除していない。

ラベルの意味:

- **確認済み** — 今回の probe で観測した、またはソースを読んで確認した。
- **仮説** — メカニズムの推測。未計測。
- **推奨** — 次にやるならこれ、という順序つきの提案。
- **保留** — 今はやらない。再開条件つき。
- **未実行** — 今回やっていない。結果を創作しない。

## 1. 数字の引用ルール

- 今回の保存・読込・メモリ測定と、過去の Actual 計測は区別する。
- [Actual の既存計測](VERIFICATION.md#actual-render-local-reuse-and-empty-query-search-2026-10-21)の **234.804 ms** は 2026-10-21 の履歴値（All Current / two Loci / 空クエリ / 80×24、キー+Notty の CPU 側、9 回中央値）であり、**現行コードの再計測ではない**。
- [期間ピッカーの既存計測](VERIFICATION.md#actual-period-bar-and-picker-2026-10-22)は別 workload（best of 5）。All の履歴値と直接比較しない。
- プロセス全体の projection cache（`2abf471`、warm キー ≤4.1 ms）は、家庭で遅さが感じられていないこと、共有可変状態と古い book の保持を理由に**意図的に撤回済み**。再開条件は「Actual が遅いと感じられたとき」。

## 2. 109,500 件で確認できたこと

目標は保存作業 ≤5 ms + durable flush、キー応答 ≤16 ms、起動 ≤100 ms。結果の数値と統計は[検証記録の表](VERIFICATION.md#performance-and-gadt-investigation-2026-10-23)を参照する。

- **確認済み（実測）**: 初回 baseline では置換・日付訂正が保存作業の目標を超えた。その後の entry-map 化で mutation 単体は短縮したが、最初の `B.entries` に O(N) のリスト再構築が残る。append の full sync、mutation、最初のリスト化、再描画は別の測定境界であり混同しない。
- **確認済み（実測）**: 研究用 snapshot のロードも起動目標を超えた。別プロセスでの読込であり、FS キャッシュを排除したディスク読込や TUI 全体の起動時間ではない。
- **測定限界**: reachable heap は RSS・割当量・GC 停止時間ではない。image と entries はオブジェクトを共有するため加算できず、文字列重複の削減可能量もこの値からは分からない。parse と admission の細かな費用配分は未計測。

**確認済み（ソース）**: `Daily_book.entries` は記録順（古い順）を返す。[`sexp/daily_book.mli:63-67`](../sexp/daily_book.mli) のとおりで、日付順ではない。日付 index を足すなら、この順序前提と保存形式を変えない範囲で別に持つ必要がある。

## 3. Actual 画面 — 実装済みの削減と残る費用

[`tui/screens/actual/actual_workspace.ml`](../tui/screens/actual/actual_workspace.ml) の調査時点の重複処理は `7a7dc9e` で削減済み:

| 対象 | 現在の状態 |
|---|---|
| 金額列幅 | 上限到達で走査を打ち切る。上限に届かない入力では全件走査が残る |
| キー処理 | 1キー内の移動とscroll調整で解決結果を共有。恒久キャッシュは追加しない |
| 行の文字列化・日別合計 | 表示する行だけ生成・集計 |
| 範囲抽出・sort | 全帳簿からの日付窓抽出と、選択された全件のsortが残る |

**確認済み（実装後の計測）**: 合成109,500件の All は probe / plain とも16 ms目標が未達。[実装時の検証記録](VERIFICATION.md#actual-all-view-faster-list-moves-2026-10-23)に対照計測の表と3,540状態の表示同一性比較がある。これらは初回 owner baseline とは別の対照計測であり、単独の金額幅実験の時間を差し引いた推定値ではない。

**日付 index の評価**: 範囲抽出を O(log N + K) にしても、All 表示では K = N となり選択件数は減らない。月などの狭い窓には候補だが、全件 sort まで解決するものではない。**1 ms / 16 ms を確実に達成する根拠はない**。

**次にやるなら**: 残る範囲抽出・sort・通常額の幅走査の寄与を分ける。狭い窓で範囲抽出が支配するなら日付 index を検討し、new / replace / date / merchant / Full / cold / replay で一致させる。記録順・同日内の表示順・保存形式を守り、具体的データ構造・API はまだ決めない。

**保留**: `Seq` 一律化、GC パラメータ調整。どちらも効果**未計測**。

## 4. 起動

**確認済み**: 既存 probe の snapshot は研究用の raw `Marshal` ロードであり、製品キャッシュの実装ではない。今回、起動目標は未達だった。`same balance` の assert は単一残高の比較であり、全意味の一致・キャッシュ失効・差分 log replay の検証ではない。

**仮説**: 使い捨て snapshot + 差分 log replay、または中間 AST を減らす解析方法は候補だが、製品としての費用・安全性は未検証。専用パーサーの割当削減率を保証できる測定はない。

**保留（既存方針の維持）**: 起動最適化は、ユーザーが遅さを感じるまで着手しない。

## 5. メモリ

**確認済み**:

- `Quantity.t` は既に `Z.t`（[`lib/quantity.ml:3`](../lib/quantity.ml)）。unbounded の範囲は維持する。

**未測定**: identifier 文字列の物理的な重複量、共有による削減可能 MiB、比較費用の寄与。通貨の構成比や具体的な削減量は仮定しない。

**推奨（小さい順）**:

1. 文字列のまま book 寿命で共有する案をまず実測する。
2. `==` だけへの置換は、canonicalization 境界の保証がない限りしない。
3. 日付の int 化は内部候補に留める。S式との検証つき変換が残る。
4. `Gc.minor_heap_size` は **words** 単位。`4 * 1024 * 1024` は 64-bit で 32 MiB であり 4 MiB ではない。設定コードの導入は現時点で不要。

## 6. GADT — 既にある適切な使用と、増やさない判断

**確認済み（適切な既存例）**:

- [`tui/shell/screen_registry.ml:49-67`](../tui/shell/screen_registry.ml) の existential `Owner : 'a owner -> owner_ref`。画面ごとに異なる状態型と関数を 1 つにまとめる、GADT の正当な用途。
- [`application/current_quantity_query.mli:49-57,110-119`](../application/current_quantity_query.mli) は `exact` / `present` を abstract にし、`outcome` は通常の variant、`quantity : exact -> Quantity.t` が present の直接利用を既に防いでいる。

**判断**:

- `outcome` の GADT 化は**推奨しない**。速度向上の証拠はなく、動的な query 結果に対する `match` は残る。`present` を直接 `quantity` に渡す誤用は既存の抽象型で防げている。
- `Book_log.op` の op タグ GADT も**推奨しない**。動的帳簿の crossref / witness 不変条件を証明しないし、現状の `apply` 戻り型も共通。
- `Screen.request` の response-index GADT は具体ニーズが**未確認**。**保留**。

原則: GADT は目標ではなく、既存の型で防げない誤用が具体的にあるときだけ足す。

## 7. 次の限定測定

1. **実行済み**: Actual owner の All / Month、key / paint を同じ合成入力・寸法・集計方法で測った。`startup-probe` とは別の使い捨て runner であり、以前の Shell + Notty ベンチとは直接比較しない。
2. **実行済み**: 金額幅の全件 fold と上限での早期終了を比較し、空・長大額・通常額・狭小幅で返る列幅の一致を確認した。その後 `7a7dc9e` で製品に組込み、フレーム同一性も比較済み。
3. **実装済み**: キー内の重複 resolve 削減、日別集計・可視行の文字列化。追加計測では、残る範囲抽出・sort・幅走査の時間と割当量を分ける。
4. **未実行**: 日付 index、identifier 共有、専用パーサー、GC 調整、GADT の試作。必要な費用が残ると測定できたものだけ検討する。

初回調査では家庭の実時間・PTY レイテンシ・保存から再描画までは未測定。その後の実装時には最新データコピーのPTY計測も行った（上記検証記録）。owner baseline は初回リスト化をタイミング外に置いた定常移動であり、保存後の遅延リスト構築とは別である。

## 8. 制約

- 性能調査は合成入力のみ。正データ原本・兄弟 repo・認証ストアにはアクセスしていない。文書の `privacy-scan --all` は非公開コピーを内部で照合するが、家計の本文は出力しない。
- 実装変更・新依存・恒久ベンチは追加しない。データへの権限、開発・Git 手順は [AGENTS.md](../AGENTS.md) に従う。
