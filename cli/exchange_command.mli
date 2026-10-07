(** 明示した2通貨の両側数量を記録する小さなCLI入口。
    v3 S-expression BookへExchange evidence付きEvent候補を作る。
    レート、手数料、評価額、自宅通貨、カード後日決済を推測しない。 *)

type side = { locus : string; measure : string; amount : Z.t }

type request = {
  book_path : string;
  output_path : string;
  date : string;
  id : string;
  source : side;
  destination : side;
  description : string option;
}

type plan = Help | Exchange of request | Refused of string

val plan : string list -> plan
val help : Response.t
val evaluate : request -> (string, string) result -> (Bakhlo_sexp.Book.t, Response.t) result
