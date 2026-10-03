module D = Loam_domain
module A = Loam_application
module P = A.Current_quantity_projection
let id event = D.Identifier.Event.to_string event
let quantity q = Z.to_string (D.Quantity.quanta q)
let location (c : D.Effect_coordinate.t) =
  Printf.sprintf "%S / %S" (D.Identifier.Locus.to_string c.locus) (D.Identifier.Measure.to_string c.measure)
let assertion_row answer =
  Printf.sprintf "%s: asserted=%s; delta=%s; quantity=%s\n"
    (location (P.coordinate answer)) (quantity (P.asserted_quantity answer))
    (quantity (P.delta answer)) (quantity (P.quantity answer))
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

let event_refusal event (D.Event.Duplicate_effect_key { key; first_position; position }) =
  Printf.sprintf "Event %S refused: duplicate Effect key %S at %d (first %d).\n"
    (id event) (D.Identifier.Effect_key.to_string key) position first_position

let validity_reference = function
  | A.Actual_validity.Base_ref event -> Printf.sprintf "base %S" (id event)
  | Revision_ref revision -> Printf.sprintf "revision %S" (D.Identifier.Validity_revision.to_string revision)

let validity_error = function
  | A.Actual_validity.Invalid_date { position; text } ->
    Printf.sprintf "validity %d: invalid ISO occurrence date %S" position text
  | Repeated_fact { reference; first_position; position } ->
    Printf.sprintf "duplicate validity fact %s at %d (first %d)" (validity_reference reference) position first_position
  | Unknown_validity_event { event; position } -> Printf.sprintf "validity %d: unknown Event %S" position (id event)
  | Unresolved_correction { position; endpoints } ->
    let endpoints = List.map (function
      | A.Actual_validity.Target reference -> "target=" ^ validity_reference reference
      | Replacement revision -> "replacement=" ^ validity_reference (Revision_ref revision)) endpoints in
    Printf.sprintf "validity correction %d: missing %s" position (String.concat ", " endpoints)
  | Cross_event_correction { position; target_event; replacement_event } ->
    Printf.sprintf "validity correction %d: Event %S differs from replacement Event %S"
      position (id target_event) (id replacement_event)
  | Repeated_target { reference; first_position; position } ->
    Printf.sprintf "repeated validity target %s at %d (first %d)" (validity_reference reference) position first_position
  | Repeated_replacement { id = revision; first_position; position } ->
    Printf.sprintf "repeated validity replacement %S at %d (first %d)"
      (D.Identifier.Validity_revision.to_string revision) position first_position
  | Cycle { path } -> "validity correction cycle: " ^ String.concat " -> " (List.map validity_reference path)
  | Repeated_current_validity { event; first_position; position } ->
    Printf.sprintf "multiple current validities for Event %S at facts %d and %d"
      (id event) first_position position
  | Missing_validity { event } -> Printf.sprintf "missing current validity for Event %S" (id event)

let source_refusal error =
  let detail = match error with
    | A.Actual_source.Events (D.Event_memory.Duplicate_id { id = event; first_position; position }) ->
      Printf.sprintf "duplicate Event %S at %d (first %d)" (id event) position first_position
    | Zero_effect { event; event_position; effect_position } ->
      Printf.sprintf "Event %S at %d: zero Effect at %d" (id event) event_position effect_position
    | Unbalanced_measure { event; event_position; measure; residual } ->
      Printf.sprintf "Event %S at %d: Measure %S residual %s" (id event) event_position
        (D.Identifier.Measure.to_string measure) (quantity residual)
    | Validity error -> validity_error error
    | Corrections error -> correction_error error
    | Descriptions error ->
      (match error with
       | A.Event_descriptions.Repeated_description { event; first_position; position } ->
         Printf.sprintf "duplicate description for %S at %d (first %d)" (id event) position first_position
       | Unknown_description_event { event; position } ->
         Printf.sprintf "description %d: unknown Event %S" position (id event)) in
  "Actual source refused: " ^ detail ^ ".\n"

let answer answer =
  let module Q = A.Current_quantity_query in
  let row = match Q.premise answer with
    | Q.Zero_origin -> Printf.sprintf "%s: zero-origin; quantity=%s\n"
        (location (Q.coordinate answer)) (quantity (Q.quantity answer))
    | Q.Opening { coordinate; opening_event } -> Printf.sprintf "%s: opening Event %S; quantity=%s\n"
        (location coordinate) (id opening_event) (quantity (Q.quantity answer))
    | Q.Current_assertion asserted -> "exact assertion; " ^ assertion_row asserted in
  "Conditional current fixture quantity (ordinary Actual subset).\n" ^ row

let present answer =
  Printf.sprintf "%s: known nonzero (presence premise); exact quantity unknown.\n"
    (location (A.Current_quantity_query.present_coordinate answer))

let unavailable (A.Current_quantity_query.Support_unknown { coordinate }) =
  Printf.sprintf "%s: quantity unknown (no supported premise in supplied fixture).\n" (location coordinate)

let refusal error =
  let detail = match error with
    | A.Current_quantity_query.Zero_origins (D.Zero_origin_coverage.Duplicate_coordinate { position; coordinate }) ->
      Printf.sprintf "duplicate zero-origin %s at %d" (location coordinate) position
    | Duplicate_opening_coordinate { coordinate; first_position; position } ->
      Printf.sprintf "duplicate opening %s at %d (first %d)" (location coordinate) position first_position
    | Opening_event_not_current { opening = { coordinate; opening_event }; position } ->
      Printf.sprintf "opening %d for %s: Event %S is not current"
        position (location coordinate) (id opening_event)
    | Opening_event_missing_coordinate { opening = { coordinate; opening_event }; position } ->
      Printf.sprintf "opening %d: Event %S does not contain %s"
        position (id opening_event) (location coordinate)
    | Groups error -> group_error error
    | Presence_cut error -> "presence cut: " ^ cut_error error
    | Duplicate_presence_coordinate { coordinate; first_position; position } ->
      Printf.sprintf "duplicate presence %s at %d (first %d)" (location coordinate) position first_position
    | Presence_overlaps_exact { coordinate; position } ->
      Printf.sprintf "presence %s at %d overlaps exact support" (location coordinate) position
    | Opening_overlaps_origin { coordinate; opening_position } ->
      Printf.sprintf "opening %s at %d overlaps zero-origin" (location coordinate) opening_position
    | Assertion_overlaps_origin { coordinate; group_position; assertion_position } ->
      Printf.sprintf "zero-origin overlaps exact assertion %s at (%d,%d)"
        (location coordinate) group_position assertion_position
    | Assertion_overlaps_opening { opening = { coordinate; opening_event }; group_position; assertion_position } ->
      Printf.sprintf "opening Event %S overlaps exact assertion %s at (%d,%d)" (id opening_event)
        (location coordinate) group_position assertion_position in
  "Current fixture refused: " ^ detail ^ ".\n"
