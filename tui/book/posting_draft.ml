(* One single-Measure posting draft. No facts, ID allocation, clock or I/O.
   Keep row order, multiplicity and existing keys; never auto-fill a residual. *)
module B = Bakhlo_household.Book
module D = Bakhlo_domain

let tr = Ui_text.tr

type row = { key : string option; locus : string; negative : bool; amount : string }
type t = { measure : string; rows : row list }

type movement_fault =
  | Empty
  | Zero of int  (** The posting's position, from 1. *)
  | Measure_differs of { position : int; expected : string; actual : string }
  | Unbalanced

(* The first way these postings are not one balanced single-Measure Movement, in
   posting order (a zero before a differing Measure on the same posting), so the
   draft can name the row. book.txt admission stays the authority on saving. *)
let movement_fault (effects : B.posting list) =
  match effects with
  | [] -> Some Empty
  | first :: _ -> (
      let rec scan position = function
        | [] -> None
        | (p : B.posting) :: rest ->
            if Z.equal p.amount Z.zero then Some (Zero position)
            else if p.measure <> first.measure then
              Some (Measure_differs { position; expected = first.measure; actual = p.measure })
            else scan (position + 1) rest
      in
      match scan 1 effects with
      | Some _ as fault -> fault
      | None ->
          let sum = List.fold_left (fun s (p : B.posting) -> Z.add s p.amount) Z.zero effects in
          if Z.equal sum Z.zero then None else Some Unbalanced)

let of_effects book (effects : B.posting list) =
  match (movement_fault effects, effects) with
  | Some _, _ | None, [] -> Error "single-measure-movement-required"
  | None, first :: _ ->
      let measure = first.measure in
      if not (List.mem_assoc measure (B.measures book)) then Error "measure-scale-not-supplied"
      else
        Ok
          {
            measure;
            rows =
              List.map
                (fun (p : B.posting) ->
                  let n = p.amount in
                  {
                    key = p.key;
                    locus = p.locus;
                    negative = Z.sign n < 0;
                    amount = B.format book measure (Z.abs n);
                  })
                effects;
          }

let amounts book draft =
  let rec loop position = function
    | [] -> Ok []
    | row :: rest -> (
        match B.parse_amount book draft.measure row.amount with
        | Error why -> Error (Printf.sprintf "row-%d: %s" position why)
        | Ok n -> (
            match loop (position + 1) rest with
            | Error _ as error -> error
            | Ok ns -> Ok ((if row.negative then Z.neg n else n) :: ns)))
  in
  match draft.rows with [] -> Error "posting-required" | _ :: _ -> loop 1 draft.rows

let format_residual_error why =
  if String.equal why "posting-required" then tr "At least one posting is required."
  else
    let line_prefix =
      if Base.String.is_prefix why ~prefix:"row-" then
        match String.index_opt why ':' with Some idx -> String.sub why 0 idx ^ ": " | None -> ""
      else ""
    in
    if Base.String.is_substring why ~substring:"invalid-amount" then
      line_prefix ^ tr "Invalid amount (for example 1000)."
    else if Base.String.is_substring why ~substring:"non-positive-amount" then
      line_prefix ^ tr "Enter a positive amount magnitude."
    else if Base.String.is_substring why ~substring:"amount-precision" then
      line_prefix ^ tr "The amount exceeds the Measure decimal scale."
    else if Base.String.is_substring why ~substring:"division-by-zero" then
      line_prefix ^ tr "The amount expression divides by zero."
    else if Base.String.is_substring why ~substring:"indivisible-amount" then
      line_prefix ^ tr "The result cannot be represented at this Measure's decimal scale."
    else why

let residual book draft =
  match amounts book draft with
  | Error _ as error -> error
  | Ok ns -> Ok (List.fold_left Z.add Z.zero ns)

let effects book draft =
  match amounts book draft with
  | Error _ as error -> error
  | Ok ns ->
      if draft.measure = "" then Error "empty-measure"
      else
        let rec loop position rows quantities =
          match (rows, quantities) with
          | [], [] -> Ok []
          | row :: rows, n :: ns -> (
              if row.locus = "" then Error (Printf.sprintf "row-%d: empty-locus" position)
              else
                match loop (position + 1) rows ns with
                | Error _ as error -> error
                | Ok rest ->
                    Ok
                      ({ B.key = row.key; locus = row.locus; measure = draft.measure; amount = n }
                      :: rest))
          | [], _ :: _ | _ :: _, [] -> Error "draft-row-count-mismatch"
        in
        loop 1 draft.rows ns
