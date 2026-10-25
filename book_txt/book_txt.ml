(* The line-based book shared with LOAM (docs/COMMON_FORMAT.ja.md, v0).
   Reading runs four stages; each collects violations and the first stage with any
   stops with its earliest line. Every accepted text is canonical. *)

type role = Asset | Liability | Equity | Income | Expense
type posting = { locus : string; measure : string; amount : Z.t; key : string option }
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
  last : string option;
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
  | Duplicate_key
  | No_effect
  | Unbalanced
  | Bad_exchange
  | Reversal_not_inverse
  | Reversal_reused
  | Bad_original
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
  | Duplicate_key -> "duplicate-key"
  | No_effect -> "no-effect"
  | Unbalanced -> "unbalanced"
  | Bad_exchange -> "bad-exchange"
  | Reversal_not_inverse -> "reversal-not-inverse"
  | Reversal_reused -> "reversal-reused"
  | Bad_original -> "bad-original"
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
  if not (String.exists (function '\\' | '\r' -> true | _ -> false) s) then Some s
  else
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
  | "EFFECT" -> [ 4; 5 ]
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
            let ok = Z.geq q Z.zero && Z.leq q (Z.of_int 9) in
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
          | [ _; "-"; day ] -> fault st Bad_token n; ("-", date st n day, None)
          | [ _; id; day ] -> (token st n id, date st n day, None)
          | [ _; "-"; day; _; _ ] -> fault st Bad_token n; ("-", date st n day, None)
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
            | "EFFECT" :: l :: m :: q :: key ->
                let key = match key with [] -> None | [ k ] -> Some (token st r.n k) | _ -> assert false in
                let e = { locus = token st r.n l; measure = token st r.n m; amount = integer st r.n q; key } in
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
        let last =
          match b.head.f with [ _; "-" ] -> None | [ _; t ] -> Some (token st b.head.n t) | _ -> assert false
        in
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

(* Effects as a physical multiset: Locus, Measure and amount; keys do not take part. *)
let sorted_effects (effects : posting list) =
  List.map (fun (e : posting) -> (e.locus, e.measure, Z.to_string e.amount)) effects |> List.sort compare

let seen () = Hashtbl.create 16
let once st tbl key code n = if Hashtbl.mem tbl key then fault st code n else Hashtbl.add tbl key ()

(* Measures, Loci and roles; returns the Measure and Locus checks other lines use. *)
let definitions st measures loci roles =
  let measure_set = seen () and locus_set = seen () in
  List.iter (fun (n, (id, _)) -> once st measure_set id Duplicate_measure n) measures;
  List.iter (fun (n, (l : locus)) -> once st locus_set l.id Duplicate_locus n) loci;
  let measure n m = if not (Hashtbl.mem measure_set m) then fault st Unknown_measure n in
  let locus n l = if not (Hashtbl.mem locus_set l) then fault st Unknown_locus n in
  let role_set = seen () in
  List.iter
    (fun (n, (l, _)) ->
      locus n l;
      once st role_set l Duplicate_role n;
      if l = "suspense" then fault st Suspense_role n)
    roles;
  (measure, locus)

(* The rules of one TX. [reversal id n target] checks that the target of reversal
   [id] is known and that the two endpoints take part in no other reversal, and
   returns the target TX. *)
let tx_rules st ~measure ~locus ~reversal a =
  let tx = a.tx in
  let keys = seen () in
  List.iter
    (fun (n, e) ->
      locus n e.locus;
      measure n e.measure;
      if Z.equal e.amount Z.zero then fault st Zero_amount n;
      Option.iter (fun k -> once st keys k Duplicate_key n) e.key)
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
  | None ->
      (* A reversal is checked as the exact inverse of its target instead; the
         inverse of an exchange is not balanced either. *)
      if tx.reversal_of = None && List.exists (fun (_, v) -> not (Z.equal v Z.zero)) nets then
        fault st Unbalanced a.tx_n);
  (match tx.original with
  | Some (m, q) ->
      measure a.original_n m;
      if Z.leq q Z.zero then fault st Bad_original a.original_n
  | None -> ());
  match tx.reversal_of with
  | Some target -> (
      match reversal tx.id a.reversal_n target with
      | Some (target : tx) ->
          let inverse = List.map (fun e -> { e with amount = Z.neg e.amount }) target.effects in
          if sorted_effects tx.effects <> sorted_effects inverse then fault st Reversal_not_inverse a.reversal_n
      | None -> ())
  | None -> ()

(* Every line after the TX section. [find] gives a TX and its position in file order;
   [known] reports an unknown TX. *)
let after_txs st ~measure ~locus ~known ~find (plans, zero, opening, history, anchors, items, closes) =
  let plan_set = seen () and paid = seen () in
  List.iter
    (fun p ->
      once st plan_set p.plan.id Duplicate_plan p.plan_n;
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
      | Some (Paid_by t) when known p.paid_n t -> once st paid t Paid_by_reused p.paid_n
      | _ -> ())
    plans;
  let supported = seen () in
  let claim n c = once st supported c Support_overlap n in
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
      if known n t && not (List.exists (fun e -> e.locus = l && e.measure = m) (snd (find t)).effects) then
        fault st Opening_missing_coordinate n;
      if Hashtbl.mem opening_set c then fault st Duplicate_support n
      else (
        Hashtbl.add opening_set c ();
        claim n c))
    opening;
  let asserted = seen () in
  List.iter
    (fun a ->
      let pointer =
        match a.anchor.last with
        | None -> Some (-1)
        | Some t -> if known a.anchor_n t then Some (fst (find t)) else None
      in
      if a.assert_ns = [] then fault st Empty_anchor a.anchor_n;
      let also = seen () in
      List.iter
        (fun (n, t) ->
          (if known n t then
             match pointer with
             | Some p when fst (find t) <= p + 1 -> fault st Also_redundant n
             | _ -> ());
          once st also t Duplicate_also n)
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
      once st history_set c Duplicate_support n)
    history;
  List.iter (fun (n, (c, _)) -> if not (Hashtbl.mem asserted c) then fault st History_unanchored n) history;
  let item_set = seen () and closed = seen () in
  List.iter (fun (n, (i : item)) -> once st item_set i.id Duplicate_item n) items;
  List.iter
    (fun (n, c) ->
      if not (Hashtbl.mem item_set c.item) then fault st Unknown_item n;
      once st closed c.item Duplicate_close n)
    closes

let references st (measures, loci, roles, txs, plans, zero, opening, history, anchors, items, closes) =
  let measure, locus = definitions st measures loci roles in
  let by_id = Hashtbl.create (List.length txs) in
  List.iteri
    (fun i a ->
      if Hashtbl.mem by_id a.tx.id then fault st Duplicate_tx a.tx_n else Hashtbl.add by_id a.tx.id (i, a.tx))
    txs;
  let known n id = if Hashtbl.mem by_id id then true else (fault st Unknown_tx n; false) in
  let find = Hashtbl.find by_id in
  (* Endpoints of the reversals so far, in file order: a later reuse is the fault. *)
  let ends = Hashtbl.create 64 in
  List.iter
    (fun a ->
      tx_rules st ~measure ~locus a ~reversal:(fun id n target ->
          if not (known n target) then None
          else (
            if id = target || Hashtbl.mem ends id || Hashtbl.mem ends target then fault st Reversal_reused n;
            Hashtbl.replace ends id ();
            Hashtbl.replace ends target ();
            Some (snd (find target)))))
    txs;
  after_txs st ~measure ~locus ~known ~find (plans, zero, opening, history, anchors, items, closes)

(* ---- reading ---- *)

let lines_of data =
  if data = "" then refuse Bad_header 1;
  let st = stage () in
  let size = String.length data in
  let count = ref (if data.[size - 1] = '\n' then 0 else 1) in
  String.iter (fun c -> if c = '\n' then incr count) data;
  if data.[size - 1] <> '\n' then fault st No_final_newline !count;
  (* One pass: line [i] runs from [start] to the next newline or the end. *)
  let start = ref 0 in
  let lines =
    Array.init !count (fun i ->
        let stop = match String.index_from_opt data !start '\n' with Some j -> j | None -> size in
        let len = stop - !start in
        let crlf = len > 0 && data.[stop - 1] = '\r' in
        if crlf then fault st Crlf (i + 1);
        let line = String.sub data !start (if crlf then len - 1 else len) in
        if not (String.is_valid_utf_8 line) then fault st Not_utf8 (i + 1);
        start := stop + 1;
        line)
  in
  close st;
  if lines.(0) <> "BOOK\t1" then refuse Bad_header 1;
  let rec find_end i = if i >= Array.length lines then None else if lines.(i) = "END" then Some i else find_end (i + 1) in
  match find_end 0 with
  | None -> refuse Missing_end (Array.length lines)
  | Some i ->
      if i + 1 < Array.length lines then refuse After_end (i + 2);
      lines

(* The first three stages: bytes and lines, block structure and order, field syntax. *)
let syntax data =
  let sections = structure (lines_of data) in
  let st = stage () in
  let typed = fields st sections in
  close st;
  typed

let value_of (measures, loci, roles, txs, plans, zero, opening, history, anchors, items, closes) =
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

let of_string data =
  try
    let typed = syntax data in
    let st = stage () in
    references st typed;
    close st;
    Ok (value_of typed)
  with Refused e -> Error e

(* ---- writing ---- *)

let line b fields =
  Buffer.add_string b (String.concat "\t" fields);
  Buffer.add_char b '\n'

let z = Z.to_string

(* BOOK, MEASURE, LOCUS and ROLE lines. *)
let print_head b t =
  line b [ "BOOK"; "1" ];
  List.iter (fun (id, scale) -> line b [ "MEASURE"; id; string_of_int scale ]) t.measures;
  List.iter
    (fun (l : locus) ->
      line b ([ "LOCUS"; l.id; escape l.label; escape l.help ] @ if l.hidden then [ "HIDDEN" ] else []))
    t.loci;
  List.iter (fun (l, r) -> line b [ "ROLE"; l; role_name r ]) t.roles

let print_tx b (tx : tx) =
  line b ([ "TX"; tx.id; tx.day ] @ match tx.memo with Some m -> [ "DESC"; escape m ] | None -> []);
  List.iter (fun e -> line b ([ "EFFECT"; e.locus; e.measure; z e.amount ] @ Option.to_list e.key)) tx.effects;
  Option.iter (fun target -> line b [ "REVERSAL-OF"; target ]) tx.reversal_of;
  Option.iter (fun (m, q) -> line b [ "ORIGINAL"; m; z q ]) tx.original;
  Option.iter (function Merchant p -> line b [ "MERCHANT"; p ] | Nonmerchant -> line b [ "NONMERCHANT" ]) tx.merchant;
  Option.iter (fun (x, y) -> line b [ "EXCHANGE"; x; y ]) tx.exchange;
  line b [ "ENDTX" ]

(* Every line after the TX section, END included. *)
let print_tail b t =
  List.iter
    (fun (p : plan) ->
      line b [ "PLAN"; p.id; p.day; p.measure ];
      List.iter (fun (l, q) -> line b [ "CHANGE"; l; z q ]) p.changes;
      Option.iter (function Paid_by tx -> line b [ "PAID-BY"; tx ] | Cancelled d -> line b [ "CANCELLED"; d ]) p.ending;
      line b [ "ENDPLAN" ])
    t.plans;
  List.iter (fun (l, m) -> line b [ "ZERO-ORIGIN"; l; m ]) t.zero_origins;
  List.iter (fun ((l, m), tx) -> line b [ "OPENING"; l; m; tx ]) t.openings;
  List.iter (fun ((l, m), d) -> line b [ "HISTORY-FROM"; l; m; d ]) t.history_from;
  List.iter
    (fun a ->
      line b [ "ANCHOR"; Option.value a.last ~default:"-" ];
      List.iter (fun tx -> line b [ "ALSO"; tx ]) a.also;
      List.iter (fun ((l, m), q) -> line b [ "ASSERT"; l; m; z q ]) a.asserts;
      line b [ "ENDANCHOR" ])
    t.anchors;
  List.iter
    (fun (i : item) ->
      let kind, when_ =
        match i.due with
        | Due_on d -> ("DUE_ON", d)
        | No_due_date -> ("NO_DUE_DATE", "-")
        | Due_undetermined -> ("DUE_UNDETERMINED", "-")
      in
      line b [ "ITEM"; i.id; kind; when_; escape i.context ])
    t.items;
  List.iter
    (fun c -> line b [ "CLOSE"; c.item; c.day; (match c.kind with Resolved -> "RESOLVED" | Dropped -> "DROPPED") ])
    t.closes;
  line b [ "END" ]

let to_string t =
  let b = Buffer.create 4096 in
  print_head b t;
  List.iter (print_tx b) t.txs;
  print_tail b t;
  Buffer.contents b

(* ---- the admitted book and its changes ---- *)

module Smap = Map.Make (String)
module Imap = Map.Make (Int)
module Sset = Set.Make (String)

module Cmap = Map.Make (struct
  type t = string * string

  let compare = compare
end)

type book = {
  value : t;
  index : (int * tx) Smap.t;  (* TX by ID, with its position in file order *)
  reversed_by : string list Smap.t;  (* target -> the TXs reversing it; one in an admitted book *)
  printed : (string * string) Imap.t;  (* position -> the TX ID and its printed block *)
  next : int;  (* position of the next TX *)
  size : int;  (* bytes in [printed] *)
  totals : Z.t Cmap.t;  (* (Locus, Measure) -> the sum of every Effect there *)
  anchored : (int * Sset.t) list;  (* per anchor: the position of [last] (-1 for -), [also] *)
  counted : (int * Z.t) Cmap.t;  (* asserted coordinate -> its anchor's index and the count *)
  since : Z.t Cmap.t;  (* asserted coordinate -> its Effects that the count does not reflect *)
}

type change =
  | Add_tx of tx
  | Replace_tx of tx
  | Put_plan of plan
  | Set_loci of locus list
  | Set_roles of (string * role) list
  | Set_anchors of anchor list
  | Set_attention of item list * close list

(* Record or forget that TX [id] reverses [target]. *)
let reverses id target map = Smap.update target (fun rs -> Some (id :: Option.value rs ~default:[])) map

let unreverses id target map =
  Smap.update target (function Some rs -> (match List.filter (( <> ) id) rs with [] -> None | rs -> Some rs) | None -> None) map

let tx_text tx =
  let b = Buffer.create 256 in
  print_tx b tx;
  Buffer.contents b

(* ---- current balances, kept with every change ---- *)

let add_to c q map = Cmap.update c (fun v -> Some (Z.add q (Option.value v ~default:Z.zero))) map

(* Whether the count of anchor [(last, also)] leaves out TX [id] at position [i]. *)
let unreflected (last, also) i id = i > last && not (Sset.mem id also)

(* [b] with the Effects of TX [tx] at position [i] added, or taken away ([sign] -1). *)
let count_tx sign i (tx : tx) b =
  List.fold_left
    (fun b (e : posting) ->
      let c = (e.locus, e.measure) and q = if sign < 0 then Z.neg e.amount else e.amount in
      let since =
        match Cmap.find_opt c b.counted with
        | Some (k, _) when unreflected (List.nth b.anchored k) i tx.id -> add_to c q b.since
        | _ -> b.since
      in
      { b with totals = add_to c q b.totals; since })
    b tx.effects

(* The anchor indexes and the Effects each count leaves out, from the whole book. *)
let recount b =
  let anchors = b.value.anchors in
  let pos id = match Smap.find_opt id b.index with Some (i, _) -> i | None -> max_int in
  let anchored =
    List.map (fun a -> ((match a.last with None -> -1 | Some id -> pos id), Sset.of_list a.also)) anchors
  in
  let counted =
    List.fold_left
      (fun (k, m) a -> (k + 1, List.fold_left (fun m (c, q) -> Cmap.add c (k, q) m) m a.asserts))
      (0, Cmap.empty) anchors
    |> snd
  in
  let b = { b with anchored; counted; since = Cmap.map (fun _ -> Z.zero) counted } in
  Smap.fold
    (fun _ (i, (tx : tx)) b ->
      List.fold_left
        (fun b (e : posting) ->
          let c = (e.locus, e.measure) in
          match Cmap.find_opt c b.counted with
          | Some (k, _) when unreflected (List.nth b.anchored k) i tx.id -> { b with since = add_to c e.amount b.since }
          | _ -> b)
        b tx.effects)
    b.index b

(* [texts] gives each TX's printed lines, in file order. *)
let book_of ?texts value =
  let texts = ref (match texts with Some ts -> ts | None -> List.map tx_text value.txs) in
  List.fold_left
    (fun b (tx : tx) ->
      let s = List.hd !texts in
      texts := List.tl !texts;
      {
        b with
        index = Smap.add tx.id (b.next, tx) b.index;
        reversed_by = (match tx.reversal_of with Some x -> reverses tx.id x b.reversed_by | None -> b.reversed_by);
        printed = Imap.add b.next (tx.id, s) b.printed;
        next = b.next + 1;
        size = b.size + String.length s;
        totals = List.fold_left (fun m (e : posting) -> add_to (e.locus, e.measure) e.amount m) b.totals tx.effects;
      })
    {
      value;
      index = Smap.empty;
      reversed_by = Smap.empty;
      printed = Imap.empty;
      next = 0;
      size = 0;
      totals = Cmap.empty;
      anchored = [];
      counted = Cmap.empty;
      since = Cmap.empty;
    }
    value.txs
  |> recount

(* Each TX block of an admitted text, in file order. An admitted text is canonical, so
   these are the lines the TX prints to. *)
let tx_blocks data =
  let rec go at start acc =
    if at >= String.length data then List.rev acc
    else
      let stop = String.index_from data at '\n' + 1 in
      let line_is s = stop - at = String.length s + 1 && String.sub data at (String.length s) = s in
      if String.length data - at > 3 && String.sub data at 3 = "TX\t" then go stop at acc
      else if line_is "ENDTX" then go stop (-1) (String.sub data start (stop - start) :: acc)
      else go stop start acc
  in
  go 0 (-1) []

let read data = Result.map (fun value -> book_of ~texts:(tx_blocks data) value) (of_string data)
let value b = b.value
let position b id = Option.map fst (Smap.find_opt id b.index)
let id_at b i = Option.map fst (Imap.find_opt i b.printed)
let tx_count b = b.next

let print b =
  let buf = Buffer.create (b.size + 65536) in
  print_head buf b.value;
  Imap.iter (fun _ (_, s) -> Buffer.add_string buf s) b.printed;
  print_tail buf b.value;
  Buffer.contents buf

(* The value after one change, without any check; the TX IDs it touched. *)
let apply (b, touched) = function
  | Add_tx tx ->
      if Smap.mem tx.id b.index then refuse Duplicate_tx 0;
      let s = tx_text tx in
      ( count_tx 1 b.next tx
          {
            b with
            value = { b.value with txs = b.value.txs @ [ tx ] };
            index = Smap.add tx.id (b.next, tx) b.index;
            reversed_by = (match tx.reversal_of with Some x -> reverses tx.id x b.reversed_by | None -> b.reversed_by);
            printed = Imap.add b.next (tx.id, s) b.printed;
            next = b.next + 1;
            size = b.size + String.length s;
          },
        tx.id :: touched )
  | Replace_tx tx ->
      let i, old = match Smap.find_opt tx.id b.index with Some found -> found | None -> refuse Unknown_tx 0 in
      let s = tx_text tx in
      let reversed_by = match old.reversal_of with Some x -> unreverses old.id x b.reversed_by | None -> b.reversed_by in
      ( count_tx 1 i tx @@ count_tx (-1) i old
        @@ {
          b with
          value = { b.value with txs = List.map (fun (x : tx) -> if x.id = tx.id then tx else x) b.value.txs };
          index = Smap.add tx.id (i, tx) b.index;
          reversed_by = (match tx.reversal_of with Some x -> reverses tx.id x reversed_by | None -> reversed_by);
          printed = Imap.add i (tx.id, s) b.printed;
          size = b.size - String.length (snd (Imap.find i b.printed)) + String.length s;
        },
        tx.id :: touched )
  | Put_plan p ->
      let plans = b.value.plans in
      let plans =
        if List.exists (fun (q : plan) -> q.id = p.id) plans then List.map (fun (q : plan) -> if q.id = p.id then p else q) plans
        else plans @ [ p ]
      in
      ({ b with value = { b.value with plans } }, touched)
  | Set_loci loci -> ({ b with value = { b.value with loci } }, touched)
  | Set_roles roles -> ({ b with value = { b.value with roles } }, touched)
  | Set_anchors anchors -> (recount { b with value = { b.value with anchors } }, touched)
  | Set_attention (items, closes) -> ({ b with value = { b.value with items; closes } }, touched)

(* A TX outside the text being checked: its rules report at line 0. *)
let at_zero (tx : tx) =
  { tx; tx_n = 0; effect_ns = List.map (fun e -> (0, e)) tx.effects; reversal_n = 0; original_n = 0; exchange_n = 0 }

exception Not_canonical

(* Admit [b], the book [before] after changes that touched the TXs [touched], by the
   rules the whole file is read with. Every line except the untouched TXs is printed
   and read back by the first three stages, and must read back as the same value.
   The reference stage then checks those lines against the whole book's TX index.
   An untouched TX is affected only through the Loci, which keep every entry here
   (otherwise the whole book is read again; no change touches the Measures), and
   through a reversal of a touched TX, which is checked again. *)
let admit ~before b touched =
  let v = b.value in
  let kept (l : locus) = List.exists (fun (k : locus) -> k.id = l.id) v.loci in
  if not (List.for_all kept before.value.loci) then (
    match of_string (to_string v) with
    | Ok back -> if back <> v then raise Not_canonical
    | Error e -> raise (Refused e))
  else
    let changed = List.map (fun id -> snd (Smap.find id b.index)) (List.sort_uniq compare touched) in
    let text = Buffer.create 4096 in
    print_head text v;
    List.iter (print_tx text) changed;
    print_tail text v;
    let ((measures, loci, roles, txs, plans, zero, opening, history, anchors, items, closes) as typed) =
      syntax (Buffer.contents text)
    in
    if value_of typed <> { v with txs = changed } then raise Not_canonical;
    let st = stage () in
    let measure, locus = definitions st measures loci roles in
    let find id = Smap.find id b.index in
    let known n id = if Smap.mem id b.index then true else (fault st Unknown_tx n; false) in
    (* Reversal [id] of [target]: neither endpoint takes part in another reversal. A
       reversal of [id] itself, [id] included, is checked as a partner and refuses
       [id] as a target that is a reversal. *)
    let reversal id n target =
      if not (known n target) then None
      else
        let (_ : int), (x : tx) = find target in
        let other = List.exists (( <> ) id) (Option.value (Smap.find_opt target b.reversed_by) ~default:[]) in
        if x.reversal_of <> None || other then fault st Reversal_reused n;
        Some x
    in
    List.iter (tx_rules st ~measure ~locus ~reversal) txs;
    let partners =
      List.filter_map
        (fun (tx : tx) ->
          match Smap.find_opt tx.id b.reversed_by with
          | Some rs -> Some (List.filter_map (fun r -> if List.mem r touched then None else Some (at_zero (snd (find r)))) rs)
          | None -> None)
        changed
      |> List.concat
    in
    List.iter (tx_rules st ~measure ~locus ~reversal) partners;
    after_txs st ~measure ~locus ~known ~find (plans, zero, opening, history, anchors, items, closes);
    close st

let change b changes =
  try
    let after, touched = List.fold_left apply (b, []) changes in
    admit ~before:b after touched;
    Ok after
  with
  | Refused e -> Error (code_name e.code)
  | Not_canonical -> Error "not-canonical"

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
        let rec after = function
          | [] -> []
          | (tx : tx) :: rest -> if Some tx.id = a.last then rest else after rest
        in
        let after txs = if a.last = None then txs else after txs in
        Known (Z.add q (sum (List.filter (fun (tx : tx) -> not (List.mem tx.id a.also)) (after t.txs))))
    | None -> Unknown

type support = Zero_origin | Opening of string | Counted of { counted : Z.t; since : Z.t }
type quantity = { amount : Z.t; support : support }

let quantity b ~locus ~measure =
  let c = (locus, measure) in
  let total () = Option.value (Cmap.find_opt c b.totals) ~default:Z.zero in
  if List.mem c b.value.zero_origins then Some { amount = total (); support = Zero_origin }
  else
    match List.assoc_opt c b.value.openings with
    | Some tx -> Some { amount = total (); support = Opening tx }
    | None -> (
        match Cmap.find_opt c b.counted with
        | Some (_, counted) ->
            let since = Option.value (Cmap.find_opt c b.since) ~default:Z.zero in
            Some { amount = Z.add counted since; support = Counted { counted; since } }
        | None -> None)
