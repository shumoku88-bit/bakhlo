# Bakhlo（バフロ）

OCamlで作るパーソナル家計簿。記帳と支払い予定を土台に、各種残高・今日の目安・
必要なレポートで家計のやりくりをする。人間が読める正データを大切にし、AIなしで動く普通の道具を目指す。

**2026-10-21からBakhloで普段の記帳をしている。** 家計簿は`../bakhlo-data`（非公開のGitバックアップ付き）。
LOAMは凍結し、互換の参照としてだけ使う。

## 大事にすること

- 金額を整数の最小単位で正確に扱い、異なる通貨を勝手に合算しない。
- 残高が不明なことと、明示的にゼロであることを区別する。
- 入力ミスの訂正と、実際の返金・取消を区別する。
- 正データは訂正済みの明細でよい。長期の履歴はGitに任せる。
- 普段はTUIで編集する。手編集のしやすさより、保存費用・復元の確実さと短く直接的な実装を優先する。

**LOAMのユーザー向け機能・見た目・操作感と細部を、Bakhloでも再現する。**
予算配分・予算振替・予算消化・用途routing・Budget Windowだけは、実際に必要になるまで延期する。
Favaとhledgerへの出力は対象外。内部実装・保存構造までLOAMと同じにする必要はない。

## 使う

```sh
./tools/household   # 家計簿を開き、終了時に変更をcommitしてpushする
./ui --demo         # 合成データだけで試す（scratch/ui-preview）
./ui                # LOAM比較：最後の取得世代のBakhloコピー
./ui loam           # 同じ世代のLOAMコピー（別の端末で）
```

比較コピーは`scratch/loam-comparison`内だけにあり、原本には書き込まない。
取得し直すときは`./tools/compare refresh`、比較後は`./tools/compare clean-copies`。
手順と制約は[AGENTS.md](AGENTS.md)の Latest-data comparison。

Home / CalendarからDay / Month / Yearを`z`で切り替え、`/`で日付へ移動する。
`Tab`／`w`でCalendarとDetail、`Space`で階層型Commands。`r`でRecord、`a`でActual、
`s`でScheduled、`b`でBalances、`d`でDaily Paceへ進む。
RecordはEnter／Ctrl-SでPreviewを開き、**Publishを選んでEnterしたときだけ記帳する**。
Esc／Cancelは下書きを保持する。
金額欄では`500+300`、`(500+300)/2`などの式を整数／有理数で計算する。先頭の`-`／`+`は式全体の向き。
通貨の最小単位に収まらない結果・ゼロ除算は拒否し、下書きを保持する。
キー・保存・復旧の詳細は[tui/README](tui/README.md)。

## 開発

```sh
./tools/bootstrap          # リポジトリ内に隔離したOCaml環境（初回のみ）
./tools/check              # CoreとTUIのビルド・テスト・アーキテクチャ検査・privacy-scan
./tools/tui --self-check   # TUIの合成検査だけを回す（./tools/checkにも含まれる）
```

- [現在の状態と次の作業](docs/HANDOFF.md)、[作業規則](AGENTS.md)
- [構成](docs/ARCHITECTURE.md)、[意味の契約](docs/SEMANTIC_CONTRACT.md)、[開発手順](docs/DEVELOPMENT.md)
- [UI方針](docs/UI_DIRECTION.ja.md)、[画面別の差分台帳](docs/LOAM_UI_GAP_LEDGER.ja.md)、
  [普段使い5領域の差分](docs/CUTOVER_DIFF_LEDGER.ja.md)、[LOAM機能の棚卸し](docs/CUTOVER_CHECKLIST.ja.md)
- [検証記録](docs/VERIFICATION.md)（2026-10-20より前は`90a5867`の同じファイル）

実データ・秘密情報はGitに入れない（`./tools/privacy-scan`）。
