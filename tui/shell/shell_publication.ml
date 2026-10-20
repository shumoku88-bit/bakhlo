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
  | Screen.Correct_entry { transaction; base } ->
      A.commit_transaction ~session:state.session ~base_revision:base transaction
  | Screen.Classify_merchant { id; disposition; base; message = _ } ->
      A.commit_classify_merchant ~session:state.session ~base_revision:base ~id ~disposition
  | Screen.Cancel_plan { id; day; base } ->
      A.commit_cancel_plan ~session:state.session ~base_revision:base ~id ~day
  | Screen.Plan_batch { plans; replace; base } ->
      A.commit_plan_batch ~replace ~session:state.session ~base_revision:base plans
  | Screen.Create_plan { plan; base } ->
      A.commit_payload ~session:state.session ~base_revision:base (A.Plan_tx { plan; replace = false })
  | Screen.Observe_quantities _ -> invalid_arg "observations publish through publish_observation"

(* Observations map their store outcomes directly. *)
let publish_observation state ~rows ~base =
  if base <> state.session.revision then ({ state with blocked = true }, Screen.Publish_conflict)
  else
    match (try F.append state.session [ Bakhlo_sexp.Book_log.Observe rows ] with F.Refused why -> F.Refused_input why) with
    | F.Written session -> (sync { state with session }, Screen.Published)
    | F.Conflict -> ({ state with blocked = true }, Screen.Publish_conflict)
    | F.Refused_input why -> (state, Screen.Publish_refused ("Observation refused: " ^ why))
    | F.Uncertain _ -> ({ state with blocked = true }, Screen.Publish_stopped)
