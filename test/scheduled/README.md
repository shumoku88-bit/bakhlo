# 予定と実績化の見本

予定（PLAN）を作る・置き換える・取り消す・実績で払うと帳簿がどうなるか、
そして今日の目安（Daily Pace）がどうなるかを、言語に依存しない入力と答えの組で書く。
どの実装も、この見本を全部通ればBakhloと同じ答えを出す。中身はすべて合成。

`book.txt` の書き方は `docs/COMMON_FORMAT.ja.md` が決める。ここに書くのは、その上に乗る
変更と答えの書き方だけ。Bakhloでの確認は `test/scheduled_tests.ml`。
`test/records/` も同じrunnerで確認する。店の分類と両替の入力はそちらのREADMEを参照。

## 1つの見本

`changes.answers` の `APPLY	<見本名>` のブロックが1つの見本（書き方は `test/README.md`）。
`USE	BOOK` が変更前の帳簿を決める。

- ブロックの入力は変更を順に並べたもの。全部受け入れるか、どれか1つでも拒否なら何も変えない。
- 受け入れたら答えは `AFTER	<見本名>.after.txt`。そのファイルに変更後の `book.txt` を
  1バイトも違わずに書く。続けて、変更後の帳簿で今日の目安を聞く問い（下の `PACE` など）を
  並べてもよい。
- 拒否なら答えは `REFUSED	<コード>`。変更後の帳簿はない。

## 使わなくなった科目（HIDDEN）

HIDDENは新しい記帳の候補に出さないという意味だけを持つ。もともとその科目を含む実績の訂正と、
その返金（REVERSAL-OF）は通す。元の記録になかったHIDDENの科目へ新しくお金を流すことは、
新しい実績・訂正・予定のどれでも拒否する（`*-hidden-locus`）。

## 変更の書き方

TXとPLANのブロックは `book.txt` と同じ書き方をする（`DESC` のメモにエスケープは使わない）。

```
PUT-ENTRY	NEW	phone-2027-01      新しい実績。3つ目が払う予定のID（払わないなら -）
TX	tx-0005	2027-02-01	DESC	phone bill
EFFECT	bank	jpy	-3000
EFFECT	phone	jpy	3000
ENDTX
PUT-ENTRY	REPLACE	-              同じIDの実績を置き換える（訂正）
PUT-PLAN	NEW                    新しい予定。続けてPLANブロック
PUT-PLAN	REPLACE                同じIDの予定を置き換える
CANCEL-PLAN	rent-2027-02	2027-02-01
CORRECT-ENTRY-DATE	tx-0004	2027-01-28
```

（右の説明は実際のファイルには書かない。）

## 今日の目安の書き方

`PACE` の行（Measure・数えた日・終わりの日（その日は含まない））と `POOL` の行（対象の科目）が
問い。続く行が答えで、問いと答えをまとめたブロック全体の文字が一致すれば正しい。

```
PACE	jpy	2027-02-01	2027-03-01
POOL	bank
BALANCE	bank	192000                 対象の科目の今の残高
DEDUCTION	save-2027-02	20000      差し引く予定（帳簿の予定の順）
DEDUCTION	rent-2027-02	80000
AVAILABLE	92000                    残高の合計 − 差し引く予定の合計
DAYS	28
DAILY	3285                       AVAILABLE ÷ DAYS。端数は小さいほうへ（-108000 ÷ 28 = -3858）
ENDPACE
```

答えられないときは、`POOL` の行のあとに `REFUSED	<理由>` だけを書く。

差し引くのは、まだ払っていない・取り消していない予定のうち、終わりの日より前の予定。
期限が過ぎた予定も差し引く。対象の科目からの出金だけを数え、対象の科目どうしの移動や入金は
0とする（`pace-rules`）。

## 過去の日の目安（History）

`PAST` は、過去のある日の終わりの時点の目安を、今の帳簿から計算し直して聞く（その日に
知っていたことの記録ではない）。`PACE` と同じ形で、`BALANCE` の代わりに、その日の終わりの
対象の科目の合計 `RESTATED` を書く。

```
PAST	jpy	2027-01-26	2027-02-01
POOL	bank
RESTATED	275000
DEDUCTION	rent-2027-01	80000      1月27日に払う予定。払う日までは取っておく
DEDUCTION	phone-2027-01	3000
AVAILABLE	192000
DAYS	6
DAILY	32000
ENDPAST
```

今日の目安との違いは、払った予定の扱いだけ。その日の残高にはまだ支払いが入っていないので、
払った予定も**払った日の前日まで**は差し引く。取り消した予定は、取り消した日より前の日でも
差し引かない（今わかっていることで過去を計算し直すため）。その日の残高の根拠がなければ、
その理由（`history-support-missing:<科目>:<Measure>` など）で拒否する（`history-rules`）。

## 日ごとの動き

`ACTIVITY` は、対象の科目が動いた日ごとに、その日の動きを聞く。動いた日だけを日付順に
`ON` で並べ、0でない値だけを次の順に書く。

```
ACTIVITY	jpy
POOL	bank
ON	2027-01-27
SCHEDULED-OUT	80000                予定の支払いで出た分
PROTECTION-RELEASED	80000          その日に払った予定のために取っておいた分
ENDACTIVITY
```

- `DISCRETIONARY-OUT` ／ `DISCRETIONARY-IN`：予定と関係ない出金・入金。
- `SCHEDULED-OUT` ／ `SCHEDULED-IN`：予定を払った実績と、その返金。
- `PROTECTION-RELEASED`：その日に払った予定が、対象の科目から取っておいてもらっていた分。
  別の口座から払っても、予定が払われた日に戻る（`pay-other-amount`）。

1つの実績は対象の科目への差し引きで数えるので、対象の科目どうしの移動は動きにならない。
元の記録と同じ日の返金は、打ち消し合ってどちらも動きに出ない（`reverse-same-day`）。

## 予定の流れ（series.answers）

予定の流れは保存されない。同じMeasureで、払う側（負）と受け取る側（正）のLocusが同じまだの予定を
1つの流れとみなす（金額は問わない）。実装は `household/schedule.ml`、確認は `test/scheduled_tests.ml`。

- `SERIES`（ブロック）：まだの予定を流れに分け、`GROUP	<予定ID>…` を流れの最初の期日順に並べる。
  流れの中は期日・IDの順。
- `SERIES-OF	<予定ID>	<答え>`：その予定の流れの予定ID。払い済み・取消済み・ない予定は
  `REFUSED	source-not-open`。
- `AMOUNT	<金額>`（ブロック）：`PLAN	<予定ID>` を `ENDINPUT` まで並べ、一括の金額変更の結果を
  `PLAN	<予定ID>	<Locus>	<数量>…` で答える。2行の予定は各Locusの符号を保って新しい金額に。
  すでにその金額の予定は除き、全部そうなら `REFUSED	unchanged`。3行以上の予定は配分を推測せず
  `REFUSED	split-plan:<予定ID>`。
- `SLOT	<起点日>	<何か月ごと>	<何回目>	<答え>`：補充の日付。起点の日を保って何か月か後へ。
  その月にその日がなければ日付を決めず `MISSING	<年-月>	<日>`（その日は人が決める）。暦の外は `NONE`。
