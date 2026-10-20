# Bakhlo 年度別正データ研究 成果棚卸し・整理・保全レポート

> **廃止（2026-10-20）**: 年別S式・`Year_read`・Recordsはユーザー判断で削除した。この文書は経緯の記録で、現在の方針はAGENTS.mdの Storage direction と[長期保存調査の第5段階](../LONG_TERM_STORAGE_STUDY.ja.md)。

状態: **TLA+形式検証および年度別S式合成実験の成果確定・保全記録**  
ブランチ: `research/canonical-storage-checkpoint`  
作成日: 2026-10-13  

---

## 1. 研究の目的と概要

本研究は、Bakhloの正データ保存方式において、従来の単一S式（Monolithic `Daily_book`）を**暦年（暦年別S式）ごとに分割保存する設計**について、以下の2軸で検証を行った記録です：

1. **TLA+ による並行更新・年度間整合性の形式検証**:
   - 過年度訂正（2025年修正）と当年記帳（2026年新規記帳）が競合した際に、楽観的同時実行制御（OCC）によって当年の記帳消失を防ぎ、一体公開の整合性を保てるかを TLC モデル検査で検証。
2. **OCaml 合成実験による意味論・拒否条件の維持検証**:
   - 物理分割しても既存 Core（`bakhlo_domain`, `bakhlo_application`, `bakhlo_sexp`）と同じ家計上の意味、数量回答、および入場拒否条件が維持できるかを、**C方式（根拠付き期首繰越 `CarryForward` ＋ 必要時のみ過年度を参照する `CrossYearResolver`）** を中心に検証。

> [!NOTE]
> 本研究は意味論・整合性の検証であり、正式な保存形式の採用や本番ストレージエンジン（SQLite, Irmin, manifest, 原子的リネーム, GC等）の実装ではありません。本体 Core・TUI・本番データには一切触れていません。

---

## 2. 研究資産の棚卸し一覧

| 資産パス | 目的 | 確認された性質 | 検査方法 | 限界 | 後続実験との関係 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `formal/bakhlo-yearclose-v01/` | 年度締め・年度間公開の基本モデル検査 | `ConsistentSelection` 充足（Safe）、片方公開で不整合反転（Broken） | TLC (Java 21, TLC2 v2.19), Python shadow probe | 不変条件の一部が自明成立（vacuous）、FailClosedRecovery未定義、クラッシュ時の揮発フラグ残留 | v01-audited へ改訂 |
| `formal/bakhlo-yearclose-v01-audited/` | v01 の監査と不変条件の厳密化 | クラッシュ復旧の健全化、空疎不変条件の特定 | TLC モデル検査 | 2026年の実績が単なる件数（`existing2026 = 1`）で、並行記帳消失を捉えられない | v02 へ発展 |
| `formal/bakhlo-yearclose-v02/` | 過年度訂正と当年新規記帳の競合検証 | 世代確認欠落時の記帳消失検出、非アトミック公開の反例、古い繰越元の公開反例 | TLC モデル検査（Safe 1件、Broken 3件） | 抽象モデルの一体公開であり、実ファイルの rename/fsync/電源断耐久性は未保証 | C方式合成実験の整合性要件の基礎 |
| `test/year_partition_study_tests.ml` | 暦年物理分割の可逆性と選択読込の基礎検証 | 素朴分割の入場拒絶（`unknown-plan-payment`, `entry-admission`）、再結合での完全一致、同封参照閉包での一致 | Dune expect-test (`year_partition_study_tests.ml`) | 2026年に2025年原本を複製同封するA方式であり、過年度訂正時の整合性同期が困難 | C方式プロトタイプ（B/C方式比較）へ展開 |
| `test/year_partition_c_study_tests.ml` | C方式（CarryForward＋Resolver）のメモリ合成試作 | 普段の残高照会での2025年スキップ、過年度反転・跨年度予定の遅延抽出、二重計上防止（root cut）、前年訂正での失効拒絶 | Dune expect-test (`year_partition_c_study_tests.ml`) | インメモリ合成のみで、S式文字列としての永続化・再起動後の復元が未検証 | 永続化境界実験へ展開 |
| `test/year_partition_c_persistence_study_tests.ml` | C方式の永続化境界とコールドスタート復元 | S式保存・再読込でのカテゴリカル残高完全復元、`plan-discharge`方式の優位性、コールドスタートからの完全一致、Fail-Closed検査 | Dune expect-test (`year_partition_c_persistence_study_tests.ml`) | 単一プロセス内の文字列再構築であり、ファイルシステム障害や電源断は対象外 | 本棚卸し・保全 |
| `docs/archive/YEAR_PARTITION_STUDY_RESULTS.ja.md` | 初期合成意味検証実験の記録 | 素朴分割の入場拒否理由、Lossless Partition、Selective Read、年金サイクル比較の記録 | 文書記録 | C方式や永続化境界の成果を含む前の初期記録 | 本インベントリ文書で補完・統括 |

---

## 3. 研究の到達点と暫定判断

1. **暦年別S式を第一候補として維持**:
   - 1年ごとに独立したS式ファイルを持ち、年度単位でアーカイブ・管理する構造は、Bakhloの可読性・監査性・可搬性と最も調和する。
2. **C方式（Qualified CarryForward + CrossYearResolver）を有望と判断**:
   - A方式（過年度の複製同封）のような正データの重複がなく、B方式（全歴史再結合）のような年数経過に伴う肥大化もない。
   - 普段は O(1) 年分の読み込みで完結し、過年度参照時のみピンポイント抽出する設計が成立することを実証。
3. **CarryForward は「導出支持情報」であり独立観測ではない**:
   - 前年の確定台帳から `Exact` / `Zero_origin` / `Known_present` / `Unknown` を厳密に導出して保持する。
   - 勝手にゼロ原点を捏造せず、前年で支持されていない未知（`salary eur`）は未知として引き継ぐ。
4. **跨年度予定完了は独立した `plan-discharge` 方式を第一候補とする**:
   - 2025年の原本を一切変更せず、2026年の `entry` 型も変更しない。
   - 2026年の正データに `(plan-discharges (discharge (plan ...) (by ...)))` を持たせることで、完了関係の唯一の権威を確立し、既存の `paid_by` との二重の権威を作らない。
5. **Core への第5支持構造の追加は保留（Core外のアプリケーション境界を優先）**:
   - Core に `(carry-forward ...)` を追加改修するのではなく、Core外の検証済み Resolver / Loader がエフェメラル台帳を合成するアーキテクチャが成立。
   - Core の責務を「単一宇宙での無矛盾計算」に純化させたまま保つことが可能。
6. **SQLiteへの移行判断は保留**:
   - 年度別S式＋C方式の境界が成立したため、現時点でSQLiteに移行する必然性は高くない。
7. **未認定事項（合成実験の成功を本番品質と混同しない）**:
   - **manifest、原子的公開、ファイルシステム排他制御、fsync、GC、電源断耐久性は未認定**。

---

## 4. 報告精度の監査と是正

過去の実験報告における表現や測定値について、以下の通り精度を監査・是正します。

1. **参照閉包の「1件論理抽出」と「実ファイル読込・パースコスト」の区別**:
   - 「1件のみ抽出」というのは、合成台帳のセマンティクス（エフェメラル台帳に組み込むエントリー数・予定数）が1件で済むという意味である。
   - 現行の実装では、前年S式ファイル全体を `B.of_string` でパースした上で `B.find_entry` しているため、**現時点のファイルI/Oおよび構文解析のコストは前年ファイル全体分が発生している**。
   - 将来的にS式ブロックのインデックス化や軽量スキャンを導入しない限り、ディスクI/Oとパース自体はファイルサイズに比例する。
2. **「O(1)」の主張の厳密な定義**:
   - O(1) とは、**過去の経過年数 $N$ に対するスケーリング**を指す（10年前、20年前の全ファイルを読み直す必要がない）。
   - 単一年度のファイルサイズやエントリー数に対する探索コストが O(1) であることを意味しない。
3. **I/O削減率（約39%〜42%）の測定条件**:
   - これは本実験で用いた小さな合成台帳（2025年約1.3KB、2026年約1.1KB、CarryForward約360B）における実測比率である。
   - 実際の家計簿データ（年間数千件、数百KB）における削減率は、年間の取引量や過年度参照の頻度によって変動する。
4. **Fingerprint（MD5ダイジェスト）の目的と限界**:
   - 本試作で用いた `Stdlib.Digest` (MD5 hex) は、**前年台帳の不慮の更新・編集の検知（世代整合性の確認）** を目的とした軽量識別子である。
   - 暗号学的な改ざん耐性や攻撃者に対する真正性証明を提供するものではない。ハッシュ値の一致のみで正当性を保証するのではなく、revision番号・基準日との複合チェックが前提である。
5. **TLA+ 抽象モデルと物理ストレージの厳密な分離**:
   - TLA+ で検証されたのは「観測世代の一致確認（OCC）を行えば、並行記帳の消失や不整合公開を防げる」という状態遷移の安全性である。
   - ディスクへの一時ファイル作成、rename による置換、電源断時の破損防止といった OS / ハードウェア層の耐久性を保証したものではない。
6. **Core の保持範囲と Resolver の追加保証範囲の分離**:
   - **Core が保証する範囲**: 単一台帳内における数量保存則、root cut による二重計上防止、台帳内での予定二重支払い拒絶、Reversal の同一台帳内相殺。
   - **Resolver が追加保証する範囲**: 前年世代の失効検知（`Stale_carry_forward`）、原本破損検知（`Fingerprint_mismatch`）、跨年度での予定二重完了拒絶（`Duplicate_discharge`）、エフェメラル台帳合成時の root cut 自動構成。
7. **コールドスタート復元と障害復旧の区別**:
   - コールドスタート復元実験は「メモリ状態を破棄して文字列から再構築できるか」を確認したものであり、書き込み途中の電源断やファイル破損からの自己修復（Journaling / WAL / Crash Recovery）を検証したものではない。

---

## 5. 次段階への研究課題定義

### 課題A：CarryForward の鮮度と信頼できる選択状態

- **背景**:
  普段2025年の全履歴を読み込まない場合、2026年の CarryForward が保持する `prior_revision: 1` が「現在の2025年の最新状態」と一致しているかを、どうやって高速かつ確実に検証するのか。
- **課題の論点**:
  1. 2025年ファイル全体を開かずに前年の最新 revision を知るための「軽量な選択状態（Manifest / Header）」の必要性。
  2. 選択状態が読み取れない、世代不一致、ハッシュ不一致、破損している場合に、**一切の推測を行わずに fail-closed で正常回答を拒絶する契約**。
- **最小合成実験計画**:
  - `prior_year_header`（年度、最新revision、fingerprintのみを含む極小S式）を模した入力を用意。
  - 2025年が rev 2 に更新された際、ヘッダーのみの参照で即座に `Stale_carry_forward` を検出し、2025年本体を開くことなく拒絶できるかを検証する。

### 課題B：跨年度予定完了の一意性と訂正耐性

- **背景**:
  2025年に作成された未払い予定 `p_2025_target` に対し、2026年と2027年で重複して discharge された場合や、2026年の支払い取引が後から訂正・反転・取消された場合、完了関係の有効性をどう判定するか。
- **課題の論点**:
  1. **複数年度での重複完了の検出**: 2026年と2027年の両方が同一予定の discharge を主張した場合、どちらを正とするか、あるいは不整合として両方拒絶するか。
  2. **支払い実績の取消に伴う予定の再オープン**: 2026年に支払った取引が 2026年内で Reversal された場合、当該予定は未払いに戻るべきか。
  3. **拒絶の局所性**: 跨年度予定の不整合が発生した際、台帳全体を拒絶するのか、当該予定に関連する回答のみを拒絶（または unknown 化）するのか。
- **最小合成実験計画**:
  - 2025年（予定作成）、2026年（支払い・discharge）、2027年（二重支払い・重複discharge）、および2026年内の反転取引を含む合成データを作成。
  - Resolver が複数年度の discharge 集合を突合し、一意性違反を検出して拒絶できるかを検証する。

---

## 6. 再現性の確認（実測記録）

### 6.1 Dune テストスイート
- コマンド: `opam exec --switch=. -- dune runtest`
- 実行結果: **全822テスト合格（Exit code: 0）**
  - `test/year_partition_study_tests.ml`: 8 expect-tests 合格
  - `test/year_partition_c_study_tests.ml`: 6 expect-tests 合格
  - `test/year_partition_c_persistence_study_tests.ml`: 5 expect-tests 合格

### 6.2 TLC モデル検査
- 実行環境: macOS 15.7.9, OpenJDK 21.0.12.1 (`/usr/local/opt/openjdk@21`), TLC2 v2.19 (`scratch/tla/tla2tools.jar`)
- コマンドおよび実測結果:

| モデル | 対象ファイル | 設定ファイル | 探索状態数 (Gen / Distinct / Queue) | 深さ | 終了コード | 判定結果 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **v01 Safe** | `YearClose.tla` | `Safe.cfg` | 72 / **44** / 0 | 11 | **0** | 合格（エラーなし） |
| **v01 Broken** | `YearClose.tla` | `Broken.cfg` | 22 / **18** / 4 | 6 | **12** | `ConsistentSelection` 違反捕捉 |
| **v01-audited Safe** | `YearCloseAudited.tla` | `Safe.cfg` | 51 / **32** / 0 | 11 | **0** | 合格（エラーなし） |
| **v01-audited Broken** | `YearCloseAudited.tla` | `Broken.cfg` | 22 / **17** / 3 | 6 | **12** | `ConsistentSelection` 違反捕捉 |
| **v02 Safe** | `YearCloseV02.tla` | `Safe.cfg` | 67 / **42** / 0 | 10 | **0** | 合格（エラーなし） |
| **v02 Broken (Stale)** | `YearCloseV02.tla` | `BrokenStalePublish.cfg` | 30 / **22** / 5 | 6 | **12** | `PreserveCurrentYear` 違反捕捉 |
| **v02 Broken (Atomic)** | `YearCloseV02.tla` | `BrokenAtomicPublish.cfg` | 24 / **18** / 5 | 5 | **12** | `ClosedRevisionImmutable` 違反捕捉 |
| **v02 Broken (Carryover)** | `YearCloseV02.tla` | `BrokenOldCarryover.cfg` | 24 / **18** / 5 | 5 | **12** | `ConsistentCarryover` 違反捕捉 |

---

## 7. 保全コミットと最終状態

- コミット対象ファイル:
  - `docs/archive/YEAR_PARTITION_RESEARCH_INVENTORY.ja.md` (本インベントリ文書)
  - `docs/archive/YEAR_PARTITION_STUDY_RESULTS.ja.md`
  - `formal/bakhlo-yearclose-v01/`
  - `formal/bakhlo-yearclose-v01-audited/`
  - `formal/bakhlo-yearclose-v02/`
  - `test/year_partition_study_tests.ml`
  - `test/year_partition_c_study_tests.ml`
  - `test/year_partition_c_persistence_study_tests.ml`
- 除外対象: `scratch/tla/tla2tools.jar` (gitignore対象), 本番データ, 秘密情報
- ブランチ: `research/canonical-storage-checkpoint`
- リモートへの push / PR作成 / merge は未実施（ローカルコミットのみ）。
