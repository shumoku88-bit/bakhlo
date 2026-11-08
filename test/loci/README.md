# 口座の規則の見本

口座に役割を付けられるか、見た残高を保存できるかを、言語に依存しない問いと答えで書く。
すべて合成で、答えは手書き。書き方は `test/README.md`、実装は `household/book.ml`
（`role_refusal`・`observation_refusal`）、確認は `test/loci_tests.ml`。

- `ROLE	<口座>	OK|REFUSED	<コード>`：役割は1回だけ付け、置き換えない（`role-already-set`）。
  未解決の受け皿 `suspense` には付けない（`suspense-no-role`）。役割は集計の見方を分けるだけで、
  記録された事実は変えない。
- `OBSERVE	<口座>	<Measure>	OK|REFUSED	<コード>`：見た残高（銀行アプリや財布で見た額）を保存できるか。
  0から始まる（`ZERO-ORIGIN`）か開始残高の記帳（`OPENING`）から決まる残高には重ねない
  （`balance-from-records`）。その場合は比べるだけで、差は記帳で直す。数えた残高（`ASSERT`）は
  数え直せ、根拠のない残高は見た残高から始められる。
