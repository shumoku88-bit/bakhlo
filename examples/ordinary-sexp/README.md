# 最小のS式帳簿（架空データ専用）

本体の `bakhlo.sexp` で、開始数量 → 支出 → 訂正 → 別プロセスから再読込を試す。
実データ、既存LOAM、既存試験ストアは使わない。これは**新規候補ファイルの作成**までで、
記録の公開、採用済みストア、durable Saved、家計全体の形式ではない。

リポジトリのルートから、まだ存在しない出力名を指定する：

```sh
mkdir -p scratch/ordinary-sexp-demo
./tools/opam exec -- dune exec bakhlo -- stage-current-sexp --canonicalize \
  examples/ordinary-sexp/initial.sexp scratch/ordinary-sexp-demo/start.sexp
./tools/opam exec -- dune exec bakhlo -- stage-current-sexp \
  scratch/ordinary-sexp-demo/start.sexp examples/ordinary-sexp/purchase.sexp \
  scratch/ordinary-sexp-demo/purchase.sexp
./tools/opam exec -- dune exec bakhlo -- stage-current-sexp --correct purchase \
  scratch/ordinary-sexp-demo/purchase.sexp examples/ordinary-sexp/correction.sexp \
  scratch/ordinary-sexp-demo/corrected.sexp
./tools/opam exec -- dune exec bakhlo -- inspect-current-sexp --summary \
  scratch/ordinary-sexp-demo/corrected.sexp wallet jpy food jpy bank jpy
```

Walletは `1000 → 900 → 850`、Foodは `0 → 100 → 150`。Bankは開始根拠がなくUNKNOWNのまま
（最後の照会は終了コード3）。訂正前のEvent、説明、日付、Effect、明示した訂正関係、開始根拠を
新しい候補にも残す。訂正後の日付が古くても、日付順で勝者を選ばない。元ファイルは変更しない。

## この開発用プロファイルの約束

先頭は `(bakhlo 1 ordinary-quantity)`。OCaml型名やアプリの版とは別のデータ形式名。
`collections` は一度だけ書き、`provided` / `empty` / `not-supplied` の三フィールドが必須。
`measures` / `events` / `event-corrections` / `observations` / `zero-origin` を、それぞれ一度だけ
いずれかに指定する。`provided` は一件以上、`empty` と `not-supplied` は実レコードなし。
後二者は同義にせず保存する。実レコードがなくても、宣言を省略して空扱いにはできない。

浅いトップレベルレコード：

- `measure "ID" (decimal-scale N)`：非負の正確な整数。参照するMeasureは明示的に宣言する。
  数量は常に符号付き整数quanta。通貨名の推定、表示丸め、換算はしない。
- `event "ID"`：`day (date "YYYY-MM-DD")`、`description (text "…")` または
  `description (not-supplied)`、順序付きの `effect`。説明の空文字と未供給は別。
  `day (not-supplied)` は構文上識別するが、既存Actualの日付完全性ゲートで拒否される。
- `effect`：`key (named "ID")` または `key (unkeyed)`、`locus`、`measure`、`quanta`。
  匿名Effectの重複・相殺も消さない。同一Eventの重複キーは拒否する。
- `event-correction`：`target` と `replacement`。元Eventは削除しない。新規支出・訂正候補は
  既存の単一Measure・非ゼロ・完全均衡Movement判定と、候補全体の判定を両方通す。
- `observation`：必須の `reflected-roots`（明示的な空リストも可）と0件以上の `assertion`。
  assertionは `locus` / `measure` / `quanta`。各観測の独立したカットを保存する。
- `zero-origin`：`locus` / `measure`。支出履歴や差分ゼロから勝手に追加しない。

未知の版・フィールド・証拠系列、単一フィールドの重複・欠落、参照切れ、無効日付、重なる根拠は
全体を拒否する。opening、presence、独立した日付改訂、Merchant、Exchange、Reversal、Relation、
Discharge、予定、設定、receipt等はこのプロファイルで表現しない。供給済みのそれらを落とす変換APIはない。
識別子と本文はバイトを保持し、trimやUnicode正規化をしない。決定的なUTF-8出力はファミリー順を
整えるが、各ファミリーの順序、Effectの順序・多重性は保つ。コメント・空白の再印字は保証しない。
重要なメモは `description` データにする。読み込んだ原文は純粋なBookと元ファイルに残る。

出力先は親ディレクトリが既存の新規ファイルだけ。既存ファイル・symlinkは終了1で拒否する。
入力の拒否は出力作成前。作成試行の失敗（既存衝突以外）、write/close/readbackの失敗は終了5で
UNCERTAINとし、あり得る生成物を削除しない。自動復旧や盲目的な再試行をしない。
成功も候補のclose・バイト再読込までで、fsync、電源断耐性、選択世代・所有権、receiptは未資格。
安定した入力と協調的な親名前空間を仮定する。

[Book API](../../sexp/book.mli) / [Architecture](../../docs/ARCHITECTURE.md#minimal-ordinary-s-expression-book) /
[Verification](../../docs/VERIFICATION.md#minimal-ordinary-s-expression-book) が境界と実行済み証拠を持つ。
より広い [v1候補](../sexp-v1-candidate/README.md) は別の人間レビュー資料で、当Codecの入力ではない。
