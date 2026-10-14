# Bakhlo 年度締め・年度間公開 TLA+ v0.1 監査・検証レポート

## 1. 実行環境
- **OS**: macOS 15.7.9 (x86_64)
- **Java**: OpenJDK 21.0.12.1 (Homebrew, `/usr/local/opt/openjdk@21`)
- **TLC**: TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)
- **Tool JAR**: `scratch/tla/tla2tools.jar` (tlaplus/tlaplus official release v1.7.4)

## 2. v0.1 オリジナルモデル実行結果 (`formal/bakhlo-yearclose-v01/`)

### 2.1 安全モデル (`Safe.cfg`)
```sh
$JAVA_HOME/bin/java -cp .../scratch/tla/tla2tools.jar tlc2.TLC -workers 1 -config Safe.cfg YearClose.tla
```
- **状態数**: 72 states generated, 44 distinct states found, 0 left on queue
- **深さ**: 11
- **結果**: エラーなし (Model checking completed. No error has been found.)
- **終了コード**: 0

### 2.2 危険モデル (`Broken.cfg`)
```sh
$JAVA_HOME/bin/java -cp .../scratch/tla/tla2tools.jar tlc2.TLC -workers 1 -config Broken.cfg YearClose.tla
```
- **状態数**: 22 states generated, 18 distinct states found, 4 left on queue
- **深さ**: 6
- **違反不変条件**: `ConsistentSelection` (`year25 = year26`)
- **反例トレース**:
  1. `Init`: year25="A", year26="A", phase="idle"
  2. `BeginAmend`: phase="draft"
  3. `Stage2025`: phase="staged25", staged25=TRUE
  4. `Stage2026`: phase="staged26", staged26=TRUE
  5. `ValidateCandidate`: phase="qualified", qualified=TRUE
  6. `SelectCandidate`: phase="half", year25="B", year26="A" (不変条件違反)
- **終了コード**: 12

※注意: Python shadow probe (`bounded_probe.py`) で報告されていた 44状態 / 24状態 という値は、Python の独自キュー探索での訪問数であり、TLC の厳密な探索状態数（Safe: 72 generated / 44 distinct, Broken: 22 generated / 18 distinct）とは異なります。

---

## 3. モデルの監査結果（欠陥と限界）

1. **不変条件の空疎性 (Vacuous Invariants)**:
   - `PreserveExisting2026` (`existing2026 = 1`):
     変数 `existing2026` を変更・減少させるアクションがモデル内に一切存在せず（すべて `UNCHANGED existing2026`）、常に自明に成立している。当年実績の喪失や競合は全く検証されていない。
   - `RetainOldFinal` (`old25Retained = TRUE`):
     変数 `old25Retained` も全アクションで `UNCHANGED`。本締め済みの旧確定版に対する通常編集要求を拒否するアクションやガードはモデル化されていない。
   - `UniquePayment` (`planPayments <= 1`):
     `PayOnce` アクション自体に `planPayments = 0` のガードがあるだけの単純なフラグ反転であり、年度間予定の二重支払い・競合の検証にはなっていない。

2. **不変条件 `FailClosedRecovery` の欠落**:
   - 仕様書や要件で言及されている「復旧不能・選択不明の状態を正常として公開しない（FailClosedRecovery）」という不変条件が、`YearClose.tla` に定義されていない。

3. **クラッシュ時の揮発性状態（メモリ状態）の残留バグ**:
   - `Crash` および `Recover` アクションにおいて、`staged25`, `staged26`, `qualified` が UNCHANGED となっている。
   - プロセスがクラッシュして `phase = "idle"` に復旧したにもかかわらず、未コミットの候補作成状態や検証フラグがメモリ上に残ったままになる不健全な状態遷移が存在した。

4. **一体公開（AtomicPublish）仮定の本質**:
   - `AtomicPublish = TRUE` は、1ステップで `year25' = "B" /\ year26' = "B"` とする抽象的な同時更新であり、実際のファイルシステム（rename, fsync, 電源断耐久性）のアトミック性は何ら証明していない。

---

## 4. 監査修正版モデル (`YearCloseAudited.tla`) の検証結果

### 修正内容:
1. 不変条件 `FailClosedRecovery` の明示的定義:
   ```tla
   FailClosedRecovery ==
     /\ (phase \in {"published", "done"} \/ acked) => (phase # "unavailable" /\ year25 = year26)
     /\ (phase = "unavailable") => ~acked
   ```
2. 不変条件名の整理（`PreserveCurrentYear`, `ClosedRevisionImmutable` を定義）。
3. `Recover` アクションにおいて、未公開状態でのクラッシュ復旧時に揮発性ステージング状態（`staged25`, `staged26`, `qualified`）を `FALSE` にリセット。

### 監査修正版の検証結果:
- **Safeモデル (`Safe.cfg`)**:
  - 生成状態数: 51 states generated, 32 distinct states found, 0 left on queue
  - 深さ: 11
  - 終了コード: 0（不変条件違反なし）
  - ※クラッシュ後の不正なメモリ残留状態が排除されたため、distinct states が 44 から 32 に正規化された。
- **Brokenモデル (`Broken.cfg`)**:
  - 生成状態数: 22 states generated, 17 distinct states found, 3 left on queue
  - 深さ: 6
  - 終了コード: 12（`ConsistentSelection` 違反で停止）
