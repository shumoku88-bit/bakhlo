# Bakhlo 年度締め・年度間公開 TLA+ v0.2 検証レポート

## 1. 目的と概要

TLA+ v0.2 では、Bakhlo の年度別正データ設計における以下の課題を検証対象としました：
1. **独立リビジョン**: 2025年（過年度）と2026年（当年）が独立したリビジョンを持つ。
2. **期首繰越の参照**: 2026年の期首繰越が2025年の特定確定リビジョンを参照する。
3. **安定ID集合による実績表現**: 2026年の実績を単なる件数ではなく、安定IDの集合（`SUBSET RecordID`）として保持。
4. **並行記帳との競合**: 2025年訂正の繰越再計算候補を作成中に、2026年へ新しい記帳が追加される競合をモデル化。
5. **楽観的同時実行制御 (OCC)**: 公開直前に観測世代と現在世代の一致を検証し、stale な候補を拒否（Reject）して当年実績の喪失を防止。
6. **空疎でない不変条件と反例検出**: 安全モデルおよび3つの危険モデルにより、具体的な反例トレースを確認。

---

## 2. TLC実行環境

- **OS**: macOS 15.7.9 (x86_64)
- **Java**: OpenJDK 21.0.12.1 (Homebrew, `/usr/local/opt/openjdk@21`)
- **TLC**: TLC2 Version 2.19 of 08 August 2024 (rev: `5a47802`)
- **ツール配置**: `scratch/tla/tla2tools.jar` (v1.7.4)

---

## 3. モデル検査結果一覧

| モデル | 設定ファイル | 設定パラメータ | 探索状態数 (Gen / Distinct / Queue) | 深さ | 終了コード | 検査結果・検出された反例 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **安全モデル** | `Safe.cfg` | `CheckGen=TRUE`, `Atomic=TRUE`, `CorrectCarryover=TRUE` | 67 / **42** / 0 | 10 | **0** | **合格**（全不変条件を充足、エラーなし） |
| **危険モデル 1** (世代確認欠落) | `BrokenStalePublish.cfg` | `CheckGen=FALSE`, `Atomic=TRUE`, `CorrectCarryover=TRUE` | 30 / **22** / 5 | 6 | **12** | **`PreserveCurrentYear` 違反**（当年新規記帳 "r2" の消失） |
| **危険モデル 2** (非アトミック公開) | `BrokenAtomicPublish.cfg` | `CheckGen=TRUE`, `Atomic=FALSE`, `CorrectCarryover=TRUE` | 24 / **18** / 5 | 5 | **12** | **`ClosedRevisionImmutable` 違反**（片方のみ先行公開） |
| **危険モデル 3** (古い繰越元公開) | `BrokenOldCarryover.cfg` | `CheckGen=TRUE`, `Atomic=TRUE`, `CorrectCarryover=FALSE` | 24 / **18** / 5 | 5 | **12** | **`ConsistentCarryover` 違反**（2025新版と繰越参照の不一致） |

---

## 4. 詳細な反例トレースの分析

### 4.1 危険モデル 1: 世代確認欠落による当年実績の喪失 (`BrokenStalePublish.cfg`)

```
State 1: <Init>
  rev25 = 1, rev26 = 1, records26 = {"r1"}, historyCommittedRecords26 = {"r1"}, phase = "idle"
State 2: <BeginAmend2025>
  phase = "amending25", staged25 = TRUE
State 3: <Stage2026Carryover>
  phase = "staged26", observedRev25 = 1, observedRev26 = 1,
  stagedRecords26 = {"r1"}, stagedCarryoverRef = 2
State 4: <Append2026>  <-- 並行操作: 2026年に "r2" が新規追加される！
  rev26 = 2, records26 = {"r1", "r2"}, historyCommittedRecords26 = {"r1", "r2"}
State 5: <ValidateCandidate>
  phase = "qualified", qualified = TRUE
State 6: <PublishCandidate>  <-- 世代確認をスキップして公開！
  rev25 = 2, rev26 = 3, phase = "published",
  records26 = {"r1"}  <-- 古い候補で上書きされ、"r2" が消失！
```
- **検出**: `historyCommittedRecords26` (`{"r1", "r2"}`) が `records26` (`{"r1"}`) の部分集合でなくなり、不変条件 `PreserveCurrentYear` 違反を捕捉。

### 4.2 危険モデル 2: 非アトミック公開による不整合 (`BrokenAtomicPublish.cfg`)

- **トレース要約**: `PublishCandidate` 実行時に `AtomicPublish = FALSE` のため、2025年のみ `rev25 = 2` に更新され、2026年は `carryoverRef26 = 1` のまま `phase = "half_published"` に遷移。
- **検出**: `ClosedRevisionImmutable` (`(rev25 = 1) \/ (rev25 = 2 /\ carryoverRef26 = 2)`) 違反。

### 4.3 危険モデル 3: 古い繰越元の公開 (`BrokenOldCarryover.cfg`)

- **トレース要約**: `Stage2026Carryover` で新しい2025年リビジョン2ではなく旧リビジョン1を参照したまま候補を作成し、そのまま公開。
- **検出**: `phase = "published"` において `rev25 = 2` かつ `carryoverRef26 = 1` となり、`ConsistentCarryover` (`carryoverRef26 = rev25`) 違反を捕捉。

---

## 5. 安全モデル (`Safe.cfg`) における競合解決メカニズム

安全モデルでは、State 4 で並行記帳 `Append2026` が発生して `rev26 = 2` となった後：
1. `PublishCandidate` はガード `observedRev26 = rev26` (1 = 2) が偽となるため**発火不能**。
2. 代わりに `RejectStaleCandidate` が発火：
   - 候補（`staged25`, `staged26`, `qualified`）を破棄し、`phase' = "rejected"` に遷移。
   - 現在の公開データ（`records26 = {"r1", "r2"}`）は**一切変更されずに保全**される。
3. `RestartAmendAfterReject` により、最新の `rev26 = 2` を観測して最初からやり直す（Re-stage & Re-validate）パスへ戻る。
4. これにより、全67状態の網羅探索において一度も当年実績が失われず、繰越参照も整合することが確認された。

---

## 6. 保存方式側に残る課題（年度別S式 vs SQLite の比較）

### 6.1 年度別S式の実装で最低限必要になる保存機構

TLA+ v0.2で検証された「OCCによる拒否」と「一体公開」を実ファイルシステム上で満たすには、以下の機構が不可避です：

1. **単一マニフェスト（HEAD / Manifest）による世代ポインタ切り替え**:
   - OSには「複数ファイルを同時にアトミックにrenameする」機能は存在しない。
   - `2025.sexp` と `2026.sexp` を個別に rename すると、電源断で必ず片方だけ更新された状態（`BrokenAtomicPublish`）に陥る。
   - したがって、有効な各年度ファイル名・世代番号を記録した `manifest.sexp` を単一の `atomic rename` + `fsync` で切り替える二層構造が必須。
2. **CAS (Compare-And-Swap) ガード**:
   - マニフェスト内に各年度の単調増加世代番号を保持し、書き込み時に読み取り時点の世代番号と一致することを確認。
3. **孤立テンポラリファイルの復旧・GC**:
   - 書き込み途中でクラッシュした場合に、未コミットの `*.tmp` を安全に破棄し、マニフェストが指す世代のみで起動するフェイルクローズ機構。

### 6.2 SQLiteに任せた方が合理的な部分

| 観点 | 年度別S式（自前実装） | SQLite採用時 |
| :--- | :--- | :--- |
| **複数年度のアトミック更新** | 自前の二重rename＋マニフェスト＋fsync順序制御が必要 | `BEGIN TRANSACTION; ... COMMIT;` の1行でDBMSが完全保証 |
| **並行記帳との競合制御** | 自前でCASループとリトライロジックを実装 | WALモード / `BEGIN IMMEDIATE` による分離レベル制御が可能 |
| **電源断・部分書き込み耐性** | OSごとのfsync挙動の差異や破損検知を自前テスト | ロールバックジャーナル/WALと `integrity_check` が標準装備 |
| **保守・実装コスト** | 低レイヤのファイルシステム保証を自前で抱え込む | 既製の実証済みストレージエンジンに委ねられる |

### 6.3 結論

S式の利点である「人間可読性・テキスト管理・可視性」を活かす場合でも、年度ファイル単独の素朴なrenameでは整合性を維持できません。**「年度別S式 ＋ 単一マニフェストファイル」** の構成が最小要件となります。
一方、トランザクションやクラッシュ耐性の保守負担を最小化したい場合は、SQLiteが極めて合理的な代替候補となります。
