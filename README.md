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
- 普段は`bk`のコマンドで記帳する。手編集のしやすさより、保存費用・復元の確実さと短く直接的な実装を優先する。

**LOAMで記録し見られたことを、`bk`のコマンドで使えるようにする（画面は再現しない、本人決定 2026-11-08）。**
予算配分・予算振替・予算消化・用途routing・Budget Windowだけは、実際に必要になるまで延期する。
Favaとhledgerへの出力は対象外。内部実装・保存構造までLOAMと同じにする必要はない。

## 使う

```sh
bk                  # 今日の目安とコマンドの一覧（bk は ./tools/household を呼ぶ）
bk r                # 記帳。bk help で全コマンド
./ui --demo [COMMAND] # 合成データだけで試す（scratch/ui-preview）
./ui [COMMAND]      # 比較用：最後の取得世代のBakhloコピーでコマンド
./ui loam           # 同じ世代のLOAMコピー（別の端末で）
```

バックアップの失敗は警告して異常終了する。ローカルの記帳は残り、pushできなかった
commitは次回に再送する。bakhlo自体が異常終了した場合は、その終了コードを保つ。

ランチャーは共有ツリーを使わず、push済みの`origin/main`を専用のworktree（`.run/`）で
ビルドして実行し、実行するcommitを1行で示す。オフラインやビルド失敗時は直前のバイナリ
を使い、バイナリが1つもなければ起動を拒否する。ランチャー本体（このスクリプト）は
作業ツリーから実行し、`origin/main`に固定されるのはbakhloのバイナリだけである。

比較コピーは`scratch/comparison`内だけにあり、原本には書き込まない（家計簿の`book.txt`を
Bakhlo用とLOAM用に1つずつ写す）。取り直すときは`./tools/compare refresh`、比較後は
`./tools/compare clean-copies`。
手順と制約は[AGENTS.md](AGENTS.md)の Latest-data comparison。

コマンドと保存の決まりは[cli/README](cli/README.md)。どのコマンドも保存の前にPreviewを見せ、
Enterで保存する。金額欄では`500+300`、`(500+300)/2`などの式を正確に計算する。

## 開発

```sh
./tools/bootstrap          # リポジトリ内に隔離したOCaml環境（初回のみ）
./tools/check              # ビルド、見本、bkの合成検査、privacy-scan
```

- [現在の状態と次の作業](docs/HANDOFF.md)、[作業規則](AGENTS.md)
- [構成](docs/ARCHITECTURE.md)、[意味の契約](docs/SEMANTIC_CONTRACT.md)、[開発手順](docs/DEVELOPMENT.md)
- [bkのコマンド](cli/README.md)、[答えの見本](test/README.md)
- [検証記録](docs/VERIFICATION.md)（2026-10-20より前は`90a5867`の同じファイル）

実データ・秘密情報はGitに入れない（`./tools/privacy-scan`）。
