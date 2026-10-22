# Bakhlo パフォーマンス最適化・メモリチューニング・GADT活用 調査書

このドキュメントは、Bakhlo（OCaml製家計簿）において **「30年分（~110k entries）の超軽快な動作」** と **「OCamlらしい型安全性・GADTの活用」** を両立させるための技術調査・設計案・引き継ぎ用まとめである。

---

## 1. 背景と現在地

* **日常運用中（2026-10-21 cutover済み）**:
  家計簿正データは `../bakhlo-data` にあり、日々の記帳に使われている。
* **基本方針（AGENTS.mdより）**:
  * **「最適化の前に計測する。形容詞ではなく数字で示す」**
  * **「機構・チェックを足す前に、何を削れるかを考える」**
  * **「正データ（S式・ログ）の保存形式破壊・暗黙マイグレーションは禁止」**
* **目標値と現状の実測値（109.5k entries 規模）**:
  | 項目 | 目標 | 現状の実測値 | 判定 | 備考 |
  |---|---|---|---|---|
  | **Save時間** | ≤ 5 ms (+ durable fsync) | **0.6 ms** (append), 4.1 ms (date/merchant) | ✅ 達成 | `F_FULLFSYNC` ~21ms |
  | **キー応答（一般）** | ≤ 16 ms | **11 ms** (期間ピッカー移動) | ✅ 達成 | |
  | **Actual画面 Down+paint** | ≤ 16 ms | **235 ms** (HANDOFF.md #60) | ❌ **未達** | 466ms→235msまで改善したが依然重い |
  | **期間切り替え** | ≤ 16 ms | **60〜166 ms** | ❌ **未達** | |
  | **起動時間（Startup）** | ≤ 100 ms | **2.2 s** (HANDOFF.md #87) | ❌ **未達** | 現在はユーザー判断で保留中 |

---

## 2. パフォーマンス最適化（CPU / レンダリング / 応答性）

### ① 【最優先】Actual画面の `scan_window` を O(N) から O(log N + K) へ

* **ボトルネックの所在**:
  `tui/screens/actual/actual_workspace.ml`:
  ```ocaml
  let scan_window ~book ~window = List.filter (in_window ~window) (B.entries book)
  ```
  カーソルを1行移動する（Downキー等）たびに、109,500件の全リストを何回もフル走査・フィルタ・ソートしている。
  235ms の大半はここでの CPU 走査および大量の中間リスト確保によるGC負荷。

* **改善設計**:
  1. `Daily_book.t` 内部に **日付順ソート済み配列**（または日付別バケット・B-treeインデックス）を保持する。
  2. `Daily_book.entries_in_range : t -> start_day:string -> end_exclusive:string -> entry list` を追加。
  3. 日付範囲 `[start_day, end_exclusive)` を二分探索（`Array.binary_search`）で特定し、該当範囲の要素のみを取り出す。
  4. **期待効果**:
     走査対象が 109,500件 → 数件〜数十件に激減し、Down+paint が **235ms → 1ms 未満** へ短縮。16ms目標を確実に達成可能。

### ② 中間リストのGCプレッシャー排除（イテレータ / Seq化）

* **現状**:
  `B.entries`（110k件のリスト）から `List.filter` → `filtered_entries` → `groups_of_entries` と多段のリスト生成が行われており、毎フレーム数千〜数万個の cons セルがマイナーGCに流れ込んでいる。
* **改善設計**:
  * ウィンドウ抽出部を `Seq.t` や配列スライス、またはコールバック `iter` 形式にして中間リストのヒープ割り当てを削減する。

### ③ 起動時間の短縮（2.2s → <100ms）

* **ボトルネック**:
  110k行の巨大なS式テキスト全体を `Parsexp.Many.parse_string` でAST（`Sexp.t` の膨大な木構造）に展開し、そこから `Daily_book.admit_payload` 内で `Map.Make(String)`（AVL木）に11万件を順次 `add` している。
* **改善設計**:
  1. **使い捨てスナップショットキャッシュ（Snapshot + Log）**:
     * `tools/startup_probe.ml` にすでに実証コードがある通り、コンパクション時に `book.snap`（Marshalまたは独自バイナリ）を保持。
     * コールド起動時は `book.snap` を即座にロードし、未コンパクションの差分ログ（`Book_log`）のみをリプレイする。
     * これによりコールド起動は数十ミリ秒で完了する。
  2. **専用ストリーミングパーサー**:
     * 汎用 `Parsexp` AST を経由せず、`bakhlo-daily` 構文専用の字句解析器で直接 `entry` レコードを構築する（アロケーションを半減）。

---

## 3. メモリチューニング（省メモリ・GC負荷軽減）

110k エントリ規模（約25万〜30万個の `Effect.t`）におけるヒープ削減。

### ① 重複文字列のインターン化（String Interning / 整数ID化）
* **現状**:
  `lib/identifier.ml`:
  ```ocaml
  module Measure = struct type t = string ... end
  module Locus = struct type t = string ... end
  ```
  すべての Effect で `measure: string`（99%が `"jpy"`）と `locus: string`（"wallet", "food" など高々数十種）が個別の文字列オブジェクトとして大量重複している。
* **改善設計**:
  * 登録された `Locus` / `Measure` を整数ID（またはハッシュコンシング/シンボル）にマッピング。
  * **効果**: 文字列重複による数MB〜十数MBのヒープ削減。さらに比較が `String.equal`（バイト比較）からポインタ等価性（`==`）や整数比較（1クロック）になり、クエリや集計が高速化。

### ② 日付（`day : string`）の Unboxed 即値化
* **現状**:
  各エントリが `"YYYY-MM-DD"`（10バイト文字列 ＝ ヒープ24バイト）を保持。
* **改善設計**:
  * 内部表現を通日（エポックからの日数: `type day = private int`）に変更。
  * **効果**: OCaml の 63-bit 即値（タグ付き整数）として **完全に Unboxed（ヒープ消費ゼロ）** になる。日付比較も `Int.compare` 1命令で完結。

### ③ OCaml GC チューニング
* TUI起動時にマイナーヒープ（デフォルト数十KB〜数MB）を拡大：
  ```ocaml
  Gc.set { (Gc.get ()) with minor_heap_size = 4 * 1024 * 1024 (* 4MB *); space_overhead = 120 }
  ```
  短命な一時オブジェクトがメジャーヒープに昇格するのを防ぎ、マイナーGCで瞬時に回収させる。

---

## 4. OCamlらしい GADT の適用ポイント

### ① `Current_quantity_query.outcome`（Exact vs Known_present の型レベル分離）
* **対象**: `application/current_quantity_query.mli`
  ```ocaml
  (* 現状 *)
  type outcome = Exact of exact | Known_present of present
  ```
* **GADT化案**:
  ```ocaml
  type exact_t
  type present_t

  type _ outcome =
    | Exact : exact -> exact_t outcome
    | Known_present : present -> present_t outcome
  ```
* **効能**:
  残高合算（Sum）や決済処理など、「厳密に確定した値（Exact）のみを受け付ける」関数のシグネチャを型レベルで固定でき、「金額不明な残高を誤って合算してしまう」バグをコンパイル時に完全に排除。

### ② `Book_log.op` とステージ検証（Admission Stages）の連動
* **対象**: `sexp/book_log.mli`, `sexp/daily_book.ml`
  `Put_entry`, `Put_plan`, `Observe`, `Add_locus` などの操作種別を GADT でタグ付け：
  ```ocaml
  type _ op =
    | Put_entry : ... -> [`Entry] op
    | Put_plan : ... -> [`Plan] op
    | Add_locus : ... -> [`Locus] op
  ```
* **効能**:
  「Entryの追加時はLocusステージの検証をスキップできる」というステージ分割の安全性を、型パラメータによって静的に保証。

### ③ `Screen.request` とレスポンス（Effect / Handler）の型安全な結合
* **対象**: `tui/protocol/screen.mli`
  画面側が発行する `Publish` や `Save_config` と、Shellから返される `published` / `saved` の型を GADT で1対1に対応づける。

---

## 5. 明日調査・着手する際の手順とコマンド

### ステップ1: 計測環境の確認
```sh
cd bakhlo
./tools/check                 # ビルド・テスト・アーキテクチャ検査
./tools/tui --self-check      # TUI合成検査
./tools/startup-probe 109500  # 合成データによるプロファイリング実行
```

### ステップ2: Actual画面のボトルネック検証
1. `tui/screens/actual/actual_workspace.ml` の `scan_window` 呼び出し頻度と時間を計測。
2. `Daily_book` に日付インデックス（二分探索）を追加するプロトタイプを作成し、`Down+paint` の時間を比較。
   * 目標: 235ms → 16ms 未満

### ステップ3: メモリ・型安全性の改善
1. `Measure` / `Locus` の intern化、または日付の int 化の検討。
2. `Current_quantity_query.outcome` の GADT化のスコープ確認。

> [!IMPORTANT]
> - `../bakhlo-data` の保存フォーマット（S式・ログ）は変更しないこと。
> - 計測値は形容詞ではなく数字（ms, MiB）で `docs/VERIFICATION.md` に記録すること。
> - リモートへの push は mokoさんの承認があるまで行わないこと。
