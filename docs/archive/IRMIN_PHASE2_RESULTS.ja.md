# Irmin 第2段階: 合成20件の最小実験

[第1段階](IRMIN_STORAGE_RESEARCH.ja.md)の既存資産/API調査を前提にした、隔離native実験。
**通常の一体更新・再読込・限定完全archive復元は確認。標準HEADのdurable Savedは認定しない。**
特に、途中branch書込みの故障で選択先commitが解決不能になるケースを実測した。
本体保存方式、Core、LOAM、本番/試用データは変更せず、root manifestは実装していない。
**Irminの本体導入は保留**。次の第一研究候補は[暦年別S式](YEAR_PARTITIONED_SEXP_RESEARCH.ja.md)、
SQLiteは比較候補として残す。合成実験の[再現用付録](irmin-phase2/README.md)にsource/固定依存を保存する。

## 環境・保全

- Bakhlo checkpoint `a81d0df1e2c35aa0ba98dd1810bf54ba403dfeca`をgit archiveした独立source。
- 実験領域 `scratch/irmin-phase2-oKzeZW/`。元のtracked差分と4文書を保存し、終了時byte一致。
- 専用OPAMROOT/local switch。既存`.tools/opam` 2.6.0のbinaryだけ再利用。
  元opam package一覧、本体/lock/wrapper等のhashも終了時一致。system package導入なし。
- 導入前に空き容量と依存解決案を確認した。導入基準: OCaml 5.3.0、Dune/Dune-configurator 3.24.2、
  ocamlfind 1.9.8、Base v0.17.3、Parsexp/Sexplib0 v0.17.0、Zarith 1.14。
- Irmin/irmin-pack/ppx_irmin **3.11.0**、Lwt **5.9.2**を固定。
  metadata repository `ac27950e5eac6c981ad809dff370c937820b7893`から事前dry-run: 56追加、
  upgrade/downgrade/removeなし。compiler等を含む導入後全67 packageを記録。
- `plan/solve.txt`, `install-atoms.txt`, `installed-all.txt`, `installed.export`,
  `environment.txt`, `final-source-binary.sha256`が依存/version/実行環境の証跡。
- macOS 15.7.9/x86_64。明示`use_fsync=true`, minimal indexing, GCなし、standalone `Lwt_main.run`。
  compiler/共通依存も独立に保持。ローカル容量/環境の生ログはignored scratchのみで、
  公開付録は再現に必要なtoolchain/version/platform条件だけを収める。

## 限定実装と意味境界

- 合成20 Actual、3 Scheduled、3通貨、180-bit quanta、escape/Unicode memo、安定ID/Effect key、
  非空reflected cut、独立数量、unknown Bank。手計算式による初期数量oracleも利用。
- `Daily_book`の追加/訂正/予定APIと既存parse/admissionをそのまま利用。
  独立量+cut更新だけは合成fixtureの既存support S式を置換し、全体を既存ownerで再入場。
  新しい家計判定器やproduction support更新APIではない。
- canonical Daily v3をsection/entry/plan cellsへ可逆分割し、変更cellだけimmutable treeへ追加。
  entry/posting/plan出現順は明示ordinalで保持し、tree探索順に委ねない。
  この小実験は全bookのcodec/admissionを保持しており、scale時の部分検査最適化ではない。
- writer lockを取ってから一つだけRW repoを開く。fixed observed head + CAS。
  stale draft拒否と二番目のstale CAS拒否を別検査。merge/retryによる意味変更なし。
  dangling branchを空storeとみなす再seedも拒否。
- `Commit.v` → `flush` → `Head.test_and_set` → 同head/treeの読戻しを別checkpoint化。
  呼出し成功は`head-update-success-not-durability`と記録し、Savedを返すpublisherは作らない。

## 結果（主証跡: `results/run-3/summary.tsv`、65ケース）

| 項目 | 観測 |
|---|---|
| 実績追加 | 3 cells更新、別process再読込一致 |
| 金額/日付/2→3 posting訂正 | 2 cells更新、reflected量を二重加算しない |
| Actual + Scheduled完了 | 4 cells更新、片方だけの状態なし |
| 予定置換/取消 | 各2 cells更新、再読込一致 |
| 独立量 + root cut | 一つのsupport payloadとpublication cellを更新、各通貨1100、Bankはunknown |
| 競合/所有/Core拒否 | stale CAS/draft、二番目RW、不均衡、重複IDを拒否。選択世代不変 |
| API checkpoint故障 | 予定完了とsupport更新それぞれ9点×returned exception/SIGKILL。HEAD前は旧、HEAD後は新を観測 |
| syscall故障 | dict/suffix/control/branchesへのEIO、short-write後EIO、partial-write後SIGKILL、およびpack fsync EIO |
| branch途中書込み | 2ケースで**branch存在、解決できるHEADなし**。新/旧どちらの正常世代とも呼べない |

checkpoint後の`new-valid`は、その時点の再起動processから読めた事実だけ。
callerに成功が届いたか/次に安全に再試行できるかは別であり、失敗callerは自動retryしない。
`signal--7`はOCamlの`Sys.sigkill`表現で、OSのsignal番号7という意味ではない。

### HEADの具体的な限界

`results/run-3/io-trace/stderr.txt`でdict/suffix/control/indexのwrite/fsync要求を観測。
branchの72-byte writeは観測したが、この操作にbranch fsync要求は見られなかった。
これは限定traceであり全filesystem命令や全条件の証明ではない。

`io-branches-short-eio`では最初の72-byte writeを36 bytesだけ進め、残りwriteでEIO。
`io-branches-partial-kill`では同じ部分書込み直後に子processをSIGKILL。
いずれも別processで`Branch.mem=true`、`Head.find=None`となったため、検査workerは
`dangling-selected-branch`として明示拒否。壊れたコピーをそのまま保存し、再seed拒否は別コピーで検査した。
旧commitが物理的にすべて失われた証拠でも、pack全体破損の主張でもない。
**選択参照の不整合を観測した**のであり、標準HEADへの単純CASを耐久なpublicationとは扱えない。

SIGKILLはOS page cacheを落とさない。成功したHEADが電源断で失われる試験はしておらず、
power-loss/P7/Ack-loss、初期作成のdurability、全てのwrite/offset/fsync故障は未確認。

## Irmin非依存の完全S式archive（この合成スコープのみ）

- 現在book全体、別のadmitted元basis、固定元`e02/e02-src`への80 unitsの参照、
  synthetic configのbyte内容、present-empty/absent、未知opaque bytes、
  選択commit/観測parent/operation/data SHA-256を一つのarchiveへ格納。
- 6通常操作ごとにarchiveだけのportable領域からstandalone restoreを実行。
  新directoryへbook/basis/config/opaqueと完全archiveを再構成し、byte/意味/照合情報を比較。
  restoreはCore+codec+Digestifでlinkし、Irmin/Lwt symbolなしも確認した。
- 数量/currency/unknown/cut/予定状態と、次のsupport更新・完了済予定への再支払拒否を検査。
  訂正後の60に80 unitsをretargetすると拒否、保存元102を使えば入場することを確認。
  basisをcurrent活動に足さない。Coreの参照判定と元Actualのfull admissionを両方使う。
- config/opaque/basis欠落・改変を拒否。HEADが解決不能なpackを開かず、既知の旧archiveから
  意味と外部bytesを復元する検査も実行した（最新未確認操作を救済したという意味ではない）。
- configはfixtureで凍結したbytesであり、実TUI設定の適用やlive外部ファイルとの世代照合は未検査。
  元Recordsのtoken/opaqueを落とす全家計export、任意の未知家計section、非空OpeningSupport/
  Presence、combined C authority、全移行、off-host/別OS復元は認定しない。
  archive内のcommit hashはprovenance。Irminなしでhash→実commitの真正性まで証明しない。
  archiveファイル自体の電源断durabilityや永続Ack照合方式も未実装。

## 追加量・未解決・次の比較

追加production code **0**。scratch実験は物理行で**495**:
OCaml 401（image/worker/restore 284、checks 117）、macOS syscall interposer C 73、shell 21。
既存Core snapshot/依存/保全失敗版は新規code量に含めない。compactな研究codeで、
LOCを保守性の順位や完成backendの見積りとしない。duplicate-interface/deprecated-clock警告は残る。
初期のDune外側root選択、syntax、virtual Digestif link、functor/printer APIの失敗も保存した。

- Irminの耐久な選択authorityとuncertain/retry判定が未解決。**root manifestは未実装**。
  本体導入を保留し、この問題を軽視した性能比較や自動的なmanifest開発へ進まない。
- SQLiteは未導入/未実験。同じCore/単位payload/原子更新/観測世代拒否、durable commitと
  failure分類、同じ履歴・元basis・config/opaque archive・復元条件を揃える必要がある。
  WAL FULL設定だけを実験済保証とは呼ばず、dependency/schema/adapter/保守量も比較する。
- 1,000件以上の性能/メモリ/履歴・backup/compaction測定は行っていない。
  標準HEADの選択安全性を未解決のまま性能優位や採用を結論しない。
- Phase 2実施時には本体/LOAMの保存方式・意味/拒否条件の変更、data移行、GC、push/PR/mergeは
  行わなかった。今回の研究文書/合成source付録の研究ブランチへの保存・pushは別の明示承認。
  main push/PR/merge、年度分割実装、実験環境削除は今回も対象外。
