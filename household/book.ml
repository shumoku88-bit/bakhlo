(* The household book in memory: an admitted book.txt (Book_txt.book) and, for the
   screens, its TXs as entries. Every change is one Book_txt change, admitted by the
   specification's rules after Bakhlo's own write policies: Loci offered for new
   entries, open plans only, a Merchant set once. Balances come from the totals the
   admitted book keeps. Pure. *)
module D = Bakhlo_domain
module T = Bakhlo_book_txt.Book_txt
module Smap = Map.Make (String)
module Imap = Map.Make (Int)

exception Refused of string

let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)
let protect f = try Ok (f ()) with Refused why -> Error why
let eid s = get "invalid-entry-id" (D.Identifier.Event.of_string s)
let lid s = get "invalid-locus" (D.Identifier.Locus.of_string s)
let mid s = get "invalid-measure" (D.Identifier.Measure.of_string s)
let lstr = D.Identifier.Locus.to_string
let mstr = D.Identifier.Measure.to_string
let valid_date day = require (T.valid_date day) "invalid-date"

(* Whom the household regards as supplying what an entry acquired: a party, or
   explicitly nobody. An entry without one is unclassified. *)
type disposition = Merchant of D.Identifier.External_party.t | Nonmerchant

type entry = {
  id : string;
  day : string;
  memo : string option;
  effects : D.Effect.t list;
  reversal_of : string option;
  exchange : (string * string) option;
  original_amount : (string * Z.t) option;
  merchant : disposition option;
}

type plan = {
  id : string;
  day : string;
  measure : string;
  changes : (string * Z.t) list;
  paid_by : string option;
  cancelled_on : string option;
}

type t = {
  txt : T.book;
  ordered : entry Imap.t; (* TX position -> its entry *)
  position : int Smap.t; (* entry ID -> TX position *)
  cached : entry list Lazy.t; (* recorded order *)
}

(* ---- entries <-> TXs ---- *)

let exchange_source = "exchange-source"
let exchange_destination = "exchange-destination"

(* An exchange names the only negative Effect of its source Measure and the only
   positive one of its destination Measure, by their keys; an unkeyed one gets a fixed
   key, which the next save writes out. *)
let entry_of (tx : T.tx) : entry =
  let only sign m =
    match
      List.filter (fun (e : T.posting) -> e.measure = m && Z.sign e.amount = sign) tx.effects
    with
    | [ e ] -> e
    | _ -> raise (Refused "exchange-ambiguous")
  in
  let named =
    match tx.exchange with
    | None -> []
    | Some (x, y) ->
        let pick e fallback =
          match e.T.key with
          | Some k -> (e, k)
          | None ->
              if List.exists (fun (o : T.posting) -> o.key = Some fallback) tx.effects then
                raise (Refused "exchange-key-taken");
              (e, fallback)
        in
        [ pick (only (-1) x) exchange_source; pick (only 1 y) exchange_destination ]
  in
  let posting (e : T.posting) =
    let key =
      match List.find_opt (fun (k, _) -> k == e) named with
      | Some (_, name) -> Some name
      | None -> e.key
    in
    D.Effect.create
      ~key:(Option.map (fun k -> get "effect-key-id" (D.Identifier.Effect_key.of_string k)) key)
      ~locus:(lid e.locus) ~measure:(mid e.measure) ~quantity:(D.Quantity.of_quanta e.amount)
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
          | T.Merchant s -> Merchant (get "merchant-id" (D.Identifier.External_party.of_string s))
          | T.Nonmerchant -> Nonmerchant)
        tx.merchant;
  }

let tx_of_entry (e : entry) : T.tx =
  let key p = Option.map D.Identifier.Effect_key.to_string (D.Effect.key p) in
  let measure_of k =
    match List.filter (fun p -> key p = Some k) e.effects with
    | [ p ] -> mstr (D.Effect.measure p)
    | _ -> raise (Refused "exchange-key")
  in
  {
    id = e.id;
    day = e.day;
    memo = (match e.memo with Some "" -> None | m -> m);
    effects =
      List.map
        (fun p : T.posting ->
          {
            locus = lstr (D.Effect.locus p);
            measure = mstr (D.Effect.measure p);
            amount = D.Quantity.quanta (D.Effect.quantity p);
            key = key p;
          })
        e.effects;
    reversal_of = e.reversal_of;
    original = e.original_amount;
    merchant =
      Option.map
        (function
          | Merchant p -> T.Merchant (D.Identifier.External_party.to_string p)
          | Nonmerchant -> T.Nonmerchant)
        e.merchant;
    exchange = Option.map (fun (s, d) -> (measure_of s, measure_of d)) e.exchange;
  }

(* The TX of an entry, which must read back as that same entry: book.txt names an
   exchange by its Measures, so an exchange whose legs are not the only negative and
   positive Effects of those Measures refuses instead of saving a book that would not
   load. *)
let tx_of e =
  let tx = tx_of_entry e in
  if entry_of tx <> e then raise (Refused "entry-not-representable");
  tx

let plan_of (p : plan) : T.plan =
  {
    id = p.id;
    day = p.day;
    measure = p.measure;
    changes = p.changes;
    ending =
      (match (p.paid_by, p.cancelled_on) with
      | Some tx, _ -> Some (T.Paid_by tx)
      | None, Some day -> Some (T.Cancelled day)
      | None, None -> None);
  }

let plan_back (p : T.plan) : plan =
  {
    id = p.id;
    day = p.day;
    measure = p.measure;
    changes = p.changes;
    paid_by = (match p.ending with Some (T.Paid_by tx) -> Some tx | _ -> None);
    cancelled_on = (match p.ending with Some (T.Cancelled d) -> Some d | _ -> None);
  }

(* ---- the book ---- *)

let make txt =
  let entries = List.map entry_of (T.value txt).txs in
  let ordered, position, _ =
    List.fold_left
      (fun (o, p, i) (e : entry) -> (Imap.add i e o, Smap.add e.id i p, i + 1))
      (Imap.empty, Smap.empty, 0) entries
  in
  { txt; ordered; position; cached = lazy entries }

let of_txt txt = protect (fun () -> make txt)
let txt t = t.txt

let read text =
  match T.read text with
  | Error e -> Error (Printf.sprintf "%s at line %d" (T.code_name e.code) e.line)
  | Ok txt -> of_txt txt

let print t = T.print t.txt
let value t = T.value t.txt

let empty ~measure ~scale =
  protect (fun () ->
      ignore (mid measure);
      require (scale >= 0 && scale <= 9) "invalid-scale";
      match T.read (Printf.sprintf "BOOK\t1\nMEASURE\t%s\t%d\nEND\n" measure scale) with
      | Ok b -> make b
      | Error _ -> raise (Refused "invalid-measure"))

let entries t = Lazy.force t.cached
let entries_rev t = List.rev (entries t)
let entry_count t = T.tx_count t.txt
let find_entry t id = Option.map (fun i -> Imap.find i t.ordered) (Smap.find_opt id t.position)
let mem_entry t id = Smap.mem id t.position
let plans t = List.map plan_back (value t).plans
let plan_is_open (p : plan) = p.paid_by = None && p.cancelled_on = None
let open_plans t = List.filter plan_is_open (plans t)
let measures t = (value t).measures

let offered t =
  List.filter_map (fun (l : T.locus) -> if l.hidden then None else Some l.id) (value t).loci

let approved_loci t = Some (offered t)
let locus_row t id = List.find_opt (fun (l : T.locus) -> l.id = id) (value t).loci
let label t id = match locus_row t id with Some l -> l.label | None -> id
let help t id = match locus_row t id with Some l -> l.help | None -> ""
let quantity t ~locus ~measure = T.quantity t.txt ~locus ~measure
let has_zero_origin t ~locus ~measure = List.mem (locus, measure) (value t).zero_origins
let openings t = (value t).openings
let bounded_history_start t ~locus ~measure = List.assoc_opt (locus, measure) (value t).history_from

let scale t m =
  get "unknown-measure"
    (match List.assoc_opt m (measures t) with Some n -> Ok n | None -> Error ())

let format t m n = Amount.format ~decimals:(scale t m) n

let parse_amount t m text =
  match protect (fun () -> scale t m) with
  | Error _ as error -> error
  | Ok decimals -> Amount.parse_positive ~decimals text

let parse_signed_amount t m text =
  (* Empty input refuses before Measure lookup, as it does in the signed editor. *)
  if String.trim text = "" then Error "empty-amount"
  else
    match protect (fun () -> scale t m) with
    | Error _ as error -> error
    | Ok decimals -> Amount.parse_signed ~decimals text

type daily_pace = {
  measure : string;
  observed_at : string;
  end_exclusive : string;
  remaining_days : int;
  pool_balances : (D.Effect_coordinate.t * Z.t) list;
  plan_deductions : (string * Z.t) list;
  eligible_pool : Z.t;
  automatic_deductions : Z.t;
  available_through_end : Z.t;
  daily_pace_quanta : Z.t;
}

(* Calendar arithmetic over the existing validated 0001..9999 ISO spelling;
   never Unix timestamps, local clock reads, or retained period state. *)
let day_number text =
  valid_date text;
  let year = int_of_string (String.sub text 0 4)
  and month = int_of_string (String.sub text 5 2)
  and day = int_of_string (String.sub text 8 2) in
  let previous = year - 1 in
  let months = [| 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
  let leap = year mod 400 = 0 || (year mod 4 = 0 && year mod 100 <> 0) in
  (365 * previous) + (previous / 4) - (previous / 100) + (previous / 400)
  + months.(month - 1)
  + day
  + if leap && month > 2 then 1 else 0

let pool_balance t (c : D.Effect_coordinate.t) =
  match quantity t ~locus:(lstr c.locus) ~measure:(mstr c.measure) with
  | Some q -> Some q.amount
  | None -> None

let daily_pace t ~measure ~pool ~observed_at ~end_exclusive =
  protect (fun () ->
      let first = day_number observed_at and last = day_number end_exclusive in
      let remaining_days = last - first in
      require (remaining_days > 0) "daily-pace-non-positive-horizon";
      ignore (scale t measure);
      let selected_measure = mid measure in
      require
        (List.length (List.sort_uniq D.Effect_coordinate.compare pool) = List.length pool)
        "daily-pace-duplicate-coordinate";
      require
        (List.for_all
           (fun (c : D.Effect_coordinate.t) ->
             D.Identifier.Measure.equal c.measure selected_measure)
           pool)
        "daily-pace-pool-measure-mismatch";
      let pool_balances =
        List.map
          (fun (c : D.Effect_coordinate.t) ->
            match pool_balance t c with
            | Some n -> (c, n)
            | None ->
                raise
                  (Refused ("daily-pace-balance-support-unknown:" ^ lstr c.locus ^ ":" ^ measure)))
          pool
      in
      let selected locus =
        List.exists (fun (c : D.Effect_coordinate.t) -> lstr c.locus = locus) pool
      in
      let plan_deductions =
        open_plans t
        |> List.filter_map (fun (p : plan) ->
            if p.measure <> measure || p.day >= end_exclusive then None
            else
              let net =
                List.fold_left
                  (fun total (locus, n) -> if selected locus then Z.add total n else total)
                  Z.zero p.changes
              in
              if Z.sign net < 0 then Some (p.id, Z.neg net) else None)
      in
      let sum rows = List.fold_left (fun total (_, n) -> Z.add total n) Z.zero rows in
      let eligible_pool = sum pool_balances and automatic_deductions = sum plan_deductions in
      let available_through_end = Z.sub eligible_pool automatic_deductions in
      {
        measure;
        observed_at;
        end_exclusive;
        remaining_days;
        pool_balances;
        plan_deductions;
        eligible_pool;
        automatic_deductions;
        available_through_end;
        (* Positive divisor: Euclidean division floors negative deficits too,
           matching LOAM's integer-quanta guide, not truncation toward zero. *)
        daily_pace_quanta = Z.ediv available_through_end (Z.of_int remaining_days);
      })

(* Per coordinate of [pool], from one pass: the total of its Effects and their sums by
   recorded day after [from], the earliest day asked about. *)
let day_sums t pool ~from =
  let tables = List.map (fun c -> (c, ref Z.zero, ref Smap.empty)) pool in
  List.iter
    (fun (e : entry) ->
      List.iter
        (fun eff ->
          match
            List.find_opt
              (fun ((c : D.Effect_coordinate.t), _, _) ->
                D.Identifier.Locus.equal (D.Effect.locus eff) c.locus
                && D.Identifier.Measure.equal (D.Effect.measure eff) c.measure)
              tables
          with
          | None -> ()
          | Some (_, total, later) ->
              let q = D.Quantity.quanta (D.Effect.quantity eff) in
              total := Z.add !total q;
              if e.day > from then
                later :=
                  Smap.update e.day
                    (fun s -> Some (Z.add q (Option.value ~default:Z.zero s)))
                    !later)
        e.effects)
    (entries t);
  List.map (fun (c, total, later) -> (c, (!total, !later))) tables

(* Two routes, per coordinate: zero-origin sums forward; a history start subtracts
   later Effects from the current count. book.txt gives a history start only to a
   counted coordinate, and a count never shares one with zero-origin or an opening. *)
let pool_at_end_of_day_from ~sums t ~measure ~pool ~day =
  protect (fun () ->
      let next_start = day_number day + 1 in
      ignore (scale t measure);
      let selected_measure = mid measure in
      require
        (List.length (List.sort_uniq D.Effect_coordinate.compare pool) = List.length pool)
        "history-duplicate-coordinate";
      require
        (List.for_all
           (fun (c : D.Effect_coordinate.t) ->
             D.Identifier.Measure.equal c.measure selected_measure)
           pool)
        "history-pool-measure-mismatch";
      let sums_of c =
        snd (List.find (fun (c', _) -> D.Effect_coordinate.equal c c') (Lazy.force sums))
      in
      (* The Effects after [day] (never before [from]), walked back from the latest day. *)
      let after c =
        Seq.fold_left
          (fun total (_, q) -> Z.add total q)
          Z.zero
          (Seq.take_while (fun (d, _) -> d > day) (Smap.to_rev_seq (snd (sums_of c))))
      in
      let through c = Z.sub (fst (sums_of c)) (after c) in
      List.fold_left
        (fun total (c : D.Effect_coordinate.t) ->
          let locus = lstr c.locus in
          let label = locus ^ ":" ^ measure in
          match bounded_history_start t ~locus ~measure with
          | None ->
              require (has_zero_origin t ~locus ~measure) ("history-support-missing:" ^ label);
              Z.add total (through c)
          | Some first ->
              require (next_start >= day_number first) ("history-precedes-bounded-start:" ^ label);
              let current =
                match quantity t ~locus ~measure with
                | Some { amount; support = T.Counted _ } -> amount
                | Some _ | None -> raise (Refused ("history-bounded-anchor-missing:" ^ label))
              in
              Z.add total (Z.sub current (after c)))
        Z.zero pool)

let pools_at_end_of_days t ~measure ~pool ~days =
  let from = List.fold_left min (match days with d :: _ -> d | [] -> "") days in
  let sums = lazy (day_sums t pool ~from) in
  List.map (fun day -> pool_at_end_of_day_from ~sums t ~measure ~pool ~day) days

let pool_at_end_of_day t ~measure ~pool ~day =
  List.hd (pools_at_end_of_days t ~measure ~pool ~days:[ day ])

(* ---- changes ---- *)

(* A Book_txt refusal as the reason the screens know: support lines refuse as
   "support-admission", everything about a TX as "entry-admission". *)
let refusal = function
  | "support-overlap" | "duplicate-support" | "history-unanchored" | "empty-anchor"
  | "also-redundant" | "duplicate-also" | "opening-missing-coordinate" ->
      "support-admission"
  | _ -> "entry-admission"

(* A plan's changes are one Movement; book.txt says how they are not one. *)
let plan_refusal = function
  | "no-effect" | "zero-amount" | "unbalanced" -> "invalid-plan-movement"
  | code -> refusal code

let commit ?(refusal = refusal) t changes =
  match T.change t.txt changes with Ok txt -> txt | Error code -> raise (Refused (refusal code))

(* The book after [txt] took [e] in at the end ([replace] false) or in its place. *)
let with_entry t txt (e : entry) ~replace =
  if replace then
    let i = Smap.find e.id t.position in
    let ordered = Imap.add i e t.ordered in
    { t with txt; ordered; cached = lazy (List.map snd (Imap.bindings ordered)) }
  else
    let i = entry_count t in
    let ordered = Imap.add i e t.ordered in
    let cached =
      if Lazy.is_val t.cached then lazy (Lazy.force t.cached @ [ e ])
      else lazy (List.map snd (Imap.bindings ordered))
    in
    { txt; ordered; position = Smap.add e.id i t.position; cached }

let known_measure t m = require (List.mem_assoc m (measures t)) "measure-scale-not-supplied"

let approve_loci t loci =
  let ids = offered t in
  List.iter (fun locus -> require (List.mem locus ids) "locus-unapproved") loci

let approve_effects t effects = approve_loci t (List.map (fun p -> lstr (D.Effect.locus p)) effects)

let find_plan t id =
  match List.find_opt (fun (p : plan) -> p.id = id) (plans t) with
  | Some p -> p
  | None -> raise (Refused "unknown-plan")

let require_open_plan (p : plan) =
  require (p.paid_by = None) "plan-already-paid";
  require (p.cancelled_on = None) "plan-cancelled"

let merchant_classified = "loam: Event Merchant is already classified; replacement is not qualified"

(* An empty memo is no memo, as book.txt writes it, so a saved entry equals its reload. *)
let no_empty_memo (e : entry) = if e.memo = Some "" then { e with memo = None } else e

(* The entry's own fields, before the specification's rules: its identity, date and
   the Measures it names. *)
let check_entry t (e : entry) =
  ignore (eid e.id);
  List.iter (fun p -> known_measure t (mstr (D.Effect.measure p))) e.effects;
  Option.iter (fun (m, _) -> known_measure t m) e.original_amount;
  require (T.valid_date e.day) "entry-admission"

let put_entry t ~replace (e : entry) ~plan =
  protect (fun () ->
      let e = no_empty_memo e in
      approve_effects t e.effects;
      require (mem_entry t e.id = replace) (if replace then "unknown-entry" else "duplicate-entry");
      (if replace then
         match (Option.get (find_entry t e.id)).merchant with
         | Some m -> require (e.merchant = Some m) merchant_classified
         | None -> ());
      let paid =
        match plan with
        | None -> []
        | Some id ->
            require (not replace) "cannot-attach-plan-on-edit";
            let p = find_plan t id in
            require_open_plan p;
            [ T.Put_plan (plan_of { p with paid_by = Some e.id }) ]
      in
      check_entry t e;
      (* A malformed exchange is a TX the rules refuse. *)
      let tx =
        try tx_of e
        with Refused ("exchange-key" | "exchange-ambiguous") -> raise (Refused "entry-admission")
      in
      with_entry t
        (commit t ((if replace then T.Replace_tx tx else T.Add_tx tx) :: paid))
        e ~replace)

(* Only the date changes; the Effects are not admitted again, so Loci no longer
   offered for new entries are kept. *)
let correct_entry_date t ~id ~day =
  protect (fun () ->
      ignore (eid id);
      valid_date day;
      let old =
        match find_entry t id with Some e -> e | None -> raise (Refused "unknown-entry")
      in
      let e = { old with day } in
      with_entry t (commit t [ T.Replace_tx (tx_of e) ]) e ~replace:true)

let valid_token s =
  s <> "" && not (String.contains s '\t' || String.contains s '\n' || String.contains s '\r')

let classify_merchant t ~id ~disposition =
  protect (fun () ->
      let old =
        match find_entry t id with
        | Some e -> e
        | None -> raise (Refused "loam: Merchant classification requires an existing Event")
      in
      require (old.merchant = None) merchant_classified;
      (match disposition with
      | Merchant p ->
          require
            (valid_token (D.Identifier.External_party.to_string p))
            "loam: Merchant party token must be a non-empty single text field"
      | Nonmerchant -> ());
      let e = { old with merchant = Some disposition } in
      with_entry t (commit t [ T.Replace_tx (tx_of e) ]) e ~replace:true)

let put_plan t ~replace (p : plan) =
  protect (fun () ->
      require (plan_is_open p) "plan-terminal-not-input";
      let exists = List.exists (fun (row : plan) -> row.id = p.id) (plans t) in
      require (exists = replace) (if replace then "unknown-plan" else "duplicate-plan");
      if replace then require_open_plan (find_plan t p.id);
      approve_loci t (List.map fst p.changes);
      require (p.id <> "") "invalid-plan-id";
      valid_date p.day;
      known_measure t p.measure;
      { t with txt = commit ~refusal:plan_refusal t [ T.Put_plan (plan_of p) ] })

let cancel_plan t ~id ~day =
  protect (fun () ->
      let p = find_plan t id in
      require_open_plan p;
      valid_date day;
      { t with txt = commit t [ T.Put_plan (plan_of { p with cancelled_on = Some day }) ] })

(* A new Locus is offered for new entries, its label its ID until one is set; a hidden
   one is offered again. *)
let add_locus t id =
  protect (fun () ->
      ignore (lid id);
      require (not (List.mem id (offered t))) "duplicate-locus";
      let loci = (value t).loci in
      let loci =
        if List.exists (fun (l : T.locus) -> l.id = id) loci then
          List.map (fun (l : T.locus) -> if l.id = id then { l with hidden = false } else l) loci
        else loci @ [ { T.id; label = id; help = ""; hidden = false } ]
      in
      { t with txt = commit t [ T.Set_loci loci ] })

let set_locus_label t ~id ~label ?help () =
  protect (fun () ->
      ignore (lid id);
      require (List.mem id (offered t)) "locus-not-approved";
      let valid_str s =
        s <> ""
        && String.length s <= 80
        && String.for_all (fun c -> Char.code c >= 32 && Char.code c <> 127) s
      in
      let label = String.trim label in
      require (valid_str label) "invalid-label";
      (* An empty retained help falls back like a missing one. *)
      let fallback = match locus_row t id with Some l when l.help <> "" -> l.help | _ -> label in
      let help =
        match help with
        | Some h ->
            let trimmed = String.trim h in
            if trimmed = "" then fallback else trimmed
        | None -> fallback
      in
      require (valid_str help) "invalid-label";
      let loci =
        List.map
          (fun (l : T.locus) -> if l.id = id then { l with label; help } else l)
          (value t).loci
      in
      { t with txt = commit t [ T.Set_loci loci ] })

(* One count of current quantities, reflecting every recorded TX: a new anchor at the
   last TX; older anchors lose the coordinates counted again, and are dropped when
   nothing is left. *)
let observe_quantities t rows =
  protect (fun () ->
      require (rows <> []) "empty-observations";
      List.iter
        (fun (l, m, _) ->
          ignore (lid l);
          ignore (mid m);
          known_measure t m;
          require (List.mem l (offered t)) "locus-not-approved")
        rows;
      let coords = List.map (fun (l, m, _) -> (l, m)) rows in
      require
        (List.length (List.sort_uniq compare coords) = List.length coords)
        "duplicate-coordinate";
      let older =
        List.filter_map
          (fun (a : T.anchor) ->
            match List.filter (fun (c, _) -> not (List.mem c coords)) a.asserts with
            | [] -> None
            | asserts -> Some { a with asserts })
          (value t).anchors
      in
      let last = match List.rev (value t).txs with (tx : T.tx) :: _ -> Some tx.id | [] -> None in
      let fresh = { T.last; also = []; asserts = List.map (fun (l, m, q) -> ((l, m), q)) rows } in
      { t with txt = commit t [ T.Set_anchors (older @ [ fresh ]) ] })

let with_bounded_history t rows =
  protect (fun () ->
      List.iter
        (fun (l, m, day) ->
          ignore (lid l);
          ignore (mid m);
          known_measure t m;
          valid_date day)
        rows;
      let coords = List.map (fun (l, m, _) -> (l, m)) rows in
      require
        (List.length (List.sort_uniq compare coords) = List.length coords)
        "duplicate-bounded-history-coordinate";
      { t with txt = commit t [ T.Set_history (List.map (fun (l, m, day) -> ((l, m), day)) rows) ] })

(* ---- the other sections of book.txt ---- *)

let roles t = (value t).roles
let attention t = ((value t).items, (value t).closes)

let set_section t change =
  match T.change t.txt [ change ] with
  | Ok txt -> Ok { t with txt }
  | Error code -> Error ("book-txt-" ^ code)

let set_roles t roles = set_section t (T.Set_roles roles)
let set_attention t ~items ~closes = set_section t (T.Set_attention (items, closes))

(* ---- publication ---- *)

type change =
  | Put_entry of { replace : bool; entry : entry; plan : string option }
  | Correct_entry_date of { id : string; day : string }
  | Put_plan of { replace : bool; plan : plan }
  | Cancel_plan of { id : string; day : string }
  | Observe of (string * string * Z.t) list
  | Add_locus of string
  | Set_locus_label of { id : string; label : string; help : string option }
  | Classify_merchant of { id : string; disposition : disposition }
  | Set_roles of (string * T.role) list
  | Set_attention of { items : T.item list; closes : T.close list }

let apply_one t = function
  | Put_entry { replace; entry; plan } -> put_entry t ~replace entry ~plan
  | Correct_entry_date { id; day } -> correct_entry_date t ~id ~day
  | Put_plan { replace; plan } -> put_plan t ~replace plan
  | Cancel_plan { id; day } -> cancel_plan t ~id ~day
  | Observe rows -> observe_quantities t rows
  | Add_locus id -> add_locus t id
  | Set_locus_label { id; label; help } -> set_locus_label t ~id ~label ?help ()
  | Classify_merchant { id; disposition } -> classify_merchant t ~id ~disposition
  | Set_roles roles -> set_roles t roles
  | Set_attention { items; closes } -> set_attention t ~items ~closes

let apply t changes =
  List.fold_left (fun t c -> Result.bind t (fun t -> apply_one t c)) (Ok t) changes
