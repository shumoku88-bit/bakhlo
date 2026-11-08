(* Finding records, the way hledger queries do, kept small.

     bk find food 2026-10          food in October 2026
     bk find ランチ amt:>1000       a memo or account with ランチ, a row over 1,000
     bk find acct:bank 2026..      the bank from 2026 on

   Every term must match. A plain word matches when one of the record's Loci
   (its display name or ID) or its memo contains it, ignoring ASCII case;
   [acct:] and [memo:] keep to one of the two. A period is a year, a month, a
   day or a range [A..B] between their starts (B excluded, either end may be
   left open), alone or after [date:]. [amt:] compares the size of each row's
   amount in its Measure's units: [amt:1200], a range [amt:1000..] or [amt:..500]
   (end excluded, no shell quoting needed), or [amt:>1000] and the like; one row
   must meet the whole condition. *)
module B = Book

type compare = Eq | Gt | Ge | Lt | Le

type term =
  | Word of string
  | Locus of string
  | Memo of string
  | Days of { from : string option; until : string option }
  | Size of (compare * string) list  (** All must hold for one row. *)

type t = term list

let lower = String.lowercase_ascii

let contains ~part text =
  let part = lower part and text = lower text in
  let n = String.length part and m = String.length text in
  let rec at i = i + n <= m && (String.sub text i n = part || at (i + 1)) in
  n = 0 || at 0

let is_digits s = s <> "" && String.for_all (fun c -> c >= '0' && c <= '9') s

(* The first day of a year, month or day, and the first day after it. *)
let span text =
  match String.split_on_char '-' text with
  | [ y ] when String.length y = 4 && is_digits y ->
      let year = int_of_string y in
      if year < 1 || year > 9999 then None
      else
        Some
          (y ^ "-01-01", if year = 9999 then None else Some (Printf.sprintf "%04d-01-01" (year + 1)))
  | [ y; m ] when String.length y = 4 && String.length m = 2 && is_digits y && is_digits m -> (
      let first = y ^ "-" ^ m ^ "-01" in
      match Day.shift_months first 1 with
      | _ when not (Day.is_valid first) -> None
      | Ok next -> Some (first, Some next)
      | Error _ -> Some (first, None))
  | [ _; _; _ ] when Day.is_valid text -> (
      match Day.shift_days text 1 with
      | Ok next -> Some (text, Some next)
      | Error _ -> Some (text, None))
  | _ -> None

(* "A..B" as (A, B); [None] without "..". *)
let range text =
  let n = String.length text in
  let rec at i =
    if i + 1 >= n then None
    else if text.[i] = '.' && text.[i + 1] = '.' then
      Some (String.sub text 0 i, String.sub text (i + 2) (n - i - 2))
    else at (i + 1)
  in
  at 0

let period text =
  match range text with
  | None -> Option.map (fun (from, until) -> Days { from = Some from; until }) (span text)
  | Some (a, b) -> (
      let start = function "" -> Some None | s -> Option.map (fun (f, _) -> Some f) (span s) in
      match (start a, start b) with
      | Some from, Some until when a <> "" || b <> "" -> Some (Days { from; until })
      | _ -> None)

let size text =
  let op, rest =
    match text with
    | _ when String.starts_with ~prefix:">=" text -> (Ge, String.sub text 2 (String.length text - 2))
    | _ when String.starts_with ~prefix:"<=" text -> (Le, String.sub text 2 (String.length text - 2))
    | _ when String.starts_with ~prefix:">" text -> (Gt, String.sub text 1 (String.length text - 1))
    | _ when String.starts_with ~prefix:"<" text -> (Lt, String.sub text 1 (String.length text - 1))
    | _ -> (Eq, text)
  in
  match range text with
  | Some (a, b) when a <> "" || b <> "" ->
      Some (Size ((if a = "" then [] else [ (Ge, a) ]) @ if b = "" then [] else [ (Lt, b) ]))
  | Some _ -> None
  | None -> if rest = "" then None else Some (Size [ (op, rest) ])

(* Digits, dashes and dots starting with a year: meant as a period, so a wrong one is
   refused rather than searched for as a word. *)
let looks_like_period word =
  String.length word >= 4
  && is_digits (String.sub word 0 4)
  && String.for_all (fun c -> (c >= '0' && c <= '9') || c = '-' || c = '.') word
  || String.starts_with ~prefix:".." word

let field term =
  match String.index_opt term ':' with
  | Some i -> Some (String.sub term 0 i, String.sub term (i + 1) (String.length term - i - 1))
  | None -> None

let parse words =
  let one word =
    match field word with
    | Some ("acct", text) when text <> "" -> Ok (Locus text)
    | Some (("memo" | "desc"), text) when text <> "" -> Ok (Memo text)
    | Some ("date", text) -> Option.to_result ~none:("bad-date:" ^ text) (period text)
    | Some ("amt", text) -> Option.to_result ~none:("bad-amount:" ^ text) (size text)
    | Some (("acct" | "memo" | "desc"), _) -> Error ("empty-term:" ^ word)
    | Some (name, _) when name <> "" && String.for_all (fun c -> c >= 'a' && c <= 'z') name ->
        Error ("unknown-field:" ^ name)
    | _ when looks_like_period word -> Option.to_result ~none:("bad-date:" ^ word) (period word)
    | _ -> Ok (Word word)
  in
  List.fold_right
    (fun word acc ->
      match (acc, one word) with
      | Error _, _ -> acc
      | Ok _, Error why -> Error why
      | Ok terms, Ok term -> Ok (term :: terms))
    words (Ok [])

let names book (e : B.entry) =
  List.concat_map (fun (p : B.posting) -> [ p.locus; B.label book p.locus ]) e.effects

let fits book (e : B.entry) = function
  | Word w -> (
      List.exists (contains ~part:w) (names book e)
      || match e.memo with Some m -> contains ~part:w m | None -> false)
  | Locus w -> List.exists (contains ~part:w) (names book e)
  | Memo w -> ( match e.memo with Some m -> contains ~part:w m | None -> false)
  | Days { from; until } -> (
      (match from with Some f -> e.day >= f | None -> true)
      && match until with Some u -> e.day < u | None -> true)
  | Size conditions ->
      let holds (p : B.posting) (op, text) =
        match B.parse_amount book ~measure:p.measure text with
        | Error _ -> false
        | Ok q -> (
            let c = Z.compare (Z.abs p.amount) q in
            match op with Eq -> c = 0 | Gt -> c > 0 | Ge -> c >= 0 | Lt -> c < 0 | Le -> c <= 0)
      in
      List.exists (fun p -> List.for_all (holds p) conditions) e.effects

let matches book query e = List.for_all (fits book e) query
let find book query = List.filter (matches book query) (B.entries book)

let days text =
  match period text with Some (Days { from; until }) -> Some (from, until) | Some _ | None -> None
