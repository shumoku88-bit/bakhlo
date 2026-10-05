module D = Bakhlo_domain
module A = Bakhlo_application
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

let exchange_error = function
  | A.Exchange_evidence.Repeated_event { event; first_position; position } ->
    Printf.sprintf "duplicate Exchange for %S at %d (first %d)" (id event) position first_position
  | Correction_mentions_event { event; position } ->
    Printf.sprintf "Exchange %d: Event %S participates in correction" position (id event)
  | Unknown_event { event; position } ->
    Printf.sprintf "Exchange %d: unknown Event %S" position (id event)
  | Missing_effect { event; side; key; position } ->
    let role = match side with A.Exchange_evidence.Source -> "source" | Destination -> "destination" in
    Printf.sprintf "Exchange %d for %S: missing %s Effect key %S" position (id event) role
      (D.Identifier.Effect_key.to_string key)
  | Same_measure { event; measure; position } ->
    Printf.sprintf "Exchange %d for %S: selected Measures are both %S"
      position (id event) (D.Identifier.Measure.to_string measure)
  | Source_not_negative { event; quantity = amount; position } ->
    Printf.sprintf "Exchange %d for %S: selected source quantity %s is not negative" position (id event) (quantity amount)
  | Destination_not_positive { event; quantity = amount; position } ->
    Printf.sprintf "Exchange %d for %S: selected destination quantity %s is not positive" position (id event) (quantity amount)
  | Third_measure { event; effect_position; measure; position } ->
    Printf.sprintf "Exchange %d for %S: third Measure %S at Effect %d"
      position (id event) (D.Identifier.Measure.to_string measure) effect_position
  | Source_total_not_negative { event; measure; total; position } ->
    Printf.sprintf "Exchange %d for %S: source Measure %S total %s is not negative"
      position (id event) (D.Identifier.Measure.to_string measure) (quantity total)
  | Destination_total_not_positive { event; measure; total; position } ->
    Printf.sprintf "Exchange %d for %S: destination Measure %S total %s is not positive"
      position (id event) (D.Identifier.Measure.to_string measure) (quantity total)

let reversal_role = function A.Actual_reversals.Target -> "target" | Reversal -> "reversal"
let reversal_error = function
  | A.Actual_reversals.Repeated_endpoint { event; first_role; first_position; role; position } ->
    Printf.sprintf "Reversal %d: repeated %s Event %S (first %s at %d)"
      position (reversal_role role) (id event) (reversal_role first_role) first_position
  | Unresolved_endpoints { position; endpoints } ->
    let missing = Base.List.map endpoints ~f:(fun (endpoint : A.Actual_reversals.endpoint) ->
      Printf.sprintf "%s Event %S" (reversal_role endpoint.role) (id endpoint.event)) in
    Printf.sprintf "Reversal %d: missing %s" position (String.concat ", " missing)
  | Not_inverse { position; fact } ->
    Printf.sprintf "Reversal %d: Event %S is not the exact physical inverse of %S"
      position (id fact.reversal) (id fact.target)

let relation_endpoint = function
  | A.Open_relations.Household -> "Household"
  | External party -> Printf.sprintf "External %S" (D.Identifier.External_party.to_string party)
let relation_error error =
  let relation id = D.Identifier.Relation.to_string id in
  let key id = D.Identifier.Effect_key.to_string id in
  match error with
  | A.Open_relations.Repeated_id { id; first_position; position } ->
    Printf.sprintf "duplicate Relation %S at %d (first %d)" (relation id) position first_position
  | Unknown_event { id = subject; event; position } ->
    Printf.sprintf "Relation %d %S: unknown Event %S" position (relation subject) (id event)
  | Missing_effect { id = subject; event; key = selector; position } ->
    Printf.sprintf "Relation %d %S: Event %S has no Effect key %S" position (relation subject) (id event) (key selector)
  | Invalid_endpoints { id = subject; debtor; creditor; position } ->
    Printf.sprintf "Relation %d %S: expected one Household and one External endpoint, debtor=%s creditor=%s"
      position (relation subject) (relation_endpoint debtor) (relation_endpoint creditor)
  | Nonpositive_quantity { id = subject; quantity = amount; position } ->
    Printf.sprintf "Relation %d %S: quantity %s is not positive" position (relation subject) (quantity amount)
  | Exceeds_source { id = subject; quantity = amount; magnitude; position } ->
    Printf.sprintf "Relation %d %S: quantity %s exceeds source magnitude %s"
      position (relation subject) (quantity amount) (quantity magnitude)
  | Overcovered_source { event; key = selector; total; magnitude; position } ->
    Printf.sprintf "Relation %d: Event %S Effect key %S coverage %s exceeds source magnitude %s"
      position (id event) (key selector) (quantity total) (quantity magnitude)

let discharge_error error =
  let target id = D.Identifier.Relation.to_string id in
  match error with
  | A.Relation_discharges.Unknown_event { event; position } ->
    Printf.sprintf "Discharge %d: unknown Event %S" position (id event)
  | Unknown_target { target = relation; position } ->
    Printf.sprintf "Discharge %d: unknown Relation %S" position (target relation)
  | Repeated_correspondence { event; target = relation; first_position; position } ->
    Printf.sprintf "Discharge %d: repeated Event %S / Relation %S (first %d)"
      position (id event) (target relation) first_position
  | Self_discharge { event; target = relation; position } ->
    Printf.sprintf "Discharge %d: Event %S established target Relation %S"
      position (id event) (target relation)
  | Nonpositive_quantity { event; target = relation; quantity = amount; position } ->
    Printf.sprintf "Discharge %d: Event %S / Relation %S quantity %s is not positive"
      position (id event) (target relation) (quantity amount)
  | Exceeds_target { event; target = relation; quantity = amount; target_quantity; position } ->
    Printf.sprintf "Discharge %d: Event %S / Relation %S quantity %s exceeds target quantity %s"
      position (id event) (target relation) (quantity amount) (quantity target_quantity)
  | Overdischarged_target { target = relation; total; target_quantity; position } ->
    Printf.sprintf "Discharge %d: Relation %S total %s exceeds target quantity %s"
      position (target relation) (quantity total) (quantity target_quantity)

let source_refusal error =
  let detail = match error with
    | A.Actual_source.Events (D.Event_memory.Duplicate_id { id = event; first_position; position }) ->
      Printf.sprintf "duplicate Event %S at %d (first %d)" (id event) position first_position
    | Zero_effect { event; event_position; effect_position } ->
      Printf.sprintf "Event %S at %d: zero Effect at %d" (id event) event_position effect_position
    | Unbalanced_measure { event; event_position; measure; residual } ->
      Printf.sprintf "Event %S at %d: Measure %S residual %s" (id event) event_position
        (D.Identifier.Measure.to_string measure) (quantity residual)
    | Exchanges error -> exchange_error error
    | Reversals error -> reversal_error error
    | Relations error -> relation_error error
    | Discharges error -> discharge_error error
    | Validity error -> validity_error error
    | Corrections error -> correction_error error
    | Descriptions error ->
      (match error with
       | A.Event_descriptions.Repeated_description { event; first_position; position } ->
         Printf.sprintf "duplicate description for %S at %d (first %d)" (id event) position first_position
       | Unknown_description_event { event; position } ->
         Printf.sprintf "description %d: unknown Event %S" position (id event))
    | Merchants error ->
      (match error with
       | A.Event_merchants.Repeated_disposition { event; first_position; position } ->
         Printf.sprintf "duplicate Merchant disposition for %S at %d (first %d)"
           (id event) position first_position
       | Unknown_merchant_event { event; position } ->
         Printf.sprintf "Merchant disposition %d: unknown Event %S" position (id event))
    | Original_amounts error ->
      (match error with
       | A.Original_amounts.Repeated_root { root; first_position; position } ->
         Printf.sprintf "duplicate original amount for root %S at %d (first %d)"
           (id root) position first_position
       | Nonpositive_quantity { root; quantity = amount; position } ->
         Printf.sprintf "original amount %d for %S: nonpositive quantity %s"
           position (id root) (quantity amount)
       | Unknown_event { root; position } ->
         Printf.sprintf "original amount %d: unknown Event %S" position (id root)
       | Not_root { root; position } ->
         Printf.sprintf "original amount %d: Event %S is not a correction root" position (id root)) in
  "Actual source refused: " ^ detail ^ ".\n"

let answer answer =
  let module Q = A.Current_quantity_query in
  let row = match Q.premise answer with
    | Q.Zero_origin -> Printf.sprintf "%s: zero-origin; quantity=%s\n"
        (location (Q.coordinate answer)) (quantity (Q.quantity answer))
    | Q.Opening { coordinate; opening_event } -> Printf.sprintf "%s: opening Event %S; quantity=%s\n"
        (location coordinate) (id opening_event) (quantity (Q.quantity answer))
    | Q.Current_assertion asserted -> "exact assertion; " ^ assertion_row asserted in
  "Conditional current fixture quantity (Actual subset).\n" ^ row

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
