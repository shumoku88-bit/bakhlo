# Bakhlo 年度締め・年度間公開 TLA+ v0.1

対象: 2025/2026の2年度、2025年の本締め後の明示的な例外訂正1件、
既存の2026年実績1件、跨年度予定1件（支払いは0/1回に抽象化）、
途中停止と再開。すべて合成・抽象状態です。

## 収録物

- `YearClose.tla` : 安全な一体公開と、故意に壊した2段階公開を切替できる同一モデル
- `Safe.cfg` : `AtomicPublish = TRUE`（論理上一体的な世代選択を**仮定**）
- `Broken.cfg` : `AtomicPublish = FALSE`（2025年だけ先に公開する負例）
- `bounded_probe.py` : 同じ状態遷移を**別に**実装した有限Python探索。TLC代替ではない。

## TLCでの検査手順

Javaと正式な `tla2tools.jar` が使える場所で、ここを作業ディレクトリにして実行:

```sh
# TLCのjarは利用者の環境にある検証済みのものを明示指定する。
TLA_TOOLS_JAR=/absolute/path/to/tla2tools.jar
java -cp "$TLA_TOOLS_JAR" tlc2.TLC -workers 1 -config Safe.cfg YearClose.tla
java -cp "$TLA_TOOLS_JAR" tlc2.TLC -workers 1 -config Broken.cfg YearClose.tla
```

期待: Safeは列挙状態において不変条件違反なし、Brokenは
`ConsistentSelection` の違反を報告し、`year25="B"`, `year26="A"`
という反例へ至る。これは**期待値**であり、今回TLCを実行した実績ではない。
`Broken.cfg` が非ゼロ終了するのは検証の目的に沿った正常な負例です。
TLCの実際の状態数・終了コード・トレースは必ず実行結果をもとに記録してください。

この環境にはTLC本体がなく、外部ネットワークも利用できなかったため、
TLA+の構文・意味は**TLC未確認**。Python探索は実行済み:

```sh
python3 bounded_probe.py
```

観測: `Safe` 44状態で指定不変条件の違反なし、`Broken` 24状態までに
`ConsistentSelection` 違反を発見。最短経路は
`Init -> BeginAmend -> Stage2025 -> Stage2026 -> ValidateCandidate -> SelectCandidate`。
これはPython側の小さな状態遷移についての確認であり、TLA+モデルのTLC検証ではありません。

## モデルの意味と限界

### 守ろうとしているもの

- `ConsistentSelection`: 選択済みの前年版と翌年の期首参照版が一致する。
- `NewSelectionQualified`: 新しい年次版は候補両方の準備と検証を経ている。
- `AckIsForNewPair`: 応答が成功を示すなら、整合した新しい組が選択されている。
- `PreserveExisting2026`: 当年の既存実績は消されない（1件だけの抽象トークン）。
- `RetainOldFinal`: 旧確定版を保全する（抽象トークン）。
- `UniquePayment`: 支払い回数は高々1回（抽象操作ガード）。

### まだ証明していないこと

- `AtomicPublish=TRUE` **自体が最も重要な未実装の仮定**。2つのS式ファイルの
  `rename` を順に実行しても、この性質は実現しない。実現方式は未選定。
- `acked` は論理的な応答。fsync、ディスクcache、電源断、HEAD/manifest、
  部分書込み、結果不確定、P7/Ack-lossの本物のストレージ保証は全く検証していない。
- 整合する二版が分かっただけでは、root cut/unknown/独立観測の意味が正しいとは言えない。
  `ValidateCandidate` はBakhlo Coreの既存入場判定を一つの原子的な抽象操作として仮定。
- `existing2026` と `old25Retained` は不変な抽象トークンで、実ファイルのバイト保全は未検証。
- 予定支払いとcross-year linkは単純な0/1ガードのみ。実際の年度間参照・二重計上・
  staleな2026年書込との競合・予定の状態は次のモデルで検証する必要がある。
- **生存性は検証していない。** Crashが無限に続けば成功しない。
- 3年以上の連鎖、日付訂正による年度移動、複数writer、GC/バックアップ、
  不完全な外部configは範囲外。

## 次の最小追加 v0.2

1. 2026年に別の実績が増えた直後、2025年の訂正候補が古い2026年版へ繰越を作り、
   そのまま公開して当年実績を消す反例を追加。
2. publish前に`observed_generation`の比較を必須にし、stale候補を拒否。
3. 旧版/新版/不確定/欠落を区別する抽象選択・復旧状態を追加し、
   ファイル保存方式（年度別S式、SQLite）の違いを挿入可能にする。
4. 既存Coreで同等性・拒否の合成fixtureを確立してから、実ファイルの
   fault injectionや性能測定へ進む。

**本体の保存方式は未採用。LOAM本番正データには触れない。**
