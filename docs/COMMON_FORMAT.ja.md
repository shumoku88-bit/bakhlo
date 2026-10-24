# 共通形式（草案 v0）

BakhloとLOAMが同じ正データを読み書きするための形式。v0の項目は2026-10-24にすべて決めた
（末尾の「決めたこと」）。Bakhloには読み書きの部品 `book_txt/` がある（2026-10-25、見本58件と
ランダムな帳簿1万件で確認）。**家計簿はまだこの形式で保存していない**（移行は段階4）。
LOAMにはまだ実装がない。

2026-10-24 決定：BakhloとLOAMで正データを共有する方向で、S式からこの形式へ移る。
LOAMの検証資産を生かしながら、両方を改善していく。
例はすべて合成で、実際の家計簿の値ではない。

## 原則

**現実を観測した事実は厳密に。自分で付けた分類は自由に。**（2026-10-24 決定）

| 種類 | 例 | 扱い |
|---|---|---|
| 現実の観測 | 記帳の金額と日付、数えた残高、「この日から記録が揃っている」 | LOAMの厳密さを残す。逆算した値で置き換えない |
| 自分の分類 | 役割、表示名、Merchant、HIDDEN、メモ | 自由に書き換えてよい。前の値はGitに残る |

1. **今の状態だけを持つ。** 訂正の途中経過・取り消した予定・役割の変更前などは
   Gitの履歴に任せ、ファイルには入れない。
2. **1行に1つの事実。** タブ区切りで、行の先頭の語を見れば種類が分かる。
3. **書くのは一度に片方だけ。** 同時に両方から記帳しない。どちらが書く番かは運用で決め、
   形式には入れない。
4. **読めない行があったら全体を拒否する。** 黙って読み飛ばしたり、空の家計簿として扱ったりしない。
5. **金額は最小単位の整数で、必ずMeasure（通貨）を付ける。** 円なら1円単位、ドルなら1セント単位。
   違うMeasure同士を足さない。

## ファイル全体

- 文字コードはUTF-8、改行はLF、最後の行も改行で終える。
- ファイル名は `book.txt`、1行目は `BOOK	1`（形式名と版）。形式は拡張子ではなく1行目で見分ける。
- 最後の行は `END`。これがなければ途中で切れたファイルとみなして拒否する。
  （LOAMの `SECTION 名前 バイト数` の代わり。手で直してもバイト数を数え直さなくてよい）
- 空行もコメント行も書かない（あれば拒否する）。受け入れるファイルの書き方を1通りにして、
  「読んで書き直すとバイト単位で元と同じ」にするため（下の「書き出しの決まり」）。
- 欄の中のテキスト（メモなど）は、LOAMと同じく `\\` `\n` `\r` `\t` でエスケープする。
- 日付は `YYYY-MM-DD` で、実在する日付。IDは空でなく、空白・タブ・改行を含まない文字列。

並び順は固定する（差分が見やすく、Gitの履歴が読みやすい）：

```
BOOK → MEASURE → LOCUS → ROLE → TX → PLAN → 残高の根拠 → ATTENTION → END
```

## 行の種類

### Measure（通貨・単位）

```
MEASURE	jpy	0
MEASURE	usd	2
```

2列目がID、3列目が小数点以下の桁数（scale、0〜9）。一度使った桁数は変えない（K1）。

### Locus（口座・科目）

```
LOCUS	food	食費	毎日の食事
LOCUS	wallet	財布	手元の現金
```

ID・表示名・説明の3つ。表示名と説明はこの行だけに置く（2026-10-24 決定）。
今の `config/locus-catalog.tsv` とBakhloの `labels` の中身をここへ移し、別のファイルには持たない。

使わなくなった科目には、行の最後に `HIDDEN` を付ける（2026-10-24 決定）。

```
LOCUS	old-phone	旧スマホ代	解約した回線	HIDDEN
```

`HIDDEN` は**新しい記帳の入力候補に出さない**という意味だけを持つ。過去の記帳の訂正・返金・
日付の変更は拒否しない（今のapproved-lociは、外れた科目を含む記帳のメモの訂正まで拒否していた）。

### Role（会計上の役割）

```
ROLE	food	EXPENSE
ROLE	wallet	ASSET
```

役割は `ASSET` `LIABILITY` `EQUITY` `INCOME` `EXPENSE` のどれか。
**後から変えてよい**（この行を書き換えるだけ。前の役割はGitに残る）。
今の `config/accounting-roles.tsv` の中身をここへ移す。

### TX（記帳1件）

LOAMの見た目をそのまま残す。

```
TX	tx-0001	2027-01-05	DESC	コンビニ
EFFECT	coffee	jpy	150
EFFECT	bread	jpy	200
EFFECT	wallet	jpy	-350
ENDTX
```

- `TX` の行：ID、日付、`DESC`（メモ。なければ `DESC` 以降を書かない）。
- `EFFECT` の行：科目、Measure、符号付きの金額、省略できる鍵。1件に1行以上。鍵は、その記帳の中でこの金額を指すID（立替の対応や両替がこの金額を指すときに使う。2026-10-25 追加）。同じ記帳の中で重複しない。
- 同じMeasureの `EFFECT` は合計がゼロになる（両替の記帳と、両替を取り消す記帳だけは例外）。
- **TXは記録した順に並べる。日付順ではない。** 訂正しても並びの位置は変えない。
  （残高の根拠のANCHORが「どこまで記録してあったか」をこの並びで表すため）
- 必要なときだけ、`ENDTX` の前に次の行を足す：

| 行 | 意味 | 例 |
|---|---|---|
| `REVERSAL-OF	<TX ID>` | 返金・取り消し。元の記帳は残す | `REVERSAL-OF	tx-0001` |
| `ORIGINAL	<Measure>	<金額>` | 外貨の元の金額（正の数） | `ORIGINAL	usd	2000` |
| `MERCHANT	<店>` / `NONMERCHANT` | 支払先の分類。後から変えてよい | `MERCHANT	some-store` |
| `EXCHANGE	<元Measure>	<先Measure>` | 両替（下を参照） | `EXCHANGE	jpy	usd` |

**訂正は同じIDのTXを書き換えるだけ。** LOAMの `REPLACES` と `DATE-REV` は持たない。

#### 両替（2026-10-24 決定）

```
TX	tx-0002	2027-03-01	DESC	空港で両替
EFFECT	bank	jpy	-16000
EFFECT	cash-usd	usd	10000
EXCHANGE	jpy	usd
ENDTX
```

- `EXCHANGE` がある記帳だけは、2つのMeasureの合計がゼロでなくてよい（元はマイナス、先はプラス）。
  ほかのMeasureは今までどおり合計ゼロ。
- 手数料は `EFFECT	fee	jpy	300` を足し、`bank` を `-16300` にすれば表せる。
- レートは計算で出せるので保存しない。

### PLAN（支払い予定）

```
PLAN	plan-0001	2027-01-25	jpy
CHANGE	bank	-3000
CHANGE	phone	3000
PAID-BY	tx-0003
ENDPLAN
```

- `PLAN` の行：ID、予定日、Measure。
- `CHANGE` の行：科目と符号付きの金額。
- 終わり方は `PAID-BY	<TX ID>`（支払った）か `CANCELLED	<日付>`（やめた）のどちらか。
  両方は書けない。どちらもなければ、まだ支払っていない予定。

### 残高の根拠

「残高が不明」と「残高がゼロ」を区別するための行。Bakhloの `support` と
LOAMの ZeroOrigin〜BoundedHistorySupport に当たる。

```
ZERO-ORIGIN	wallet	jpy
OPENING	loan-a	jpy	tx-0004
HISTORY-FROM	savings	jpy	2027-01-01
```

| 行 | 意味 |
|---|---|
| `ZERO-ORIGIN` | この科目は記録の始まりで0だった |
| `OPENING` | この科目の開始残高は、この記帳に書いてある |
| `HISTORY-FROM` | この日以降の動きは全部記帳してある（それより前は不明） |

#### ANCHOR（数えて確かめた残高）

```
ANCHOR	tx-0120
ASSERT	wallet	jpy	1200
ASSERT	savings	jpy	5000
ENDANCHOR
```

意味：**ファイルの先頭から `tx-0120` までに記録してある記帳は、すべてこの確かめた額に
含まれている。** 今の残高は「確かめた額 ＋ `tx-0120` より後に記録した記帳」で計算する。

記帳がまだ1件もないうちに数えたとき（家計簿を始めた日に財布を数えた、など）は `ANCHOR	-` と書く。
すべての記帳が「数えた後」になる（2026-10-25 追加）。だから記帳のIDに `-` は使えない。

- LOAMは同じことを、含まれる記帳のIDを全部並べて持っている（`ROOT` 行）。
  2026-10-24に実データで確かめたところ、既存のANCHORはすべて「記録した順で先頭から
  ある件まで」の連続した範囲だった。なので、最後の1件のIDだけで同じ意味を表せる。
  数えるときには、それまでに記録した記帳が全部含まれるので、これからもこの形になる。
- 日付ではなく記録の並びで区切る。日付で区切ると、数えた日の数える前と後の記帳を
  区別できない。
- 含まれている記帳を後で訂正しても、今の残高は変わらない（数えた事実が優先）。
  変わるのは、それより前の時点の残高の計算だけ。LOAMと同じ性質。
- この表し方がLOAMのIDの一覧と同じ意味になるには、次の3つを守る：
  1. 新しい記帳は必ずTXの並びの末尾に足す（途中に差し込まない）
  2. 訂正しても、そのTXの位置は動かさない
  3. ANCHORが指す記帳そのものを入力ミスとして消すときは、指す先を、その前にある記帳に移す

2026-10-24、LOAMのAlloyモデル（`loam/experiments/386_recorded_prefix_anchor_cut.als`、
Observation 386）で確かめた。上の3つを守れば、

- 数えた直後の「ある件まで」は、LOAMのIDの一覧とちょうど同じ範囲になり、残高も同じになる
- 含まれている記帳の訂正・削除、指す先の付け替えでは、今の残高は変わらない
- ALSOがないと、後から見つけたレシートは二重に引かれる（LOAMの今の仕組みも同じ）。
  ALSOで現実の残高に戻る
- 記録済みだが数えた額にはまだ入っていなかった記帳（銀行の処理待ちなど）は、ALSOでは
  表せない。その場合は `EXCEPT` が要る

記帳4件・5ビット整数の範囲で調べ、5件・6ビットに広げても同じ結果だった。ALSOを無視するように
モデルをわざと壊すと、「ALSOで現実の残高に戻る」の検査が反例を出して失敗する。

例外の行 `ALSO	<TX ID>`（v0に入れる。2026-10-24 決定）：

```
ANCHOR	tx-0120
ALSO	tx-0125
ASSERT	wallet	jpy	1200
ENDANCHOR
```

数えた後で、数える前のレシートを見つけて記帳した（`tx-0125`）。お金は数えた時点でもう
出ていたので、確かめた額に含まれている。`ALSO` がないと、その分を二重に引いてしまう。
LOAMの今の仕組みにも同じ穴があり（IDの一覧に後から足す方法がない）、2026-10-24の
実データ確認では該当する記帳はまだなかった。

逆向きの例外（記録はしてあったが、数えた時点ではまだ口座に反映されていなかった。銀行の
処理待ちなど）を表す `EXCEPT` は、実際に必要になるまで入れない。

数えて合わなかったときは、差額の記帳を作らず、ANCHORを付け直す。差額の記帳は、いつ・何に
使ったか分からないお金を特定の日と科目に押し付けてしまう（下の「引き継ぐ決まり」のK6）。

### ATTENTION（気にかけておくこと）

今の `attention.loam` と同じ形式。

```
ITEM	attention-1	DUE_ON	2027-02-28	check-the-bill
ITEM	attention-2	NO_DUE_DATE	-	ask-about-the-fee
CLOSE	attention-1	2027-02-20	RESOLVED
```

- `ITEM` の行：ID、期限の種類（`DUE_ON`・`NO_DUE_DATE`・`DUE_UNDETERMINED`）、期限の日付
  （`DUE_ON` のときだけ日付、ほかは `-`）、内容（エスケープしたテキスト、空でない）。
- `CLOSE` の行：閉じる `ITEM` のID、閉じた日、`RESOLVED`（片付いた）か `DROPPED`（やめた）。
  1つの `ITEM` を閉じられるのは1回だけ。

## 書き出しの決まり

受け入れるファイルは1通りの書き方しかないようにする。だから、どちらの実装でも
**読んで書き直すと、バイト単位で元のファイルと同じになる**（K13）。

- 節の順：`BOOK` → `MEASURE` → `LOCUS` → `ROLE` → `TX` → `PLAN` → 残高の根拠 → `ATTENTION` → `END`。
  残高の根拠の中は `ZERO-ORIGIN` → `OPENING` → `HISTORY-FROM` → `ANCHOR`。
  `ATTENTION` の中は `ITEM` → `CLOSE`。
- 同じ節の中の並びは、読んだ順のまま書く。新しく足すものは、その節の末尾に足す。
- `TX` の中：`EFFECT` の行（読んだ順）→ `REVERSAL-OF` → `ORIGINAL` → `MERCHANT` か `NONMERCHANT` →
  `EXCHANGE`。どれも1回まで。
- `PLAN` の中：`CHANGE` の行（読んだ順）→ `PAID-BY` か `CANCELLED`。
- `ANCHOR` の中：`ALSO` の行 → `ASSERT` の行。
- 整数は10進で、`+` を付けず、先頭に余分な `0` を付けない（`0` そのものはよい）。`-0` は書かない。
- メモが無い記帳は `DESC` 以降を書かない。空のメモ（`DESC` の後が空）は書かない。
- `LOCUS` の説明は空でもよい（行は `LOCUS	<ID>	<表示名>	` のようにタブで終わる）。表示名は空にしない。

## 読むときに拒否すること

次のどれかに当たったら、ファイル全体を拒否する（原則4）。実装は、下の**理由のコード**と、
問題に気づいた**行番号**を返す。行番号は1から数える。どの行かは表の「行」の欄のとおり。
同じ理由に当たる行がいくつかあるときは、いちばん前の行を返す。

### ファイル全体と行の形

| コード | 拒否すること | 行 |
|---|---|---|
| `not-utf8` | UTF-8として読めない | 読めない文字のある行 |
| `crlf` | 行の終わりが `\r\n` | その行 |
| `no-final-newline` | 最後の行が改行で終わっていない | 最後の行 |
| `bad-header` | 1行目が `BOOK	1` でない | 1 |
| `missing-end` | `END` の行がない | 最後の行 |
| `after-end` | `END` の後に何かある | `END` の次の行 |
| `blank-line` | 空行がある | その行 |
| `unknown-line` | 知らない種類の行、欄の数が違う、`TX` などの外に出てはいけない行が外にある | その行 |
| `section-order` | 節の順や、`TX`・`PLAN`・`ANCHOR` の中の行の順が違う | 順が崩れた行 |
| `unclosed-block` | `TX` が `ENDTX` で、`PLAN` が `ENDPLAN` で、`ANCHOR` が `ENDANCHOR` で閉じていない | 閉じていない塊の最初の行 |
| `bad-token` | IDなどが空、または空白・タブを含む。`TX` のIDが `-` | その行 |
| `bad-escape` | テキストのエスケープが `\\` `\n` `\r` `\t` 以外、または `\` で終わる | その行 |
| `empty-text` | 空であってはいけないテキストが空（`DESC` の後、表示名、ATTENTIONの内容） | その行 |
| `bad-date` | 日付が `YYYY-MM-DD` でない、または実在しない | その行 |
| `bad-integer` | 整数の書き方が上の決まりと違う | その行 |

### 定義と参照

| コード | 拒否すること | 行 |
|---|---|---|
| `duplicate-measure` | 同じMeasureが2回 | 2回目 |
| `duplicate-locus` | 同じ科目が2回 | 2回目 |
| `duplicate-role` | 同じ科目の `ROLE` が2回 | 2回目 |
| `duplicate-tx` | 同じIDの `TX` が2回 | 2回目の `TX` |
| `duplicate-plan` | 同じIDの `PLAN` が2回 | 2回目の `PLAN` |
| `duplicate-item` | 同じIDの `ITEM` が2回 | 2回目 |
| `unknown-measure` | 宣言していないMeasureを使っている | 使っている行 |
| `unknown-locus` | `LOCUS` の行がない科目を使っている（`ROLE`・`EFFECT`・`CHANGE`・残高の根拠） | 使っている行 |
| `unknown-tx` | 存在しない記帳を指している（`REVERSAL-OF`・`PAID-BY`・`OPENING`・`ANCHOR`・`ALSO`） | 指している行 |
| `unknown-item` | 存在しない `ITEM` を閉じている | `CLOSE` の行 |
| `bad-role` | 役割が5つのどれでもない | その行 |
| `suspense-role` | 仮置きの科目 `suspense` に役割を付けている（K10） | その行 |
| `bad-scale` | Measureの桁数が0〜9の整数でない | その行 |
| `bad-hidden` | `LOCUS` の5つ目の欄が `HIDDEN` でない | その行 |

仮置きの科目のIDは `suspense` と決めておく。使うときは、ほかの科目と同じく `LOCUS` の行を書く。

### 記帳（TX）

| コード | 拒否すること | 行 |
|---|---|---|
| `zero-amount` | `EFFECT` の金額が0（K2） | その行 |
| `duplicate-key` | 同じ記帳の中で、同じ鍵が2回 | 2回目の `EFFECT` |
| `no-effect` | `EFFECT` が1行もない | `TX` |
| `unbalanced` | `EXCHANGE` も `REVERSAL-OF` もない記帳で、どれかのMeasureの合計が0でない（取り消しの記帳は元の記帳をちょうど逆にしたものなので、両替の取り消しは合計が0にならない） | `TX` |
| `bad-exchange` | `EXCHANGE` の2つのMeasureが同じ、元の合計がマイナスでない、先の合計がプラスでない、またはほかのMeasureの合計が0でない | `EXCHANGE` |
| `reversal-not-inverse` | `REVERSAL-OF` の記帳が、元の記帳の `EFFECT` をちょうど逆にしたもの（科目・Measure・金額・行の数がすべて合う。並びは問わない）でない（K11） | `REVERSAL-OF` |
| `reversal-reused` | 同じ記帳が、取り消す側・取り消される側のどちらかとして2回以上出てくる（自分自身を取り消す場合も） | 2回目に出てきた `REVERSAL-OF` |
| `bad-original` | `ORIGINAL` の金額が0以下（元の金額は正の数で書く） | その行 |

### 予定（PLAN）

| コード | 拒否すること | 行 |
|---|---|---|
| `zero-amount` | `CHANGE` の金額が0 | その行 |
| `no-effect` | `CHANGE` が1行もない | `PLAN` |
| `unbalanced` | `CHANGE` の合計が0でない | `PLAN` |
| `paid-by-reused` | 同じ記帳が2つの予定の `PAID-BY` になっている | 2回目の `PAID-BY` |

`PAID-BY` と `CANCELLED` の両方がある予定は、行の順の決まりにより `section-order` で拒否される。

### 残高の根拠

| コード | 拒否すること | 行 |
|---|---|---|
| `opening-missing-coordinate` | `OPENING` が指す記帳に、その科目・Measureの `EFFECT` がない | `OPENING` |
| `support-overlap` | 同じ科目・Measureに、`ZERO-ORIGIN`・`OPENING`・`ASSERT` のうち2つ以上がある。または `ASSERT` が2回ある（どの組でも、後の行） | 後の行 |
| `duplicate-support` | 同じ科目・Measureの `ZERO-ORIGIN` や `OPENING` や `HISTORY-FROM` が2回 | 2回目 |
| `history-unanchored` | `HISTORY-FROM` の科目・Measureに `ASSERT` がない（LOAMと同じく、記録が揃っている期間は確かめた残高と組でしか使えない） | `HISTORY-FROM` |
| `empty-anchor` | `ASSERT` のない `ANCHOR` | `ANCHOR` |
| `also-redundant` | `ALSO` が、`ANCHOR` の指す記帳か、それより前か、そのすぐ次の記帳を指している（すぐ次なら `ANCHOR` をその記帳にする。同じ範囲の書き方を1通りにするため。`ANCHOR	-` なら最初の記帳がすぐ次） | その `ALSO` |
| `duplicate-also` | 同じ `ANCHOR` の中で同じ記帳を2回 `ALSO` にしている | 2回目 |

### ATTENTION

| コード | 拒否すること | 行 |
|---|---|---|
| `bad-due` | 期限の種類が3つのどれでもない、`DUE_ON` なのに日付がない、ほかの種類なのに `-` でない | その行 |
| `bad-close` | 閉じ方が `RESOLVED` でも `DROPPED` でもない | その行 |
| `duplicate-close` | 同じ `ITEM` を2回閉じている | 2回目 |

## 今の残高の求め方

見本の期待値と、両方の実装の答えを揃えるための決まり。科目・Measureの組ごとに：

| 根拠 | 今の残高 |
|---|---|
| `ZERO-ORIGIN` | その組の `EFFECT` の合計（すべての記帳） |
| `OPENING` | その組の `EFFECT` の合計（すべての記帳。開始の額は指す記帳に入っている） |
| `ASSERT`（`ANCHOR` の中） | 確かめた額 ＋ `ANCHOR` が指す記帳より後（`ANCHOR	-` ならすべて）にあって、`ALSO` に挙がっていない記帳の、その組の `EFFECT` の合計 |
| どれもない | 不明（0ではない） |

`HISTORY-FROM` は過去の時点の残高にだけ効き、今の残高は変えない。`PLAN` は残高を変えない。

## 見本ファイル集

`test/common_format/` に置く。中身はすべて合成。

- `ok-*.txt`：受け入れるファイル。読んで書き直すと、バイト単位で同じにならなければいけない。
  同じ名前の `.answers` に、今の残高の期待値を書く（`BALANCE	<科目>	<Measure>	<金額>` か
  `BALANCE	<科目>	<Measure>	UNKNOWN`）。
- `ng-*.txt`：拒否するファイル。1つのファイルは決まりを**ちょうど1つだけ**破る。
- `cases.tsv`：見本ごとの期待（`ok`、または拒否の理由のコードと行番号）。

## LOAMの検証から引き継ぐもの・手放すもの

2026-10-24に、LOAMのCIで今も動いている検証（Alloy 35・TLA+ 20・SPIN 6・Leanの資格検査 15・
`Loam.DurableProofs`）と、`docs/SEMANTIC_BLUEPRINT.md` を見て仕分けた。番号はLOAMの
`experiments/` と `tla/` の名前。

### 引き継ぐ決まり（形式と両方の実装が守る）

| | 決まり | 根拠 |
|---|---|---|
| K1 | MEASUREの桁数（scale）は、一度使ったら変えない。変えるなら明示的な移行で全部の金額を書き直す | 328、TLA MeasureScalePublicationOrder |
| K2 | `EFFECT` の金額は0でない | Lean `positiveTotalQuanta_pos_of_nonempty_nonzero`、BakhloのActual_source |
| K3 | 「最初の記帳がある」ことから「その前は0」を導かない。0から始まったと言えるのは `ZERO-ORIGIN` があるときだけ | 088、TLA FirstEventAnchoredOrigin・ZeroOriginAdmissionEvidence |
| K4 | 今の残高の根拠（ANCHOR）と、記録が揃っている期間（HISTORY-FROM）は別の事実。片方からもう片方を導かない | 243 |
| K5 | 数えた額と帳簿が一致しても、それだけで「記録が揃っている」ことにはならない | 345 |
| K6 | 合わなかった差額を埋めると、それより前の時点の残高は逆算できなくなる。HISTORY-FROMを動かすかどうかは本人が決め、プログラムが勝手に動かさない | 346 |
| K7 | 含まれている記帳を訂正しても、ANCHORから計算する今の残高は変わらない | 246 |
| K8 | Merchantは「店あり」「店なし（`NONMERCHANT`）」「未分類（行がない）」の3つを区別する。未分類を「店なし」として数えない | 268 |
| K9 | `DESC`（メモ）の文字列から支払先を決めない | 265 |
| K10 | 未分類の仮置き科目（suspense）には役割を付けない。仮置きの金額は、分かっている科目へ移すことでしか減らない | 269 |
| K11 | `REVERSAL-OF` の記帳は、元の記帳の金額をちょうど逆にしたもの。元の記帳も消さない | Bakhlo S5 |
| K12 | 保存の直前に、読み込んだときからファイルが変わっていないことを確かめる。変わっていたら保存を拒否する（BakhloとLOAMを同時に開いたときに、片方の記帳を消さないため） | SPIN ui-stale-admission、Bakhlo S9 |
| K13 | 書いたものを読み直すと同じになる（`読む(書く(x)) = x`）。記帳のあとの手元の状態は、ファイルを読み直した状態と一致する | Lean VersionedRows、Bakhloのoracle試験 |

複数のファイルを順に書くときの途中状態の問題（SPIN split-publication の各モデル）は、
1つのファイルを丸ごと差し替える方式なので、形式そのもので起きなくなる。

### 手放すもの（今の状態だけを持つことの代償）

| | 手放すもの | 関係する検証 | 代わり |
|---|---|---|---|
| L1 | 「その日の時点で何を知っていたか」（知った時点の履歴） | TLA ValidTimeVsLearnedTime・BitemporalCorrectionFrontier・TemporalEvidenceCorrection ほか、381、DailyPaceAutomaticKnowledge | Gitの履歴。精度はコミットの単位（Bakhloは終了ごと） |
| L2 | 訂正どうしの衝突の扱い | TLA TemporalCorrectionConflict・TemporalConflictResolutionHistory、LeanのOb.043〜046 | 書くのは一度に片方だけ（原則3）とK12 |
| L3 | 予定の完了・取消・置換の経緯 | 105、Lean scheduled-replacement-frontier | `PAID-BY`・`CANCELLED` だけを持つ。経緯はGit |
| L4 | 予算と、その方針の履歴 | Capacity・Routingの各検査、TLA PolicyAttributionHistory・PolicyDefinitionHistory | 予算が必要になったら改めて考える |

L1は、Bakhloがすでに受け入れていること（Bakhlo S5）と同じ。「今の知識で過去を計算し直した値」は
これまでどおり出せる。

### 今は使っていないので後で決めるもの

現実の観測にあたるので、入れるときはLOAMの検証を読み直して厳密に扱う。

| | もの | 関係する検証 |
|---|---|---|
| D1 | 立替・貸し借りの対応（Settlement・Relation） | 373〜379、TLA AsynchronousSettlement、SPIN discharge-*、Lean RelationDischargeFrontier |
| D2 | 「残高はあるが金額は不明」（Presence） | Bakhlo S6 |
| D3 | 支払先の同一性（同じ店・同じ人） | 263、264 |

### この形式には関係しないもの

外部の会計の考え方との対応を調べた研究（083、242、249、251、252、254）と、記帳の
解釈メモの研究（320〜327）。年別保存の検査（TLA Annual*）は、LOAMですでに年別保存を廃止している。

## 持たないもの

| LOAMにあるもの | 理由 |
|---|---|
| `REPLACES`・`DATE-REV` と訂正の連鎖 | 訂正は上書き。前の値はGit |
| 予定の ROOT/CHANGE の変更履歴、完了・取消・置換の記録 | 予定は今の状態だけ |
| Capacity・ActualRouting・ScheduledRouting（予算） | 使っていない。必要になったら別に考える |
| ANCHORの `ROOT` の一覧 | 記録の並びと最後の1件で同じ意味を表せる |
| `SECTION 名前 バイト数` | 最後の `END` で代わりにする |
| `OPERATION bakhlo-reflection:…` | 同じファイルを読むので、反映し合う必要がない |

## ファイルの外に残すもの

`config/` のTSVは表示や画面の設定なので、正データに入れない：
`balance-view.tsv`、`boundary-presets.tsv`、`daily-pace.tsv`、`measure-presentation.tsv`、
`scheduled-coverage.tsv`。

## 保存のしかた

**毎回ファイル全体を書き直す**（2026-10-24 決定。下の測定を見たうえで再確認した）。
一時ファイルに書いてfsyncし、名前を差し替える。一つ前の世代を `.prev` に残す。
保存の目安は100ms以内（BakhloのAGENTS.mdの「5ms以内＋fsync」を置き換える）。

最初の判断は「書き直し＋fsyncは30年分の大きさでも約31ms、時間のほとんどはfsyncで追記方式と同じ」
という測定によった。これは**出来上がった文字列を書く時間だけ**で、帳簿から文字列を作る時間を
含まず、名前の差し替えに必要なディレクトリのfsyncも含んでいなかった。

2026-10-24の測定（`tools/startup-probe` と同じ合成帳簿、このMac、7回の中央値。3は3回）：

| | 1,000件 | 10,950件 | 109,500件 |
|---|---:|---:|---:|
| 1. 今のBakhloの保存（1件追記＋fsync） | 22 ms | 21 ms | 21 ms |
| 2. 新形式で全体を書き直す（作る＋書く＋fsync×2＋差し替え） | 45 ms | 56 ms | 156 ms |
| 　うち文字列を作る | 0.9 ms | 10 ms | 96 ms |
| 　うち書く＋fsync×2＋差し替え | 44 ms | 46 ms | 55 ms |
| 2'. 1件ずつの文字列を覚えておき、変わった1件だけ作り直して連結（書く・fsyncは除く） | 0.02 ms | 0.4 ms | 5.4 ms |
| 3. 今のBakhloのまとめ直し（S式で全体を書き直す。終了時、200件ごと） | 94 ms | 521 ms | 4,887 ms |
| 書いたものを読み直して確かめる（K13） | 1.1 ms | 15 ms | 146 ms |
| 起動：S式の字句解析（Parsexp） | 4.6 ms | 60 ms | 627 ms |
| 起動：新形式の字句解析 | 0.8 ms | 14 ms | 146 ms |
| 起動：S式を読んで帳簿を組み立てる全体（今のBakhlo） | 12 ms | 158 ms | 1,680 ms |

ファイルの大きさは109,500件でS式31.5MB、新形式11.5MB。

- 全体を書き直すと、ファイルとディレクトリの2回fsyncするので、小さい帳簿でも約44ms
  かかる（追記は1回で約21ms）。
- 109,500件（BakhloのAGENTS.mdの30年目標）では、全体の書き直しは156msで、Bakhloの目標
  「保存の処理は5ms以内＋fsync」を満たさない。1件ずつの文字列を覚えておく方式でも、作る5.4msに
  11.5MBを書く時間とfsync×2が加わる。
- 新形式は、文字列を作るのがS式より約6.6倍、字句解析が約4.3倍速い。
- **見直す目安**：保存が100msを超えたとき、または起動時の読み込みが遅いと感じたとき。
  そのときは追記方式か、年ごとの分割を考える。

## 決めたこと（2026-10-24）

- ファイル名は `book.txt`、1行目は `BOOK	1`
- 保存は毎回ファイル全体を書き直す。目安は100ms以内
- LOAMの検証からK1〜K13を引き継ぎ、L1〜L4を手放す
- 表示名と説明は `LOCUS` 行に置く
- 使わない科目は `HIDDEN`（入力候補から外すだけ）
- Merchantは後から変えてよい
- ANCHORは「記録の並びで、ある記帳まで」で表す。TXは記録した順に並べる
- `ALSO` はv0に入れる。`EXCEPT` は必要になるまで入れない
- 両替は `EXCHANGE	<元Measure>	<先Measure>` で表す
