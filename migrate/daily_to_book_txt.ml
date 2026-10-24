(* The household's one-time conversion to book.txt, and the comparison that checks a
   book against its book.txt value through two separate implementations. *)
module B = Bakhlo_sexp.Daily_book
module L = Bakhlo_sexp.Book_log
module X = Bakhlo_sexp.Daily_txt
module T = Bakhlo_book_txt.Book_txt
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module M = Bakhlo_application.Event_merchants

type input = {
  book : string;
  accounting_roles : string option;
  attention : string option;
  settlements : string option;
}

type report = {
  entries : int;
  plans : int;
  coordinates : int;
  known : int;
  unknown : int;
  added_loci : string list;
  hidden_loci : string list;
  empty_memos : int;
}

exception Refused of string

let refuse why = raise (Refused why)
let locus = D.Identifier.Locus.to_string
let measure = D.Identifier.Measure.to_string

let compare_entries (source : B.entry list) (txs : T.tx list) =
  if List.length source <> List.length txs then refuse "entry-count";
  List.iter2
    (fun (e : B.entry) (tx : T.tx) ->
      let same_effects =
        List.length e.effects = List.length tx.effects
        && List.for_all2
             (fun p (q : T.posting) ->
               locus (D.Effect.locus p) = q.locus
               && measure (D.Effect.measure p) = q.measure
               && Z.equal (D.Quantity.quanta (D.Effect.quantity p)) q.amount
               && Option.map D.Identifier.Effect_key.to_string (D.Effect.key p) = q.key)
             e.effects tx.effects
      in
      let memo = match e.memo with Some "" -> None | m -> m in
      if
        e.id <> tx.id || e.day <> tx.day || memo <> tx.memo || (not same_effects) || e.reversal_of <> tx.reversal_of
        || e.original_amount <> tx.original
        || Option.map
             (function M.Merchant p -> Some (D.Identifier.External_party.to_string p) | M.Nonmerchant -> None)
             e.merchant
           <> Option.map (function T.Merchant s -> Some s | T.Nonmerchant -> None) tx.merchant
        || Option.is_some e.exchange <> Option.is_some tx.exchange
      then refuse ("entry-differs:" ^ e.id))
    source txs

let compare_plans (source : B.plan list) (plans : T.plan list) =
  if List.length source <> List.length plans then refuse "plan-count";
  List.iter2
    (fun (p : B.plan) (q : T.plan) ->
      let ending =
        match q.ending with
        | Some (T.Paid_by t) -> (Some t, None)
        | Some (T.Cancelled d) -> (None, Some d)
        | None -> (None, None)
      in
      if p.id <> q.id || p.day <> q.day || p.measure <> q.measure || p.changes <> q.changes
         || (p.paid_by, p.cancelled_on) <> ending
      then refuse ("plan-differs:" ^ p.id))
    source plans

let check book (t : T.t) =
  try
    compare_entries (B.entries book) t.txs;
    compare_plans (B.plans book) t.plans;
    let coordinates =
      List.concat_map (fun (tx : T.tx) -> List.map (fun (e : T.posting) -> (e.locus, e.measure)) tx.effects) t.txs
      @ t.zero_origins @ List.map fst t.openings @ List.map fst t.history_from
      @ List.concat_map (fun (a : T.anchor) -> List.map fst a.asserts) t.anchors
    in
    let distinct = List.sort_uniq compare coordinates in
    let image = B.image book in
    let known = ref 0 and unknown = ref 0 in
    List.iter
      (fun (l, m) ->
        let c : D.Effect_coordinate.t =
          {
            locus = (match D.Identifier.Locus.of_string l with Ok x -> x | Error _ -> refuse "locus-id");
            measure = (match D.Identifier.Measure.of_string m with Ok x -> x | Error _ -> refuse "measure-id");
          }
        in
        let source =
          match Q.query image c with
          | Ok (Q.Exact x) -> Some (D.Quantity.quanta (Q.quantity x))
          | Ok (Q.Known_present _) -> refuse "presence"
          | Error (Q.Support_unknown _) -> None
        in
        match (source, T.balance t ~locus:l ~measure:m) with
        | Some a, T.Known b when Z.equal a b -> incr known
        | None, T.Unknown -> incr unknown
        | _ -> refuse ("balance-differs:" ^ l ^ "/" ^ m))
      distinct;
    Ok
      {
        entries = List.length t.txs;
        plans = List.length t.plans;
        coordinates = List.length distinct;
        known = !known;
        unknown = !unknown;
        added_loci = [];
        hidden_loci = [];
        empty_memos = 0;
      }
  with Refused why -> Error why

let convert input =
  match input.settlements with
  | Some s when s <> "" -> Error "settlements"
  | _ -> (
      match L.load input.book with
      | Error why -> Error ("book-" ^ why)
      | Ok loaded when loaded.torn -> Error "torn-tail"
      | Ok loaded -> (
          let sidecars : X.sidecars =
            {
              roles = Option.value input.accounting_roles ~default:"";
              attention = Option.value input.attention ~default:"";
            }
          in
          match X.to_txt loaded.book sidecars with
          | Error why -> Error why
          | Ok (t, n) ->
              Result.map
                (fun r ->
                  (t, { r with added_loci = n.added_loci; hidden_loci = n.hidden_loci; empty_memos = n.empty_memos }))
                (check loaded.book t)))
