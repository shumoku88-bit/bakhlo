# 正データの論理設計研究

状態: **研究中。新スキーマ・構文・保存方式は未採用。**

問いは「S式か行形式か」の前に、**何を独立して残せば、必要な家計の回答・訂正・復旧が成立するか**。
処理費用・30年間の増加・復元/移行・別実装への持ち出しを、その同じ情報で比較する。
通常の編集入口はTUI等。ユーザーはS式/行形式の読みやすさに大差を感じておらず、
手読み・手編集のしやすさを選定の主軸にしない。読取/診断可能性は補助条件として残す。
[意味の契約](SEMANTIC_CONTRACT.md)が制約を所有し、現行formatの意味は既存APIが所有する。
この研究が既存のcodec/admissionを変更するわけではない。正データは引き続きLOAM。

## 研究の順序

1. ユーザーが許可したLOAM正データ履歴のread-only棚卸しで、現在よく行う操作を把握する。
   現在の必要分を優先し、未使用の返金/精算機能を全部選択・実装することは先行条件にしない。
   LOAMの既存資産から既知の情報境界を引き継ぎ、新しい検証は表現変更の残差/OCaml接続に絞る。
2. 候補の論理構造を比べ、失う回答・拒否する操作・参照の保全方法を明示する。
3. 同じ論理情報をS式と行形式に表し、パーサ/検査の保守費、割当/メモリ、診断/移行を比較。
   手編集用の構文磨きや可読性の順位付けを独立した先行工程にしない。
4. 同じ操作・検査・同期・backup条件で長期の費用を測り、保存方式を選ぶ。
5. 最後にLOAMとの差を、パーサ保守だけでなく情報・操作・復旧まで含めて判断する。

[長期保存調査](LONG_TERM_STORAGE_STUDY.ja.md)は4の現行経路baselineを担当する。
現行S式の速度が遅いことだけで構文を捨てず、以前S式を選んだことだけで固定もしない。
意味/実装の検証は合成例と公開実装を使う。ユーザーは追加で、現在の操作の優先順を
LOAM正データ履歴から把握する限定的なread-only棚卸しを許可した。
その私的棚卸しは新しい停止captureで完了した。明細内容/件数/使用傾向はprivate scratchに
保管し、公開文書へ転記しない。LOAM起動中に原本を読まない原則は今後の再取得にも適用する。

## 生活操作から決める表（初稿）

この表は「どの根拠を潰すと後で困るか」を調べる拡張時の参照であり、全機能の先行設計表ではない。
**設計案は未採用。全行が必須という決定でも、実装済みの表でもない。**
優先順は実際の現在の操作から決め、未使用の追加機能は必要になってから実装する。
金額例はすべて合成。完了した私的棚卸しの結果はこの例へ混ぜず、実装優先順の別根拠として使う。
既存の[切替判定表](CUTOVER_CHECKLIST.ja.md)のR04（訂正）・R07（返金）・
S03（予定の支払い）を具体化する。保存schemaや新しい汎用relation型を先に作らない。

| 普段したい操作 / 例 | 現行LOAMの通常入口 | Bakhloの設計案（生活上の結果） | 残す根拠 / 未決定・拒否すること |
| --- | --- | --- | --- |
| 普通の入力ミスを直す。購入額1000を1200へ訂正 | 現在の普通の単一通貨明細なら訂正可。参照/反転等の制限あり | 同じ一件の現在内容を直す。訂正で新しい支払いが発生したとは扱わない | 一件の同一性、現在の全内訳、日付、通貨、独立残高支持。参照のない旧内容は必ずしも日常canonicalに全保存しない。換算・丸め・残高埋合せはしない |
| 支払い済みの入力ミスを直す。予定から記帳した180を190へ訂正 | 予定完了だけを理由には訂正を拒否しない。他の制限は同じ | 実績を直しても支払い対応と予定の完了を維持。二重払い・自動再openなし | 予定の元内容、明示した実績への完了対応、訂正後実績。単なる同額/同日やpaidフラグでは代用しない。現行Daily API/testにこの狭い操作の資産あり |
| 本当に全額が戻る。購入1000と返金1000を記帳 | 普通の現在明細のexact inverseを別実績＋Reversalとして発行。Relation/Discharge参照あり、予定完了の直接対応先、既に反転済み等は拒否 | 元の購入を消さず、返金の日付・口座・通貨・額を別明細で残し、元購入との対応を保持したい | Reversalを使う場合は量だけでなく全内訳の物理的逆であることが必要。返金先の口座が違うケースは別に要検討。純額0だけの一件へ潰さない。許可拡大は未採用 |
| 一部だけ戻る。購入1000に対し300の返金 | 300をexact Reversalにはできない。普通の新規取引として記帳できることと、元購入への正式な返金対応を持つことは別 | **将来候補**: 必要になった時に、購入1000と返金300を別に残し、元購入との対応を追加できるようにする | 購入を700へ訂正する操作とは分ける。差引700は派生値。一般の部分返金対応は現行Dailyの保存契約にない。摘要だけで対応済みとせず、未対応情報の変換/操作は拒否する |
| 立替・精算の後に元の入力ミスを直す | Relationの元明細・Dischargeに使った明細のEvent訂正/反転を拒否。精算済みでも保持参照があれば同じ | **将来候補**: 必要になった時に、支出・立替の負担・実際の精算を分けて編集範囲を決める。今は既存拒否を比較基準にする | 元posting/必要な元内容、関係量・方向/相手、実際の精算Eventと対応量。支出額の訂正だけで貸借や精算額を自動変更しない。現在の精算残額をこの未認定の重なりから推定しない |

ここで「返金」はお金が本当に戻ったこと。「取消」は予定の取り下げ、実取引の反転、
誤入力の訂正のどれなのかを区別する。商品返品の操作や意図だけから、まだ起きていない
返金の実績を作らない。複数回返金/過返金/手数料/外貨返金は、この300の例だけで認定しない。

### 表の操作がぶつかるところ

- **予定を支払った後に返金**: 現行LOAMのReversal入口は、予定完了の対応先に直接
  なっているActualを拒否する。将来の追加候補で、今の保存研究の完了条件にはしない。
  設計案は、購入と返金と予定完了を残し、返金しただけで予定を未払いへ戻さない。
  再び支払う必要があるなら別の明示操作/予定の話で、自動再openや再支払い許可にしない。
- **全額返金後に購入額の誤入力に気づく**: 元と返金の量を片側だけ書き換えると
  exact inverseが壊れる。いまは既存拒否を基準にする。実際の返金額まで「帳尻合わせ」で
  書き換えない。許可するなら固定元根拠と現在内容をどう分けるかを先に決める。
- **残高を確認済みの明細を訂正**: 確認した観測量と取り込み済み活動の対応はそのまま。
  訂正で取り込み済み分を再加算せず、観測そのものを自動変更しない。
  一方、特定Eventを開始根拠にした支持は、訂正で失効することがある。
  「観測に取り込み済み」と「このEventが開始根拠」は別で、後者の暗黙継承はしない。
- **日付だけが誤入力**: LOAMには独立した日付訂正があり、現在の日付付き明細なら
  relation/反転の存在だけを理由に止めない。金額訂正と一つの許可にまとめない。

LOAMのガードは直接Event IDの参照を検査する。correction系列全体へ同じ制限が
伝播することまでは、表の「拒否」から推論しない。ガードをすり抜けるID付替えを
設計上の許可や運用手順にせず、比較する対象と意味を明示する。

### 現在の必要分を先に、追加機能は必要になってから

ユーザーの方針は、**現在多く実行する操作がまずできればよい。追加機能は必要になってから。
その実装ができなくなる/不必要に難しくなる情報削減や境界の混同を、今の設計で避ける**。
予定返金・部分返金・精算後訂正を今すべて採択する質問や、全LOAM機能の設計を先行させない。
普通の訂正・支払い対応・観測済み活動の非二重計上は既存の設計/検証を引き継ぐ。
長期保存の要求は既知なので、現在よく使う操作の長期費用と安全性も最初から比較する。

「あとで実装しやすい」のために今守る境界は次の範囲に絞る。

- 一件のID・postingの出現/必要なkey、通貨とexact量を維持する。表示名や日付をidentityにしない。
- 実績、予定と完了対応、独立残高支持、元根拠を分ける。返金を減額訂正へ、対応をbadgeへ、
  元根拠を純額/残高へ潰さない。参照された根拠は使える形で保持する。
- 保存versionと明示的な移行を使い、現在の型/フィールドが永久に変わらないことを要求しない。
  原本・旧capture/候補を別に保全し、未対応情報は欠落なく保持するか変換/操作を拒否する。
  opaque保管だけで意味の認定や利用可能な対応が得られたとは言わない。
- 計算/参照検査とUI、ファイルpublicationを分ける。将来の対応を足す時は当該独立根拠と
  既存入場ownerを拡張し、画面や別の第二admission engineで意味を作らない。
- 拡張時に既存回答/拒否/restoreを確認できる合成oracleを残す。汎用plugin、全用途relation、
  空の将来フィールドや永久の全訂正chainを今作ることは、拡張余地の条件ではない。

これで未知の将来機能の容易な実装を保証するとは言わない。現在分の情報境界を保ち、
新しく独立した意味が必要になったら小さな型/入場/明示移行を追加できることが目標。
下のA/B/Cはこの同じ現在分で比べる。未使用の複雑な意味を全部解くまでは構文/保存研究へ
進めない、という進行条件にしない。writer/保存実装の許可を今回変更したわけではない。

### 私的な操作履歴棚卸しの範囲

今回のユーザー許可は、正データ履歴から現在の操作の優先順を把握するread-only分析。
原本の編集、再生、復旧、同期、operational cutoverの許可ではない。

- 全LOAMを閉じてから、新しい私的なcaptureで行う。停止確認と読取前後の安定性確認を使い、
  原本へ書かず、旧capture/試用編集を上書きしない。起動中は停止してもらうまで保留。
  既存captureを最新として黙って代用せず、古い時点を使う場合は明示する。
- 原本/結果/操作別の件数・比率もignored scratchへ権限を絞って保管。摘要・金額・相手先・
  家計ID/日付や私的件数を公開文書/fixture/commitへ転記しない。ユーザーへの報告は
  優先操作と確認限界を中心とし、明細内容を不要に出力しない。
- 新規実績、Event訂正、独立date訂正、予定作成/終端、明示Reversal、関係/精算、
  独立観測等を**保持された専用根拠で識別できる範囲**で数える。符号・摘要・同額だけで
  購入/返金/立替/予定対応を推定しない。unknown/未分類familyも保全して別に数える。
- 正データはUI操作ログではない。importされた歴史、現在画像だけに残る観測、閲覧、
  失敗した操作を区別できない場合は不明とする。回数が復元できない現在画像は
  「根拠あり」であって実行頻度ではない。保存行数をそのまま人間の操作回数にしない。
- 現在Dailyへ変換できないfamilyも棚卸し対象。Daily converterの成功を棚卸しの前提にして
  未対応行を除外しない。物理framing/専用codecの読取と家計全体のsemantic admissionは別。
  不明なversion/形状は分類不能として報告し、部分読取を全体認定や切替成功と呼ばない。
- 頻度は優先順の手がかり。未使用/少数だから既存根拠を削除せず、Daily Pace・残高等の
  既に必要とされた閲覧機能を操作履歴にないことだけで外さない。

新しい停止captureとbounded棚卸しは完了。私的根拠は
`scratch/operation-inventory-leEhTN`へ保全した。`CAPTURE_VERIFIED`は停止前後確認、
regular/bounded入力、読取前後と一括snapshotの安定性、排他的なコピー/byte-exact読戻しを記録する。
`details-v2/INVENTORY_COMPLETE`と`priorities.private.md`が検証範囲/優先操作/実装差分を所有する。
原本、過去capture/試用編集、UI比較のCURRENTは変更していない。

観測には既存`Envelope`/`Input`/`Actual_source`/`Read`と、既存私的Scheduled readerを使用した。
Scheduled完了のretained Actual参照閉包も確認した。Actual＋4支持のread profileの成功は
その限定範囲での結果で、Attentionはrow-shape棚卸しに留まる。他familyはbyte-exactで保全し、
全LOAM意味の入場・移行・切替を認定していない。Dailyへの変換成功を棚卸しの前提にしていない。

one-off観測コードは同じprivate scratchのみ。合成のUnicode/巨大量/複数Measure、
訂正とdate訂正の区別、予定の明示対応、malformed framing/未知をゼロ扱いしない検査を通した。
synthetic copy/readbackとsymlink入力の拒否も確認した。正常結果/途中成果を上書きせず保全した。
private入力をtest fixture/公開モデルへ移してはいない。

### 現在の表現を小さくする時の一般的な移行確認

私的な使用状況とは別に、公開codecだけから確認できる境界を使う。

- Scheduled lifecycle v1の`RETIREMENT`には取消日がない。Daily v3の`cancelled-on`へ移す時、
  予定日や移行当日を取消日として発明しない。閉じた状態を消してopenに戻したり、
  retired/replaced行を削除して全体移行成功と呼んだりしない。必要な未供給/不明の区別を残す。
- Scheduledの完了対象は現在terminalとは限らず、retained Actual Eventで解決される。
  現在行だけへの縮約では、入場済みcorrection系列から得た一件への対応を明示的に移す。
  同額・近い日付から補完しない。元に付いた完了を黙って失敗/未払いへ変えない。
- 同一entry IDへの内容置換は、特定EventへのOpeningSupportを維持する証明ではない。
  現在のsnapshot回答の一致と、次の訂正での支持失効/明示再支持の一致を分けて確認する。

これらは新しい返金/精算機能の設計ではなく、既存の意味境界を縮約/移行で守る義務。
現行format/APIをここで変更せず、必要な移行や拒否を曖昧にしたままauthorityを採用しない。

## LOAMの既存資産を前提にする

今回の意味境界はLOAMで既に広く検証されている。意味を一から再発見する研究ではなく、
**既存の契約・法則・反例を引き継ぎ、履歴を縮める表現との差分だけを検証する**。
以前のlocal tests/AlloyをLOAMで未知だった結果として扱わない。
OCaml実装への接続testには役割があるが、それは新しい家計意味の獲得とは別。

以下はsibling `loam`を置いた開発workspace向けの参照。
source確認時のLOAM HEADは`1e95e7a724b944a38945b71626ade0f71bffc066`。
既存研究記録はそれぞれの記載baseline/scopeで読む。この資産表の作成ではLOAMの
build/test/モデル再実行、sourceコピー、実データ読取をしていない。
追加で許可された私的棚卸しは上の別スコープで行う。既存Lean proofのstatementは資産として使うが、
そのままOCamlや新しいCの証明になるとは言わない。

| 既知の問い / 引き継ぐ結論 | LOAMの直接owner / 検証資産 | Bakhloで残る差分 |
| --- | --- | --- |
| 観測量と反映済みcutは独立。反映済みrootの訂正は再加算しない。観測群を同一化しない | [Observation 246 Alloy](../../loam/experiments/246_shared_current_anchor_cut.als)、[CurrentQuantityAnchor](../../loam/Loam/Application/CurrentQuantityAnchor.lean)、[native test](../../loam/Loam/Tests/CurrentQuantityAnchor.lean) | chainを省いてもroot/現在行の対応、複数群とunknown/拒否を保持できるか |
| 元relationは正確なEvent/keyへ固定。個別量とsource単位の合計量を検査 | [OpenRelationFrontier](../../loam/Loam/Application/OpenRelationFrontier.lean)、[Relation/Discharge D/P/R](../../loam/docs/research/RELATION_DISCHARGE_DPR_OBLIGATION_DAG_2026-09-19.md) | 必要な元根拠の閉包を現在活動から分離し、同一世代で合成できるか |
| 局所参照検査は全Actual入場の代わりではない。元Event/独立根拠の閉包を再検査 | [NormalizedActualAdmission](../../loam/Loam/Persistence/NormalizedActualAdmission.lean)、[persistence test](../../loam/Loam/Tests/NormalizedActualPersistenceTest.lean) | Cの区画に分けても同じ所有・参照閉包・対象スコープの拒否を守るか |
| 実際の反転は訂正とは別。exact inverseは全物理出現のmultisetに関する条件で、純額ゼロだけでは足りない | [ActualReversal](../../loam/Loam/Core/ActualReversal.lean)の`exactPhysicalInverse?_eq_true_iff` / `coordinateNetZero_of_exactPhysicalInverse`、[ActualReversalBalance](../../loam/Loam/Core/ActualReversalBalance.lean) | 元反転両端と現在選択を区別したまま表現できるか。数学的inversionを新しく証明し直さない |
| 日常writerはRelation/Discharge参照先とReversal参加Eventの訂正を未認定として拒否。履歴decodeとは別 | [CorrectionPublisher](../../loam/Loam/Publisher/CorrectionPublisher.lean)、[writer test](../../loam/Loam/Tests/CorrectionPublisher.lean)、[Reversal writer test](../../loam/Loam/Tests/ActualReversalPublisher.lean) | 比較はこの実操作境界を基準にする。許可を広げるなら別の明示的なsemantic変更 |
| 予定完了・置換・取消は独立した型付き終端根拠。金額一致から完了を推定しない | [ScheduledTerminal](../../loam/Loam/Core/ScheduledTerminal.lean)、[ScheduledInspection](../../loam/Loam/Application/ScheduledInspection.lean)、[publisher test](../../loam/Loam/Tests/ScheduledTerminalPublisher.lean) | Dailyが選ぶ単発予定の範囲で、retained Actual endpointとstable entryの明示対応、原子的更新、二重払い拒否を維持 |
| 開始支持は特定Eventへの意味。訂正でstaleになっても訂正自体を止めず、支持を勝手に後継へ移さない。anchorとは違う | [OpeningSupport/correction DAG](../../loam/docs/research/OPENING_SUPPORT_CORRECTION_OBLIGATION_DAG.md)、[FourVoice V6b/V6c](../../loam/Loam/Tests/FourVoiceCompatibilityV6.lean) | stable entry IDへの内容置換で、元Event支持が暗黙に引継がれないか。前の5ケースだけでは不足 |

根拠削減の判断方法にも資産がある。
[Observation 191](../../loam/experiments/191_observational_quotient_factorization.md)と
[Lean owner](../../loam/Loam/Observations/Observation191.lean)の
`closure_iff_factors_through_indistinguishability`は、選んだ観測族で同じになる入力を
縮めてよい範囲と、追加観測が区別を必要とする範囲を説明する。
ただし全endomapに関する一般則で、Cの具体的変換を認定するものではない。
比較する観測族には量だけでなく参照解決・support unknown・操作の拒否も含める。
全旧版照会を契約から外すことと、これらの区別を消すことは別。

[Correction diff/composition boundary](../../loam/docs/research/CORRECTION_DIFF_COMPOSITION_BOUNDARY.md)
（Observations 257–262）により、量差分・endpoint合成は既存Eventと入場済みtopologyから
導出でき、cross-Event Effect lineageや保存diffは不要と分かる。
[SparseEffectIdentity](../../loam/Loam/Application/SparseEffectIdentity.lean)には、独立参照が
必要とするキーだけに永続identityを認める既存の小さな規則もある。
どちらも「同じkey名なら別Eventのpostingを同一化できる」という意味ではない。
新しいdiff authorityや汎用revision engineをCのために作らない。

### 前の比較の補正: 履歴の可読性と、writerの許可を混ぜない

前のB/native probeは、保持された元参照とcorrectionを**同時に読めること**を示した。
現行LOAMの`CorrectionPublisher`が、その組合せを新しく作る操作を許すことは示さない。
実際にはRelation source/Discharge Eventの訂正もReversal参加Eventの訂正も拒否する。
このwriter-local拒否を、既存履歴をdecode不能にするglobal拒否へ移してもいけない。
この区別は上の既存D/P/RのP3とR1に明記されている。未認定のcurrent outstandingは
必要な消費者が現れるまで未認定のままにし、保存研究から新機能へ広げない。

反転後の日付訂正は別入口`ActualValidityPublisher`で許されることを既存writer testが守る。
したがって「Bなら元根拠を残して量訂正できる」はread/import表現の話に限定し、
実用比較ではまずLOAMのwriter拒否を引き継ぐ。追加許可を本研究で採用したわけではない。

開始支持は新しく見つかった**表現差分の検証対象**。
現行Dailyは同じentry IDへ内容を置換し、`admit`で同じIDのsingleton Eventを再構成する。
LOAMのOpeningSupportが持つ「特定の元Eventが現在も選択されている」という区別は、
entry IDを保つだけでは保証されない。特定内容への支持か、一件に追随する別の支持かを
明示し、必要なら支持失効/再支持を表せる情報を残す。まだ動作差の新test/修正はしていない。
観測cutの訂正安定性を全support familyへ一般化しない。

### 今後の調べ方

まず上の直接ownerと既存counterexampleの対応を確認し、既知の意味境界を前提に置く。
新規検証は、①履歴縮約/明示変換、②OCaml接続、③LOAMから意図的に変える契約、の
どれかを名指しできる場合に絞る。LOAMの全featureや内部schemaを複製する必要はない。
既存の意味研究を繰り返すためにAlloy/Lean/TLA+を追加・再実行しない。
必要な原本/試行や今回のregression testsは保全し、新たな第二authorityも作らない。

## 最初に確かめた最小対

`test/daily_book_tests.ml`に既存Dailyパーサ/入場口を使う2つの合成expect testを追加した。
`entry_view`は意図的に明細だけの比較で、正データ全体の同一性ではない。

### 同じ明細・同じ観測数量でも、反映済み集合が違う

共通の実績はwallet -100 / food +100。最初の2ケースの独立観測は同じwallet 1000。
3ケース目だけ、その数量根拠を未供給にする。

| 観測が反映済みと宣言する明細 | 現在のwallet回答 |
| --- | ---: |
| 明示的な空集合 | 900 |
| 明細eを含む | 1000 |
| 独立数量の根拠が未供給 | **不明** |

**明細＋単なる残高数値では足りない。数量と、その数量がどの活動を反映するかの対応が必要。**
日付、ファイル順、最大ID、観測の保存時刻を代わりに使うには別の契約と根拠が必要になる。
これは既存のroot-cut意味のDaily接続確認で、一般のcut圧縮・移行の証明ではない。

### 同じActualでも、予定完了は同じとは限らない

共通の実績はwallet -200 / food +200。共通の予定も同じ量を持つ。

| 明示対応 | wallet回答 | 未完了予定数 |
| --- | ---: | ---: |
| 対応なし | 800 | 1 |
| 予定→実績paymentの完了対応あり | 800 | 0 |

**金額・摘要・近い日付が一致しても、支払い済みを推定できない。**
単なるpaidフラグだけでは対応先を失う。物理明細と予定の終端事実を一緒に残す。
既存のDaily Pace testは、後の実績訂正/実際の返金でも対応が残り、予定が勝手に再開しないことを保護する。
部分払い・複数予定への充当・再開操作を完成させたという意味ではない。

## 正データに残す情報の候補

これは論理上の役割の一覧で、ファイル分割・新しいCore型・必須フィールド名を決めた表ではない。
「未接続」を「不要」と解釈せず、使う回答に必要な範囲を選ぶ。

| 情報 | 消すと失うこと | 現行Daily / 研究の境界 |
| --- | --- | --- |
| 訂正済み明細の安定ID、発生日、摘要、全posting | 一件の特定・訂正、日別明細、数量・内訳の再計算 | v3にある。日付と記録順/記録時刻は別。匿名postingの集約や勝手なkey生成をしない |
| 正確なQuantityとMeasure、明示scale | 端数・巨大量・外貨の解釈。通貨を勝手に合算できない | v3にある。機械整数/floatへ狭めない。使ったMeasureの解釈変更は移行 |
| Reversal/両替の独立対応 | 実際の反転と入力訂正、両替と通常取引の区別 | Dailyに一部あり。純額だけ残したり、返金を元明細の減額に置換しない |
| 予定の安定ID、予定日、元の量/内訳、型付き終端対応 | 何が予定で何が実績か、未払い/取消/完了、二重実績化拒否 | paid-byとcancelled-onはある。置換/Series/部分払い等は別の未決範囲 |
| 独立数量観測と各反映済みcut | 二重計上を避けた現在残高 | ある。観測量は派生残高cacheではない。匿名群の家計上の永続IDを義務にしない |
| ゼロ起点、開始根拠、非ゼロだが額不明、履歴支持 | 根拠なしとゼロ/正確量、現在回答と過去回答の区別 | ゼロ起点/開始根拠/観測/存在根拠はある。期間の完全性は未統合で、現在観測から作れない |
| 科目/口座ID、許可語彙、表示名、明示分類 | 名前変更、新規記帳許可、収支/資産負債の集計 | ID/許可/表示はある。AccountingRole等は未統合。名前・量の符号から推測しない |
| Daily Paceの口座選択・通貨・期間条件 | なぜその目安か、新環境で同じ問いを再現すること | 計算結果は非保存。現在UI設定と必要な解釈情報のbackup範囲を決める |
| Attentionの文脈、期限の値/なし/未定、解決/取り下げと日付 | 未確認事項を引き継ぐこと | ユーザー選択済みの必要分野だがDaily未統合。残高や予定終端とは別 |
| 原額、取引先、立替/関係/精算等の独立根拠 | 外貨請求・対応・残額など選んだ回答 | Coreの器とDailyの保存対応は別。未対応情報は原本に保全し、普通の支出に潰さない |
| requestと元の結果/根拠への対応 | 保存結果不明時の照合、誤った再試行の防止 | household factsとは別のpublication層。P7は未解決。IDやpaid-byだけで代替しない |

**保存しない派生値**: 集計した残高、月/年の合計、Daily Paceの額、残日数、
期限超過badge、索引、検索結果。必要な独立入力があれば再構成する。
人間の摘要と機械参照は別。自由文への埋込だけで必須の対応を保存したことにしない。

## 論理構造の比較候補

| 候補 | 良さ | 費用 / 確認しないと決められない点 |
| --- | --- | --- |
| A. 訂正済み明細＋独立観測/予定/方針 | 日常読取が直接的で、永久の入力訂正chainが不要 | 元postingを指す関係がある場合に、どの訂正を拒否するか/どう元根拠を残すか。旧版照会は別archiveの範囲 |
| B. 元明細＋訂正/日付frontierを保持 | 元の参照と入力履歴を残しやすい。既存Core/LOAMの知見がある | frontier・版数・参照解決の保守と寿命増加。全履歴を残すだけで保存耐久や完全復旧は成立しない |
| C. 訂正済み明細＋参照に必要な元根拠だけ保持 | 通常明細を直接読める一方、必要な元情報を消さない可能性 | **全体として未検証の仮説**。下のAlloy sliceでは直接参照だけの不足と、全元行が必要になる場合を確認。完全な入場検査・cut・移行は未検証 |

Aは現行Dailyの方向、Bは履歴保持型の既存資産、Cは研究候補。
Cのために新しい汎用ontology、疑似Event、第二のadmission engineを先に実装しない。

### 次の核心: 訂正と、元の明細を指す参照

合成の論理例: 元eのkey kに数量10、独立relation rがその元Effectを根拠に数量8を保持する。
入力訂正後のeの量が6でも、rを自動で「現在eのk」へ付け替えてはいけない。
元根拠の10と現在量6は異なる役割で、単なるstable IDや同じkey名だけでは表せない。

既存 `relation_tests.ml` は、元Effectへの参照が訂正後も保たれることを検査する。
Dailyはこのrelation familyを保存できないため、この例のDaily移行は未認定。
Aなら意味を保存できない変換/操作は拒否。B/Cなら参照対象・元量・必要な入場根拠の保持を検証する。
**永久に全訂正履歴を残すことを今決めないが、参照された根拠まで消してよいとはしない。**

現在の反転済み明細の量訂正も、実際の反転を壊すなら拒否する既存ケースがある。
この拒否を外して軽くするのではなく、生活上どの編集を成立させたいかから候補を比較する。

## 論理モデル初稿: 参照先を3つに分ける

以下は合成ケースから得た**比較用の論理モデル**。新しい保存schema、Core型、
候補Cの実装/採用ではない。既存DailyやCoreの参照を黙って変更しない。

### 同じIDに見えても、参照する対象は別

| 論理上の参照 | 対象 / 訂正時の意味 | 例 |
| --- | --- | --- |
| `EntryRef(e)` | 家計上の一件。訂正後も同じ一件として存続 | 予定の`paid-by`。量/日付を訂正しても完了対応を解除・付替えしない |
| `ContentRef(v, k)` / `ContentRef(v)` | 固定された元内容のposting出現 / 全行。現在内容へ追随しない | relationの元Event/key、Reversalの両端。元の符号・Measure・数量・multiplicityを保持 |
| `ActivityRootRef(r)` | 観測に反映済みの活動系列。現在選択された内容ではなく系列を除外 | walletの独立観測1000と反映済みroot。日付訂正で反映済み集合を作り直さない |

`e`、`v`、`r`は役割を示す記号で、全明細に3つの新IDを発行する提案ではない。
Dailyは訂正chainを持たないため、entry IDがsingleton rootにもなる。
Coreでは元Event ID、replacement Event ID、root IDを既存の実際のchainから得る。
同じ綴りや同じkey名だけでは、別の役割への付替えを正当化できない。
Coreのrootはterminal延長では保たれるが、prefix追加では変わり得る。
この初稿は**既に選んだ活動系列の内容/日付訂正**の範囲で、任意のgraph組替えまで
stableな家計IDと主張しない。

### 候補Cに必要な論理上の区画

1. **現在明細**: 安定した一件ID、現在の日付/摘要、順序と出現を保つ全posting。
   量をbalance cacheで置き換えず、Measure・keyあり/なし・exact `Z.t`を保持する。
2. **独立根拠/対応**: 観測量とroot cut、開始/ゼロ/存在根拠、予定と型付き終端対応、
   必要な解釈/方針。ActivityRootと現在明細の所有対応も保存対象。
   graph由来なら入場済みのroot/terminal対応から明示的に変換し、日付から推定しない。
3. **固定元根拠**: 必要なContentRefの参照先。現在明細と別区画で、訂正しても変更しない。
   少なくとも今回のfull-source境界では、参照postingだけでなく元行全postingと
   当該入場に必要な根拠を残す。元Event ID/keyを勝手に新しい現在IDへ付替えしない。

重要な区別: **保持することと、現在の物理活動として選択することは違う。**
元根拠を現在明細一覧へ足すだけでは、過去内容も新しい活動として計上される。
一つのschemaに置いても、この選択境界と参照解決は別でなければならない。
「元行がある」だけではrootと現在行の対応は保証されない。

論理的な読取は、観測ごとのcutに含まれない活動rootの**現在明細だけ**を加算する。
元根拠はContentRefの解決/検査には使うが、加算集合には入れない。
これは既存root-cut法則が要求するroot/row対応の前提を記述しただけで、
Cから既存opaque frontier/query型への変換が実装/証明されたわけではない。
疑似Eventや存在しなかった短絡correction edgeでこの不足を埋めない。

### 5つの訂正ケース

量の例はJPY最小単位、wallet観測1000。`-10/+10`はwallet/foodの2posting。
Bは既存OCamlの履歴保持型Actual oracleで確認した**read/import表現**の範囲。
LOAM全体の入場認定や日常writerの許可ではない。実操作の基準は上のLOAM資産表で区別する。
Aの実例は現行Daily v3。C欄は、必要な保持条件と未認定事項を分けた。

| ケース | A: 訂正済みのみ | B: 履歴保持 | C: 必要元根拠のみ（初稿） |
| --- | --- | --- | --- |
| 普通の量/日付訂正 | 一件IDと独立supportを維持し現在内容を置換。`100→150`ならwallet `900→850` | 全元内容/chainを保持しterminalを選択 | 元内容参照がなければ現在行とroot対応で足りる可能性。無参照の全旧版照会は契約外 |
| 支払い済みActualの訂正 | `180→190`でも`paid-by payment`と閉じた予定を保持、wallet `820→810`。二重払い/再openは拒否 | LOAMのScheduled終端はretained Actual endpointを保持する。今回のActual_source probeはScheduledを持たず、この合成を検証しない | 完了とstable entryの明示対応を保つ。元量だけを残す義務はないが、元量への別参照は次のケース |
| 元posting参照ありの訂正 | 現行Dailyはrelation familyを保存できず移行未認定。捨てる/現在keyへ付替える変換は拒否すべき | 元10・中間9・現在6の3行、元へのclaim8。元10を解決しつつ現在wallet994 | 元全行10と現在行6を別に保持。basisだけのclaim検査とcurrentだけの量は一致したが、**一冊Cの合成入場は未検証** |
| 実際の反転/返金後の訂正 | `e -10`と`refund +10`を保持。どちらかを6にすると反転不一致で拒否。日付/摘要だけは変更可能 | read/import oracleでは元target -10/refund +10を保持し現在target-6を読める。純量+4、wallet1004。**LOAM日常writerはこのEvent訂正を拒否**。独立date訂正は許可 | 元反転両端・refund活動・現在選択の区別を保存。操作比較はLOAMのwriter拒否を基準とし、許可拡大は別の変更 |
| 観測反映済み活動の訂正 | `e 100→6`と日付を1900年へ変更しても反映済みeは除外、wallet1000。新しい未反映20を記帳すると980 | root=元、terminal=現在。反映済みrootで全系列を除外し1000、未反映なら994 | 元postingはcutだけのためには不要でも、root/現在行の所有対応は必要。元全行を足すだけでは不成立 |

普通の訂正とpaid Actualは既存
`daily replacement and plan payment use current entries, preserving support`、
`plan payment stays atomic, terminal plans cannot change or reopen`で確認済み。
反映済み/反転後は今回追加した`canonical daily …`の2件でcold rereadも確認した。
**反映済み観測の1000を訂正差分で自動調整しない。** 観測そのものの訂正/再観測は
独立した明示操作で、この明細訂正の副作用ではない。

### native反例: 「参照postingだけで十分」の検査範囲

[test/canonical_reference_tests.ml](../test/canonical_reference_tests.ml)の4件は、
保存実装ではなく既存`Actual_source`、`Open_relations`、`Actual_reversals`、
`Reflected_root_cut`、`Current_quantity_query`を使う合成probe。
元行だけのsourceは元参照の局所検査用で、家計全体の活動sourceとして使わない。

- **元参照と合計制限**: 元10→中間9→現在6でも元へのclaim8は残る。
  現在行だけでは`Unknown_event`、現在の同名keyへ付替えると`Exceeds_source`。
  全履歴と元全行basisの両方で`8+2`は入場、`8+3`は`Overcovered_source`。
  source単位の集約制限は個別relation検査の繰返しでは代替できない。
- **元行全体の入場**: 参照postingが同一の-10でも、相手postingが+10の元行は入場し、
  +9の別raw入力は残差-1で拒否。既存`Open_relations.create`だけなら両方入場する。
  これはAlloyのfull-row前提に対応するnative反例だが、関係の局所predicate自体が
  誤りという意味ではない。whole-source入場はそのAPIの所有外である。
- **反転は現在取消ではない**: 元-10/refund+10への固定対応は、現在-6へ訂正しても
  保たれる。元target省略はclosure拒否、現在への付替えは`Not_inverse`。
  refundを削除したり、現在targetと合せて自動ゼロにしたりしない。
- **cutと活動の区別**: rootを現在terminalに置換すると`Not_root`。
  現在行だけでは元rootが`Unknown_event`。元全行と現在行をcorrectionなしで
  単純合併したsourceは「2活動」として入場するが、元を反映済みにしても994、
  未反映なら984となる。本来の1000/994とは違い、basis全行保持だけでは不十分。

最初のケースはBの3行のうち中間9を元参照検査に使わない具体例を示す。
**履歴削減の一般証明ではない**。1行basisと1行currentを別々に入場できても、
一冊の整合性、opaque owner間の対応、同じ世代、更新時の再入場はまだ確立していない。

### 保持閉包・操作境界の暫定規則

- Aへ表せない情報を持つ入力は、原本を残すだけで成功にせず、変換を拒否する。
  現行Dailyにrelationや旧反転内容を扱う新しい保存能力があると主張しない。
- Cの暫定basis集合は直接ContentRefから開始し、その入場に必要な全元行/独立対応/
  根拠へ閉じる。Reversalなら両端、Exchangeなら選択keyと当該入場根拠、dischargeなら
  元relationとEvent等へ広がる。**この閉包の全実装/最小性は未検証**。
- root所有とEntryRefの解決は別の保持条件。basisが不要でも消せない。
  将来のprefix付替え、entry削除、basis参照解除、部分払い/予定置換は未定義なので
  この初稿から許可しない。編集で根拠を黙って脱落させない。
- whole-sourceと同じ拒否を求めるなら、参照Effectの量だけを検査するpredicateでは足りない。
  無参照postingの非ゼロ/Measure別均衡/重複key、その他の必要な独立根拠も所有境界を決める。
  full Eventを残しても、date history、original amountsのroot制約、Exchangeのcorrection禁止、
  supportや複数relation/dischargeの合計制約まで自動的に保たれるわけではない。
- 変換入口では全元入力を既存oracleで先に入場し、失敗を削除で救済しない。
  Cが全無参照旧版の照会/再編集を捨てるなら、それは明示的な契約縮小。
  未保存旧版を使う将来操作は拒否し、同一スコープの回答/拒否を比較する。
- 一つの元行が複数参照の共有先なら重複保存しないが、postingの出現は集約しない。
  多数の元内容が参照されれば結局全行が必要。Cの固定割合削減やbounded容量は未獲得。

**このsliceの結論**: Cは「古い履歴を全部消せる案」ではなく、現在活動と固定根拠を
分けて、必要な根拠閉包を選ぶ案。普通/paid/反映済みだけなら全旧posting保持の動機は弱いが、
元posting/実際の反転には別の根拠が要る。反転後のamount編集についてAとBの操作差を
消して同等扱いしてはいけない。既知の意味/LOAM日常writerを前提とし、Cの合成入場、
履歴縮約とroot/開始支持の対応、明示変換が次の未解決点。

## 形式手法の役割と最初の結果

形式手法は不要ではない。今回の問いに合うものから選び、全ツールを必須pipelineにはしない。

| 問い | 選ぶ道具 | 今回の扱い |
| --- | --- | --- |
| どの元参照を省くと構造が壊れるか | Alloy / 既存の有限モデル | 最初の限定Alloy sliceを実行 |
| 訂正・予定完了・snapshot切替・中断/再起動の順序は安全か | TLA+/TLC（必要なら既存SPIN） | 具体的な保存状態/遷移/原子性を選ぶ段階で調べる。まだ新モデルは作らない |
| 固まった保持/変換規則が任意の入力で成り立つか | Lean 4 | 既存9法則を再確認。新しい圧縮法の一般証明は未実施 |
| 実装・I/O・処理費用がモデルに対応するか | 既存OCaml oracle/tests、故障試験と実測 | 形式モデルだけでは代替しない |

### Alloy: 元postingだけか、必要な元行までか

新しい [CanonicalReferenceRetention.als](../formal/CanonicalReferenceRetention.als) を
既存Alloy 6.2.0/SAT4Jで実行した。raw receipt/instancesは
`scratch/canonical-alloy-sPIIJd/solutions`、モデルsnapshotと環境/hashも同じ試行へ保全。
7つのnamed commandのsolution有無をreceiptで確認した。`exec`のexit 0だけでは認定していない。
JDKのrestricted-method warningは残った。設定変更や依存追加はしていない。

**モデルの対応と仮定**:
- `EntryId`は論理的な一件、`Version`はその元/現在の行、`Posting`は名前付きkeyの出現。
  これは数学的な区別で、保存スキーマへversion ID型を採用したわけではない。
- `Relation.source`は元postingへ固定された参照、`demand`は対応量の単一制約。
  magnitudeはEffectの絶対量に対応する。実際の符号・通貨・端点・日付等はモデル外。
- source sliceは既に条件を満たすと仮定。各行2postingの絶対量を等しくし、
  一つの通貨で逆符号を与えれば均衡移動にできる形だが、全Event入場検査は実装していない。
- 元行の入場根拠として**その行の全postingが必要**という既存full-row境界を仮定する。
  違う最小根拠/pure predicateが同じ拒否を維持するかは別の未解決問題。
- scopeは1論理ID、2key、2または3version、4または6posting、1relation。
  Intは5-bit、量は1..10、整数overflowを許さない。家計の`Z.t`の範囲を狭める契約ではない。
  複数relationの合計制限、補正frontier、観測cut、未知情報、保存protocolは含まない。

| command | 期待/観測 | 分かったこと |
| --- | --- | --- |
| `changedMagnitudeWitness` | SAT | 元絶対量10・対応8・現在絶対量6、同じ論理ID/keyの具体例が存在 |
| `partialOriginalRowWitness` | SAT | source postingとそのownerを残しても、元行の相手postingが落ちる例が存在 |
| `pruneUnreferencedVersion` | SAT | 現在行＋参照された元行以外を省ける例が存在 |
| `allRowsNeeded` | SAT | 同じ方式でも全行が必要となる例が存在。常に削減できるわけではない |
| `RetargetingPreservesRelationBound` | SAT（反例） | 元参照を現在の同名keyへ付け替える一般案は不成立 |
| `DirectReferencedPostingIsEnough` | SAT（反例） | full-row境界で直接source postingだけ残す一般案は不成立 |
| `CompleteRowsPreserveThisSlice` | UNSAT（scope内で反例なし） | このsliceのsource参照・量制約・全postingは、現在行＋参照元の全行で保たれる |

最後のcheckは**完全な参照元行のまま保持するという定義に条件付けた局所性質**。
候補C全体の成立、一般の最小保持集合、任意規模、OCamlの正しさを証明したものではない。
SAT witnessで入力が存在することも確認し、矛盾したfactによる空虚なUNSATと区別した。

### Lean 4: 既存法則を使うが、証明範囲を広げて言わない

既存 [RootCutLaws.lean](../formal/RootCutLaws.lean) を、導入済みのnative Lean 4.33.1で
`tools/check-root-cut-laws`から再確認した。9法則は成功、出力は同じscratchの`lean-laws.txt`。
root固定下の観測除外、量/不明、観測premiseの所有を扱い、任意の有限rowに対する一般則を持つ。
`propext`/`Quot.sound`等の依存は [formal README](../formal/README.md)に記載。`sorryAx`なし。
ただしrootとrowの対応を前提にするため、raw graphの圧縮がその対応を保つことは未証明。
新しい保存形式・OCaml実装・物理耐久を認定したことにもならない。

TLA+は、保存結果不明、完了対応の片側だけ残る状態、compaction中断などを扱う次の段階で使う。
今の構造問題を時系列モデルでも重複して調べるのではなく、状態・操作・故障モデルを先に決める。
P7は引き続き未解決で、このAlloy/Lean結果を保存成功の根拠にしない。

## 一冊の境界と更新単位

同じ世代の事実・必要な解釈/方針をまとめて読めることを要求する。
別ファイルにする場合も、黙って違う世代のscaleや分類を混ぜない。
backupからの抽出対象には必要な外部configとpublicationの照合根拠も含める。

- 実績＋予定の完了対応、観測量＋反映済みcutは一体で変更する。
- 入力訂正は明示的に選んだIDと、その参照先/支持の意味を再検査する。
- 未知/未対応情報は保持か全体拒否。opaqueで保管できても意味の検証済みとは言わない。
  回答/出版の安全な独立範囲を示せなければ、都合のよい部分成功にしない。
- version変換は新しい場所へ明示的に行い、原本/旧候補を保全する。
  日付・ID・ラベル・ファイル順で勝手に同一化しない。

構文、内部OCaml型、論理スキーマ、物理配置、publication、archive保持は別の選択。
単一ファイルだから安全、追記だから履歴がある、S式だから意味が保存されるとはしない。

## 次の小さな研究

1. 完了した私的棚卸しの`priorities.private.md`を使い、現在分の操作に対応する入場/移行/
   UIの具体的な差分へ絞る。私的件数/使用傾向を公開文書/fixtureへ移さない。
   未使用の追加機能の先行採択は要求しない。LOAMの資産表を前提に、現在分について
   Cの合成入場/根拠閉包と拡張余地を絞る。
   日常操作はまず現行LOAMのwriter拒否を比較基準にし、許可拡大と既存履歴の読取を分ける。
   既知のrelation-local/whole-sourceの区別を再研究せず、縮約後のroot/現在行/固定元根拠、
   特にOpeningSupportのstale/再支持を保存できるかに絞る。
   complete frontier、観測/開始/存在支持、複数対応/discharge合計のCへの接続は未検証。
   原本archiveだけに依存して、新しい一冊が自己完結すると言わない。
2. [切替チェックリスト](CUTOVER_CHECKLIST.ja.md)の必要分だけを選び、Attention・役割・
   観測更新等の欠落を論理表へ反映する。旧表の予算/v4記述は現行方針ではない。
   budget/routingは復活させず、全LOAM機能を実装義務にもしない。
3. 選んだ同じ情報を短い合成例でS式/行形式へ表す。TUI等からの同じ操作に対して、
   読取/検査/出力の保守費、割当/メモリ、追記/置換時の変更範囲、unknown/version拒否と
   診断/移行を比べる。読みやすさは選定の主軸にせず、独自パーサや依存追加はまだしない。
   構文の差と、全体書換え/backup/保存配置の差を混同しない。
4. その候補について長期測定を更新し、LOAMより扱いやすくなる点と代償を最終確認する。

2026-10-12: 上のDaily最小対2件と既存 `./tools/check` は成功。
最小対だけの直接実行は`test/`から、既存inline runnerの`-matching 'daily identical' -strict`を使う。
最初のrootからの直接実行はexpectのsource探索で失敗したため、2件の成功として数えず、
正しい作業ディレクトリで再実行して確認した。
参照限定保持Cは上の論理モデル初稿・限定構造モデル・局所native probeまでで、全体の成立は未検証。
追加native 6件と`./tools/check`は成功。対象raw出力とsource snapshotは
`scratch/canonical-native-A0FNBh`に保全した。`canonical`で6件を選択できる。
最新runnerは`./tools/check`で構築してから直接実行する。最初は旧runnerで0件だったため
成功と数えていない。初回全checkでは、bad-cut fixture置換がwriterのquoted IDに一致せず
2つの拒否確認がfalseになった。fixture一致のassertとquoted IDで修正後、全check/対象を再確認。
今回の変更はdocs/testのみ。既存入場ownerを再利用し、GC調整/新parser/疑似correctionを追加しない。
形式間移行、全家計の充足性・長期耐久もまだ検証していない。
