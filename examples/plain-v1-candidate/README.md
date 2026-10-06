# 括弧なしのプレーンテキスト候補

S式の[4つの合成例](../sexp-v1-candidate/README.md)を、同じ情報のまま行指向にした比較用です。
**parser／writer／migrationは未実装。採用済み文法ではありません。実データも使っていません。**

| プレーンテキスト | 対応するS式 |
| --- | --- |
| [01-retained-evidence.txt](01-retained-evidence.txt) | [01](../sexp-v1-candidate/01-retained-evidence.sexp)：元Event・関係・cut・policy/provenanceの保持 |
| [01-retained-evidence-uniform.txt](01-retained-evidence-uniform.txt) | **追加比較**：01と同じ意味を、record固有の `to` / `end-event` 等を使わず、nested block + generic `end` + explicit `state` に寄せた版 |
| [02-retained-evidence-reordered.txt](02-retained-evidence-reordered.txt) | [02](../sexp-v1-candidate/02-retained-evidence-reordered.sexp)：並べ替え・前方参照 |
| [03-precision-and-unknown.txt](03-precision-and-unknown.txt) | [03](../sexp-v1-candidate/03-precision-and-unknown.sexp)：無限精度・Measure・空／未供給／数量不明 |
| [04-invalid-flattened-generation.txt](04-invalid-flattened-generation.txt) | [04](../sexp-v1-candidate/04-invalid-flattened-generation.sexp)：**不正例**。元Event欠落による拒否を期待 |

## 均一構文の追加比較

[01-retained-evidence-uniform.txt](01-retained-evidence-uniform.txt) は、既存の01と保存内容を変えずに、
プレーンテキスト案の「専用言語化」をどこまで抑えられるかを見るための**人間向け比較fixtureだけ**です。

- recordごとの `end-event` / `end-relation` ではなく、nested blockを一つの `end` で閉じます。
- `correct-event "e1" to "e2"` のようなrecord固有の接続語を使わず、
  `event-correction` の下に `target` / `replacement` を置きます。
- collectionの supplied / empty / not-supplied は `state provided|empty|not-supplied` と明示します。
- `description text ...`、`key named ...`、`debtor household` のようなvariant値は残しています。
  これは構文上のshortcutを採用したという意味ではなく、schema上の値表現候補です。
- インデントは読みやすさのためだけで、意味はblockと `end` に持たせる想定です。
- この比較からparser grammar、canonical spelling、依存選択、migration方針は採用しません。

意図的に既存plain版より冗長です。読みやすさを保ったまま構文規則を減らせるか、
それともS式の既存parserを使う方が長期総コストで有利かを見る材料に限定します。

## 見た目だけを軽くするルール案

- 先頭の `bakhlo 1` は形式の候補版、末尾は `end-book`。アプリ版・日付・保存成功ではありません。
- ブロックは `event` と `end-event`、`relation` と `end-relation`、
  `observation` と `end-observation`、`presence` と `end-presence` で区切ります。
  インデントは見やすさのためで、括弧やインデントの深さに意味を持たせません。
- 各レコード自身が、その型の宣言を供給します。空の集合だけ `empty ...`、未供給だけ `not-supplied ...` と明示します。
  例の非空集合は、対応するS式の `provided` と同じ状態です。**行がないことを空・未供給のデフォルトにしません。**
  将来の検証では、空宣言とレコードの併記、空／未供給の重複、状態の欠落を拒否する必要があります。
- `new-write-loci` は明示的な新規記録の許可集合で、既存Eventから推測しません。
- 日付やメモは値または `not-supplied`。`description text ""` は空文字で、未供給とは別です。
- IDと文字列は引用し、引用内の改行・引用符は `\n`・`\"` で表す案です。UTF-8・大文字小文字・ID・数量を変換しません。
  語の境界やエスケープは未確定で、字句解析の正しさを実証したものではありません。
- Effectは一行につき一つ。`effect key` と `effect unkeyed` を区別し、同座標でも集約しません。
- 各観測・presenceに必須の `reflected-roots` を置きます。`reflected-roots empty` は明示的な空集合。
  引用されたIDとしての `"empty"` とは別です。グループIDや日時・行位置からのcut推測は追加しません。
- 順序で現在性を決めず、Event訂正と日付改訂は独立したレコードにします。
  `revise-occurrence` の最初のIDは改訂ID、`event` と `corrects-base` はEvent IDです。
- 各fileは選択された自己完結する **evidence generation** の候補。flattenした回答表ではありません。
  未供給のfamilyや受領証を消したり、原本や祖先で参照を黙って補完したりしません。

01/02のwallet/jpyは条件付き996、food/jpyは66、relation残量は2という期待を含め、
[意味の期待値と限界](../sexp-v1-candidate/README.md#01--02同じ関係と条件付き回答を保つ)はS式版と同じです。
03の無限精度整数・引用・改行・空文字も保持し、04は全体拒否を期待します。実行検証はまだありません。
request-originは完全なpublication receiptではなく、元candidate/base・元結果の完全復元は引き続き未供給です。

今回は、意味を減らさず読みやすくできるかの比較だけです。S式の以前の選択を自動で置き換えるものでも、
独自parserを実装してよいという許可でもありません。依存を省く場合に増える字句解析・診断・整形の保守負担も、後で比較します。
