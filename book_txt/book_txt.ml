(* The line-based book shared with LOAM (docs/COMMON_FORMAT.ja.md, v0).
   Reading runs four stages; each collects violations and the first stage with any
   stops with its earliest line. Every accepted text is canonical. *)

type role = Asset | Liability | Equity | Income | Expense
type posting = { locus : string; measure : string; amount : Z.t }
type merchant = Merchant of string | Nonmerchant

type tx = {
  id : string;
  day : string;
  memo : string option;
  effects : posting list;
  reversal_of : string option;
  original : (string * Z.t) option;
  merchant : merchant option;
  exchange : (string * string) option;
}

type plan_end = Paid_by of string | Cancelled of string

type plan = {
  id : string;
  day : string;
  measure : string;
  changes : (string * Z.t) list;
  ending : plan_end option;
}

type locus = { id : string; label : string; help : string; hidden : bool }

type anchor = {
  last : string;
  also : string list;
  asserts : ((string * string) * Z.t) list;
}

type due = Due_on of string | No_due_date | Due_undetermined
type close_kind = Resolved | Dropped
type item = { id : string; due : due; context : string }
type close = { item : string; day : string; kind : close_kind }

type t = {
  measures : (string * int) list;
  loci : locus list;
  roles : (string * role) list;
  txs : tx list;
  plans : plan list;
  zero_origins : (string * string) list;
  openings : ((string * string) * string) list;
  history_from : ((string * string) * string) list;
  anchors : anchor list;
  items : item list;
  closes : close list;
}

type code =
  | Not_utf8
  | Crlf
  | No_final_newline
  | Bad_header
  | Missing_end
  | After_end
  | Blank_line
  | Unknown_line
  | Section_order
  | Unclosed_block
  | Bad_token
  | Bad_escape
  | Empty_text
  | Bad_date
  | Bad_integer
  | Duplicate_measure
  | Duplicate_locus
  | Duplicate_role
  | Duplicate_tx
  | Duplicate_plan
  | Duplicate_item
  | Unknown_measure
  | Unknown_locus
  | Unknown_tx
  | Unknown_item
  | Bad_role
  | Suspense_role
  | Bad_scale
  | Bad_hidden
  | Zero_amount
  | No_effect
  | Unbalanced
  | Bad_exchange
  | Reversal_not_inverse
  | Reversal_reused
  | Zero_original
  | Paid_by_reused
  | Opening_missing_coordinate
  | Support_overlap
  | Duplicate_support
  | History_unanchored
  | Empty_anchor
  | Also_redundant
  | Duplicate_also
  | Bad_due
  | Bad_close
  | Duplicate_close

let code_name = function
  | Not_utf8 -> "not-utf8"
  | Crlf -> "crlf"
  | No_final_newline -> "no-final-newline"
  | Bad_header -> "bad-header"
  | Missing_end -> "missing-end"
  | After_end -> "after-end"
  | Blank_line -> "blank-line"
  | Unknown_line -> "unknown-line"
  | Section_order -> "section-order"
  | Unclosed_block -> "unclosed-block"
  | Bad_token -> "bad-token"
  | Bad_escape -> "bad-escape"
  | Empty_text -> "empty-text"
  | Bad_date -> "bad-date"
  | Bad_integer -> "bad-integer"
  | Duplicate_measure -> "duplicate-measure"
  | Duplicate_locus -> "duplicate-locus"
  | Duplicate_role -> "duplicate-role"
  | Duplicate_tx -> "duplicate-tx"
  | Duplicate_plan -> "duplicate-plan"
  | Duplicate_item -> "duplicate-item"
  | Unknown_measure -> "unknown-measure"
  | Unknown_locus -> "unknown-locus"
  | Unknown_tx -> "unknown-tx"
  | Unknown_item -> "unknown-item"
  | Bad_role -> "bad-role"
  | Suspense_role -> "suspense-role"
  | Bad_scale -> "bad-scale"
  | Bad_hidden -> "bad-hidden"
  | Zero_amount -> "zero-amount"
  | No_effect -> "no-effect"
  | Unbalanced -> "unbalanced"
  | Bad_exchange -> "bad-exchange"
  | Reversal_not_inverse -> "reversal-not-inverse"
  | Reversal_reused -> "reversal-reused"
  | Zero_original -> "zero-original"
  | Paid_by_reused -> "paid-by-reused"
  | Opening_missing_coordinate -> "opening-missing-coordinate"
  | Support_overlap -> "support-overlap"
  | Duplicate_support -> "duplicate-support"
  | History_unanchored -> "history-unanchored"
  | Empty_anchor -> "empty-anchor"
  | Also_redundant -> "also-redundant"
  | Duplicate_also -> "duplicate-also"
  | Bad_due -> "bad-due"
  | Bad_close -> "bad-close"
  | Duplicate_close -> "duplicate-close"

type error = { code : code; line : int }
type balance = Known of Z.t | Unknown

exception Refused of error

(* One reading stage: violations in discovery order; the earliest line wins. *)
type stage = { mutable found : error list }

let stage () = { found = [] }
let fault st code line = st.found <- { code; line } :: st.found

let close st =
  match List.rev st.found with
  | [] -> ()
  | first :: rest ->
      raise (Refused (List.fold_left (fun b e -> if e.line < b.line then e else b) first rest))

let refuse code line = raise (Refused { code; line })

(* ---- field syntax ---- *)

let escape s =
  if not (String.exists (function '\\' | '\n' | '\r' | '\t' -> true | _ -> false) s) then s
  else
    let b = Buffer.create (String.length s + 8) in
    String.iter
      (function
        | '\\' -> Buffer.add_string b "\\\\"
        | '\n' -> Buffer.add_string b "\\n"
        | '\r' -> Buffer.add_string b "\\r"
        | '\t' -> Buffer.add_string b "\\t"
        | c -> Buffer.add_char b c)
      s;
    Buffer.contents b

let unescape s =
  let b = Buffer.create (String.length s) in
  let rec go i =
    if i >= String.length s then Some (Buffer.contents b)
    else
      match s.[i] with
      | '\r' -> None
      | '\\' when i + 1 < String.length s -> (
          match s.[i + 1] with
          | '\\' -> Buffer.add_char b '\\'; go (i + 2)
          | 'n' -> Buffer.add_char b '\n'; go (i + 2)
          | 'r' -> Buffer.add_char b '\r'; go (i + 2)
          | 't' -> Buffer.add_char b '\t'; go (i + 2)
          | _ -> None)
      | '\\' -> None
      | c -> Buffer.add_char b c; go (i + 1)
  in
  go 0

let is_digit c = c >= '0' && c <= '9'

let valid_date s =
  String.length s = 10
  && s.[4] = '-'
  && s.[7] = '-'
  && List.for_all (fun i -> is_digit s.[i]) [ 0; 1; 2; 3; 5; 6; 8; 9 ]
  &&
  let y = int_of_string (String.sub s 0 4)
  and m = int_of_string (String.sub s 5 2)
  and d = int_of_string (String.sub s 8 2) in
  let leap = (y mod 4 = 0 && y mod 100 <> 0) || y mod 400 = 0 in
  let days = [| 31; (if leap then 29 else 28); 31; 30; 31; 30; 31; 31; 30; 31; 30; 31 |] in
  y >= 1 && m >= 1 && m <= 12 && d >= 1 && d <= days.(m - 1)

let canonical_integer s =
  s = "0"
  ||
  let body = if String.length s > 0 && s.[0] = '-' then String.sub s 1 (String.length s - 1) else s in
  String.length body > 0 && body.[0] <> '0' && String.for_all is_digit body

(* Field readers report into a stage and return a placeholder on failure; a stage
   that reports anything never yields its values. *)
let token st n s =
  if s = "" || String.exists (fun c -> c = ' ' || c = '\r') s then fault st Bad_token n;
  s

let text st n ?(may_be_empty = false) s =
  match unescape s with
  | None -> fault st Bad_escape n; ""
  | Some v ->
      if s = "" && not may_be_empty then fault st Empty_text n;
      v

let date st n s =
  if not (valid_date s) then fault st Bad_date n;
  s

let integer st n s =
  if canonical_integer s then Z.of_string s
  else (
    fault st Bad_integer n;
    Z.zero)

let role_of = function
  | "ASSET" -> Some Asset
  | "LIABILITY" -> Some Liability
  | "EQUITY" -> Some Equity
  | "INCOME" -> Some Income
  | "EXPENSE" -> Some Expense
  | _ -> None

let role_name = function
  | Asset -> "ASSET"
  | Liability -> "LIABILITY"
  | Equity -> "EQUITY"
  | Income -> "INCOME"
  | Expense -> "EXPENSE"

(* ---- structure ---- *)

type raw = { n : int; f : string list }
type block = { head : raw; mutable inner : raw list (* reversed *) }

let arity = function
  | "BOOK" -> [ 2 ]
  | "MEASURE" -> [ 3 ]
  | "LOCUS" -> [ 4; 5 ]
  | "ROLE" -> [ 3 ]
  | "TX" -> [ 3; 5 ]
  | "EFFECT" -> [ 4 ]
  | "REVERSAL-OF" | "MERCHANT" | "PAID-BY" | "CANCELLED" | "ANCHOR" | "ALSO" -> [ 2 ]
  | "ORIGINAL" | "EXCHANGE" | "CHANGE" | "ZERO-ORIGIN" -> [ 3 ]
  | "NONMERCHANT" | "ENDTX" | "ENDPLAN" | "ENDANCHOR" | "END" -> [ 1 ]
  | "PLAN" | "OPENING" | "HISTORY-FROM" | "ASSERT" | "CLOSE" -> [ 4 ]
  | "ITEM" -> [ 5 ]
  | _ -> []

let rank = function
  | "BOOK" -> Some 0
  | "MEASURE" -> Some 1
  | "LOCUS" -> Some 2
  | "ROLE" -> Some 3
  | "TX" -> Some 4
  | "PLAN" -> Some 5
  | "ZERO-ORIGIN" -> Some 6
  | "OPENING" -> Some 7
  | "HISTORY-FROM" -> Some 8
  | "ANCHOR" -> Some 9
  | "ITEM" -> Some 10
  | "CLOSE" -> Some 11
  | "END" -> Some 12
  | _ -> None

(* Position of a line inside its block and whether that position may repeat. *)
let inner_slot block kind =
  match (block, kind) with
  | "TX", "EFFECT" -> Some (0, true)
  | "TX", "REVERSAL-OF" -> Some (1, false)
  | "TX", "ORIGINAL" -> Some (2, false)
  | "TX", ("MERCHANT" | "NONMERCHANT") -> Some (3, false)
  | "TX", "EXCHANGE" -> Some (4, false)
  | "PLAN", "CHANGE" -> Some (0, true)
  | "PLAN", ("PAID-BY" | "CANCELLED") -> Some (1, false)
  | "ANCHOR", "ALSO" -> Some (0, true)
  | "ANCHOR", "ASSERT" -> Some (1, true)
  | _ -> None

let closer = function "TX" -> "ENDTX" | "PLAN" -> "ENDPLAN" | _ -> "ENDANCHOR"

let is_inner = function
  | "EFFECT" | "REVERSAL-OF" | "ORIGINAL" | "MERCHANT" | "NONMERCHANT" | "EXCHANGE" | "CHANGE"
  | "PAID-BY" | "CANCELLED" | "ALSO" | "ASSERT" | "ENDTX" | "ENDPLAN" | "ENDANCHOR" ->
      true
  | _ -> false

let kind_of (r : raw) = List.hd r.f

(* Lines 2..END grouped by kind, blocks with their inner lines. *)
type sections = {
  s_measures : raw list;
  s_loci : raw list;
  s_roles : raw list;
  s_txs : block list;
  s_plans : block list;
  s_zero : raw list;
  s_opening : raw list;
  s_history : raw list;
  s_anchors : block list;
  s_items : raw list;
  s_closes : raw list;
}

let structure lines =
  let st = stage () in
  let tops = ref [] and blocks = ref [] in
  let current = ref 0 and open_block = ref None and slot = ref (-1) in
  Array.iteri
    (fun i line ->
      let n = i + 1 in
      if n = 1 then ()
      else if line = "" then fault st Blank_line n
      else
        let f = String.split_on_char '\t' line in
        let kind = List.hd f in
        if not (List.mem (List.length f) (arity kind)) then fault st Unknown_line n
        else
          let r = { n; f } in
          match !open_block with
          | Some b when kind = closer (kind_of b.head) -> open_block := None
          | Some b -> (
              if rank kind <> None then (
                fault st Unclosed_block b.head.n;
                close st);
              match inner_slot (kind_of b.head) kind with
              | None -> fault st Unknown_line n
              | Some (s, repeatable) ->
                  if s < !slot || (s = !slot && not repeatable) then fault st Section_order n;
                  slot := s;
                  b.inner <- r :: b.inner)
          | None -> (
              if is_inner kind then fault st Unknown_line n
              else
                match rank kind with
                | None -> fault st Unknown_line n
                | Some k ->
                    if k < !current then fault st Section_order n;
                    current := max !current k;
                    if kind = "TX" || kind = "PLAN" || kind = "ANCHOR" then (
                      let b = { head = r; inner = [] } in
                      blocks := b :: !blocks;
                      open_block := Some b;
                      slot := -1)
                    else if kind <> "END" then tops := r :: !tops))
    lines;
  close st;
  let tops = List.rev !tops and blocks = List.rev !blocks in
  let raws k = List.filter (fun r -> kind_of r = k) tops in
  let blks k = List.filter (fun b -> kind_of b.head = k) blocks in
  List.iter (fun b -> b.inner <- List.rev b.inner) blocks;
  {
    s_measures = raws "MEASURE";
    s_loci = raws "LOCUS";
    s_roles = raws "ROLE";
    s_txs = blks "TX";
    s_plans = blks "PLAN";
    s_zero = raws "ZERO-ORIGIN";
    s_opening = raws "OPENING";
    s_history = raws "HISTORY-FROM";
    s_anchors = blks "ANCHOR";
    s_items = raws "ITEM";
    s_closes = raws "CLOSE";
  }

(* ---- typed lines, still carrying their line numbers ---- *)

type tx_at = {
  tx : tx;
  tx_n : int;
  effect_ns : (int * posting) list;
  reversal_n : int;
  original_n : int;
  exchange_n : int;
}

type plan_at = { plan : plan; plan_n : int; change_ns : (int * (string * Z.t)) list; paid_n : int }

type anchor_at = {
  anchor : anchor;
  anchor_n : int;
  also_ns : (int * string) list;
  assert_ns : (int * ((string * string) * Z.t)) list;
}

let fields st s =
  let measures =
    List.map
      (fun r ->
        match r.f with
        | [ _; id; scale ] ->
            let id = token st r.n id and q = integer st r.n scale in
            let ok = Z.geq q Z.zero && Z.fits_int q in
            if canonical_integer scale && not ok then fault st Bad_scale r.n;
            (r.n, (id, if ok then Z.to_int q else 0))
        | _ -> assert false)
      s.s_measures
  in
  let loci =
    List.map
      (fun r ->
        match r.f with
        | _ :: id :: label :: help :: rest ->
            let id = token st r.n id in
            let label = text st r.n label in
            let help = text st r.n ~may_be_empty:true help in
            let hidden = rest <> [] in
            if hidden && rest <> [ "HIDDEN" ] then fault st Bad_hidden r.n;
            (r.n, { id; label; help; hidden })
        | _ -> assert false)
      s.s_loci
  in
  let roles =
    List.map
      (fun r ->
        match r.f with
        | [ _; l; name ] -> (
            let l = token st r.n l in
            match role_of name with
            | Some role -> (r.n, (l, role))
            | None -> fault st Bad_role r.n; (r.n, (l, Asset)))
        | _ -> assert false)
      s.s_roles
  in
  let txs =
    List.map
      (fun b ->
        let n = b.head.n in
        let id, day, memo =
          match b.head.f with
          | [ _; id; day ] -> (token st n id, date st n day, None)
          | [ _; id; day; "DESC"; m ] -> (token st n id, date st n day, Some (text st n m))
          | [ _; id; day; _; _ ] -> fault st Unknown_line n; (token st n id, date st n day, None)
          | _ -> assert false
        in
        let at =
          ref
            {
              tx =
                {
                  id;
                  day;
                  memo;
                  effects = [];
                  reversal_of = None;
                  original = None;
                  merchant = None;
                  exchange = None;
                };
              tx_n = n;
              effect_ns = [];
              reversal_n = 0;
              original_n = 0;
              exchange_n = 0;
            }
        in
        List.iter
          (fun r ->
            let a = !at in
            match r.f with
            | [ "EFFECT"; l; m; q ] ->
                let e = { locus = token st r.n l; measure = token st r.n m; amount = integer st r.n q } in
                at := { a with effect_ns = a.effect_ns @ [ (r.n, e) ] }
            | [ "REVERSAL-OF"; t ] ->
                at := { a with tx = { a.tx with reversal_of = Some (token st r.n t) }; reversal_n = r.n }
            | [ "ORIGINAL"; m; q ] ->
                let o = (token st r.n m, integer st r.n q) in
                at := { a with tx = { a.tx with original = Some o }; original_n = r.n }
            | [ "MERCHANT"; p ] -> at := { a with tx = { a.tx with merchant = Some (Merchant (token st r.n p)) } }
            | [ "NONMERCHANT" ] -> at := { a with tx = { a.tx with merchant = Some Nonmerchant } }
            | [ "EXCHANGE"; x; y ] ->
                let x = token st r.n x and y = token st r.n y in
                at := { a with tx = { a.tx with exchange = Some (x, y) }; exchange_n = r.n }
            | _ -> assert false)
          b.inner;
        let a = !at in
        { a with tx = { a.tx with effects = List.map snd a.effect_ns } })
      s.s_txs
  in
  let plans =
    List.map
      (fun b ->
        let n = b.head.n in
        let id, day, measure =
          match b.head.f with
          | [ _; id; day; m ] -> (token st n id, date st n day, token st n m)
          | _ -> assert false
        in
        let changes = ref [] and ending = ref None and paid_n = ref 0 in
        List.iter
          (fun r ->
            match r.f with
            | [ "CHANGE"; l; q ] -> changes := (r.n, (token st r.n l, integer st r.n q)) :: !changes
            | [ "PAID-BY"; t ] -> ending := Some (Paid_by (token st r.n t)); paid_n := r.n
            | [ "CANCELLED"; d ] -> ending := Some (Cancelled (date st r.n d))
            | _ -> assert false)
          b.inner;
        let change_ns = List.rev !changes in
        {
          plan = { id; day; measure; changes = List.map snd change_ns; ending = !ending };
          plan_n = n;
          change_ns;
          paid_n = !paid_n;
        })
      s.s_plans
  in
  let coordinate st r = match r.f with _ :: l :: m :: _ -> (token st r.n l, token st r.n m) | _ -> assert false in
  let zero = List.map (fun r -> (r.n, coordinate st r)) s.s_zero in
  let opening =
    List.map
      (fun r -> match r.f with [ _; _; _; t ] -> (r.n, (coordinate st r, token st r.n t)) | _ -> assert false)
      s.s_opening
  in
  let history =
    List.map
      (fun r -> match r.f with [ _; _; _; d ] -> (r.n, (coordinate st r, date st r.n d)) | _ -> assert false)
      s.s_history
  in
  let anchors =
    List.map
      (fun b ->
        let last = match b.head.f with [ _; t ] -> token st b.head.n t | _ -> assert false in
        let also_ns =
          List.filter_map
            (fun r -> match r.f with [ "ALSO"; t ] -> Some (r.n, token st r.n t) | _ -> None)
            b.inner
        in
        let assert_ns =
          List.filter_map
            (fun r ->
              match r.f with
              | [ "ASSERT"; l; m; q ] -> Some (r.n, ((token st r.n l, token st r.n m), integer st r.n q))
              | _ -> None)
            b.inner
        in
        {
          anchor = { last; also = List.map snd also_ns; asserts = List.map snd assert_ns };
          anchor_n = b.head.n;
          also_ns;
          assert_ns;
        })
      s.s_anchors
  in
  let items =
    List.map
      (fun r ->
        match r.f with
        | [ _; id; kind; when_; context ] ->
            let id = token st r.n id in
            let due =
              match kind with
              | "DUE_ON" when when_ = "-" -> fault st Bad_due r.n; No_due_date
              | "DUE_ON" -> Due_on (date st r.n when_)
              | "NO_DUE_DATE" | "DUE_UNDETERMINED" ->
                  if when_ <> "-" then fault st Bad_due r.n;
                  if kind = "NO_DUE_DATE" then No_due_date else Due_undetermined
              | _ -> fault st Bad_due r.n; No_due_date
            in
            (r.n, { id; due; context = text st r.n context })
        | _ -> assert false)
      s.s_items
  in
  let closes =
    List.map
      (fun r ->
        match r.f with
        | [ _; id; day; kind ] ->
            let item = token st r.n id and day = date st r.n day in
            let kind =
              match kind with
              | "RESOLVED" -> Resolved
              | "DROPPED" -> Dropped
              | _ -> fault st Bad_close r.n; Resolved
            in
            (r.n, { item; day; kind })
        | _ -> assert false)
      s.s_closes
  in
  (measures, loci, roles, txs, plans, zero, opening, history, anchors, items, closes)

(* ---- definitions and references ---- *)

let nets (effects : posting list) =
  List.fold_left
    (fun acc (e : posting) ->
      let v = Option.value (List.assoc_opt e.measure acc) ~default:Z.zero in
      (e.measure, Z.add v e.amount) :: List.remove_assoc e.measure acc)
    [] effects

let sorted_effects (effects : posting list) =
  List.sort
    (fun (a : posting) (b : posting) ->
      match compare (a.locus, a.measure) (b.locus, b.measure) with 0 -> Z.compare a.amount b.amount | c -> c)
    effects

let references st (measures, loci, roles, txs, plans, zero, opening, history, anchors, items, closes) =
  let seen () = Hashtbl.create 16 in
  let once tbl key code n = if Hashtbl.mem tbl key then fault st code n else Hashtbl.add tbl key () in
  let measure_set = seen () and locus_set = seen () in
  List.iter (fun (n, (id, _)) -> once measure_set id Duplicate_measure n) measures;
  List.iter (fun (n, (l : locus)) -> once locus_set l.id Duplicate_locus n) loci;
  let measure n m = if not (Hashtbl.mem measure_set m) then fault st Unknown_measure n in
  let locus n l = if not (Hashtbl.mem locus_set l) then fault st Unknown_locus n in
  let role_set = seen () in
  List.iter
    (fun (n, (l, _)) ->
      locus n l;
      once role_set l Duplicate_role n;
      if l = "suspense" then fault st Suspense_role n)
    roles;
  let by_id = Hashtbl.create 64 and position = Hashtbl.create 64 in
  List.iteri
    (fun i a ->
      if Hashtbl.mem by_id a.tx.id then fault st Duplicate_tx a.tx_n
      else (
        Hashtbl.add by_id a.tx.id a.tx;
        Hashtbl.add position a.tx.id i))
    txs;
  let known n id = if Hashtbl.mem by_id id then true else (fault st Unknown_tx n; false) in
  let reversal_ends = seen () in
  List.iter
    (fun a ->
      let tx = a.tx in
      List.iter
        (fun (n, e) ->
          locus n e.locus;
          measure n e.measure;
          if Z.equal e.amount Z.zero then fault st Zero_amount n)
        a.effect_ns;
      if tx.effects = [] then fault st No_effect a.tx_n;
      let nets = nets tx.effects in
      (match tx.exchange with
      | Some (x, y) ->
          measure a.exchange_n x;
          measure a.exchange_n y;
          let net m = Option.value (List.assoc_opt m nets) ~default:Z.zero in
          let ok =
            x <> y
            && Z.lt (net x) Z.zero
            && Z.gt (net y) Z.zero
            && List.for_all (fun (m, v) -> m = x || m = y || Z.equal v Z.zero) nets
          in
          if not ok then fault st Bad_exchange a.exchange_n
      | None -> if List.exists (fun (_, v) -> not (Z.equal v Z.zero)) nets then fault st Unbalanced a.tx_n);
      (match tx.original with
      | Some (m, q) ->
          measure a.original_n m;
          if Z.equal q Z.zero then fault st Zero_original a.original_n
      | None -> ());
      match tx.reversal_of with
      | Some target when known a.reversal_n target ->
          if tx.id = target || Hashtbl.mem reversal_ends tx.id || Hashtbl.mem reversal_ends target then
            fault st Reversal_reused a.reversal_n;
          Hashtbl.replace reversal_ends tx.id ();
          Hashtbl.replace reversal_ends target ();
          let inverse = List.map (fun e -> { e with amount = Z.neg e.amount }) (Hashtbl.find by_id target).effects in
          if sorted_effects tx.effects <> sorted_effects inverse then fault st Reversal_not_inverse a.reversal_n
      | Some _ | None -> ())
    txs;
  let plan_set = seen () and paid = seen () in
  List.iter
    (fun p ->
      once plan_set p.plan.id Duplicate_plan p.plan_n;
      measure p.plan_n p.plan.measure;
      List.iter
        (fun (n, (l, q)) ->
          locus n l;
          if Z.equal q Z.zero then fault st Zero_amount n)
        p.change_ns;
      if p.change_ns = [] then fault st No_effect p.plan_n
      else if not (Z.equal (List.fold_left (fun s (_, q) -> Z.add s q) Z.zero p.plan.changes) Z.zero) then
        fault st Unbalanced p.plan_n;
      match p.plan.ending with
      | Some (Paid_by t) when known p.paid_n t -> once paid t Paid_by_reused p.paid_n
      | _ -> ())
    plans;
  let supported = seen () in
  let claim n c = once supported c Support_overlap n in
  let coordinate n (l, m) = locus n l; measure n m in
  let zero_set = seen () in
  List.iter
    (fun (n, c) ->
      coordinate n c;
      if Hashtbl.mem zero_set c then fault st Duplicate_support n
      else (
        Hashtbl.add zero_set c ();
        claim n c))
    zero;
  let opening_set = seen () in
  List.iter
    (fun (n, (((l, m) as c), t)) ->
      coordinate n c;
      if known n t
         && not (List.exists (fun e -> e.locus = l && e.measure = m) (Hashtbl.find by_id t).effects)
      then fault st Opening_missing_coordinate n;
      if Hashtbl.mem opening_set c then fault st Duplicate_support n
      else (
        Hashtbl.add opening_set c ();
        claim n c))
    opening;
  let asserted = seen () in
  List.iter
    (fun a ->
      let pointer = if known a.anchor_n a.anchor.last then Some (Hashtbl.find position a.anchor.last) else None in
      if a.assert_ns = [] then fault st Empty_anchor a.anchor_n;
      let also = seen () in
      List.iter
        (fun (n, t) ->
          (if known n t then
             match pointer with
             | Some p when Hashtbl.find position t <= p -> fault st Also_redundant n
             | _ -> ());
          once also t Duplicate_also n)
        a.also_ns;
      List.iter
        (fun (n, (c, _)) ->
          coordinate n c;
          claim n c;
          Hashtbl.replace asserted c ())
        a.assert_ns)
    anchors;
  let history_set = seen () in
  List.iter
    (fun (n, (c, _)) ->
      coordinate n c;
      once history_set c Duplicate_support n)
    history;
  List.iter (fun (n, (c, _)) -> if not (Hashtbl.mem asserted c) then fault st History_unanchored n) history;
  let item_set = seen () and closed = seen () in
  List.iter (fun (n, (i : item)) -> once item_set i.id Duplicate_item n) items;
  List.iter
    (fun (n, c) ->
      if not (Hashtbl.mem item_set c.item) then fault st Unknown_item n;
      once closed c.item Duplicate_close n)
    closes

(* ---- reading ---- *)

let lines_of data =
  if data = "" then refuse Bad_header 1;
  let st = stage () in
  let parts = String.split_on_char '\n' data in
  let parts =
    if String.ends_with ~suffix:"\n" data then List.rev (List.tl (List.rev parts))
    else (
      fault st No_final_newline (List.length parts);
      parts)
  in
  let lines =
    List.mapi
      (fun i line ->
        let line =
          if String.ends_with ~suffix:"\r" line then (
            fault st Crlf (i + 1);
            String.sub line 0 (String.length line - 1))
          else line
        in
        if not (String.is_valid_utf_8 line) then fault st Not_utf8 (i + 1);
        line)
      parts
  in
  close st;
  let lines = Array.of_list lines in
  if lines.(0) <> "BOOK\t1" then refuse Bad_header 1;
  let rec find_end i = if i >= Array.length lines then None else if lines.(i) = "END" then Some i else find_end (i + 1) in
  match find_end 0 with
  | None -> refuse Missing_end (Array.length lines)
  | Some i ->
      if i + 1 < Array.length lines then refuse After_end (i + 2);
      lines

let of_string data =
  try
    let sections = structure (lines_of data) in
    let st = stage () in
    let typed = fields st sections in
    close st;
    let st = stage () in
    references st typed;
    close st;
    let measures, loci, roles, txs, plans, zero, opening, history, anchors, items, closes = typed in
    Ok
      {
        measures = List.map snd measures;
        loci = List.map snd loci;
        roles = List.map snd roles;
        txs = List.map (fun a -> a.tx) txs;
        plans = List.map (fun p -> p.plan) plans;
        zero_origins = List.map snd zero;
        openings = List.map snd opening;
        history_from = List.map snd history;
        anchors = List.map (fun a -> a.anchor) anchors;
        items = List.map snd items;
        closes = List.map snd closes;
      }
  with Refused e -> Error e

(* ---- writing ---- *)

let to_string t =
  let b = Buffer.create 4096 in
  let line fields =
    Buffer.add_string b (String.concat "\t" fields);
    Buffer.add_char b '\n'
  in
  let z = Z.to_string in
  line [ "BOOK"; "1" ];
  List.iter (fun (id, scale) -> line [ "MEASURE"; id; string_of_int scale ]) t.measures;
  List.iter
    (fun (l : locus) ->
      line ([ "LOCUS"; l.id; escape l.label; escape l.help ] @ if l.hidden then [ "HIDDEN" ] else []))
    t.loci;
  List.iter (fun (l, r) -> line [ "ROLE"; l; role_name r ]) t.roles;
  List.iter
    (fun (tx : tx) ->
      line ([ "TX"; tx.id; tx.day ] @ match tx.memo with Some m -> [ "DESC"; escape m ] | None -> []);
      List.iter (fun e -> line [ "EFFECT"; e.locus; e.measure; z e.amount ]) tx.effects;
      Option.iter (fun target -> line [ "REVERSAL-OF"; target ]) tx.reversal_of;
      Option.iter (fun (m, q) -> line [ "ORIGINAL"; m; z q ]) tx.original;
      Option.iter
        (function Merchant p -> line [ "MERCHANT"; p ] | Nonmerchant -> line [ "NONMERCHANT" ])
        tx.merchant;
      Option.iter (fun (x, y) -> line [ "EXCHANGE"; x; y ]) tx.exchange;
      line [ "ENDTX" ])
    t.txs;
  List.iter
    (fun (p : plan) ->
      line [ "PLAN"; p.id; p.day; p.measure ];
      List.iter (fun (l, q) -> line [ "CHANGE"; l; z q ]) p.changes;
      Option.iter
        (function Paid_by tx -> line [ "PAID-BY"; tx ] | Cancelled d -> line [ "CANCELLED"; d ])
        p.ending;
      line [ "ENDPLAN" ])
    t.plans;
  List.iter (fun (l, m) -> line [ "ZERO-ORIGIN"; l; m ]) t.zero_origins;
  List.iter (fun ((l, m), tx) -> line [ "OPENING"; l; m; tx ]) t.openings;
  List.iter (fun ((l, m), d) -> line [ "HISTORY-FROM"; l; m; d ]) t.history_from;
  List.iter
    (fun a ->
      line [ "ANCHOR"; a.last ];
      List.iter (fun tx -> line [ "ALSO"; tx ]) a.also;
      List.iter (fun ((l, m), q) -> line [ "ASSERT"; l; m; z q ]) a.asserts;
      line [ "ENDANCHOR" ])
    t.anchors;
  List.iter
    (fun (i : item) ->
      let kind, when_ =
        match i.due with
        | Due_on d -> ("DUE_ON", d)
        | No_due_date -> ("NO_DUE_DATE", "-")
        | Due_undetermined -> ("DUE_UNDETERMINED", "-")
      in
      line [ "ITEM"; i.id; kind; when_; escape i.context ])
    t.items;
  List.iter
    (fun c -> line [ "CLOSE"; c.item; c.day; (match c.kind with Resolved -> "RESOLVED" | Dropped -> "DROPPED") ])
    t.closes;
  line [ "END" ];
  Buffer.contents b

(* ---- answers ---- *)

let balance t ~locus ~measure =
  let c = (locus, measure) in
  let sum txs =
    List.fold_left
      (fun acc (tx : tx) ->
        List.fold_left
          (fun acc e -> if e.locus = locus && e.measure = measure then Z.add acc e.amount else acc)
          acc tx.effects)
      Z.zero txs
  in
  if List.mem c t.zero_origins || List.mem_assoc c t.openings then Known (sum t.txs)
  else
    match List.find_map (fun a -> Option.map (fun q -> (a, q)) (List.assoc_opt c a.asserts)) t.anchors with
    | Some (a, q) ->
        let rec after = function [] -> [] | (tx : tx) :: rest -> if tx.id = a.last then rest else after rest in
        Known (Z.add q (sum (List.filter (fun (tx : tx) -> not (List.mem tx.id a.also)) (after t.txs))))
    | None -> Unknown
