(* Daily_book <-> book.txt, both directions, and the book.txt changes of one save. *)
module T = Bakhlo_book_txt.Book_txt
module B = Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module G = Bakhlo_application.Current_quantity_groups
module P = Bakhlo_application.Current_quantity_projection
module M = Bakhlo_application.Event_merchants

type sidecars = { roles : string; attention : string }

let no_sidecars = { roles = ""; attention = "" }

exception Refused of string

let refuse why = raise (Refused why)
let get why = function Ok x -> x | Error _ -> refuse why
let locus = D.Identifier.Locus.to_string
let measure = D.Identifier.Measure.to_string
let event = D.Identifier.Event.to_string
let coord (c : D.Effect_coordinate.t) = (locus c.locus, measure c.measure)

let coordinate (l, m) : D.Effect_coordinate.t =
  { locus = get "locus-id" (D.Identifier.Locus.of_string l); measure = get "measure-id" (D.Identifier.Measure.of_string m) }

let event_id s = get "event-id" (D.Identifier.Event.of_string s)

(* ---- sidecar texts ---- *)

let roles_header = "LOAM-ACCOUNTING-ROLE-MAP\t1"
let attention_header = "LOAM-ATTENTION-MEMORY\t1"

(* The header, then rows; only the final line may be empty. "" is no file. *)
let rows ~header text =
  if text = "" then []
  else
    match String.split_on_char '\n' text with
    | first :: rest when first = header ->
        let rec body = function
          | [] | [ "" ] -> []
          | "" :: _ -> refuse "blank-row"
          | r :: rest -> r :: body rest
        in
        body rest
    | _ -> refuse "bad-header"

let role_of = function
  | "ASSET" -> T.Asset
  | "LIABILITY" -> T.Liability
  | "EQUITY" -> T.Equity
  | "INCOME" -> T.Income
  | "EXPENSE" -> T.Expense
  | _ -> refuse "accounting-role-kind"

let role_name = function
  | T.Asset -> "ASSET"
  | T.Liability -> "LIABILITY"
  | T.Equity -> "EQUITY"
  | T.Income -> "INCOME"
  | T.Expense -> "EXPENSE"

let roles_of text =
  List.map
    (fun row ->
      match String.split_on_char '\t' row with
      | [ "ROLE"; l; kind ] -> (l, role_of kind)
      | _ -> refuse "accounting-role-row")
    (try rows ~header:roles_header text with Refused why -> refuse ("accounting-roles-" ^ why))

(* attention.loam rows are book.txt's ITEM/CLOSE lines: admit them through Book_txt. *)
let attention_of text =
  let body = try rows ~header:attention_header text with Refused why -> refuse ("attention-" ^ why) in
  match T.of_string (String.concat "" (List.map (fun r -> r ^ "\n") (("BOOK\t1" :: body) @ [ "END" ]))) with
  | Ok t -> (t.items, t.closes)
  | Error e -> refuse ("attention-" ^ T.code_name e.code)

let lines header rows = if rows = [] then "" else String.concat "\n" (header :: rows) ^ "\n"

(* The ITEM/CLOSE lines Book_txt prints for this Attention, between BOOK and END. *)
let attention_text (t : T.t) =
  let printed = T.to_string { (T.of_string "BOOK\t1\nEND\n" |> Result.get_ok) with items = t.items; closes = t.closes } in
  let body = String.split_on_char '\n' printed |> List.filter (fun l -> l <> "" && l <> "BOOK\t1" && l <> "END") in
  lines attention_header body

let roles_text (t : T.t) = lines roles_header (List.map (fun (l, r) -> "ROLE\t" ^ l ^ "\t" ^ role_name r) t.roles)

(* ---- book.txt -> Daily_book: one TX ---- *)

let exchange_source = "exchange-source"
let exchange_destination = "exchange-destination"

(* An exchange names the only negative Effect of its source Measure and the only
   positive one of its destination Measure, by their keys; an unkeyed one gets a fixed
   key, which the next save writes out. *)
let entry_of (tx : T.tx) : B.entry =
  let only sign m =
    match List.filter (fun (e : T.posting) -> e.measure = m && Z.sign e.amount = sign) tx.effects with
    | [ e ] -> e
    | _ -> refuse "exchange-ambiguous"
  in
  let named =
    match tx.exchange with
    | None -> []
    | Some (x, y) ->
        let pick e fallback =
          match e.T.key with
          | Some k -> (e, k)
          | None ->
              if List.exists (fun (o : T.posting) -> o.key = Some fallback) tx.effects then refuse "exchange-key-taken";
              (e, fallback)
        in
        [ pick (only (-1) x) exchange_source; pick (only 1 y) exchange_destination ]
  in
  let posting (e : T.posting) =
    let key = match List.find_opt (fun (k, _) -> k == e) named with Some (_, name) -> Some name | None -> e.key in
    D.Effect.create
      ~key:(Option.map (fun k -> get "effect-key-id" (D.Identifier.Effect_key.of_string k)) key)
      ~locus:(get "locus-id" (D.Identifier.Locus.of_string e.locus))
      ~measure:(get "measure-id" (D.Identifier.Measure.of_string e.measure))
      ~quantity:(D.Quantity.of_quanta e.amount)
  in
  {
    id = tx.id;
    day = tx.day;
    memo = tx.memo;
    effects = List.map posting tx.effects;
    reversal_of = tx.reversal_of;
    exchange = (match named with [ (_, a); (_, b) ] -> Some (a, b) | _ -> None);
    original_amount = tx.original;
    merchant =
      Option.map
        (function
          | T.Merchant s -> M.Merchant (get "merchant-id" (D.Identifier.External_party.of_string s))
          | T.Nonmerchant -> M.Nonmerchant)
        tx.merchant;
  }

(* ---- Daily_book -> book.txt ---- *)

let tx_of_entry (e : B.entry) : T.tx =
  let exchange =
    match e.exchange with
    | None -> None
    | Some (source, destination) ->
        let measure_of key =
          match List.filter (fun p -> Option.map D.Identifier.Effect_key.to_string (D.Effect.key p) = Some key) e.effects with
          | [ p ] -> measure (D.Effect.measure p)
          | _ -> refuse "exchange-key"
        in
        Some (measure_of source, measure_of destination)
  in
  let memo = match e.memo with Some "" -> None | m -> m in
  {
    id = e.id;
    day = e.day;
    memo;
    effects =
      List.map
        (fun p : T.posting ->
          {
            locus = locus (D.Effect.locus p);
            measure = measure (D.Effect.measure p);
            amount = D.Quantity.quanta (D.Effect.quantity p);
            key = Option.map D.Identifier.Effect_key.to_string (D.Effect.key p);
          })
        e.effects;
    reversal_of = e.reversal_of;
    original = e.original_amount;
    merchant =
      Option.map
        (function M.Merchant p -> T.Merchant (D.Identifier.External_party.to_string p) | M.Nonmerchant -> T.Nonmerchant)
        e.merchant;
    exchange;
  }

(* The TX of an entry, which must read back as that same entry: book.txt names an
   exchange by its Measures, so an exchange whose legs are not the only negative and
   positive Effects of those Measures refuses instead of saving a book that would not
   load. *)
let tx_of e =
  let tx = tx_of_entry e in
  if entry_of tx <> e then refuse "entry-not-representable";
  tx

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
let anchor_of ~position ~id_at (g : G.group) : T.anchor =
  let roots = List.map event g.reflected_roots in
  let pos r = match position r with Some n -> n | None -> refuse "anchor-root-missing" in
  let inside = Hashtbl.create 64 in
  List.iter (fun r -> Hashtbl.replace inside (pos r) ()) roots;
  let rec prefix k = if Hashtbl.mem inside k then prefix (k + 1) else k in
  let k = prefix 0 in
  {
    last = (if k = 0 then None else Some (id_at (k - 1)));
    also = List.filter (fun r -> pos r >= k) roots |> List.sort (fun a b -> compare (pos a) (pos b));
    asserts = List.map (fun (a : P.assertion) -> (coord a.coordinate, D.Quantity.quanta a.quantity)) g.assertions;
  }

(* Loci in a stable order: labelled, then approved, then first use. *)
let loci_of (p : B.payload) ~used =
  let labels = Option.value p.labels ~default:[] in
  let order = ref [] and seen = Hashtbl.create 64 in
  let add id =
    if not (Hashtbl.mem seen id) then (
      Hashtbl.add seen id ();
      order := id :: !order)
  in
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
  loci

(* The value and its printed text, already admitted. *)
let convert book sidecars =
  try
    let p = B.export_payload book in
    (match p.presence with Some pr when pr.coordinates <> [] -> refuse "presence" | _ -> ());
    let txs = List.map tx_of p.entries in
    let ids = Array.of_list (List.map (fun (tx : T.tx) -> tx.id) txs) in
    let position = Hashtbl.create 1024 in
    Array.iteri (fun i id -> Hashtbl.replace position id i) ids;
    let roles = roles_of sidecars.roles in
    let items, closes = attention_of sidecars.attention in
    let zero_origins = List.map coord p.origins in
    let openings = List.map (fun (o : Q.opening) -> (coord o.coordinate, event o.opening_event)) p.openings in
    let anchors =
      List.map (anchor_of ~position:(Hashtbl.find_opt position) ~id_at:(Array.get ids)) p.observations
    in
    let history_from = List.map (fun (c, day) -> (coord c, day)) p.bounded in
    let used =
      List.concat_map (fun (tx : T.tx) -> List.map (fun (e : T.posting) -> e.locus) tx.effects) txs
      @ List.map fst zero_origins
      @ List.map (fun ((l, _), _) -> l) openings
      @ List.map (fun ((l, _), _) -> l) history_from
      @ List.concat_map (fun (a : T.anchor) -> List.map (fun ((l, _), _) -> l) a.asserts) anchors
      @ List.concat_map (fun (pl : B.plan) -> List.map fst pl.changes) p.plans
      @ List.map fst roles
    in
    let loci = loci_of p ~used in
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
    match T.of_string text with
    | Error e -> Error (Printf.sprintf "book-txt-%s-line-%d" (T.code_name e.code) e.line)
    | Ok admitted ->
        (* The printer is deterministic, so an equal value prints to the same text. *)
        if admitted <> target then Error "book-txt-roundtrip"
        else Ok (admitted, text)
  with Refused why -> Error why

let to_txt book sidecars = Result.map fst (convert book sidecars)
let to_text book sidecars = Result.map snd (convert book sidecars)

(* ---- one save: the changes its operations make ---- *)

module L = Book_log

(* [txt] after [ops], where [after] is the book after them: each entry and plan they
   touch as [after] has it, the loci or anchors again when an operation changes them,
   and the roles and Attention of [sidecars]. When [txt] is [to_txt] of the book
   before, the result is [to_txt after] (test/daily_book_oracle_tests.ml). *)
let changes txt after ?sidecars ops =
  try
    let tx id = match B.find_entry after id with Some e -> tx_of e | None -> refuse "entry-missing" in
    let plan id =
      match List.find_opt (fun (p : B.plan) -> p.id = id) (B.plans after) with
      | Some p -> T.Put_plan (plan_of p)
      | None -> refuse "plan-missing"
    in
    let records =
      List.concat_map
        (function
          | L.Put_entry { replace; entry; plan = paid } ->
              (if replace then T.Replace_tx (tx entry.id) else T.Add_tx (tx entry.id))
              :: List.map plan (Option.to_list paid)
          | Correct_entry_date { id; _ } | Classify_merchant { id; _ } -> [ T.Replace_tx (tx id) ]
          | Put_plan { plan = p; _ } -> [ plan p.id ]
          | Cancel_plan { id; _ } -> [ plan id ]
          | Observe _ | Add_locus _ | Set_locus_label _ -> [])
        ops
    in
    let p = lazy (B.export_payload after) in
    let loci =
      if List.exists (function L.Add_locus _ | Set_locus_label _ -> true | _ -> false) ops then
        [ T.Set_loci (loci_of (Lazy.force p) ~used:[]) ]
      else []
    in
    (* TXs added by this save follow the existing ones, in the order they were added. *)
    let added = List.filter_map (function T.Add_tx (tx : T.tx) -> Some tx.id | _ -> None) records in
    let count = T.tx_count txt in
    let position id =
      match T.position txt id with
      | Some n -> Some n
      | None -> Option.map (fun (n, _) -> count + n) (List.find_opt (fun (_, a) -> a = id) (List.mapi (fun n a -> (n, a)) added))
    in
    let id_at k = if k < count then Option.get (T.id_at txt k) else List.nth added (k - count) in
    let anchors =
      if List.exists (function L.Observe _ -> true | _ -> false) ops then
        [ T.Set_anchors (List.map (anchor_of ~position ~id_at) (Lazy.force p).observations) ]
      else []
    in
    let sidecars =
      match sidecars with
      | None -> []
      | Some s ->
          let items, closes = attention_of s.attention in
          [ T.Set_roles (roles_of s.roles); T.Set_attention (items, closes) ]
    in
    match T.change txt (records @ loci @ anchors @ sidecars) with
    | Ok txt -> Ok txt
    | Error code -> Error ("book-txt-" ^ code)
  with Refused why -> Error why

(* ---- book.txt -> Daily_book ---- *)

let of_txt (t : T.t) =
  try
    let ids = Array.of_list (List.map (fun (tx : T.tx) -> tx.id) t.txs) in
    let position = Hashtbl.create 1024 in
    Array.iteri (fun i id -> Hashtbl.replace position id i) ids;
    let group (a : T.anchor) : G.group =
      let k = match a.last with None -> 0 | Some id -> Hashtbl.find position id + 1 in
      {
        reflected_roots = List.map event_id (Array.to_list (Array.sub ids 0 k) @ a.also);
        assertions =
          List.map
            (fun (c, q) : P.assertion -> { coordinate = coordinate c; quantity = D.Quantity.of_quanta q })
            a.asserts;
      }
    in
    let payload : B.payload =
      {
        measures = t.measures;
        labels = Some (List.map (fun (l : T.locus) -> (l.id, l.label, l.help)) t.loci);
        approved = Some (List.filter_map (fun (l : T.locus) -> if l.hidden then None else Some l.id) t.loci);
        entries = List.map entry_of t.txs;
        plans =
          List.map
            (fun (p : T.plan) : B.plan ->
              {
                id = p.id;
                day = p.day;
                measure = p.measure;
                changes = p.changes;
                paid_by = (match p.ending with Some (T.Paid_by tx) -> Some tx | _ -> None);
                cancelled_on = (match p.ending with Some (T.Cancelled d) -> Some d | _ -> None);
              })
            t.plans;
        origins = List.map coordinate t.zero_origins;
        openings = List.map (fun (c, tx) : Q.opening -> { coordinate = coordinate c; opening_event = event_id tx }) t.openings;
        observations = List.map group t.anchors;
        presence = None;
        bounded = List.map (fun (c, day) -> (coordinate c, day)) t.history_from;
      }
    in
    match B.of_payload payload with
    | Error why -> Error ("daily-book-" ^ why)
    | Ok book -> Ok (book, { roles = roles_text t; attention = attention_text t })
  with Refused why -> Error why

let text ?(sidecars = no_sidecars) book =
  match to_text book sidecars with Ok text -> text | Error why -> invalid_arg why

let book text =
  match T.of_string text with
  | Error e -> invalid_arg (Printf.sprintf "%s at line %d" (T.code_name e.code) e.line)
  | Ok t -> ( match of_txt t with Ok (book, _) -> book | Error why -> invalid_arg why)
