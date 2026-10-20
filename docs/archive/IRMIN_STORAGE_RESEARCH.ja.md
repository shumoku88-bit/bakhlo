# Irmin長期保存研究 — 第1段階

状態: **第1段階の資産/API調査記録。以下の未実行記述は当時の状態。**
その後の[限定Phase 2](IRMIN_PHASE2_RESULTS.ja.md)は隔離環境で完了し、通常検証とHEAD途中書込みの
復旧問題を記録した。durable Saved未確立のため**Irminの本体導入は保留**。
次の第一研究候補は[暦年別S式](YEAR_PARTITIONED_SEXP_RESEARCH.ja.md)、SQLiteは比較候補として残す。

目的は部分更新、一体公開、永続的な世代共有と、既存Coreの家計意味を組み合わせられるか。
IrminのmergeやSQLiteのSQLを第二の家計意味エンジンにしない。
[意味の契約](../SEMANTIC_CONTRACT.md)、[論理設計](../CANONICAL_DATA_DESIGN.ja.md)、
[保存費用の既存測定](../LONG_TERM_STORAGE_STUDY.ja.md)が前提。
この文書の保存方式A/B/Cは、論理設計文書の履歴保持候補A/B/Cとは別軸。

## 調査対象と制限

2026-10-12に確認:

- Bakhlo `research/canonical-storage-checkpoint`、HEAD `a81d0df1e2c35aa0ba98dd1810bf54ba403dfeca`。
  `HANDOFF`/language-aware review/storage studyの既存未コミット変更を保全した。
  直接印字・引用長単独試作の結果はローカル追記であり、push済checkpointに含まれない。
- LOAM HEAD `347ab730c34b6b771102b625ec73ce006cddc925`。公開ソース/研究/テストを読んだだけ。
  LOAMのbuild/test再実行、source移植、本番/既存試用データの読取・変更はしていない。
- GitHub公式latest releaseはIrmin **3.11.0（2025-06-19）**、commit
  `0970e7136bc259b80f120b83363c51ec6469cbaa`。release sourceとopam-repositoryのmetadataを照合。
  upstream mainの確認値は`7a09a06fff67bc4981faca36a332c51fc16e819e`（2025-11-28）。
  repositoryのpushed_atはmain commit日とは異なるので、保守頻度の指標へ混同しない。
- 公開取得物、API応答、source archive/hash、installed package一覧、既存diffの退避:
  `scratch/irmin-research-xHxxdu`。取得sourceを実行/buildしていない。
- 第1段階時点でIrmin/Lwt/SQLite OCaml bindingは既存isolated環境に未導入。SQLite CLIは3.43.2。
  当時package solve/build/耐久実験は未実行。Phase 2では別switchへ承認済み導入を行い、
  本体環境/lockは変更していない（全依存versionと合成再現ソースはPhase 2付録）。

## 結論

**Irminは細粒度のimmutable treeと世代共有には適合する研究候補。
SQLite相当のdurable transactionをそのまま得られる、とはまだ認定できない。**

特に重要な残差:

1. `irmin-pack.unix`は**single-writer/multi-reader**。複数RW instance、同じFMの同時fiber利用は
   source interfaceでundefined。cross-process ownershipをIrminのCASで置き換えない。
2. `use_fsync`の既定値は**false**。実験では明示trueが必要だが、それだけで十分とは言わない。
3. **packの同期とbranch HEADの永続化は別。** 後述のsource接続にdurable Savedの未確認箇所がある。
4. 世代commitは家計の訂正/root/固定元内容の参照役を代用しない。GCはそれらを理解しない。
5. SQLiteと併用して二つの正データを作るのではなく、まず代替方式として比較する。

## 既存資産: 再利用と残差

| 所有者 / 資産 | 既にあるもの | 今回の差分 |
| --- | --- | --- |
| `application/actual_source.mli`、libのEvent/Quantity/Identifier | `Z.t`相当の無限精度量、通貨分離、posting/key出現、Actual/Exchange/Reversal/参照の限定入場 | storeから同じcommandを構築し、全体oracleの回答/拒否と一致させる。全LOAM意味対応と称しない |
| `current_quantity_query`、groups、root cut | unknown≠zero、exact≠presence、独立支持と反映root、非二重計上 | 一つのcommit/SQL snapshotでActualと支持を読む。保存先変更でOpeningSupportの失効/継承問題を解決したと扱わない |
| `sexp/daily_book` | 純粋な記帳/訂正/予定変更・取消・Actual追加＋予定完了、indexed lookup、新規普通記帳のincremental fast pathと全体oracle | 初期実験の共通semantic ownerとして使う。置換/特殊明細/予定管理の全体入場費用は残る。支持更新の公開mutation APIは現在ない |
| `sexp/records_book` | 純粋payload/frame codec、CRC/LSN、opaque保持、末尾tornと中間破損の区別 | codec/拒否specを利用できるが、Records v1は訂正と予定完了一体保存を表現できず、同等authority候補ではない |
| `sexp/durable_append` | writer lock、LSN競合、token一致/内容drift拒否、不確定同期結果、in-doubt検出 | 結果分類/試料を引き継ぐ。log engine自体をIrmin内部へ重ねない。session Ackの永続化/P7は未解決 |
| `tui/daily_file`、`recovery_checks` | serialization再解析＋canonical比較、checked book返却、attempt/pending/before、同期/readback、7 checkpoints、cold retry freeze | gateの目的・結果分類を保つ。file renameのcheckpoint番号をIrminにそのまま移して認定しない |
| `tools/storage_study`/`storage_breakdown`/`storage_profile` | 合成生成、同操作、exact期待値、段階時間/割当/bytes/RSS、原所有者control | 生成器とoracleを再利用。新backend自身のprotocol checkpointと独立readbackが追加で必要 |
| LOAM HouseholdImage/HouseholdAuthority | 一つの観測世代、既知section入場、unknown/未変更sectionの厳密保持、missing≠present-empty、writer所有、stale拒否、current/previous明示復旧 | section一体世代の契約を使う。Irmin treeが自動で家計参照閉包を保証するわけではない |
| LOAM normalized Actual encoder | transient HashMap/group index、Array row蓄積、元wire/順序維持、入場後出力 | 再び二次的探索/append問題を研究しない。OCamlの現経路は別実装なので費用を個別測定する |
| LOAM `loadCurrentWithActual?` / `loadHouseholdObserved?` | 全世代を一度qualifyして入場済みActualと観測wireを組で返す | mutableな根拠なしcacheではなく、commitに束縛したchecked imageとして再利用する設計を引き継ぐ |
| LOAM ScheduledTerminal/CurrentQuantityAnchor publisher | Actual＋予定終端、exact anchor＋presenceを一つのHousehold世代で更新 | Irmin/SQLで同じ更新境界にする。異なるheadからfamilyごとに読まない |

### LOAMで解決済みと未認定を分ける

[LOAM text/SQLite study](../../../loam/docs/research/external-pressure/LOAM_TEXT_SQLITE_PERSISTENCE_STUDY_2026-10.md)
のE3.3は、初期encoderの反復全探索/伸長list appendを既にproductionで修正した。
現`NormalizedActualPersistence.lean:encodeNormalizedActual?`も入場を残し、groupを一度組み立て、
historical wire順を維持している。旧encoderの計測値を現在のLOAM性能に使わない。

[`HouseholdAuthority`](../../../loam/Loam/Authority/HouseholdAuthority.lean)の
`loadCurrentWithActual?`はadmitted Actualを局所pairで返し、
[`ActualAuthority`](../../../loam/Loam/Authority/ActualAuthority.lean)の
`loadHouseholdObserved?`が再利用する。全callerの重複decodeが除去済みとは言わない:
`decodeHouseholdGeneration?`経由や公開時には独立した再入場も残る。
[`TuiHomeActualGeneration`](../../../loam/Loam/Tests/TuiHomeActualGeneration.lean)等は
選択済みActualを後続readへ運ぶ期待値を持つが、外部configも含む全世界snapshotの証明ではない。

[`HouseholdAuthority` test](../../../loam/Loam/Tests/HouseholdAuthority.lean)はstale拒否、
unknown保持、previous選択の明示、partial stageの非選択を検査する。
現publisherのsourceはwrite/readback/renameで、**file/parent fsyncは見つからない**。
この論理公開/復旧資産を、そのまま電源断耐久やBakhloのP7解決として引用しない。
Lean law/既存testは意味の資産であり、Irmin OCaml adapterの証明ではない。

## Irmin 3.11.0: APIと適合性

### 世代・一体更新

現APIは`Irmin.Generic_key.S`、packの入口は`Irmin_pack_unix`。
小さい文字列payloadで始めるなら`KV(...).Make(Irmin.Contents.String)`系を使える。
pack独自keyとcontent hashは別の型/役割であり、offsetやhashを家計IDにしない。

- `Tree`はimmutableな構造。変更leaf/祖先を更新し、未変更部分を世代間共有できる。
  family全体を一つの巨大blobへ詰めると部分更新の利益は得られない。
- `Commit.v`でtree/parents/infoを持つimmutable commitを作れる。
- `Head.test_and_set`は観測headとの一致を条件にする更新。
- `with_tree`はsubtreeを原子的に更新する。strategyは`Set`/`Test_and_set`/`Merge`、
  defaultは`Test_and_set`、実装のdefault retriesは13。
- APIはsnapshot isolationを説明するが、**全read dependencyのserializable家計入場を保証しない**。
  root全体の観測commitを固定し、他更新があれば再入場またはstale拒否が必要。
- 別々の`set`をActual/予定/支持へ順に行うのは一体transactionではない。
  immutable rootの変更を一つのcommit＋一回の選択へまとめる。
- 自動merge/無検査retryは使わない。callbackは再実行されうるため、ID採番や家計事実の追加を
  副作用として置かない。最初は明示stale拒否を選ぶ。
- `Repo.batch`はpack書込/flush単位で、SQLのrollback transactionと同一ではない。
  failure時もflushする実装なので、非選択objectが残りうる。成功条件は選択世代で判定する。

### 永続化: 最初のstop/go条件

[pack config](https://github.com/mirage/irmin/blob/3.11.0/src/irmin-pack/conf.ml)では
`use_fsync=false`、indexing strategyのdefaultは`always`。
[FM interface](https://github.com/mirage/irmin/blob/3.11.0/src/irmin-pack/unix/file_manager_intf.ml)
はSWMR/crash consistencyを区別し、**branch storeを対象外**とする。
作成・version migration・integrity repair中のcrashはundefinedと説明されている。

[FM implementation](https://github.com/mirage/irmin/blob/3.11.0/src/irmin-pack/unix/file_manager.ml)
の同期対象はdict/suffix/control/index。
[branch store](https://github.com/mirage/irmin/blob/3.11.0/src/irmin-pack/unix/atomic_write.ml)
の`set_entry`/CASは`Io.write_exn`で更新し、そこでfsyncを呼んでいない。
[Unix IO](https://github.com/mirage/irmin/blob/3.11.0/src/irmin-pack/unix/io.ml)のopen/writeも
O_SYNCではなく通常writeである。確認したmainのbranch sourceもreleaseと同じ。

従って、`use_fsync=true`＋`Head.test_and_set`成功だけでdurable Savedと結論しない。
これは**sourceで特定した未確認の接続**で、今回電源断反例を実験したという主張ではない。
利用可能なpublic APIだけでbranch選択まで同期できるかを最初に確認する。
private内部へ無理にアクセスしたり、勝手にupstream patchへ進まない。

APIだけで条件を満たせない場合の限定候補は、Irminをimmutable object/commit保存に使い、
**小さいfsync/readback付きroot manifestを唯一の選択authority**にすること。
これは実装決定ではない。root object同期→manifest stage/backup/rename/parent syncという
残る公開mechanics・失敗分類を明記し、Irmin branch HEADを第二authorityにはしない。
復元用manifestはpack offsetに依存せず、hash/key解決・index方針・GC後の有効性を検査する。
ここが複雑になりすぎるならSQLiteへ任せる方が直接的な可能性もある。

### 履歴・GC・バックアップ

[pack GC API](https://github.com/mirage/irmin/blob/3.11.0/src/irmin-pack/unix/store_intf.ml)
はtarget commit以前をdelete/archiveする。lower layerがあればArchive、なければDelete。
[GC設計](https://github.com/mirage/irmin/blob/3.11.0/doc/irmin-pack/design/layered_store.md)
は、到達可能性計算でcommitのparentリンクを辿らないことを明示する。
**親commitがあるから古い全世代を永久に復元できる、という仮定は誤り。**

GC許可はindexing strategy等に依存し、default `always`をそのままGC対応とみなさない。
必要な固定元根拠は現在のcanonical tree内の入場対象として保持し、old commitだけに頼らない。
必要な履歴window、previous root、未確定操作、明示archiveを別々に保護する。
GCとreader/exportのlifetimeも問題になる。`create_one_commit_store`はsource filesが
途中で別processのGCに消されないことを要求する。

世代共有は同じdiskの破損/紛失に対するbackupではない。Pack全fileの整合copyと、
Irminに依存しないS式archiveの別環境復元は別の試験。
初期実験はGCを起動せず、後続は**新しい合成repositoryコピーだけ**で許可を得て試す。
既存証拠/試用/backupの自動pruneは行わない。

### MirageOS・依存・保守

- generic Irminと`irmin-mirage`/`irmin-mirage-git`はMirageOS向け資産を持つ。
  しかし今回の`irmin-pack.unix`は`lwt.unix`、`index.unix`、Unix IO、GC forkに依存する。
  **Bakhloでpackを使えばそのままMirageOSへ移植できる、とは言わない。**
  Mirageでのdurable backendは別の実装/検証課題。初回Bakhlo実験へ含めない。
- core直接依存: repr、fmt、uri、uutf、jsonm、Lwt、digestif、ocamlgraph、bheap、astring、
  mtime、bigstringaf、ppx_irmin。packがindex、optint、checkseum、rusage、cmdliner等を追加。
  PPXはppx_repr/ppxlibへ依存。test/doc/server/git/Mirage依存を全部導入する必要はない。
- opam metadataの下限はcore OCaml>=4.08、pack>=4.12、Dune>=2.9、pack Lwt>=5.4。
  3.10 changelogはOCaml 5.3の`effect`予約語対応を記録しているが、現在のBase/Bonsaiを
  含む依存解決やcompile成功を保証しない。現環境とのsolve/buildは未確認。
- Bakhloの同期CoreとLwtの境界、さらにBonsai側runtimeとの接続は保守費用になる。
  最初は独立native workerに閉じ、TUI/runtime統合は実験しない。
- ISC license。pack doc自体が特定用途向けで詳細configurationが必要、と注意している。
  長期のpack format移行、GC、dependency更新を保守計上する。初期実験では
  `no_migrate`による自動format更新拒否を候補にし、移行は別の明示操作で試す。

## 第1段階時点の比較設計（履歴）

20件のIrmin spikeはPhase 2で実行済み。以下のscale/GC/全比較は未実行で、
この順序を現在の次作業とはしない。最新方針は暦年別S式の専用計画に従う。

### 共通の意味とデータ

既存生成器の1,000 / 36,500 / 109,500件を使い、閏日を省いた10件/日という**合成仮定**を維持。
3通貨、180-bit超量、Unicode/escape、複数posting、明示反転、予定終端、unknownと明示zero。
既存oracleに、非空cut、独立観測群/Presence、OpeningSupportと必要な元根拠の例を足す。
量をSQLite INTEGER/REAL、JSON numberやfloatへ狭めず、canonical decimal TEXT/bytes→`Z.t`で読む。

初回のlogical scopeは既存Dailyを超えて全LOAMを採用しない。
支持/root更新は現在mutation APIがないので、shared synthetic fixture adapterでcandidateを作り、
既存Core/`Daily_book.of_string`の全入場を共通oracleにする設計から始める。
表現C/OpeningSupportの未解決問題を保存backendの機能で「解決済み」にしない。

### A/B/Cと最小粒度

| 方式 | 保存粒度・一体更新 | 検査境界 | 留意点 |
| --- | --- | --- | --- |
| A: 現行単一S式 | 現`Daily_file.publish`の全体stage/backup/rename | 現roundtrip/canonical/入場全gate | 基準は運用ownerのまま。直接印字の未採用試作は補助referenceで別表示 |
| B: Irmin-pack | entryごと・planごと・独立観測群ごとにsmall payload、immutable root/commit一回選択 | 共通Core＋persisted payload再読込による同世代入場 | per-effectまで分割しない。root選択同期/SWMRが先。巨大order一覧の毎回rewriteを避け、元の順序/出現を明示保持 |
| C: SQLite | 同じpayload粒度のrow更新＋generation競合検査を一つのSQL transaction | 共通Core＋保存後same-snapshot readback/入場 | 初回はSQLで家計計算をしない。SQLite自身に訂正chain/root意味を推測させない |

Bのpayload例はentry/planと、量＋cutを一体で持つ観測群。
家計IDは正確なidentifierのまま持ち、tree pathへのencodingは可逆にする。
Irminのlexical traversal順を記帳順/ポスティング出現/観測群のidentityへ置き換えない。
Coreに必要な順序を保持する小さな構造を別途決めるが、汎用plugin/schema frameworkは作らない。

Cは`BEGIN IMMEDIATE`等でwriterを直列化し、draftの観測generationとの不一致を拒否する。
WALを使う比較候補では`synchronous=FULL`を明示し、NORMAL/OFFの速度を耐久保存と混ぜない。
transaction中のActual追加＋予定完了＋世代更新を一体にする。BUSY等を空成功にしない。
WAL/SHM/checkpointを含むbackupを使い、稼働中の.db単体copyを完全backupとは言わない。
Irminの世代復元が比較要件なら、Cも同じ復元windowに必要な技術的before row/世代記録を保持する。
SQLite current-onlyとの比較は履歴機能差を明示し、容量を同等保証の順位に使わない。

### 操作・障害の共通表

1. 普通の新規記帳、同じIDの量/日付/2→3以上のposting訂正。
2. Actual追加＋Scheduled完了、同じ予定の変更、明示取消、二重払い/閉予定変更の拒否。
3. 独立数量と反映rootを同時更新。反映済root訂正の非二重計上、unknown/presenceの非scalar化。
4. fresh process再起動、二つのstale draft、他family更新中のquery世代固定。
   packの同時RWを敢えて許す試験にはしない。先にwriter ownershipを取ってからRWを開く。
5. object永続化前後、root選択前後、同期失敗、Ack前後で中断。
   復旧結果はold/new/不確定を明示し、部分的な予定完了や支持更新を見せない。
6. backend backup、完全S式archiveからfresh場所/別環境復元。
   必要なidentity/固定元根拠/root/unknown/終端/opaqueを落とす変換は拒否する。

process killだけで電源断を検証したとは言わない。初期段階でEIO/kill注入とsourceの同期順を
確認し、VM/デバイス故障試験を後続でどう用意するか別に決める。P7/Ack lossも独立した項目。

### Irminに依存しない完全S式archive

一つの固定commitから一つのdomain imageを取り出す。versionと保存スコープ、必要なentries/
posting出現/key、予定終端/対応、独立根拠/cut、必要な固定元内容を含め、Coreで完全入場できる
archiveを目指す。Irminのpack/Snapshot exportやhash一覧だけでは、この条件を満たさない。

- 初回は**限定合成スコープの完全archive**。現Daily v3を全家計完全archiveと呼ばない。
- Records→Dailyでopaque/tokenを無拒否で落とす既知seamがある。現在のconverterをそのまま
  lossless archive用に使わない。unsupportedがあれば保持可能性を確認するかexportを拒否する。
- restore-only executableの依存はCore＋S式codecのみ。Irmin無しで読取/全入場/復元し、
  同じ回答だけでなく次の訂正/予定操作/支持失効の回答・拒否も確認する。
- source commit/hashは技術的provenance。家計ID/反映root/元Event参照の代用ではない。
- archiveは選択authorityにしない。世代と鮮度を明示し、Irminとの双方向自動同期を作らない。
  頻度/RPOは未選定。周期archiveと毎保存archiveの費用を分ける。
- Ledger/CSVは別の交換形式で、必要な独立根拠/参照/unknownを失いうる。restore oracleにしない。

### 測定と最初の実験順

**候補順（承認後）**:

1. **20件のB安全性spike**: API/build適合、SWMR所有、同じ観測rootの入場と一体更新、
   root選択までの同期、独立再読込、stale/uncertain分類。
   branch HEADだけでは成立しない場合、small manifest案を先に相談する。
2. 同じ小fixtureでA/B/Cの意味・拒否・中断・S式独立restoreを揃える。
3. その後だけ1,000/36,500/109,500へ拡大し、反復/順序反転/必要なら無作為化して測る。
4. 同じ復元window/独立backup条件でディスク増加を比較。GCは別copyで、保護対象と
   中断/reader/export条件を先に定めてから測る。採用/移行はさらに別判断。

測るもの:

- end-to-end保存/訂正/予定/支持更新、起動、同世代読取、archive/export、復元の時間。
- semantic候補作成、codec、persist/readback、同期、選択、復旧をphase分離。
- `Gc.counters`による累積割当、promotion/major、operation RSS/whole-worker peak。
  Pythonモデルの時間や過去別環境のLOAM値と混ぜない。
- file別disk増加（object/commit/index/branch/manifest/WAL/backup/archive）、非選択object、
  checkpoint/GC一時最大量と停止時間。API bytesと実media writeは別。
- frozen全世代を同条件で再入場した費用と、checked世代の安全な再利用による費用を別表示。
  速さのため独立serialization検査を削除しない。
- adapter/publisher/migration/restoreの追加LOC、依存closure、compile/runtime統合、
  pack format移行とGC/backup手順。汎用multi-backend interfaceやORMを先に作らない。

**中止/見直し条件**: durable選択を公開API＋短いmechanicsで説明できない、
必要情報のarchiveを作れない、保存後入場/拒否がoracleと違う、retained参照がGCで失われる、
依存/runtime/運用手順が家庭用の利益を上回る。Irminを選ぶこと自体は目標ではない。

## 公式参照（確認版）

- [Irmin 3.11.0 release](https://github.com/mirage/irmin/releases/tag/3.11.0)
- [Store interface: Commit/Head/with_tree](https://github.com/mirage/irmin/blob/3.11.0/src/irmin/store_intf.ml)
- [pack-specific API: flush/GC/Snapshot](https://github.com/mirage/irmin/blob/3.11.0/src/irmin-pack/unix/store_intf.ml)
- [pack用途/設定の注意](https://github.com/mirage/irmin/blob/3.11.0/doc/irmin-pack/index.mld)
- [Mirage package](https://github.com/mirage/irmin/blob/3.11.0/irmin-mirage.opam)
  / [pack Unix dependencies](https://github.com/mirage/irmin/blob/3.11.0/src/irmin-pack/unix/dune)
- [現opam pack metadata](https://github.com/ocaml/opam-repository/blob/master/packages/irmin-pack/irmin-pack.3.11.0/opam)
- SQLite: [transactions](https://www.sqlite.org/lang_transaction.html),
  [WAL](https://www.sqlite.org/wal.html), [synchronous](https://www.sqlite.org/pragma.html#pragma_synchronous),
  [atomic commit](https://www.sqlite.org/atomiccommit.html), [online backup](https://www.sqlite.org/backup.html)

第1段階実施時はここで停止し、依存install/native試作/authority変更/LOAM/data変更や
commit/push/PR/mergeは行わなかった。後続の限定実験と現在の判断はPhase 2報告を参照。
