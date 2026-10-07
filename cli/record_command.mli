(** 支出・移動の便利入力の試作。1対1の入力も複数の効果へ展開する。
    省略日付はローカルの今日、通貨は台帳に1種類だけ定義されている場合に補う。
    現在は外側のファイル入出力も含む。実データの運用保存としては未確認。 *)

type single_transfer = {
  from_locus : string;
  to_locus : string;
  amount : Z.t;
}

type movement_kind =
  | Single of single_transfer
  | Multiple of (string * Z.t) list

type request = {
  book_path : string;
  output_path : string option;
  date : string option;
  id : string option;
  measure : string option;
  movement : movement_kind;
  description : string option;
}

type plan =
  | Help
  | Record of request
  | Refused of string

val plan : string list -> plan
val help : Response.t

val evaluate : request -> (string, string) result -> Response.t
(** 取引候補を検査して出力先を置き換える。renameの成功は耐久性や競合防止の保証ではない。 *)
