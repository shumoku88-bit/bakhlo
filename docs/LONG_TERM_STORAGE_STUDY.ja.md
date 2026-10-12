# 長期保存方式の調査

状態: **現行経路baselineと単一S式の保存費用分解を測定済み。方式の最終選定・運用認定は未完了。**

家計簿の長期運用は既知の基本要件であり、UI完成後の追加課題ではない。
この文書は「何十年使える保存方式を選べるか」「LOAMとの違いはパーサ保守だけか」
を扱う。[意味の契約](SEMANTIC_CONTRACT.md)が優先し、LOAMは引き続き正データの唯一の運用先。
正データ・私用コピーを読んだり変更したりせず、合成データと公開実装だけを調べた。

## 今回の範囲と再現

2026-10-12、Bakhlo `3a85b4c3c4e599ed86445859c8ef1515f299a5b4` の作業ツリー。
今回追加した計測ドライバと、以前からのUI/比較関連の未コミット変更がある。
計測対象のライブラリ・`daily_file.ml`・`daily_actions.ml`の意味・保存実装は変更していない。
LOAMは `ce21ab38e78c81e6185f8fe53144e76fdd34cfcd` の近隣所有者をソース確認しただけ。
LOAMのビルド・実行・ソースコピーや同条件の速度測定はしていない。

既存の主環境、OCaml 5.3.0 / macOS 15.7.9 x86_64、Base v0.17.3、
Parsexp/Sexplib0 v0.17.0、Zarith 1.14、Dune 3.24.2を使用。依存追加・GC調整なし。

```sh
./tools/storage-study                    # 1,000 / 36,500 / 109,500件
./tools/storage-study 100                # 短い合成確認
```

これは既存パーサ・admission・publisherを呼ぶ任意実行の小さな計測ドライバ。
保存プロトコルの再実装、新バックエンド、独立oracle/CIハーネスではない。
毎回新しいignored scratchへソーススナップショット・環境/hash・入力・全出力を残す。
既存の過去試行・失敗・候補を上書きしない。
確定値の生ログは `scratch/storage-study-m3eLcJ`。
初回の2 compile失敗（OCaml 5の予約語と数量API名）は修正前ソースを保存してから訂正。
途中計測のquick_statが短い処理のminor割当を0と表示したため、最終値は`Gc.counters`を使用。
これらの初期結果を成功・最終割当値として採用していない。

- 年数は**仮定**: 1日10件 × 年365日で10年36,500件、30年109,500件。
  グレゴリオ暦で有効な日付を使い、生成日程では閏日を省いた。利用者の実件数ではない。
- 3通貨、全明細にUnicode/引用符/改行memo、5件に1件は3ポスティング。
  97件ごとに直前明細の実際の反転を作り、通常明細の量は997件ごとに180-bitとする。
  大規模な両替・Effectキー・複雑なsettlement・観測cutは今回の負荷には含めない。
- 360予定（初期20支払済・20取消済・320未完了）、3つのWallet/通貨座標の独立数量観測、
  費目の明示ゼロ根拠と、根拠がなく残高不明のBankを含む。
  これは限定された負荷の形であり、30年間の予定/観測履歴が完全だという主張ではない。
- 同じRecords値から両入力を作り、**共通Daily事実**の正規化結果を比較。
  Recordsの追加token/CRC/LSN情報まで単一S式と同一とは主張しない。
- 各形式を新しいプロセスで読み、記帳3回、古い日付・摘要・EUR数量の訂正1回、
  予定支払い1回、再読込、新しい場所へのbyte一致copy/restoreを確認。
  walletは生成ポスティングを畳まない独立算術期待値でも検査。
  Recordsの未対応2操作は拒否とbyte不変を確認する。拒否時間を保存速度に数えない。
- filesystem cacheはflushしない。プロセス新規起動はdisk coldを意味しない。
  各件数/形式1 worker、記帳は3試料。中央値はその3件だけで、SLOや安定したp95ではない。
  他処理・機器による差はあり、過去のLOAMベンチとの速度順位には使えない。

## 現行経路の測定結果

単位: 秒。記帳は3試料の中央値。他の操作は1試料。

| 件数 | 形式 | 読込 | 記帳 | 過去明細訂正 | 予定支払い | 新規copy/restore |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 単一S式 | 0.018 | 0.049 | 0.051 | 0.043 | 0.043 |
| 1,000 | Records | 0.052 | 0.00044 | **拒否** | **拒否** | 0.101 |
| 36,500 | 単一S式 | 0.700 | 1.531 | 1.814 | 1.428 | 1.434 |
| 36,500 | Records | 1.662 | 0.00042 | **拒否** | **拒否** | 3.300 |
| 109,500 | 単一S式 | 2.267 | 4.728 | 5.608 | 4.520 | 4.400 |
| 109,500 | Records | 4.771 | 0.00041 | **拒否** | **拒否** | 10.171 |

30年負荷で現行データは単一S式約29.54 MB、Records約34.48 MB（10進）。
単一S式の5保存は全体before backupを約147.69 MB残した。
Recordsは3追記で717 bytes増えたが、既存データの独立backupはこの経路に存在しない。
「backupゼロ」を保存機能の優越とはしない。過去試行のbackupを削除する決定もしていない。

30年負荷の記帳1回目のGC countersは、単一S式でminor約403.08M words、
promoted約88.64M、major約185.29M。Recordsでminor 2,614 words、promotion/major 0。
promotionはmajorにも含まれるため、これらを単純加算して総割当としない。
ロード直後のRSSは単一S式約429 MiB、Records約477 MiB。
Darwin `time -l`による**検査・再読込・復元も含むworker全体**のpeak RSSは
約1.63 GiB / 1.24 GiB。これはTUIのsteady/idle RSSやリーク認定ではない。
観測用の全byte読取・正規化比較もworkerのメモリに含まれる。

全条件で共通事実の初期一致、正確な残高/不明の保持、支払リンク/訂正の再読込、
新規copy/restoreの完全byte一致を確認した。
既存 `./tools/check` と既存Bonsai実行ファイルの `--self-check` も成功。
後者は7 returned fault + 7 SIGKILL等の既存ケースであり、新しい物理耐久試験ではない。

## 第2段階: 単一S式の保存費用分解

通常はTUI等から編集し、手読み・手編集の快適さは選定の主軸にしない。
同じ日常操作の保存費用、メモリ/割当、backup増加、復元/移行と保守を優先する。

```sh
./tools/storage-breakdown          # 同じ合成1,000 / 36,500 / 109,500件
./tools/storage-breakdown 20       # 短い確認
```

最終証拠は`scratch/storage-breakdown-tphEVe`、先行の短い確認は
`scratch/storage-breakdown-1J1z2p`。旧studyの生成器を再利用し、原本/私用候補を読まない。
`storage_instrument.ml`はfresh scratchに置いたsource copyだけを、exact anchor確認の上で
観測する。運用コードにhookを追加せず、gate/順序を変えず、別のdecoder/storeは作らない。
元のlibrary/所有者を使うcontrol executableと、観測用source copyのexecutableを別プロセスで
逐次実行する。環境・生成source・buildされたlibraryのhashも保全する。GC設定/依存は変更しない。

各workerは記帳3回、量訂正、3→4 postingへの訂正、日付だけの訂正、予定支払い、
予定変更、予定取消の9保存を行う。最後にcold processではない再読込とfresh copy/restore。
同じ最終bytes、独立した正確な残高期待値/unknown、行数/日付、予定の対応/終端、
元の`Daily_book`での読取/正規化一致を検査した。観測とcontrol双方で7 returned checkpoint
faultの不確定/選択/再書込guard、競合の無変更、malformed拒否も成功。
source anchor driftと不正件数の拒否、元sourceの`cmp`、既存`./tools/check`も確認した。
これは新しいSIGKILL/電源断/P7・全家計移行/外部config復元の認定ではない。

### 30年相当の新規記帳1回: 内訳

観測workerの`record-2`一試料。秒、丸めあり。inclusiveな親子を二重加算せず、
`self_ms`を合計してoperation全体と一致することをdriver内でも検査する。

| 分類 | 秒 | 測定範囲 |
| --- | ---: | --- |
| 一件の候補追加 | 0.000031 | 既存incremental `put_entry` |
| 全文の印字 **2回** | 1.526 | S式AST構築＋文字列化、canonical安定性確認用の再印字も含む |
| S式構文解析1回 | 0.670 | `Parsexp.Many.parse_string` |
| スキーマ解釈/Entry_map再構築 | 0.263 | syntax/semantic以外のdecode＋`make_data` |
| 全Actual/数量支持の入場1回 | 0.898 | Event再構成、Actual command/Source、数量支持 |
| 形式判定 | 0.111 | header判定、全文行split等 |
| writer下のI/O等 | 0.871 | lock/照合、3全文出力、readback、sync、rename/cleanup |
| その他 | 0.020 | 上記以外の照合/observer等 |
| **全体** | **4.360** | 同じ操作の未観測controlは4.461秒 |

I/O分類の内部はread約0.738秒、write約0.093秒、file/parent fsync約0.008秒。
readにはBuffer拡張/文字列copy/その場のGCも含み、disk待ちだけではない。
filesystem cacheはflushしていない。低いfsync時間をデバイス耐久や一般的な速度保証にしない。

新規記帳ごとに **全文印字2回、全体decode/admission1回、全文write3回、全文read6回**。
この試料ではAPIに渡したwrite bytes約88.62 MB、返ったread bytes約177.23 MB。
物理mediaへの書込量ではない。3回のfile fsyncと4回のparent fsyncを確認した。
訂正は候補を作る側でも全体再構築/入場するため、合計2回の全体入場になった。
量訂正の候補作成だけで約0.891秒、保存全体約5.434秒。
量/行数/日付訂正や予定変更/取消はこの負荷でおおむね5.0〜5.4秒だった。
予定支払いはincremental候補で約4.237秒。これらはcontroller/APIの時間で、画面描画時間ではない。

### 割当とbackup

新規記帳`record-2`の総割当は約499.73M words、64-bitで約4.00 GBの累積一時割当。
`minor + major - promoted`で算出し、promotionを二重加算しない。これは常駐量ではない。
そのうち印字2回が約192.04M words、全体入場が約154.97M words、
構文解析が約41.17M words。AST構築だけでなく、renderも大きな割当を持つ。
全9操作＋検査/再読込/復元を含むworker peak RSSはcontrol約1.66 GiB、観測約1.69 GiB。
TUI idle/steady RSS、live heapやリークの証拠ではない。

9保存のbefore backupは約265.85 MB。既存のbefore/失敗artifactは削除しない。
全体書換え/無期限全体backupの増加は、印字やパーサを速くしても残る。

### この測定からの次候補

- **confirmed**: 新規一件追加のincremental経路は既に軽い。重いのは毎回の全文保存経路。
  既存の高速化を繰り返す新indexやGC tuningを先に追加しない。
- **confirmed**: S式パーサ単体はこの新規保存の約15%。「行形式にすれば全て解決」とは言えない。
  印字、意味再構築、copy/readback、backup policyと分ける。行形式の優劣自体は未測定。
- **hypothesis**: AST経由/レイアウトprobe/引用の再計算を減らす直接出力を、まず合成prototypeで
  比較する余地がある。手編集向け整形は主目的ではないが、escape/整数/往復/拒否を変えない。
  まだ実装改善や速度向上を獲得したとは言わない。
- **boundary**: roundtrip入場と再印字は独立したserialization/canonical確認でもある。
  単なる重複として削除しない。候補/serialized世代の検査目的と、返すchecked imageを維持して
  再構築を減らせるかを次に確認する。
- これとは別に、同じ訂正/完了/取消/支持更新を一体保存できる追記＋snapshot候補と、
  復旧/保持policyを比べる。現行Records v1はその同等操作の比較対象としては未成立。

制限: 各count/control/観測1 worker。記帳だけ3試料、他操作は1試料。
controlが先で観測が後、順序の無作為化/反転はしていない。観測による小さな追加割当と
compiler/module配置の差もある。時間の差を改善効果や厳密なobserver overheadと呼ばない。
`gettimeofday`のwall clockを使い、GC時間は起きたphaseに含むがCPU/GC pause単独は未分離。
元studyと同じ限定fixtureで、OpeningSupport/複雑cut/settlement等の負荷は含まれない。
Records起動の重複decode分解、row parser、同操作のLOAM測定も今回していない。

## 確認した課題と意味

### confirmed: 全文保存・無期限before backupの費用

`daily_file.ml:publish`はprinter出力を全読込/admissionし、attempt・pending・beforeを
同期してから選択とreadbackを行う。1成功で概ね新全体2個＋旧全体1個をデータ書込する。
全体の検査・印字・I/Oを含む今回の記帳時間が、長期の待ち時間として残る。
**パーサ単体が全時間の原因と分離測定したわけではない。**

最終の約29.54 MBを固定して1日10保存を30日続けると、beforeだけで約8.86 GBになる
計算上の例。寿命全体の蓄積が単一ファイルのサイズとは別問題になる。
これは実運用の増加量・メディア書込量の測定ではない。

### confirmed: 追記が速いことと、日常台帳の成立は別

`daily_actions.ml:commit_transaction`はRecordsの置換・予定完了を追記前に拒否する。
`Records_book.payload`には両操作の一体保存を表す型がない。
現行v1を長期の唯一の台帳に選べない。新transactionとsnapshot/compactionを作るなら、
その実装・切替・tokenの有効期間・不確定な保存の扱いも保守対象になる。

`daily_file.ml:load`の取得/recovery/再取得/二重Records decodeは読込調査候補。
第1段階のRecords読込は単一S式より遅いが、境界の違いを無視して削除してはいけない。
単一S式の各phaseは上の第2段階で分離した。Records起動の分解は別の未実施sliceとして、
[Issue #28の指針](LANGUAGE_AWARE_DESIGN_REVIEW.md)に従う。

### confirmed: 変換の情報保存は別途必要

小さな合成probeで、Records codecが保持する未知のheader fieldを、
Daily読込→単一S式出力が保持せず、拒否もせずに落とすことを確認した。
`Daily_book.of_records`/`to_records`は公開token/opaque情報までのlossless変換ではない。
現在の比較用入力の完全source保存は、この変換を完全な正データに昇格させる根拠にならない。
将来の仕様は意味を保存できない未知データを**保持するか全体拒否する**必要がある。

### intentional trade-off: 訂正済み台帳

訂正の旧版を正データ内に永久保持しないことは承認済みの製品方針。
LOAMと同じ過去版/訂正chain照会ができるとは言わない。実際の反転・予定の終端事実は残す。
backup/原本が代替する範囲、復旧時に選ぶ根拠、移行で失う回答を明示する。

## LOAM形式との比較 — 最終判断の入口

これはソース比較であり、利用者のデータ・稼働binary・機器の調査ではない。

| 軸 | 現行LOAM | 現行Bakhlo / 次候補 |
| --- | --- | --- |
| 全体の形 | `HouseholdImagePersistence.lean`の名前付きsection。長さはUnicode scalar数。未知sectionと未変更bodyを保存 | 標準S式構文＋名前付きschema。外枠の文字数再計算は不要だが、schema/admissionは別に保守する |
| 通常の選択/書込 | `HouseholdAuthority.lean:publishObserved?`がlock下で観測byte比較、全体staging/readback、旧全体を `.prev` に保持、rename | 単一S式も全体更新。attempt/pending/無期限beforeとfile/parent fsyncがある。**LOAMを追記形式として比較しない** |
| 履歴 | Actualの訂正/日付frontierを保持。`.prev`は一世代で、長期履歴はGitが意図されている | 訂正済みの現行明細。beforeが永久増加する現実装は長期保持policyではない |
| 未知情報/家計範囲 | 外枠のopaque保存と各既知familyのqualificationを分離 | Dailyは部分範囲。未知opaque/token変換の欠落と、未対応家計family/外部configを先に区別する |
| 書込の確かさ | 見たHouseholdAuthority経路には明示fsyncがない。stagingは自身もdurability claimをしない | fsync成功・rename/readbackだけではpower-lossやAck lossを認定しない。Records parent syncは一部unsupported errnoを許容し、単一経路と同保証とも言えない |
| 長期抽出 | 各内側codecと解釈configが必要 | Parsexp以外でもS式構文は読めるが、意味・version・解釈configなしで移行できるわけではない |

したがって、**「デメリットはパーサ保守だけ」とは現段階では言えない**。
構文の選択、訂正モデル、保存protocol、保持policy、変換範囲の差を分けて判断する。
ただし、上の費用がS式そのものの不可避な限界だと示されたわけでもない。
LOAMの過去ベンチは[長期Actual調査](https://github.com/shumoku88-bit/loam/blob/ce21ab38e78c81e6185f8fe53144e76fdd34cfcd/docs/research/falsification/LONG_HISTORY_ACTUAL_READ_PRESSURE_2026-09.md)
の独立した証拠。同じ家計操作・負荷・hostでないため今回との生時間の勝敗比較はしない。

## 次に選定を進める条件

1. **最小の一冊を定義**: [正データの論理設計研究](CANONICAL_DATA_DESIGN.ja.md)で、
   日常の訂正・予定完了/取消・残高根拠・通貨scale・必要な
   分類/解釈configを一覧化。未知field/familyの保存/拒否と、byte集合としてのbackup範囲を決める。
   Daily v3が必要な家計情報をすべて表すとの認定はまだしない。
2. **分解結果から候補を絞る**: 上の第2段階でprinter、syntax decode、admission、
   backup/write/readbackを測定済み。次は印字/一時表現と全体再構築を候補にし、
   ownershipとrefusalを維持したまま費用を減らせるか合成prototypeで確認する。
   全保存の無期限backupから、通常復旧＋明示的な長期archiveの設計候補を分ける。
   既存backup/不確定artifactの自動削除はしない。
3. **追記候補に同じ日常操作を要求**: 過去訂正、予定完了/取消、観測更新を含む一体保存、
   snapshot切替とcompaction中断、旧token/idempotencyを設計・確認してから再比較。
   現行v1の追記速度だけで採用しない。新しい形式実装はこの調査の次の選択であり未実施。
4. **復旧と運用を選ぶ**: P7/Ack loss、不確定な結果の照合、破損/不足の拒否、backup保持、
   config込みの別媒体copyとfresh-host復元、version変換と抽出を確認する。
   今回は同host・同媒体の一ファイルcopyのみ。物理電源断・media障害・live backupは未検証。
5. **最後にLOAMとの差を再確認**: 同じ日常の回答と拒否、保守するcodec/protocolの量、
   保存待ち・起動・backup容量・復元手順・意図的に失う履歴回答を並べ、選定理由を残す。

現時点の推奨は、**論理情報を先にそろえ、構文を決め打ちせず、現行の保存経路をそのまま長期運用に認定しない**。
S式は現行baseline。行形式も同じ情報で比較する。単一保存の費用と、一体transaction付き追記の保守も比べる。
方式選定はこの調査内で行う。正式記帳先の切替、依存導入、backup削除、公開/pushは別の承認。
