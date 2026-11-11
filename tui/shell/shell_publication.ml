(* Ledger publications requested by screen owners, executed through the single
   writer against the current session. *)
open Shell_state

let execute_publication state = function
  | Screen.Add_locus { token; role } -> Publication.add_locus ~session:state.session ~role token
  | Screen.Set_locus_label { locus; label; help } ->
      Publication.set_locus_label ~session:state.session ~base_revision:state.session.revision
        ~id:locus ~label ~help ()
  | Screen.Commit_transaction { transaction; base } ->
      Publication.transaction ~session:state.session ~base_revision:base transaction
  | Screen.Reverse_entry { id; day; base } ->
      Publication.reverse_entry ~session:state.session ~base_revision:base ~id ~day
  | Screen.Correct_entry_date { id; day; base } ->
      Publication.correct_entry_date ~session:state.session ~base_revision:base ~id ~day
  | Screen.Classify_merchant { id; disposition; base; message = _ } ->
      Publication.classify_merchant ~session:state.session ~base_revision:base ~id ~disposition
  | Screen.Cancel_plan { id; day; base } ->
      Publication.cancel_plan ~session:state.session ~base_revision:base ~id ~day
  | Screen.Plan_batch { plans; replace; base } ->
      Publication.plan_batch ~replace ~session:state.session ~base_revision:base plans
  | Screen.Create_plan { plan; base; offer_pace = _ } ->
      Publication.payload ~session:state.session ~base_revision:base
        (Draft.Plan_tx { plan; replace = false })
  | Screen.Observe_quantities _ -> invalid_arg "observations publish through publish_observation"

let publish_outcome = function
  | Publication.Published _ -> Screen.Published
  | Publication.Refused why -> Screen.Publish_refused why
  | Publication.Conflict | Publication.Conflict_base_changed -> Screen.Publish_conflict
  | Publication.Uncertain _ | Publication.Storage_failed _ -> Screen.Publish_stopped

(* Observe keeps its modal until the owner receives the result. Storage failures
   and uncertain evidence use the same transition as ordinary recording. *)
let observation_result state result =
  let state =
    match result with
    | Publication.Published session -> sync { state with session }
    | _ -> apply_outcome state ~draft:state result
  in
  let outcome =
    match result with
    | Publication.Refused why -> Screen.Publish_refused ("Observation refused: " ^ why)
    | _ -> publish_outcome result
  in
  (state, outcome)

let publish_observation state ~rows ~base =
  observation_result state
    (Publication.observations ~session:state.session ~base_revision:base rows)
