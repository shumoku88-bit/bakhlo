# 報告とActualの合計の見本

Actualの日見出し・期間の合計と、6つの報告（収支・活動・残高と流れ・推移・流動性・多通貨）が
同じ帳簿から何を答えるかを、言語に依存しない問いと答えで書く。表示の文言や金額の桁区切りは
対象外で、数はすべて最小単位の整数（`usd` のscale 2なら `450` は4.50ドル）。中身はすべて合成。
Bakhloでの確認は `test/reports_tests.ml`。

## 1つの見本

`cases.tsv` の1行が1つの見本：`見本名`、帳簿、周期のファイル（なければ `-`、書き方は
`test/periods/`）、説明。`見本名.answers` に問いのブロックを並べる。ブロックは
`<種類>` で始まる行と、問いの入力の行（`TRACK`・`LIABILITY`・`LOCUS`・`POOL`）、答えの行、
`END<種類>` の行でできていて、ブロック全体の文字が一致すれば正しい。答えられないときは
答えの代わりに `REFUSED	<理由>` を書く（理由はBakhloの英語の文言）。

科目の役割は帳簿の `ROLE` の行。役割のない科目は推測せず、「役割なし」として扱う。

## 問いの種類

- `EXPENSE-TOTAL	<始まり>	<終わり（含まない）>`：その間の実績の、EXPENSEの科目の合計を
  Measureごとに `TOTAL` で（0は出さない）。役割のない科目の動きがあれば `PARTIAL`（Actualの `+?`）。
  1日の窓がActualの日見出し、期間の窓が期間バーと期間選択の合計。
- `INCOME-EXPENSE	<始まり>	<終わり>`：帳簿のすべてのMeasureについて `MEASURE`、科目ID順の
  `INCOME`（符号を反転）と `EXPENSE`、`TOTAL-INCOME`・`TOTAL-EXPENSE`、予定を払った実績と
  その返金（取消の実績）のEXPENSE `SCHEDULED` と残り `ORDINARY`、`NET`（収入−支出）。返金は
  予定の分を戻すもので、HistoryのScheduledと同じ決まり。最後に役割のない動きを
  `UNRESOLVED	日付	科目	Measure	金額` で。
- `TRANSACTIONS-FLOW	<始まり>	<終わり>`：触れた（科目, Measure）ごとの
  `ROW	科目	Measure	増	減	差	総量	件数` を総量の大きい順（同じなら科目、Measureの順）に。
  各行の下に動かした実績を `FROM	日付	ID	金額` で記帳順に。
- `STOCK-FLOW	<Measure>	<始まり>	<終わり>`：`TRACK`（と負債の `LIABILITY`）の科目ごとに
  `COORD	科目	根拠	始まり	増	減	差	終わり	今`（分からない値は `?`）。根拠は
  `zero-origin`・`bounded:<日>`・`before-start:<日>`・`opening:<日>`・`opening-on:<日>`・
  `opening-inside:<日>`・`opening-after:<日>`・`observation-undated`。そのあと合計
  （`BALANCE-START`・`BALANCE-END` は分かる値だけの和、`UNKNOWN-STARTS`、`INCREASES`・
  `DECREASES`・`NET`・`CURRENT`）、根拠のない科目 `UNSUPPORTED`、流れから外した開始の記帳
  `EXCLUDED-OPENING`。開始の記帳は残高を決めるもので流れではないので、それを含む窓の `NET` は `?`。
- `TREND	<Measure>	<観察日>	<CYCLE|MONTH|DAY>	<範囲>`：`LOCUS` の科目ごとに、区切りごとの
  `POINT	始まり	終わり	日数	COMPLETE|PARTIAL	合計	値`。周期と月の値は合計÷日数の切り捨て、
  日の値は合計。観察日を含む区切りは `PARTIAL`。範囲（`ALL-HISTORY`・`CURRENT-CYCLE`・
  `CURRENT-MONTH`・`LAST-30-DAYS`）は日ごとのときだけ効き、`SCOPE` 行に実際の範囲を出す。
- `TREND-DEFAULT	<Measure>	<始まり>	<終わり>`：推移を開いたときに選ばれる科目。EXPENSEの科目の
  うち実績の件数が多い3つ（同じなら動いた量の多い順、次に科目の順）。
- `LIQUIDITY	<今日>	<この日まで>`：`POOL	科目	Measure` の今の残高の和 `CURRENT` に、
  その日までのまだの予定を日ごとに足した `POINT	日付	変化	残高`、最後の `FINAL` と一番低い
  `LOW`（今を含む）。今日より前の期限のまだの予定があれば拒否する。
- `MULTICURRENCY	<始まり>	<終わり>`：通貨を換算しない。両替でない実績のEXPENSE `ORDINARY`、
  数えた元の金額 `ORIGINAL`、両替の実績のEXPENSE `EXCHANGE-EXPENSE` を通貨ごとに。両替
  `EXCHANGE`（元と先の動き）とその他の動き `EXCHANGE-EXTRA`、役割のない動き
  `UNRESOLVED-ORDINARY`・`UNRESOLVED-EXCHANGE`、数えなかった元の金額と理由
  `UNRESOLVED-ORIGINAL`・`UNCOUNTED-ORIGINAL`（`unresolved-roles`・`exchange`・
  `no-positive-expense`）。元の金額は、正のEXPENSEがある両替でない実績のときだけ数える。
