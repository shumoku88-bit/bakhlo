# 実績の記帳と訂正の見本

Actualの追加・訂正・日付訂正・返金・店の分類と、Recordフォームから実績を作る規則を、
言語に依存しない入力と答えで書く。すべて合成。期待する帳簿と答えは手書き。
帳簿の規則そのものは `docs/COMMON_FORMAT.ja.md`、金額の入力は `test/amounts/`。

## 帳簿の変更

`cases.tsv` は `test/scheduled/` と同じ4列（見本名、変更前の帳簿、`ok`か拒否コード、説明）。
`<名前>.changes` の変更をまとめて適用する。成功なら `<名前>.after.txt` の全bytesと一致し、
1つでも拒否なら何も変えない。共通runnerは `test/scheduled_tests.ml`。Scheduled側の28件も
同じrunnerで確認する。HIDDENの訂正・返金と予定の支払いの他の境界はそちらの見本も契約。

変更は `PUT-ENTRY NEW|REPLACE <予定ID|->` とTXブロック、
`CORRECT-ENTRY-DATE <実績ID> <日付>`、および次の行（実ファイルはtab区切り）：

```
CLASSIFY-MERCHANT	seed	MERCHANT	sample-cafe
CLASSIFY-MERCHANT	seed	NONMERCHANT
```

TXはbook.txtと同じ。ただし**変更とフォームの入力のEXCHANGEの2欄は元と先のEffectの鍵**で、
保存後のbook.txtでは元と先のMeasureになる。Bookのentryが鍵で両替を指すためで、壊れた鍵も
入力して拒否を問える。メモのescapeは共通形式の見本の持ち分で、ここでは使わない。
CLASSIFY-MERCHANTの店名欄だけは `\t`・`\r`・`\n`・`\\` をdecodeし、制御文字の拒否も問う。

- 新しい実績は末尾へ。同じLocusの複数行も保つ。訂正はIDと位置を保ち、予定のPAID-BYを変えない。
- 返金は正確な逆の実績を別に足す。元は残り、払った予定を開き直さない。両替の逆も同じ。
- 未分類、MERCHANT、NONMERCHANTは別。分類済みの店は現状では変えられない。
- `entry-admission:<理由>` はBook_txtの拒否（`no-effect`、`zero-amount`、`unbalanced`、
  `bad-date`、`bad-token`、`duplicate-key`、`bad-original`、`bad-exchange`、
  `unknown-tx`、`reversal-not-inverse`、`reversal-reused`）または両替の
  `exchange-key`・`exchange-ambiguous`。画面と出版境界は以前のentry-admissionの文言を保つ。
- `exchange-key-taken` は鍵なしの両替の自動鍵が別行にある場合、`entry-not-representable` は
  書いて読んだentryが元と違う場合。どちらも保存しない。
- その他の拒否はBookのコード。店の分類は `merchant-classified`（分類済み、訂正でも変えない）、
  `merchant-unknown`（実績なし）、`merchant-token`（空、または空白・tab・CR・LFを含む店名）。

## Recordの問い

`forms.answers` の1ブロックが1つの問い。先頭は種類・見本名・帳簿などの入力、
`ENDINPUT` までが入力、次が答え、最後が `END<種類>`。全ブロックの文字が一致すれば正しい。
実装は `household/record.ml`、確認は `test/records_tests.ml`。

- `MOVEMENT <名前>`：EFFECTの列。答えは `OK` か `FAULT <コード>`。
  `empty`、`zero:<1始まりの行>`、`measure-differs:<行>:<初めのMeasure>:<違うMeasure>`、
  `unbalanced`。各行ではzeroをMeasure違いより先に、行の問題を合計より先に見る。
- `EDITABLE <名前> <帳簿>`：TXブロック。`OK` または `REFUSED <コード>`。
  `linked-entry`（両替、返金、その元）、`single-measure-movement-required`、
  `measure-scale-not-supplied`。通常の2行はpairとして先に認める。
- `POSTINGS <名前> <帳簿>`：TXのeffectsをフォームに戻す。
  答えは `MEASURE` と `ROW <鍵|-> <Locus> <符号付きdecimal>`、またはREFUSED。
- `PAY-DRAFT <名前> <帳簿> <予定ID>`：まだの予定を同じROWの形へ。
  払い済み・取消済み・不正座標・単一MeasureのMovementでない・scaleなしは拒否。
- `FORM <名前> <帳簿> NEW|EDIT|PAY <対象ID|-> <新ID>`：DAY、MEMO、MEASURE、
  `ROW <鍵|-> <Locus> <符号付き入力>` と任意の `ORIGINAL <Measure> <quanta>`。
  先頭のASCII +/-を方向として読み、残りを正の金額の式として読む。EditはLocusを変えた行だけ
  鍵を落とす。答えは `RESULT NEW|REPLACE <予定ID|->` とTX、または `REFUSED <コード>`。
  Editは新IDを使わず、元のORIGINAL・Merchantを保持する。Payは新しい実績で予定を閉じる。
  日付→行の解析→原額のMeasure→釣合い→Bookの順で検査する。拒否は
  `day-format`、`postings:<行のコード>`、`original-measure`、`movement:<fault>`、
  `admission:<Bookのコード>`。Day.normalizeは実在する日だけを返すので、日付の拒否は `day-format` の1つ。

画面に残るもの：Payで予定日と今日のどちらを初期日として渡すか、最大6行、行の追加・削除、
補完操作、Ctrl-Uのsuspense補助、Original欄の操作（金額はRecordの行と同じく `test/amounts/` のPOSITIVEで読む）、フォーカス・caret・paste・Preview/Publish・
通知文・draft保持・非保存。これらはフォームの操作で、今回のコア抽出の対象ではない。
