# Bakhlo（バフロ）

OCamlで作るパーソナル家計簿。日々の記帳と編集、口座・科目、支払い予定、予算、
レポートを、読みやすいS式のデータで扱う。AIなしで動く普通の道具を目指す。

**開発中。普段の記帳と正データはまだLOAM。元データを変更せず、まずBakhlo用の候補を試す。**

## 大事にすること

- 金額を整数の最小単位で正確に扱い、異なる通貨を勝手に合算しない。
- 残高が不明なことと、明示的にゼロであることを区別する。
- 入力ミスの訂正と、実際の返金・取消を区別する。
- 正データは訂正済みの明細でよい。修正前は元データやバックアップで別に残せる。
- 人間が読めるデータと、短く直接的な実装を優先する。

永久の訂正ログ、LOAMの全内部構造、教科書化、複数バックエンドは必須条件にしない。
これは必要な予定・予算・レポートを省くという意味ではない。

## 今できること

- 独立した数量・取引検査と、根拠のある残高／不明の回答。
- 限定された普通の記帳形式のS式読取と、新しい候補ファイルへの書出し。
- 新しい家計簿S式をNotty／Bonsai画面で読み、記帳・終了・再起動・編集・科目追加・予定の支払いを試せる。
  編集前の内容は別バックアップに残し、正データの明細IDは保つ（まだ試用保存）。
- Daily台帳の純粋APIで、単発予定の作成・変更・日付付き取消を扱える（操作UIは未接続）。
  取消済み予定は残し、支払い済み／取消済みの再支払いを拒否する。
- `Daily_book.daily_pace`でLOAM Home `d`相当の今日の目安を計算できる（UIは未接続）。
  対象口座・通貨・観測日・期間末を明示し、残高と控除した予定も返す。予算残額とは別。
- Daily台帳の純粋APIで、期間・通貨・用途の予算配分、用途間の再配分、記録された実績・
  未払い予定・残額を扱える（UIは未接続）。対象科目と用途割当は明示し、未割当と管理外を区別する。
  予算を供給した台帳はDaily v4で保存する。口座の資金や履歴の完全性を保証する機能ではない。
- `record` で単一通貨の支出・収入・振替を記録できる。
- v3 Bookでは `exchange` で両替元と両替先の通貨・数量を明示した両替を記録でき、
  受け取った現地通貨は通常の `record --measure` で使える。
- `record` の上書き経路はまだ実データの耐久保存として未確認。元データには使わない。

現在の `bakhlo 1/2/3 ordinary-quantity` Bookは訂正関係を保持する既存形式で、
支払い予定やLOAM全体を表せる形式ではない。新しい `bakhlo-daily` は別形式で、
訂正済み明細・予定・独立した数量根拠を扱う。`record` / `exchange` CLIとは混用しない。
形式を変える場合は明示的に変換し、古いファイルを残す。

## ビルドと試用

```sh
./tools/bootstrap
./tools/check
./tools/opam exec -- dune exec bakhlo -- --help
./tools/opam exec -- dune exec bakhlo -- inspect-current-sexp --summary \
  examples/ordinary-sexp/initial.sexp wallet jpy food jpy
./tools/opam exec -- dune exec bakhlo -- exchange --help
```

[合成データの短い例](examples/ordinary-sexp/README.md)で読取・候補作成を試せる。
`examples/ordinary-sexp/travel.sexp` はJPY→EUR両替、EUR支出、帰国時の逆両替を試すための
合成データ。両替レートを推測したり、異なる通貨を合算したりしない。
カード利用を外貨で記録して後日JPY決済と対応づける機能はこのPRの範囲外。
セットアップはリポジトリ内だけで行う。

### 日々の画面を試す

今ある隔離Notty／Bonsai環境を使う。`tools/tui` は依存を新規インストールしない。
最初は合成データを新しい場所へコピーする（既存ファイルは置換しない）。

```sh
umask 077
mkdir scratch/my-daily-trial
./tools/tui --copy-from examples/daily-book.sexp --book scratch/my-daily-trial/book.sexp
./tools/tui --book scratch/my-daily-trial/book.sexp
# 同じ台帳をBonsaiで開く（Nottyを終了してから）
./tools/tui bonsai --book scratch/my-daily-trial/book.sexp
```

上は記帳、下は閲覧。`Tab`／`Shift-Tab`で上下を切り替え、上の`↑↓`は記帳項目、下の`↑↓`は一覧選択。
下の`←→`で明細／予定を切り替え、下書きと各一覧の選択位置は保持する。
新規は出金元から。上の`←→`は通貨・科目の候補、日付・金額・メモでは文字カーソル。
出金元／入金先の`Enter`は検索できる口座・科目picker、
その他の入力項目の`Enter`は取引全体のプレビュー。確認paneの`Ctrl-S`だけが記帳し、`Esc`で入力へ戻る。
picker内の確定は下書きの選択だけで保存しない。明細一覧の`Enter`は閲覧専用の詳細。
`Ctrl-T`で単一通貨の複数posting下書き（行追加・削除・科目検索・正確な差額）。
そのpaneでは`Enter`は保存せず、`Ctrl-S`で検査・プレビュー、`Esc`は下書きを保持して閉じる。
`Ctrl-E`で選択した明細の編集（複数行は構成・キー・対応を保った金額訂正）、
`Ctrl-N`で下書きを明示的に破棄して新規、`Ctrl-P`でも予定／明細を切り替えられる。
予定の`Enter`はまず詳細、詳細の`Enter`で支払い入力へ。入力中の下書きがあれば置換を拒否する。`Ctrl-Q`で終了。
両画面は同じ入力・台帳・保存処理を使う。起動時にファイルがなければ拒否し、空台帳へ置き換えない。
[現在の対応範囲と保存の限界](tui/README.md)も参照。

## コードを見る場所

- `lib/`：識別子・金額・取引の小さな型。
- `application/`：検査と数量の問い合わせ。
- `sexp/`：既存Bookと、新しい `Daily_book` の純粋な読取・更新。
- `tui/`：新しい家計簿を使うNotty画面と、明示的なファイル入出力。
- `cli/`、`presentation/`、`bin/`：引数・表示・入出力。
- `loam_read/`：限定された読み取り専用LOAM入力。完全な移行アダプタではない。
- `test/`：既存のOCamlテスト。

## 次の作業と参考

まず[現在の引継ぎ](docs/HANDOFF.md)を見る。
[LOAMの機能棚卸し・乗り換え判定表](docs/CUTOVER_CHECKLIST.ja.md)で、
現在の対応範囲と切替前に必要な生活操作を選ぶ。
予定関連・各種残高・今日いくら使えるか・予算周り・Attentionは必要な分野として整理済み。
詳細は検討中で、既存経路を使う小さな段階案も同じ表にまとめている。ほかは必要な箇所だけ読む。

- [意味の契約](docs/SEMANTIC_CONTRACT.md)
- [開発手順](docs/DEVELOPMENT.md)
- [現在の実装・実験の設計資料](docs/ARCHITECTURE.md)
- [検証記録と限界](docs/VERIFICATION.md)

実データ・秘密情報はGitに入れない。試作の成功だけで本番移行や公開はしない。
