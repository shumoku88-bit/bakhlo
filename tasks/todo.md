# やること

まだのことだけを、上ほど先に置く。済んだら、その作業のコミットで消す（何をしたかはGitと
[検証記録](../docs/VERIFICATION.md)に残る）。不具合は再現できる形で書く：コマンドと、打った
答えの順（例：`bk pay` → `q` → Enter）。コマンドは[cli/README](../cli/README.md)。
済んだ項目の残る前の版は`858b489:tasks/todo.md`、TUIの未完了・受入領域は`6453e14:tasks/todo.md`。

## 不具合

- 今は知られていない。

## 次

- qemacsの作者たちの開発から学んで直す（2026-11-09から、順に）：
  - 5 依存を持たないこと：Unicodeの表をデータから生成するqemacsと、`cli/width.ml`の表示幅の表を比べる。
  - 6 小ささと速さ：保存は合成109,500件で164 ms（目標100 msを超える）、起動1.9 s。qemacsの
    バッファ表現（ページ・mmap）を参考に、測ってから見る。
  - 最後に、Bellardの作品（QuickJS・TCCなど）を読む。
- 家計で日々足りないと感じたもの（気づいたらここに足す）。
- Zigへの書き直し：コア（約6,000行）とその見本、次にbkコマンド（約3,500行とチェック）。
- 認められたMeasure・Locusの型（2026-10-28に設計で止めた）：再開はGitの
  `5b48008:docs/ADMITTED_TYPES_STUDY.ja.md`から。

## きっかけを待つ

- 起動：遅く感じたら、捨ててよいsnapshotから。古い年の遅延読み込みは必要なときだけ。
- `bk`の速さ：遅く感じたら、全件走査・sortの費用を測ってから決める。追加のGADT化は勧めない
  （調査はGitの`5b48008:docs/PERFORMANCE_AND_GADT_STUDY.ja.md`）。
- 予算配分・振替・消化・routing・Budget Window：必要になるまで作らない。

## 要判断

- LOAMのComplete Since（履歴の完全性の記録）をパリティ一覧に入れるか（Daily Paceの過去日に関わる）。
