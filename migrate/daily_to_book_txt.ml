(* Daily_book (book.sexp + appended records) -> Book_txt, then an independent
   comparison of entries, plans and every current quantity. *)
module B = Bakhlo_sexp.Daily_book
module L = Bakhlo_sexp.Book_log
module T = Bakhlo_book_txt.Book_txt
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module G = Bakhlo_application.Current_quantity_groups
module P = Bakhlo_application.Current_quantity_projection
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
let event = D.Identifier.Event.to_string
let coord (c : D.Effect_coordinate.t) = (locus c.locus, measure c.measure)
let quanta q = D.Quantity.quanta q

(* Rows of a LOAM-style memory file: the header, then rows; only the final line may be empty. *)
let rows ~header text =
  match String.split_on_char '\n' text with
  | first :: rest when first = header ->
      let rec body = function
        | [] -> []
        | [ "" ] -> []
        | "" :: _ -> refuse "blank-row"
        | r :: rest -> r :: body rest
      in
      body rest
  | _ -> refuse "bad-header"

let roles text =
  List.map
    (fun row ->
      match String.split_on_char '\t' row with
      | [ "ROLE"; l; kind ] ->
          ( l,
            match kind with
            | "ASSET" -> T.Asset
            | "LIABILITY" -> T.Liability
            | "EQUITY" -> T.Equity
            | "INCOME" -> T.Income
            | "EXPENSE" -> T.Expense
            | _ -> refuse "accounting-role-kind" )
      | _ -> refuse "accounting-role-row")
    (try rows ~header:"LOAM-ACCOUNTING-ROLE-MAP\t1" text with Refused why -> refuse ("accounting-roles-" ^ why))

(* attention.loam rows are Book_txt's ITEM/CLOSE lines: admit them through Book_txt. *)
let attention text =
  let body = try rows ~header:"LOAM-ATTENTION-MEMORY\t1" text with Refused why -> refuse ("attention-" ^ why) in
  match T.of_string (String.concat "" (List.map (fun r -> r ^ "\n") (("BOOK\t1" :: body) @ [ "END" ]))) with
  | Ok t -> (t.items, t.closes)
  | Error e -> refuse ("attention-" ^ T.code_name e.code)

let tx_of empty_memos (e : B.entry) : T.tx =
  let keyed = List.filter (fun p -> D.Effect.key p <> None) e.effects in
  let exchange =
    match e.exchange with
    | None ->
        if keyed <> [] then refuse "effect-key";
        None
    | Some (source, destination) ->
        if List.length keyed <> 2 then refuse "effect-key";
        let measure_of key =
          match
            List.filter
              (fun p -> Option.map D.Identifier.Effect_key.to_string (D.Effect.key p) = Some key)
              e.effects
          with
          | [ p ] -> measure (D.Effect.measure p)
          | _ -> refuse "exchange-key"
        in
        Some (measure_of source, measure_of destination)
  in
  let memo =
    match e.memo with
    | Some "" ->
        incr empty_memos;
        None
    | m -> m
  in
  {
    id = e.id;
    day = e.day;
    memo;
    effects =
      List.map
        (fun p : T.posting ->
          { locus = locus (D.Effect.locus p); measure = measure (D.Effect.measure p); amount = quanta (D.Effect.quantity p) })
        e.effects;
    reversal_of = e.reversal_of;
    original = e.original_amount;
    merchant =
      Option.map
        (function M.Merchant p -> T.Merchant (D.Identifier.External_party.to_string p) | M.Nonmerchant -> T.Nonmerchant)
        e.merchant;
    exchange;
  }

let plan_of (p : B.plan) : T.plan =
  {
    id = p.id;
    day = p.day;
    measure = p.measure;
    changes = p.changes;
    ending =
      (match (p.paid_by, p.cancelled_on) with
      | Some tx, None -> Some (T.Paid_by tx)
      | None, Some day -> Some (T.Cancelled day)
      | None, None -> None
      | Some _, Some _ -> refuse "plan-paid-and-cancelled");
  }

(* A reflected-root cut as the longest recorded prefix it contains plus later ALSO roots. *)
let anchor_of position ids (g : G.group) : T.anchor =
  let roots = List.map event g.reflected_roots in
  let pos r = match Hashtbl.find_opt position r with Some n -> n | None -> refuse "anchor-root-missing" in
  let inside = Hashtbl.create 64 in
  List.iter (fun r -> Hashtbl.replace inside (pos r) ()) roots;
  let rec prefix k = if Hashtbl.mem inside k then prefix (k + 1) else k in
  let k = prefix 0 in
  {
    last = (if k = 0 then None else Some ids.(k - 1));
    also = List.filter (fun r -> pos r >= k) roots |> List.sort (fun a b -> compare (pos a) (pos b));
    asserts = List.map (fun (a : P.assertion) -> (coord a.coordinate, quanta a.quantity)) g.assertions;
  }

(* Loci in a stable order: labelled, then approved, then first use. *)
let loci_of (p : B.payload) ~used =
  let labels = Option.value p.labels ~default:[] in
  List.iter (fun (_, label, _) -> if label = "" then refuse "empty-label") labels;
  let order = ref [] and seen = Hashtbl.create 64 in
  let add id = if not (Hashtbl.mem seen id) then (Hashtbl.add seen id (); order := id :: !order) in
  List.iter (fun (id, _, _) -> add id) labels;
  List.iter add (Option.value p.approved ~default:[]);
  List.iter add used;
  let hidden id = match p.approved with Some ap -> not (List.mem id ap) | None -> false in
  let loci =
    List.rev_map
      (fun id : T.locus ->
        match List.find_opt (fun (k, _, _) -> k = id) labels with
        | Some (_, label, help) -> { id; label; help; hidden = hidden id }
        | None -> { id; label = id; help = ""; hidden = hidden id })
      !order
  in
  let added = List.filter_map (fun (l : T.locus) -> if List.exists (fun (k, _, _) -> k = l.id) labels then None else Some l.id) loci in
  (loci, added, List.filter_map (fun (l : T.locus) -> if l.hidden then Some l.id else None) loci)

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
               && Z.equal (quanta (D.Effect.quantity p)) q.amount)
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
      let ending = match q.ending with Some (T.Paid_by t) -> (Some t, None) | Some (T.Cancelled d) -> (None, Some d) | None -> (None, None) in
      if p.id <> q.id || p.day <> q.day || p.measure <> q.measure || p.changes <> q.changes || (p.paid_by, p.cancelled_on) <> ending
      then refuse ("plan-differs:" ^ p.id))
    source plans

let convert input =
  try
    (match input.settlements with Some s when s <> "" -> refuse "settlements" | _ -> ());
    let loaded = match L.load input.book with Ok l -> l | Error why -> refuse ("book-" ^ why) in
    if loaded.torn then refuse "torn-tail";
    let book = loaded.book in
    let p = B.export_payload book in
    (match p.presence with Some pr when pr.coordinates <> [] -> refuse "presence" | _ -> ());
    let empty_memos = ref 0 in
    let txs = List.map (tx_of empty_memos) p.entries in
    let ids = Array.of_list (List.map (fun (tx : T.tx) -> tx.id) txs) in
    let position = Hashtbl.create 1024 in
    Array.iteri (fun i id -> Hashtbl.replace position id i) ids;
    let roles = Option.fold ~none:[] ~some:roles input.accounting_roles in
    let items, closes = Option.fold ~none:([], []) ~some:attention input.attention in
    let zero_origins = List.map coord p.origins in
    let openings = List.map (fun (o : Q.opening) -> (coord o.coordinate, event o.opening_event)) p.openings in
    let anchors = List.map (anchor_of position ids) p.observations in
    let history_from = List.map (fun (c, day) -> (coord c, day)) p.bounded in
    let coordinates =
      List.concat_map (fun (tx : T.tx) -> List.map (fun (e : T.posting) -> (e.locus, e.measure)) tx.effects) txs
      @ zero_origins @ List.map fst openings @ List.map fst history_from
      @ List.concat_map (fun (a : T.anchor) -> List.map fst a.asserts) anchors
    in
    let used =
      List.map fst coordinates @ List.concat_map (fun (pl : B.plan) -> List.map fst pl.changes) p.plans @ List.map fst roles
    in
    let loci, added_loci, hidden_loci = loci_of p ~used in
    let target : T.t =
      {
        measures = p.measures;
        loci;
        roles;
        txs;
        plans = List.map plan_of p.plans;
        zero_origins;
        openings;
        history_from;
        anchors;
        items;
        closes;
      }
    in
    let text = T.to_string target in
    let admitted =
      match T.of_string text with
      | Ok t -> t
      | Error e -> refuse (Printf.sprintf "book-txt-%s-line-%d" (T.code_name e.code) e.line)
    in
    if admitted <> target || T.to_string admitted <> text then refuse "book-txt-roundtrip";
    compare_entries p.entries admitted.txs;
    compare_plans p.plans admitted.plans;
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
          | Ok (Q.Exact x) -> Some (quanta (Q.quantity x))
          | Ok (Q.Known_present _) -> refuse "presence"
          | Error (Q.Support_unknown _) -> None
        in
        match (source, T.balance admitted ~locus:l ~measure:m) with
        | Some a, T.Known b when Z.equal a b -> incr known
        | None, T.Unknown -> incr unknown
        | _ -> refuse ("balance-differs:" ^ l ^ "/" ^ m))
      distinct;
    Ok
      ( admitted,
        {
          entries = List.length admitted.txs;
          plans = List.length admitted.plans;
          coordinates = List.length distinct;
          known = !known;
          unknown = !unknown;
          added_loci;
          hidden_loci;
          empty_memos = !empty_memos;
        } )
  with Refused why -> Error why
