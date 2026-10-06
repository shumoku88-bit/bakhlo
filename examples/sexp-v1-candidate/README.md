# v1候補：合成canonical evidence generation

**人が確認するための4例です。採用済みスキーマ・実行テスト・世帯データではありません。**
parser、writer、migration、DTO、依存追加は実装していません。全内容を合成し、原本・私用コピー・利用状況からの転載はありません。

「一つの現在の本」は、現在選択された自己完結する **canonical evidence generation** です。
現在のEventだけを抽出した表、残高キャッシュ、日付順のコマンドログではありません。
訂正前のEvent、明示relation、observation/cut、供給されたpolicy/provenanceも、その世代の入力に残ります。
self-containedは、すべての家計質問に答えられるという意味ではありません。不明は不明のまま表します。
世代の選択・所有権・永続性・物理トークンは、この例の外側で後に設計する境界です。

## 共通の読み方（候補であり、まだ仕様確定ではない）

- `(format-version 1)` はデータ形式の候補版。アプリ版や記録時刻ではありません。
- コレクションの `(provided ...)` は、供給された宣言集合。`(provided)` は明示的な空集合です。
  `(not-supplied)` は未供給であり、空集合や既知のゼロではありません。空宣言は現実の網羅性を証明しません。
  必要なフィールド自体の欠落を、これらの状態へ自動補完する設計にはしません。
- 日付は `(date "...")` または未供給、descriptionは `(text "...")` または未供給。
  `(text "")` と未供給は異なります。必要なメモはデータ項目に置き、コメントにだけ置きません。
- 各Effectのキーは `(named "...")` または `(unkeyed)`。匿名の出現にも勝手な永続キーを作りません。
  `(Event ID, Effect key)` がrelationのsourceを特定します。他Eventの同名キーには付け替えません。
- 数量は十進の符号付き無限精度整数quanta。Measure・decimal-scaleは明示し、floatや機械整数に落としません。
  IDはそのまま保持し、trim・大文字小文字変換・Unicode正規化をしません。
- 各観測・presenceはそれ自身の必須 `reflected-roots` を持ちます。空の根集合を明示できても、
  フィールド欠落を空へ補完したり、別グループのcutを流用したりしません。観測グループの安定IDは設けません。
- 一覧の順序で訂正先や現在性を選びません。ただし、個々のEffectの順序・出現・キー等は消しません。
- 候補は実績・数量根拠・一部policy/provenanceのレビュー範囲です。予定・配分・注意・決済等は
  明示的に未供給です。全familyの形式・意味検証・移行同等性を網羅したとは主張しません。
- request-originは「論理リクエストが作った元Event」への対応だけです。`publication-receipts` は未供給。
  元candidate/baseや元結果を復元できる完全な受領証、再試行許可、durable Savedを表してはいません。

## 4例と期待するレビュー結果

| ファイル | 確認する境界 |
| --- | --- |
| [01-retained-evidence.sexp](01-retained-evidence.sexp) | 元Event、Event訂正と日付改訂、元Effectを指すrelation、明示discharge、独立cut、policy/provenanceを同じ世代に保持 |
| [02-retained-evidence-reordered.sexp](02-retained-evidence-reordered.sexp) | 01と同じ事実を参照先より先に配置。全体を見て参照解決し、行順・最大日付で現在性を決めない |
| [03-precision-and-unknown.sexp](03-precision-and-unknown.sexp) | 無限精度、同じLocusの異なるMeasure、開始Eventの指定、空・未供給・数量不明、合計ゼロでも出現を残す |
| [04-invalid-flattened-generation.sexp](04-invalid-flattened-generation.sexp) | **意図的に不正**。01から元Eventだけを消したもの。外部の祖先で補完せず、全体を拒否すべき |

### 01 / 02：同じ関係と条件付き回答を保つ

以下は既存の意味・モデルに照らした**手作業の期待値**で、S式readerの実行結果ではありません。
02は元の宣言順が異なるので、原本バイト列・一覧順・エラー位置まで等しいとは主張しません。

- `e1 -> e2` により現在のEventは `e2`。`e2` の日付は `e1` より古くても、この関係を変えません。
  `e1` 本体・説明・日付は消さず、`e2` に未供給の説明を継承しません。`e3` の空文字説明も区別します。
- occurrence revisionのIDも意図的に `e1`。Event IDと日付改訂IDは別の役割です。
  日付改訂は `e1` のbase occurrenceを1850-01-01へ改訂し、Event訂正や `e2` の日付を変更しません。
- relation `r1` は **元の `(e1, cash)`** を指し、quantity 6 <= 元Effectの絶対量10。
  `e2` の同名キーに移しません。`e3` による明示discharge 4で条件付き残量は2。
  relation/discharge自体を物理Effectとして二重に数えたり、現実の債務・履行の完全性と同一視したりしません。
- wallet/jpy：供給された観測1000、cutに `e1`。その根の現在Event `e2` は未反映deltaに入れず、
  `e3` の -4だけを加えて **996 quanta**。food/jpyは独立した空cutと観測50なので **50 + 12 + 4 = 66**。
  別グループのcutを共有すると誤答します。この回答値はfixtureには保存していません。
- quiet/jpyは明示zero-originにより0。pantry/jpyは既知の非ゼロ・正確な量/符号は不明。
  old-only/jpyは活動の合計が0でも数量根拠がなく、0とは答えません。
- old-onlyの過去Effectは保持しますが、NEW-write vocabularyには含みません。
  過去に出現したことから新規記録の許可を推測しません。分類・routingが未供給なら補いません。
- `req-old -> e1` はそのまま。後の訂正先 `e2` に付け替えず、元結果の完全復元までは主張しません。

### 03：精度・不明・開始量を分ける

- wallet/usdの開始Eventが持つ量は `100000000000000000000000000000000000001` quanta。
  opening-supportはEventの指定だけで、数量を重複保存しません。offset/usdには開始量の指定がなく、
  活動値をそのまま正確な残高とみなしません。
- 同じwalletでも、wallet/jpyは別のzero-originで0。USDとJPYを合算・換算しません。
- 観測集合とrelation集合は明示的に空。bounded-history・routing等は未供給。
  01の未供給accounting-rolesと、03の明示的に空のassignment集合も保存状態として区別します。
- pantry/jpyの量を1や0へ置換せず、old-onlyの +1/-1という二つの匿名Effectを消しません。
  日付未供給をファイル時刻で埋めず、引用・日本語・改行・空文字メモを保持します。

### 04：flattenによる欠落を拒否する

削除された `e1` を、Event訂正、日付改訂、relation source、observation cut、request-originが参照します。
見えている `e2/e3` だけで部分成功にしたり、古いファイルから黙って回収したり、参照を捨てて直したりしません。
すべての拒否理由を網羅するfixtureではなく、**「現在の本から訂正前情報を落としてはいけない」**という一つの反例です。
まだ実行器がないため、拒否の実行・最初のエラー順序・診断形式は未確認です。

## 今回確認してほしいこと

1. `provided` / `not-supplied` とキー/説明/日付の表記は、過剰でなく区別を保てているか。
2. 全体で参照を解決でき、現在性を求めても元情報・cut・policy/provenanceが消えないか。
3. 受領証の範囲や未供給familyを曖昧にせず、v1の次の検討に必要な例になっているか。

[意味の契約](../../docs/SEMANTIC_CONTRACT.md)と
[長期設計の境界](../../docs/ARCHITECTURE.md#selected-s-expression-direction--long-term-boundaries)が上位の制約です。
確認後に別途判断するまで、parser/writer/migration実装へは進みません。
