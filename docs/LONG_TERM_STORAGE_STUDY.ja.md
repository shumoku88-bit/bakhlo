# 長期保存方式の調査

状態: **第1〜5段階は測定済み。Records・年別S式は2026-10-20に削除。次の方針はAGENTS.mdの Storage direction（差分更新Core→追記ログ＋捨てられるsnapshot）。**

最新の配置/分析・繰越・年度間参照・原子性/復旧と合成検証計画は
[暦年別S式研究](YEAR_PARTITIONED_SEXP_RESEARCH.ja.md)が所有する。
[Irmin Phase 1](IRMIN_STORAGE_RESEARCH.ja.md)・[Phase 2](IRMIN_PHASE2_RESULTS.ja.md)は保存済み。
限定通常操作は成功したが、HEAD途中書込み故障で選択参照不整合を観測し、durable Saved未確立。
Irminの本体導入は保留、SQLiteはtransaction/安全性/費用/保守の比較候補として残す。
この文書の第1〜4段階は**S式既存経路の測定履歴**で、IrminのPhase番号とは別。

家計簿の長期運用は既知の基本要件であり、UI完成後の追加課題ではない。
この文書は「何十年使える保存方式を選べるか」「LOAMとの違いはパーサ保守だけか」
を扱う。[意味の契約](SEMANTIC_CONTRACT.md)が優先し、LOAMは引き続き正データの唯一の運用先。
正データ・私用コピーを読んだり変更したりせず、合成データと公開実装だけを調べた。

## 既存経路baselineの範囲と再現

以下は当時の測定記録。2026-10-12、Bakhlo `3a85b4c3c4e599ed86445859c8ef1515f299a5b4` の作業ツリーで、
計測ドライバとUI/比較関連の未コミット変更があった（後にcheckpointへ保存）。
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
- **当時のhypothesis**: AST/レイアウトprobe/引用再計算を減らす直接出力。
  後続の第3・4段階で限定試作を測定したが、production改善としては未採用。
  手編集向け整形は主目的ではなく、escape/整数/往復/拒否を維持する。
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

## 第3段階: S式のまま、中間ASTなしで直接印字する試作

checkpoint `a81d0df1e2c35aa0ba98dd1810bf54ba403dfeca`を
`research/canonical-storage-checkpoint`へpushした後の、**未採用のscratch試作**。
証拠は`scratch/direct-print-study-Nu2SzS`。prototype/生成source/実行手順/環境hash/
raw logs/`findings.md`を保持した。運用の`Daily_book`/publisherは変更していない。

同じ観測sourceのcontrolとdirectを比較。directは同じv3項目をBufferへ直接出し、
AST、quoted-string中間buffer、幅probe/pretty layoutを使わない。空白を減らし、
data stringを引用する。同じS式文法で、別parser/schema/backendを作らない。
**複数の出力上の変更をまとめた試作で、AST削減だけを単独分離した測定ではない。**
再解析・全体意味入場・再印字安定性のgate、lock/照合、全書込/readback/sync/backup、
不確定/復旧処理は元のまま。新しいprinterでのcanonical bytesはcontrolと異なるため、
両者を元のnative reader/printerで正規化した最終bytesの一致を確認した。

短い合成のrich probeでは、両出力のS式AST一致と元native oracle一致も確認した。
Unicode/引用/改行/CR/tab/backslash/NUL/DEL、220-bit量、key/Exchange、OpeningSupport、
非空の観測/存在cut、provided空と未供給を含む。両variantで7 returned checkpoint fault/
競合無変更/malformed拒否、全9保存の正確量・unknown・訂正・予定対応/終端、fresh restore成功。
初期2試行はprobeのOCaml予約語とcompile入力copy不足で失敗。修正前source/途中成果を別dirへ
残し、成功として数えずfresh trialを実行した。新SIGKILL/電源断/P7認定ではない。

| 30年相当の合成負荷 | control | direct |
| --- | ---: | ---: |
| 新規保存中央値（3試料） | 4.341秒 | 3.032秒 |
| 印字2回（record-2） | 1.573秒 | 0.463秒 |
| 総割当（record-2） | 499.73M words | 336.93M words |
| 量訂正 | 5.458秒 | 3.998秒 |
| 行数訂正 | 5.269秒 | 4.046秒 |
| 日付訂正 | 5.229秒 | 3.908秒 |
| 予定支払い | 4.483秒 | 2.984秒 |
| 予定変更 | 5.225秒 | 3.886秒 |
| 予定取消 | 5.386秒 | 4.267秒 |
| 最終file | 29.54 MB | 26.29 MB |
| 9 before backups | 265.85 MB | 239.84 MB |

この実行では保存中央値が約30%、累積一時割当が約33%低下した。
印字割当は192.04M→35.20M words。**同じS式のままでも、出力実装を簡単にする余地がある。**
同時にfileが小さくなったためI/O量も減り、heap lifetime/GCの位置も変わった。
パーサ/入場の全体再構築は残り、backupは依然として保存ごとに全体サイズで増える。
この試作だけで長期保存問題やsyntax選択を解決したとは言わない。

1,000件はcontrol→direct、109,500件はdirect→controlの順に実行したが、反復/無作為化した
crossoverではない。filesystem cacheはflushせず、各count/variant 1 worker、他操作1試料。
改善率の一般保証や安定p95ではない。全検査/再読込/復元を含むpeak RSSは約1.69→1.37 GiBで、
TUIの常駐/idle/live heapの比較ではない。privateデータ/新依存/GC tuning/自動pruneは使わない。

残る全Actual command/入場の割当と、候補/serialized/checked世代の所有は改善候補として残す。
直近の第一候補は暦年配置の同等性検証。serializerの検査目的、保存設計、試作printerの
運用採用/広いcodec互換性/全家計移行を混同せず、printer採用は引き続き未認定。

## 第4段階: 出力不変の引用長計算を単独比較

外部pitの未実行案を受け、既存local OCaml計測器で実行した。
外部のPython保存モデル/未添付scriptは取り込まず、証拠を
`scratch/quote-length-study-z4vm71`へ保持した。**scratch copyだけで、未採用。**

control/lengthの差はlayout probeの`String.length (leaf s)`を、文字列を作らない
`leaf_length s`へ替えた1箇所。元のinteger判定を共用し、引用2 bytes、特殊escape
2 bytes、decimal control escape 4 bytes、その他1 byteを数える。
出力するquote/AST/layout幅/語彙/全入場/再印字比較/公開・backup・不確定gateはそのまま。
端末文字幅や金額のmachine-int変換ではない。probeは元のraw-length上限判定も維持した。

空文字、全1-byte/2-byte組合せ、Unicode/control/長文/符号付き・整数風文字列を
元quoteの実際の出力長と比較。11,153 renderer例で110-byte境界、tag/non-tag、深い
indentを含む両process出力が完全一致した。rich Bookの元native printer一致、7 returned
checkpoint fault/競合無変更/malformed拒否も成功。各負荷の保存/訂正/予定/復元の期待値と
最終selected/restored/正規化bytesは一致。最初のprepareは観測wrapperとの曖昧anchorを
拒否したので失敗として保持し、unique anchorに修正してfresh trialで実行した。

| 合成明細数 | control新規保存中央値 | 引用長計算 |
| --- | ---: | ---: |
| 1,000 | 0.0464秒 | 0.0488秒 |
| 36,500 | 1.579秒 | 1.483秒 |
| 109,500 | 4.335秒 | 4.286秒 |

30年相当のrecord-2では印字2回が1.576→1.492秒、印字割当192.04M→141.66M words、
全保存割当499.73M→449.35M words（約10%減）だった。
**約403 MBの累積短命割当は減ったが、実用的な速度・常駐メモリ改善を示したとは言えない。**
promoted/major wordsはほぼ同じ、全worker peak RSSも両方約1.69 GiB。
read/write traffic、29.54 MBのfile、265.85 MBの9 backupsは完全に同じ。
109,500件の時間差約1%は小さく、1,000件では方向も逆で、安定したspeedupとは認定しない。

各count/variant 1 worker、記帳3連続試料/他操作1試料、cacheをflushしない。
1,000/36,500件はcontrol先、109,500件はlength先で、反復無作為化crossoverではない。
新SIGKILL/電源断/P7/移行/別環境復元の認定ではない。
第3段階とは違いfile bytesを変えない切分けであり、短命引用buffer削減だけでは
全文保存・全体再構築・backup蓄積を解決しないと分かった。
この小改善の採否と、正データの論理構造/構文/保存方式の選定を分ける。

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
2. **暦年別S式を先に検証**: 単一S式と当年＋必要期首根拠の候補で意味/回答/拒否をそろえる。
   年度間分析と採択した支給日cycleを保存年から独立させ、繰越失効・参照閉包を確認する。
   最初の2025-10-15〜2026-10-14/6 cycleの入口は専用計画へ集約。今回はまだ実装しない。
   printer試作の改善率を配置の速度保証やschema採択へ広げず、既存検査gate/backupを維持する。
3. **同じ日常操作・復旧で候補比較**: 年度切替/複数fileの一体更新を未解決のまま明示し、
   意味同等性の後に故障/不確定/復元を確認する。SQLiteも同じ保持/原子性条件で比較。
   IrminはPhase 2の限界により導入保留。現行Records v1の追記速度だけで採用しない。
   全体beforeと長期archiveの保持policyは別に選び、既存artifactを自動削除しない。
4. **復旧と運用を選ぶ**: P7/Ack loss、不確定な結果の照合、破損/不足の拒否、backup保持、
   config込みの別媒体copyとfresh-host復元、version変換と抽出を確認する。
   今回は同host・同媒体の一ファイルcopyのみ。物理電源断・media障害・live backupは未検証。
5. **最後にLOAMとの差を再確認**: 同じ日常の回答と拒否、保守するcodec/protocolの量、
   保存待ち・起動・backup容量・復元手順・意図的に失う履歴回答を並べ、選定理由を残す。

現在の推奨は、**暦年別S式を第一研究候補にし、同じ情報・回答・拒否を先に検証する**。
単一S式はcontrol、SQLiteは比較候補、Irminの本体導入は保留。性能/保守とdurabilityを分け、
現行単一S式や年別配置をそのまま長期運用に認定しない。構文再比較は必要時の別軸。
研究文書/既存合成再現ソースの研究ブランチへの保存・pushは今回承認済みだが、
年度分割実装、正データ切替、依存追加、backup削除、main push/PR/mergeは含めない。

## 第5段階: 起動・スナップショット・メモリ上応答（2026-10-20）

`./tools/startup-probe`（合成のみ、原本/私用コピーは読まない）。Bakhlo `3bda3ca`、
macOS x86_64 / OCaml 5.3.0。filesystem cacheはflushしていない。冷ロードは新規プロセスで3回。
目標値はユーザー指定の案（30年≒109,500件で起動100ms・保存5ms・キー応答16ms）。

| 件数 | S式起動（冷） | うちParsexp | Marshal起動（冷） | 既存明細の置換（メモリ） | 新規追加（メモリ） | live book |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 19 ms | 6.7 ms | 5 ms | 5.1 ms | 0.002 ms | 0.9 MiB |
| 36,500 | 770 ms | 336 ms | 62〜69 ms | 249 ms | 0.002 ms | 33 MiB |
| 109,500 | 2,370 ms | 969 ms | 185〜196 ms | 796 ms | 0.002 ms | 100 MiB |

- S式起動の約4割が構文解析、残りがdecode/`make_data`/全体入場。
- `Marshal.Closures`で入場済み`Daily_book.t`を保存すると冷ロードは約12倍速く、残高も一致。
  ただし量に比例し、30年で100msには届かない。Marshalは同一binary限定の捨てられる
  cache候補としてのみ測った。正データ形式や採用ではない。
- **新規の素の明細以外（訂正・Reversal・Exchange・OriginalAmount・Merchant・予定支払い）は
  `put_entry_full`で全体再入場する**（`sexp/daily_book.ml:1395`）。保存方式と独立に、
  訂正1回が10年で約0.25秒、30年で約0.8秒の応答停止になる。
- 30MBのS式がlive約100MiB。うち`Q.t` imageが約80MiB（entries listと共有部分あり、単純加算しない）。
- 残高照会・`daily_pace`は約1µs以下。

次の候補順: (1) 訂正等の差分入場を、全体入場と同じ拒否を保ったまま可能か調べる、
(2) 全操作を1レコードで表す追記ログ＋捨てられるsnapshot、(3) 古い年の遅延読込。
SQLiteは当面使わない（ユーザー判断 2026-10-20）。
旧`tools/storage-study`/`tools/storage-breakdown`等は現HEADで実行できなくなっていたため、2026-10-20に削除した（結果は上の記録に残る）。

## 第6段階: 訂正・予定・語彙の差分更新（2026-10-20）

同じ`./tools/startup-probe`・合成fixture（バイト同一）で、メモリ上の操作だけを比較。

| 109,500件 | 第5段階 | 差分化後 |
| --- | ---: | ---: |
| 既存明細の訂正 | 796 ms | 4.3 ms |
| 予定の追加 | （全体入場 ≒0.8 s） | 0.001 ms |
| Locus追加 | （全体入場 ≒0.8 s） | <0.001 ms |
| 新規記帳・残高照会・Daily Pace | 0.002 ms以下 | 変化なし |

- 訂正はReversal組・Exchange・期首根拠・presence根拠に関わらない明細だけをその場で更新し、
  それ以外は従来の全体入場に戻る。訂正は明細listの置換でまだ件数に比例する（目標16 ms内）。
- 予定と語彙は残高に影響しないため、その段階だけを検査して残高imageを再利用する。
- 正しさは`test/daily_book_oracle_tests.ml`で、全操作を全体入場の参照（`Daily_book.Full`）と
  保存後の冷再読込の両方に一致させて確認（400系列×30操作、presence根拠ありfixtureを含む）。
- 起動（S式2.2 s、snapshot 0.19 s）・保存は未着手。次は追記ログ＋捨てられるsnapshot。

## 第7段階: 保存を記録の追記に置き換え（2026-10-20）

`Daily_file.append`：Coreで操作を適用→未変更確認→記録行1行を追記＋fsync→末尾読戻し。
保存ごとの全文書換え・attempt/pending/before（無期限backup）は廃止。圧縮時に`.prev`を1世代残す。

| 合成fixture | 第5段階（全文書換え） | 追記 |
| --- | ---: | ---: |
| 1,000件 | 0.049 s | 0.66 ms |
| 109,500件 | 4.73 s | 36.5 ms |

109,500件の36.5 msの大半はsessionが保持するファイル全文（31 MB）の連結コピーとそのGC
（単独の連結で約8.5 ms、fsync込みの1,000件保存全体が0.66 ms）。目標5 msには、全文の代わりに
revision tokenを持たせる次の段階が必要。起動（S式2.2 s）は未着手。

## 第8段階: 版番号（revision）で全文コピーをなくす（2026-10-20）

sessionはファイル全文の代わりに、サイズと末尾4 KiBのdigestからなるrevisionと末尾4 KiBだけを持つ。
追記後のrevisionは追記した行だけから計算する。

| 合成fixture | 第7段階 | revision |
| --- | ---: | ---: |
| 1,000件 | 0.66 ms | 0.57 ms |
| 36,500件 | — | 0.58 ms |
| 109,500件 | 36.5 ms | 0.60 ms |

保存は件数によらずほぼ一定（目標5 ms以内）。revisionは連続する保存を区別するための識別子で、
全バイトの同一性の証明ではない。書込みはinode・サイズ・更新時刻・末尾の一致確認で守る。
