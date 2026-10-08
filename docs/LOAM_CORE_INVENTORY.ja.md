# LOAMコアの設計資産・日本語棚卸し（調査第1版）

調査基準：LOAM `f82f4c45498ce9b3c51a76acb7189588a5f74718`、2026-10-08。GitHub上の**ソース／文書の読取調査**であり、この棚卸しのためにLeanビルド、定理の再検証、Alloy/TLA+/SPINやCIを実行したわけではない。

目的：**LOAMで得られた不変条件、独立した情報の境界、拡張時の反例を、Bakhloに継承すべき設計資産として記録する。** 未来の機能を一斉に実装するためのロードマップではない。Bakhloで実装済みかどうかは [機能・保証台帳](CAPABILITY_LEDGER.ja.md) で別に管理する。

## まず保証の意味を分ける

| 調査ラベル | 何が確かめられたか | 言えないこと |
| --- | --- | --- |
| **Core実装** | 現行のLeanコードに型・構築・演算・局所検査がある | どの値も自動的に家計正データとして許可されるわけではない |
| **Application実装** | 特定の問いに必要な複数の事実や境界を検査する実装がある | 別の問い・完全なUI・実運用保存まで成立するわけではない |
| **Lean局所定理** | 指定した仮定のもと、明示された命題の証明がソースにある | システム全体が正しい、再検証を今回実行したという意味ではない |
| **限定モデル・反例** | ある有限モデル／具体例が区別や設計候補を示した | 全入力・全実環境の万能性や本番機能の完成は示さない |
| **製品経路** | LOAMのAuthority/Publisher/Review/TUIにつながる経路を確認できた | あらゆる故障やデータ移行に対する無条件保証ではない |
| **未決・未選択** | 研究の問い、反例、欠けた情報が特定された | 実装予定、必須の新Core型、すでに解決した事柄ではない |

**単独の「完全」「証明済み」「株式対応」という表記は禁止。** 何をどの前提・道具・対象範囲で確認したかとセットにする。

## 1. Coreのファイル全数を、意味のまとまりで分類する

`Loam/Core/` の **41個のLeanファイル**を次の9群に分類した。分類はこの棚卸しの見出しであり、ソースの物理移動やCore型の統合提案ではない。

| 群 | 数 | モジュール |
| --- | ---: | --- |
| 数量・座標・保持の基礎 | 8 | `Quantity`・`Measure`・`Effect`・`Event`・`EventMemory`・`BalancedMovement`・`FiniteKeyed`・`HashNodup` |
| Actualの訂正・日付・返金・付随根拠 | 10 | `ActualEvidence`・`EventCorrection`・`EventCorrectionMemory`・`ActualValidity`・`ActualValidityHistory`・`ActualReversal`・`ActualReversalBalance`・`EventDescription`・`EventMerchantEvidence`・`MovementOperationEvidence` |
| 異種Measureと表示原額 | 2 | `ExchangeEvidence`・`OriginalAmountEvidence` |
| 関係・精算 | 3 | `ExternalParty`・`OpenRelation`・`Settlement` |
| 予定の独立性と終了 | 4 | `Scheduled`・`ScheduledMemory`・`ScheduledTerminal`・`ScheduledRouting` |
| 配分・分類の時間性 | 7 | `Purpose`・`Capacity`・`CapacityMemory`・`CapacityEffective`・`CapacityEvidence`・`RoutingEffective`・`HistoricalRouting` |
| 残高根拠のうちCoreのもの | 3 | `ZeroOriginCoverage`・`OpeningSupport`・`BoundedHistorySupport` |
| 会計役割・新規記帳許可 | 2 | `AccountingRole`・`LocusAdmission` |
| 注意事項 | 2 | `Attention`・`AttentionMemory` |
| **合計** | **41** | すべて現行Coreディレクトリに所在 |

**重要な境界：** `CurrentQuantityAnchor`、`CurrentQuantityPresence`、`MovementAdmission`、`SettlementFrontier` などは `Loam/Application/` の意味論であり、`Loam/Core/` というディレクトリだけで拡張能力を評価してはいけない。LOAMの `Application/` は別に **35ファイル**ある（この時点の目録）。

## 2. 継承候補となる不変条件・境界

| ID | LOAMで実際に確認できた意味 | 現在の所在・根拠 | 重要な適用限界 |
| --- | --- | --- | --- |
| K01 | `Quantity` は符号付き無制限精度の整数quanta。浮動小数・比率・丸めはCoreの前提ではない | [Quantity](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/Quantity.lean) | 通貨の小数桁・表示・税計算の丸めは別 |
| K02 | `Measure` は通貨や株式に固定しないID。同一Measureの加算は型付き、外部入力の異なるMeasureは自動加算しない | [Measure](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/Measure.lean) | 複数Measureを単一金額に換算する評価根拠は別 |
| K03 | `Event` は種類・日付・役割を内蔵しない。`Effect`は座標と量を保ち、後で参照する必要のあるEffectのみ安定したkeyを持てる | [Event](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/Event.lean)・[Effect](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/Effect.lean) | 全Eventがbalancedでも、Effectの配列順が時系列でもない |
| K04 | `BalancedMovement` は一つのMeasure内で正負量の合計=0を構築時の証拠として持つ。物理移動とCapacityは代数を共有できる | [BalancedMovement](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/BalancedMovement.lean)・[Capacity](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/Capacity.lean) | 配分と預金残高は同じ意味にはならない。空リストは代数的にゼロでも実用記帳の許可ではない |
| K05 | 履歴の保持・訂正前線・有効日訂正・物理的な反転は別の情報 | [EventCorrection](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/EventCorrection.lean)・[ActualValidityHistory](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/ActualValidityHistory.lean)・[ActualReversal](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/ActualReversal.lean) | 反転は元Eventを削除しない。分岐・合流訂正を勝手に採用しない |
| K06 | 出来事の説明、Merchant/非Merchant/未指定、記帳操作IDはEventの物理量ではない | [EventDescription](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/EventDescription.lean)・[EventMerchantEvidence](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/EventMerchantEvidence.lean)・[MovementOperationEvidence](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/MovementOperationEvidence.lean) | 名前からMerchantや決済・同一取引を推測しない |
| K07 | 両替は別Measureの出所・受取Effectを選ぶ独立証拠 | [ExchangeEvidence](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/ExchangeEvidence.lean)・[ExchangeAdmission](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Application/ExchangeAdmission.lean) | 両替レート、市場時価、取得原価、税務上のbasisを自動生成しない |
| K08 | Relationの発生量・債権債務方向・後日の消し込み量・残額を区別 | [OpenRelation](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/OpenRelation.lean)・[RelationDischargeFrontier](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Application/RelationDischargeFrontier.lean) | Relationの訂正・撤回の一部は研究のみ。単なる後続Eventは消し込み証拠ではない |
| K09 | Settlementは独立した決済Measure・Quantity、現物対応、相殺、非決済での消滅、改訂を保持できる | [Settlement](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/Settlement.lean)・[SettlementFrontier](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Application/SettlementFrontier.lean) | Coreの生データは未検査。Applicationによる整合性検査を通した範囲だけ採用 |
| K10 | ScheduledはActualと別。実績化・後継置換・終了を明示し、保存則の計算のみ共有 | [Scheduled](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/Scheduled.lean)・[ScheduledTerminal](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/ScheduledTerminal.lean) | 予定がない=義務がない、という完備性は導けない |
| K11 | Purpose/Capacity/履歴ルーティングは物理量と独立。未分類と明示的管理外を区別し、適用日順で判定 | [HistoricalRouting](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/HistoricalRouting.lean)・[RoutingEffective](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/RoutingEffective.lean) | 予算残額やPurposeは財布内の現金と同じものではない |
| K12 | 残高を答えるには独立根拠が必要。ゼロ起点・明示的開始Event・正確な現時点観測・金額不明だが非ゼロ・期間内履歴完備を区別 | [ZeroOriginCoverage](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/ZeroOriginCoverage.lean)・[OpeningSupport](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/OpeningSupport.lean)・[CurrentQuantityAnchor](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Application/CurrentQuantityAnchor.lean)・[CurrentQuantityPresence](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Application/CurrentQuantityPresence.lean)・[BoundedHistorySupport](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/BoundedHistorySupport.lean) | 残高が不明なときにゼロにしない。複数根拠の重なりも勝手に優先判定しない |
| K13 | 会計Roleと新規Effectの書込許可語彙は別。保存済みの歴史に現れたLocusが新規書込可能とは限らない | [AccountingRole](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/AccountingRole.lean)・[LocusAdmission](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/LocusAdmission.lean) | Locus名、支出符号、表示設定から会計Roleや権限を推測しない |
| K14 | Attentionの「期限なし／未決定／確定」と「未解決／解決／破棄」をそれぞれ区別 | [Attention](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Core/Attention.lean) | Attention間の来歴関係は研究段階 |
| K15 | 家計正データの世代、writer ownership、前世代の回復・未知セクション保存が意味論とは別の権限境界 | [HouseholdAuthority](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Authority/HouseholdAuthority.lean) | 特定ファイル構成やPublisher実装をBakhloのCoreへそのまま移植する必要はない |

## 3. 実際の「証明」と「限定観測」の代表

| 種別 | 代表例 | その範囲 |
| --- | --- | --- |
| Leanの証拠付き構築 | `BalancedMovement.balanced`、`totalQuanta_zero` | **その値**の符号付き合計が0。全実際の取引が保存則を満たすことではない |
| Leanの局所定理 | `SomeAmount.add?_sameMeasure`、`ActualReversal.exactPhysicalInverse?_eq_true_iff` | 同Measureの加算、物理的反転の選択した法則 |
| Leanの表現等価性 | `FiniteKeyed.hashIndexBy_get?_eq_findBy?`、`HistoricalRouting.statusAt_perm` | 該当する検査・検索が列順や高速化で意味を変えない |
| 実装内の境界検査 | `SettlementFrontier`、`MovementAdmission`、`CurrentSupportRouting` | 問い・世界・根拠が一致した範囲だけ受け入れ、拒否する |
| 常設の証拠選択 | [DurableProofs](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/DurableProofs.lean) | 永続的に保持したい局所証明を束ねる。全Coreの完全証明ではない |
| 広い観測・反例 | [Evidence Atlas](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/docs/EVIDENCE_ATLAS.md)・[Falsification Progress](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/docs/research/falsification/LOAM_FALSIFICATION_PROGRESS.md) | Lean/Alloy/TLA+/SPIN等の特定問題への結果。今回の調査では実行していない |

**反例候補200件**（F001〜F200）は照合済み。ただし [Falsification Progress](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/docs/research/falsification/LOAM_FALSIFICATION_PROGRESS.md) では、多くが `REVIEWED / UNTESTED / RESEARCH_ONLY` のまま。「200件をすべて証明・実装した」とは言わない。

## 4. コアの拡張性を実際に攻撃した研究（重要）

| ID | 調べた対象 | 得られた限定的な結果 | 製品化状況 |
| --- | --- | --- | --- |
| E01 | **保守的拡張** | 新しい独立証拠を追加しても、元のEventや既存の問いを同じ意味のまま保てる構成を確認 | [Application 006](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/experiments/application_006_conservative_fact_extension.md)。単独の実行証拠は卒業・Git履歴へ |
| E02 | **株式買付と両替の衝突** | 同じ2Measureの符号形状でも、Exchange証拠を流用すると証券買付が両替レポートへ混入する | [Observation 345](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Observations/Observation345.lean)。現行製品の証券受入は未対応 |
| E03 | **取得→保有→売却** | 中立Event/Effectに取得原価・売却来歴を足すと、売却元により実現損益が変わる選択例を構成できる | [Observation 346](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Observations/Observation346.lean)。研究用の縦断モデル |
| E04 | **同じ形だが違う意味** | 両替・証券売買・株式分割は機械的検査を共有できるが、意味上の権限を統合できない | [Observation 347](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Observations/Observation347.lean) |
| E05 | **1対多・多対1の異種Measure** | `Effect.measureTotals` はスピンオフや合併も数量表現できる。残差の符号だけでは正当なEventとは認定できない | [Observation 348](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Observations/Observation348.lean)。入場規則は別 |
| E06 | **ロットと取得元の継続性** | 部分売却、移管、分割、統合、外部証券会社のロットIDはそれぞれ独立情報を要求し得る | [Lot比較](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/docs/research/external-pressure/LOT_CONTINUITY_OBJECT_VS_PROVENANCE_GRAPH_2026-09.md)・[Observation 292](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Observations/Observation292.lean) |
| E07 | **平均取得原価と丸め** | 取得原価、FIFO型の来歴、平均原価の選択政策、正確な分数、丸めの位置は別の情報 | [Observation 349](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Observations/Observation349.lean)・[Observation 350](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Observations/Observation350.lean)。税務方式の全適用範囲を認定しない |
| E08 | **過去に提出した損益と現在の再計算** | 元の申告内容と、訂正後の取得原価に基づく値は自動的に同一化されない。明示した申告訂正が必要 | [Observation 358](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Observations/Observation358.lean)。本番の申告機能なし |
| E09 | **Coreの非家計利用** | 現在の基本型で書籍在庫の移動や、保存則のない葉の数の観測も表現できる。一方「文書の派生」は専用の関係が別途必要 | [PhysicalInventory](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Examples/PhysicalInventory.lean)・[ScientificObservation](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Examples/ScientificObservation.lean)・[DocumentProvenanceBoundary](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/Loam/Examples/DocumentProvenanceBoundary.lean) |
| E10 | **新しい情報 vs Coreの形そのものの欠陥** | 独立した型を追加すれば選択した反例に対応できるケースを確認。選択した圧力試験で**必須の既存Core形状変更**は立証されなかった | [Concept Pressure](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/docs/research/falsification/LOAM_CONCEPT_PRESSURE_SELECTION_2026-09.md)。将来の全ケースで安全という主張ではない |

## 5. 実装済みではないものを明記

- 株式・ロット・取得原価・FIFO/平均法・企業行動・税務処理を統合した**製品レベルの証券会計**。
- 正式な他通貨建て総資産評価、汎用FX時価・レート出所・残差／丸め・税務損益の**製品上の完全な体系**。
- すべての業務で使える汎用予約／オーソリ保留、未確定金額義務、企業会計の認識・申告確定・監査ワークフロー。
- あらゆる補助証拠から自動的に資金残高や履歴完全性を再構築する能力。
- すべてのソースコード・ユーザー操作・永続化経路を包含する単一の形式的正当性証明。

[Accounting Capability Audit](https://github.com/shumoku88-bit/loam/blob/f82f4c45498ce9b3c51a76acb7189588a5f74718/docs/research/ACCOUNTING_CAPABILITY_AUDIT_CHECKPOINT_2026-09.md) の当時の分類は重要だが、**2026年9月時点のスナップショット**。後続の実装や観測を無視した現在機能表として転用しない。実装範囲を主張する際は必ず現行Production経路を再確認する。

## 6. Bakhloへ引き継ぐ際の判断基準

1. **保持する意味：** K01〜K15のうち、対象の家計機能が実際に依存する不変条件と境界。LOAMのファイル配置や型名は保存対象ではない。
2. **使うとき初めて実装：** E01〜E10の反例と未決条件を読み、実際の生活の問いを満たす最小の独立証拠だけを加える。
3. **勝手に同一視しない：** 類似したデータ型や処理形状は意味論の同一性を保証しない。ExchangeとSecurityTrade、ActualとScheduled、現金とCapacityが代表例。
4. **再度確かめる：** LOAMのLean定理や限定反例は設計上の根拠。BakhloのOCaml型・検査・保存・UI・障害時挙動への自動保証にはならない。
5. **どの段階か明示：** 原則／限定観測／Core実装／Application検査／Daily保存／TUI／運用認定を別々に管理する。

調査の第1版はCoreとApplicationの主要な意味の境界と代表研究を対象とする。全研究・全Publisher・全CIの一件ずつの実行監査はしていない。既存の研究資料をBakhloの新たな実装義務としない。
