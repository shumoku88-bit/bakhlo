(* Ledger publications requested by screen owners, executed through the single
   writer against the current session. *)
open Shell_state

let execute_publication state = function
  | Screen.Add_locus token -> A.commit_add_locus ~session:state.session token
  | Screen.Set_locus_label { locus; label; help } ->
      A.commit_set_locus_label ~session:state.session ~base_revision:state.session.revision
        ~id:locus ~label ~help ()
  | Screen.Commit_transaction { transaction; base } ->
      A.commit_transaction ~session:state.session ~base_revision:base transaction
  | Screen.Reverse_entry { id; day; base } ->
      A.commit_reverse_entry ~session:state.session ~base_revision:base ~id ~day
  | Screen.Correct_entry_date { id; day; base } ->
      A.commit_correct_entry_date ~session:state.session ~base_revision:base ~id ~day
  | Screen.Classify_merchant { id; disposition; base; message = _ } ->
      A.commit_classify_merchant ~session:state.session ~base_revision:base ~id ~disposition
  | Screen.Cancel_plan { id; day; base } ->
      A.commit_cancel_plan ~session:state.session ~base_revision:base ~id ~day
  | Screen.Plan_batch { plans; replace; base } ->
      A.commit_plan_batch ~replace ~session:state.session ~base_revision:base plans
  | Screen.Create_plan { plan; base; offer_pace = _ } ->
      A.commit_payload ~session:state.session ~base_revision:base
        (A.Plan_tx { plan; replace = false })
  | Screen.Observe_quantities _ -> invalid_arg "observations publish through publish_observation"

let publish_outcome = function
  | A.Published _ -> Screen.Published
  | A.Refused why -> Screen.Publish_refused why
  | A.Conflict | A.Conflict_base_changed -> Screen.Publish_conflict
  | A.Uncertain _ | A.Storage_failed _ -> Screen.Publish_stopped

(* Observe keeps its modal until the owner receives the result. Storage failures
   and uncertain evidence use the same transition as ordinary recording. *)
let observation_result state result =
  let state =
    match result with
    | A.Published session -> sync { state with session }
    | _ -> apply_commit_result state ~draft:state result
  in
  let outcome =
    match result with
    | A.Refused why -> Screen.Publish_refused ("Observation refused: " ^ why)
    | _ -> publish_outcome result
  in
  (state, outcome)

let publish_observation state ~rows ~base =
  observation_result state (A.commit_observations ~session:state.session ~base_revision:base rows)
