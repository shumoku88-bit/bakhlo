# 受理済みの型（Measure / Locus）調査書

**状態: 未着手の研究課題（2026-10-28）。** パイロットは設計の段階で中止し、製品コードは変えていない。
人でも別の AI でも、この文書と参照先だけから再挑戦を始められるように書く。

ラベルの意味:

- **確認済み** — ソースを読んで、または実行して確かめた。
- **仮説** — 未検証の見込み。再挑戦のときに確かめる。
- **推奨** — 次にやるならこの順、という提案。
- **未実行** — まだやっていない。結果を創作しない。

## 1. 目的

型を「もう確かめた」という印にする（parse, don't validate）。通貨（Measure）と科目（Locus）を、
book.txt の受理を通ったときにしか作れない値にして、次の状態を型で表せなくする。

1. 帳簿に無い通貨で `Book.format` / `parse_amount` を呼ぶこと（`format` は今、例外を出す）。
2. 科目と通貨の取り違え。

AGENTS.md の「グルー（つなぎの補助関数）ではなく型で部品を噛み合わせる」「規則の持ち主は一つ」に沿う形でだけ
入れる。型のための変換やテスト用の生成補助が増えるなら、それはこの目的に反する。

## 2. 現在地（2026-10-28、`b78c1f2` 時点）

- **確認済み**: 型付き識別子の層 `lib/` は削除済み（`abcb39e`）。規則が book.txt の受理と重複し、より弱く、型が
  Effect の中にしか効いていなかったため。経緯と計測は
  [検証記録](VERIFICATION.md#the-typed-effect-layer-is-removed-entries-are-booktxt-postings-2026-10-28)。
- **確認済み**: 記帳の行は `Book.posting = Book_txt.posting = { locus : string; measure : string; amount : Z.t;
  key : string option }`、残高の座標は `Book.coordinate = { locus : string; measure : string }`、予定の通貨は
  `plan.measure : string`。
- **確認済み**: `Book_txt` の値（`T.t` と、その中の posting）は手で組み立てられる。受理されるのは、印字した文字列を
  読み直したときだけ（`book_txt/book_txt.mli` の `T.t` の説明「A value built by hand is admitted only by reading its
  printed text back; there is no second admission path」）。生成テスト（`test/book_txt_tests.ml` の
  `Generated`）は任意の `T.t` を組み立てる。`Book_txt.change` の `Put_tx` / `Replace_tx` も手で組んだ TX を受け取る。
- **確認済み**: `Book.format` は帳簿に無い通貨で `Refused "unknown-measure"` を投げる（`household/book.ml` の
  `scale`）。呼び出し元を調べた限り、その経路は今ない。通貨は帳簿の posting・予定・選択中の通貨から来るか、
  外部入力は手前で拒否される。精算ファイルの通貨は帳簿に無いこともあるが、精算画面が `declared` で確かめてから
  表示する（`b78c1f2`）。設定ファイルの座標は `quantity_value` / `daily_pace` が拒否する。
- **確認済み**: 隣り合う文字列（通貨と入力文字列）だった `parse_amount` / `parse_signed_amount` は、通貨をラベル
  `~measure` で渡す（`ff0f7b3`）。`Book` で隣り合う文字列の引数はこれだけだった。
- **確認済み（2026-10-28 の数）**: `B.format` 37 か所、`format_money` 81、金額の解析 19、`B.label` 33、
  `B.measures` 20、`B.approved_loci` 18、本番で posting や予定を作る所 約 96、利用者が通貨を入力する欄 約 24。
  テストは `"jpy"` のような文字列で posting を作る所が数十ある（テストの帳簿は book.txt のテキストから読む）。

## 3. パイロットを止めた理由

- **確認済み**: posting の通貨を「受理済みの型」にすると、次のどちらかが要る。
  1. `T.t` を手で組む経路（生成テスト、`change`）に、確認なしで型を作る口。これで「受理済みでしか作れない」が崩れる。
  2. `Book` の境界での文字列から型への変換。`abcb39e` で取り除いた層の再来になる。
- **仮説**: 2. を選ぶと、読み込みの速さも `abcb39e` 以前に近づく（その変更で `Book.of_txt` は 109,500 件で
  154.5 → 119.1 ms）。
- 結論: 「手で組む値」と「受理済みの帳簿」を型で分ける設計なしには、グルーを足さずには入らない。

## 4. 設計案（すべて仮説・未検証）

- **A. 二層の型**: `Book_txt` で、手で組む値（文字列）と、受理済みの帳簿から取り出す値（`Measure.t` などの
  `private string`）を別の型にする。確かめること: 読み込みで二つの型の間に変換が要るか、要るならその費用と行数。
- **B. 幽霊型**: 同じ表現に状態の型引数を付ける（例: `type 'state posting`、`raw` / `admitted`）。受理関数だけが
  `admitted` を返す。確かめること: 昇格を `Obj.magic` も全件の作り直しもなしに書けるか。書けないなら採らない。
- **C. 尺度を使う関数の入口だけ型にする**: `Book.measure : t -> string -> measure option`、
  `format : t -> measure -> ...`。posting は文字列のまま。表示のたびに引き直すので、グルーになる見込みが高い。
  採らない方向。
- **D. GADT**: [性能・GADT 調査書](PERFORMANCE_AND_GADT_STUDY.ja.md)は GADT を増やす利点が示されていないとしている。
  同じ判断を引き継ぐ。

## 5. 再挑戦の手順（推奨）

1. 製品コードはブランチと worktree で試す（AGENTS.md: 大きな実験は隔離する）。手順の例は `git worktree add` の
   あと、`.tools` / `.opam-root` / `_opam` を本体へのシンボリックリンクにして `./tools/opam` を使う。
2. 先に通貨だけで試す。読みやすく収まると確かめられたら科目に広げる。
3. 次をすべて満たしたときだけ `main` に入れる。
   - 新しいグルー（文字列と型の変換関数、テスト用の生成補助）を足していない。足したなら、その数と理由を示す。
   - `format` / `parse_amount` の帳簿に無い通貨の経路が型で消えている。
   - `./tools/check`、`./tools/tui --self-check`、`./tools/format --check`、一致する CI がすべて通る。
   - cold reload の照合（`test/book_cold_reload_tests.ml`）と適合フィクスチャ（`test/common_format/`）が変わらない。
   - 同じキー操作で、変更前と変更後のバイナリが書く book.txt がバイト単位で同じ（tmux の手順は
     [検証記録](VERIFICATION.md#roles-and-attention-are-typed-book-changes-daily_txt-is-removed-2026-10-28)）。
   - `./tools/startup-probe` の 109,500 件で、`Book.of_txt` と cold load が `abcb39e` 以後の値
     （119.1 ms / 1,026 ms、各 1 回）より遅くない。
4. 中止する条件: 上のどれかを満たせない。または book.txt の形式や LOAM と共有する適合フィクスチャに影響する。

## 6. 制約

- book.txt の形式は変えない（変えるには `../bakhlo-data` の移行についての本人の承認が要る）。
- 受理の仕組みを二つにしない。`Book_txt.change` は、印字したファイル全体を読み直したときと同じものだけを受理する。
- 新しい依存を足さない。家計の実データをこの文書・コミット・テストに入れない。

## 7. 参照

- コミット: `1e8276b`（二重の受理をやめた）、`a74b1de`（entry の行を posting に）、`57d1fdc`（座標）、
  `abcb39e`（`lib/` 削除）、`ff0f7b3`（`~measure` ラベル）、`b78c1f2`（精算画面の金額）、`0b9099b`（パイロット中止の記録）。
- ファイル: `book_txt/book_txt.mli`（`T.t`、`book`、`change`）、`household/book.mli`、`test/book_txt_tests.ml`
  （`Generated`）、`test/book_cold_reload_tests.ml`、`tools/startup-probe`。
