# 入力した金額の見本

文字から厳密な最小単位の整数への変換と、その整数の小数表示を、言語に依存しない問いと答えで書く。
すべて合成。答えは手書きで、Bakhloでの確認は `test/amounts_tests.ml`。

`input.answers` の問いはすべて1行（書き方は `test/README.md`）：

```
POSITIVE	0	(500+300)/2	400
SIGNED	2	-1.23	-123
POSITIVE	0	100/3	REFUSED	indivisible-amount
FORMAT	2	-1	-0.01
```

2列目はMeasureのscale（0〜9）。POSITIVE / SIGNED の3列目は入力文字列、最後がquantaか
`REFUSED` とコード。FORMAT の3列目はquanta、4列目は小数表示。空欄は空文字そのもの。
文字列中の `\t`・`\r`・`\n`・`\\` だけはtab・CR・LF・backslashを表す。
桁区切り表示や画面の符号欄はここでは扱わない。

## 決まり

- POSITIVEは正のdecimalか四則演算。乗除が加減より先、同じ優先順位は左から。
  途中は有理数のまま、最終値だけが正で最小単位に収まる必要がある。丸めない。
- literalは書いた小数の桁数も守る。scale 2で `1.000` は拒否、`1.000+0` は100。
- commaは初め1〜3桁、以後ちょうど3桁。全角数字・小数点・comma・演算子・括弧・空白と
  `×` / `÷` は認めた半角表記へ直す。未知の文字は削除しない。
- 式内部の空白はASCII spaceだけ。POSITIVEに単項の符号はない。
- SIGNEDは外側のASCII whitespaceを除いて、ASCIIの先頭符号を読み、その後で全角表記を直す。
  式は扱わず、0も受け入れる。全角の先頭符号は受け付けない。
- FORMATは符号を保ち、scaleと同じ桁数の小数を出す。groupingや丸めはない。
- 整数は機械整数の範囲に制限しない。式の入力は正規化後4096 bytesまで。

拒否コード：`invalid-amount`（文法・grouping・入力長）、`amount-precision`（literalの桁数）、
`non-positive-amount`（POSITIVEの結果が0以下）、`division-by-zero`、`indivisible-amount`
（計算結果が最小単位の整数でない）、`empty-amount`（SIGNEDの空入力）。既存のAmountはすでに
文言でなくこのコードを返すので、画面文言の変更も新しいerror型も必要ない。
