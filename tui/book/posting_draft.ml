(* One single-Measure posting draft. No facts, ID allocation, clock or I/O.
   Keep row order, multiplicity and existing keys; never auto-fill a residual. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
let tr = Ui_text.tr

type row = {
  key : D.Identifier.Effect_key.t option;
  locus : string;
  negative : bool;
  amount : string;
}

type t = { measure : string; rows : row list }

let of_effects book effects =
  match D.Movement.validate effects with
  | Error _ -> Error "single-measure-movement-required"
  | Ok movement ->
      let measure = D.Identifier.Measure.to_string (D.Movement.measure movement) in
      if not (List.mem_assoc measure (B.measures book)) then Error "measure-scale-not-supplied"
      else
        Ok
          {
            measure;
            rows =
              List.map
                (fun p ->
                  let n = D.Quantity.quanta (D.Effect.quantity p) in
                  {
                    key = D.Effect.key p;
                    locus = D.Identifier.Locus.to_string (D.Effect.locus p);
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
        match String.index_opt why ':' with
        | Some idx -> String.sub why 0 idx ^ ": "
        | None -> ""
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
  | Ok ns -> (
      match D.Identifier.Measure.of_string draft.measure with
      | Error D.Identifier.Empty -> Error "empty-measure"
      | Ok measure ->
          let rec loop position rows quantities =
            match (rows, quantities) with
            | [], [] -> Ok []
            | row :: rows, n :: ns -> (
                match D.Identifier.Locus.of_string row.locus with
                | Error D.Identifier.Empty -> Error (Printf.sprintf "row-%d: empty-locus" position)
                | Ok locus -> (
                    match loop (position + 1) rows ns with
                    | Error _ as error -> error
                    | Ok rest ->
                        Ok
                          (D.Effect.create ~key:row.key ~locus ~measure
                             ~quantity:(D.Quantity.of_quanta n)
                          :: rest)))
            | [], _ :: _ | _ :: _, [] -> Error "draft-row-count-mismatch"
          in
          loop 1 draft.rows ns)
