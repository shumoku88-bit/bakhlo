module D = Loam_domain
module A = Loam_application
module P = A.Current_quantity_projection
let id event = D.Identifier.Event.to_string event
let location (c : D.Effect_coordinate.t) =
  Printf.sprintf "%S / %S" (D.Identifier.Locus.to_string c.locus) (D.Identifier.Measure.to_string c.measure)
let preview answer =
  Printf.sprintf "Conditional Actual fixture quantity (not household admission).\n%s: asserted=%s; delta=%s; quantity=%s\n"
    (location (P.coordinate answer))
    (Z.to_string (D.Quantity.quanta (P.asserted_quantity answer)))
    (Z.to_string (D.Quantity.quanta (P.delta answer))) (Z.to_string (D.Quantity.quanta (P.quantity answer)))
let unknown (P.Assertion_unknown { coordinate }) =
  Printf.sprintf "%s: quantity unknown (no exact assertion in supplied fixture).\n" (location coordinate)
let cut_error = function
  | A.Reflected_root_cut.Duplicate_root { id = event; first_position; position } ->
    Printf.sprintf "duplicate root %S at %d (first %d)" (id event) position first_position
  | Unknown_event { id = event; position } -> Printf.sprintf "unknown root %S at %d" (id event) position
  | Not_root { id = event; position } -> Printf.sprintf "not a root %S at %d" (id event) position
let group_error = function
  | A.Current_quantity_groups.Invalid_cut { group_position; error } ->
    Printf.sprintf "group %d: %s" group_position (cut_error error)
  | Invalid_assertions { group_position; error = P.Duplicate_coordinate { coordinate; first_position; position } } ->
    Printf.sprintf "group %d: duplicate assertion %s at %d (first %d)" group_position (location coordinate) position first_position
  | Repeated_coordinate { coordinate; first_group_position; first_assertion_position; group_position; assertion_position } ->
    Printf.sprintf "overlapping assertion %s at (%d,%d), first (%d,%d)" (location coordinate)
      group_position assertion_position first_group_position first_assertion_position
let correction_error = function
  | A.Correction_frontier.Unresolved_correction { position; errors } ->
    let endpoints = List.map (fun (A.Correction_check.Missing_event { endpoint; id = event }) ->
      let role = match endpoint with Target -> "target" | Replacement -> "replacement" in
      Printf.sprintf "%s=%S" role (id event)) errors in
    Printf.sprintf "correction %d: missing %s" position (String.concat ", " endpoints)
  | Repeated_target { id = event; first_position; position } ->
    Printf.sprintf "repeated target %S at %d (first %d)" (id event) position first_position
  | Repeated_replacement { id = event; first_position; position } ->
    Printf.sprintf "repeated replacement %S at %d (first %d)" (id event) position first_position
  | Cycle { path } -> "correction cycle: " ^ String.concat " -> " (List.map (fun event -> Printf.sprintf "%S" (id event)) path)
let refusal error =
  let detail = match error with
    | A.Actual_quantity_preview.Events (D.Event_memory.Duplicate_id { id = event; first_position; position }) ->
      Printf.sprintf "duplicate Event %S at %d (first %d)" (id event) position first_position
    | Invalid_date { position; text } -> Printf.sprintf "validity %d: invalid ISO occurrence date %S" position text
    | Repeated_validity { event; first_position; position } ->
      Printf.sprintf "duplicate validity for %S at %d (first %d)" (id event) position first_position
    | Unknown_validity_event { event; position } -> Printf.sprintf "validity %d: unknown Event %S" position (id event)
    | Missing_validity { event } -> Printf.sprintf "missing base validity for Event %S" (id event)
    | Corrections error -> correction_error error
    | Groups error -> group_error error in
  "Actual fixture refused: " ^ detail ^ ".\n"
