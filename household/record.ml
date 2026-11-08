(* A Record is a single-Measure form, not another book admission engine.
   Keep row order and keys; Book.put_entry still decides what may be saved. *)
module B = Book

type row = { key : string option; locus : string; negative : bool; amount : string }
type t = { measure : string; rows : row list }

let ( let* ) = Result.bind

(* The form shows each Effect as a sign and a magnitude in the Measure's decimals. *)
let rows_of book measure (effects : B.posting list) =
  {
    measure;
    rows =
      List.map
        (fun (p : B.posting) ->
          {
            key = p.key;
            locus = p.locus;
            negative = Z.sign p.amount < 0;
            amount = B.format book measure (Z.abs p.amount);
          })
        effects;
  }

(* An admitted book has no empty, zero or unbalanced Movement and no undeclared
   Measure, so only links and a second Measure keep an entry out of the form. *)
let open_edit ~book (e : B.entry) =
  if
    e.exchange <> None || e.reversal_of <> None
    || List.exists (fun (row : B.entry) -> row.reversal_of = Some e.id) (B.entries book)
  then Error "linked-entry"
  else
    match e.effects with
    | first :: _ when List.for_all (fun (p : B.posting) -> p.measure = first.measure) e.effects ->
        Ok (rows_of book first.measure e.effects)
    | _ -> Error "single-measure-movement-required"

let open_plan ~book (plan : B.plan) =
  if plan.paid_by <> None then Error "plan-already-paid"
  else if plan.cancelled_on <> None then Error "plan-cancelled"
  else
    Ok
      (rows_of book plan.measure
         (List.map
            (fun (locus, amount) -> { B.key = None; locus; measure = plan.measure; amount })
            plan.changes))

let amounts book draft =
  let rec loop position = function
    | [] -> Ok []
    | row :: rest ->
        let* n =
          Result.map_error
            (Printf.sprintf "row-%d: %s" position)
            (B.parse_amount book ~measure:draft.measure row.amount)
        in
        let* ns = loop (position + 1) rest in
        Ok ((if row.negative then Z.neg n else n) :: ns)
  in
  match draft.rows with [] -> Error "posting-required" | _ :: _ -> loop 1 draft.rows

let effects book draft =
  let* quantities = amounts book draft in
  if draft.measure = "" then Error "empty-measure"
  else
    let rec loop position = function
      | [] -> Ok []
      | ((row : row), amount) :: rest ->
          if row.locus = "" then Error (Printf.sprintf "row-%d: empty-locus" position)
          else
            let* rest = loop (position + 1) rest in
            Ok ({ B.key = row.key; locus = row.locus; measure = draft.measure; amount } :: rest)
    in
    loop 1 (List.combine draft.rows quantities)

type mode = New | Edit of B.entry | Pay of string
type form_row = { key : string option; locus : string; amount : string }

let split_sign text =
  let negative = String.starts_with ~prefix:"-" text in
  if negative || String.starts_with ~prefix:"+" text then
    (negative, String.sub text 1 (String.length text - 1))
  else (false, text)

let form ~editing ~measure (rows : form_row list) =
  {
    measure;
    rows =
      List.map
        (fun (row : form_row) ->
          let negative, amount = split_sign row.amount in
          let key =
            match (editing, row.key) with
            | Some (entry : B.entry), Some key ->
                if
                  List.exists
                    (fun (p : B.posting) -> p.key = Some key && p.locus = row.locus)
                    entry.effects
                then Some key
                else None
            | _, key -> key
          in
          { key; locus = row.locus; negative; amount })
        rows;
  }

type transaction = { entry : B.entry; replace : bool; plan : string option }
type content = { day : string; memo : string; draft : t; original_amount : (string * Z.t) option }

type error =
  | Day_format
  | Postings of string
  | Unbalanced
  | Original_measure
  | Admission of { reason : string; id : string }

let code = function
  | Day_format -> "day-format"
  | Postings why -> "postings:" ^ why
  | Unbalanced -> "unbalanced"
  | Original_measure -> "original-measure"
  | Admission { reason; _ } -> "admission:" ^ reason

let canonical_day day = Result.map_error (fun _ -> Day_format) (Day.normalize day)
let draft_effects ~book draft = Result.map_error (fun why -> Postings why) (effects book draft)

(* One Measure and nonzero rows are the form's own shape; only the sum can fail. *)
let balanced effects =
  let sum = List.fold_left (fun s (p : B.posting) -> Z.add s p.amount) Z.zero effects in
  if Z.equal sum Z.zero then Ok () else Error Unbalanced

let build_transaction ~new_id ~book ~mode { day; memo = memo_str; draft; original_amount } =
  let* day = canonical_day day in
  let* effects = draft_effects ~book draft in
  let* () =
    match original_amount with
    | Some (m, _) when not (List.mem_assoc m (B.measures book)) -> Error Original_measure
    | _ -> Ok ()
  in
  let* () = balanced effects in
  let memo =
    match mode with
    | Edit e when Option.value ~default:"" e.memo = memo_str -> e.memo
    | New | Pay _ | Edit _ -> if memo_str = "" then None else Some memo_str
  in
  let entry, replace, plan =
    match mode with
    | Edit e -> ({ e with day; memo; effects }, true, None)
    | New | Pay _ ->
        ( {
            B.id = new_id ();
            day;
            memo;
            effects;
            reversal_of = None;
            exchange = None;
            original_amount;
            merchant = None;
          },
          false,
          match mode with Pay id -> Some id | New | Edit _ -> None )
  in
  match B.put_entry book ~replace entry ~plan with
  | Ok _ -> Ok { entry; replace; plan }
  | Error reason -> Error (Admission { reason; id = entry.id })

let build_plan ~new_id ~book ~editing ~day ~draft =
  let* day = canonical_day day in
  let* effects = draft_effects ~book draft in
  let* () = balanced effects in
  let changes = List.map (fun (e : B.posting) -> (e.locus, e.amount)) effects in
  let plan, replace =
    match editing with
    | Some (p : B.plan) -> ({ p with day; measure = draft.measure; changes }, true)
    | None ->
        ( {
            B.id = new_id ();
            day;
            measure = draft.measure;
            changes;
            paid_by = None;
            cancelled_on = None;
          },
          false )
  in
  match B.put_plan book ~replace plan with
  | Ok _ -> Ok (plan, replace)
  | Error reason -> Error (Admission { reason; id = plan.id })

(* A refund adds a fact; it never erases the record. Every row of the original is
   negated in a new record linked to it ([REVERSAL-OF]); Book still decides whether
   that record is admissible. A refund is not refunded again, and a record is
   refunded once. *)
let refund ~book ~new_id ~id ~day =
  match B.find_entry book id with
  | None -> Error "unknown-entry"
  | Some (target : B.entry) ->
      if target.reversal_of <> None then Error "already-refund"
      else if List.exists (fun (e : B.entry) -> e.reversal_of = Some id) (B.entries book) then
        Error "already-refunded"
      else
        Ok
          {
            B.id = new_id ();
            day;
            memo = Some (match target.memo with Some m -> "Refund: " ^ m | None -> "Refund");
            effects =
              List.map (fun (p : B.posting) -> { p with amount = Z.neg p.amount }) target.effects;
            reversal_of = Some id;
            exchange = None;
            original_amount = None;
            merchant = None;
          }
