# LOAMの機能・見た目・使い勝手をBakhloで再現する

作業の順序と未完了だけを置く。画面別の差分・進捗は[UI差分台帳](../docs/LOAM_UI_GAP_LEDGER.ja.md)、
普段使い5領域の要約は[カットオーバー差分台帳](../docs/CUTOVER_DIFF_LEDGER.ja.md)、実行証拠は
[検証記録](../docs/VERIFICATION.md)。完了済みの記録と旧計画（#42再構築、CI段階、Home／Record
仕上げ、各sliceのレビュー）は`032a876:tasks/todo.md`にある。

## 優先順位

普段使いの5領域（Record、Scheduled、Loci、Balances、Daily Pace）の差を先に閉じ、
次に残るLOAM機能・画面を再現する。予算配分・振替・消化・routing・Budget Windowは必要になるまで延期。

## 要判断

- [ ] Trend / Locus comparisonの既定系列：LOAMは家計の科目3つを固定、Bakhloは先頭の科目で空のグラフになりうる。設定で選べるようにするか。
- [ ] LOAMのComplete Since（履歴の完全性の記録）をパリティ一覧に入れるか（Daily Paceの過去日に関わる）。

## 未完了

- [ ] Trend / Locus comparisonのグラフ描画（LOAMは補間した点字の線と期間軸）とマウスでの選択。
- [ ] Accountingの一覧欄で長い説明行が`…`省略される（詳細欄と並ぶため）。80×24で照合。
- [ ] Daily Pace：同じ端末寸法でcontext／Trend／History／Selected day／feedback／操作案内、
  グラフと日付軸・件数・選択・scroll・戻りを揃え、同じ入力で4寸法・全5期間・known／partial／
  unavailable・resize・coldをLOAMと対照する。
- [ ] Scheduled保存操作で owner→intent→Shell→単一writer→owner結果 を検証する。

## 受入領域（各画面の詳細は差分台帳）

各sliceは、入口から入力・確認・取消／確定・親復帰まで接続し、合成回帰、LOAM既存binaryとの
同じ入力での対照、保存→再起動の同一性、失敗・競合時の非保存と下書き保持を確かめる。
実装・self-check・対照実行・本人／IME受入・P7は別々に記録する。

1. [ ] Record lifecycle（新規・候補・Posting追加削除・差額補助・Preview全文／狭小gate・下書き再開）
2. [ ] Actual／Selected Day（検索・scope・sort・詳細、訂正・日付変更・Merchant／原額・返金／反転）
3. [ ] Scheduled（List／Series Calendar／Months／Detail、作成・置換・取消・実績化・補充・Expected pace）
4. [ ] Balances／Observe（Current／Accounting・履歴、根拠と不明、複数座標観測）
5. [ ] Daily Pace／Trend（Pool・期間、What-if、履歴支持、予定控除、設定の保存と保全）
6. [ ] Attention／Settlement／Exchange（期限・解決、部分精算・相殺、両数量と専用Preview）
7. [ ] 残るReports・Household setup・Help／Theme／locale・Print／診断・盆栽の表示と成長
