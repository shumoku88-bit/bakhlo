# Bakhlo → LOAM 帰還可能性: 合成・限定検証（2026-10-19）

**状態:** Phase 1 のプローブ。LOAMへの正式移行・正データ書込・完全往復試験ではない。
**対象:** Bakhlo `main` から派生した試験ブランチの `test/loam_return_probe_tests.ml`。
**原則:** Bakhlo/LOAMの実家計データ・正データ・秘密設定には触れない。合成データ以外を入力にしない。

## 問い

Bakhloを日常のauthorityに移した後、Bakhloで追加した記帳を、保全済みのLOAM householdへ**一度だけ**戻せるか。
「残高の再入力で新しいLOAMを始める」と「過去のLOAM履歴に継続記帳を接続する」は異なる問題。

## 既存の接続口（直接ソース確認）

- Bakhlo: `sexp/daily_book.mli` の `entry` はID/日付/optional memo/全Effects/反転/両替/原額/merchantを持つ。
  `plan` は `paid_by` / `cancelled_on` を持つ。単なるEvents一覧への縮約は情報を失う。
- LOAM: `Loam/Cli/Movement/Proposal.lean` は `LOAM-MOVEMENT-PROPOSAL<TAB>2` を読み、
  `operation`、`date`、`description`、`effect` を受け取る。
- LOAM: `Loam/Cli/MovementProposalRecordCli.lean` は `HouseholdCommand.recordIdempotent` 経由で
  writer-owned publication を実行する。操作IDは再送防止IDであり、元Bakhlo Event IDの継承ではない。
- LOAM: `Loam/HouseholdCommand.lean` は通常Movement以外にもExchange、Scheduled、
  Cancellation、Reversal、Merchant、OriginalAmount等の**別**publisherを持つ。

## Phase 1: 実施できる検査

`test/loam_return_probe_tests.ml` はBakhloの実際の `Daily_book.empty`、
`add_locus`、`put_entry`、`to_string`、`of_string` を用いて正規化後の合成1件を得て、
単純な単通貨・保存済み・均衡MovementのLOAM v2提案**形状**を作る。
出力のquanta/順序/日付/description/操作IDを静的契約と照合する。

プローブは意図的に、反転参照、両替、原額、merchant分類、混合Measure、不均衡、
不正な輸送テキスト、受理外のkey、予定への支払いリンクがある明細を普通Movementとして
受け入れない。輸送形状は同一性・残高根拠・他のfamilyを運べないので、全家計移行成功としない。

**限定:** Bakhlo側のプローブはLOAM Leanパーサやwriterを実行しない。
テストの合格は「LOAMが受け入れた」でも「一度だけ正しく書いた」でもない。

## Phase 2: 実機で必要な最小E2E（未実施）

1. 2つのバージョン/commit SHAを固定。元LOAMを変更しない。
2. 新規合成LOAM householdを `loam init` で**試験用**未存在ディレクトリに作成。
3. 明示Locus admission/Measure scaleを行い、Bakhlo合成記帳1件をLOAM v2 proposalとして保存する。
4. LOAM CLIのread-only proposal review → `movement-proposal-record` で発行。
   同じoperationで再送し、Eventが増えないことをLOAMの正規再読込で確認。
5. Exact quanta、Locus/Measure、日付/摘要、Current Balancesの独立根拠を個別に照合。
   「同じ合計」だけでは合格にしない。
6. 未サポートの独立情報は**書込前に拒否**。データも運用権威も暗黙には切り替えない。

## Phase 3: 旧LOAM履歴への接続（未実施）

- 切替時点のLOAM snapshotを固定し、Bakhloの**切替以降**だけの差分を定義する。
  Bakhloへ取り込んだ旧LOAM Actualを再投入しない（重複防止）。
- Bakhloの新entry ID ↔ LOAM publisherが割当てたEvent ID、idempotency operation、
  Scheduled plan ↔ Actual、Reversal targetの対応表が必要。ID一致を推測しない。
- 切替**前**のLOAM EventをBakhloで訂正した場合、差分の単純追加では戻せない。
  正規の訂正処理か、明示した移行制約が必要。
- Bakhloが保持しない旧LOAM correction chainはLOAMのsnapshotで保全する。
  Bakhlo切替後の訂正履歴がBakhloで保存されていなければ、正確な旧履歴は復元不能。
- ZeroOrigin、OpeningSupport、CurrentQuantityAnchor/Presence、reflected cut、unknown、
  過年度繰越、Attention、各種設定の情報を補完推測しない。
- LOAMのMovement proposalだけでScheduled、Exchange、Merchant、OriginalAmount、
  Reversalや精算の復元を称さない。

## 切替条件の提案

本番のBakhloへの切替までに、最低でも「単純Movementの合成E2E」、
「旧LOAM snapshot + 新Bakhlo差分の参照・重複確認」、
「対応不能なfamilyを列挙して確実に止める検証」を通す。
さらに日常使用で必要なScheduled/支払リンク/数量支持について、
**情報保存か拒否か**を明示する。

この研究はLOAMを再び運用authorityにする許可ではない。
