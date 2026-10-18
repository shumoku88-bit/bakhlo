module B = Bakhlo_sexp.Daily_book
module F = Daily_file
module A = Daily_actions
module S = Scheduled_bulk_session
module C = Daily_interaction_state
module H = Daily_interaction

let require = F.require
let get = function Ok x -> x | Error why -> raise (F.Refused why)
let key button = `Key (button, [])
let text s = List.init (String.length s) (fun i -> `Key (`ASCII s.[i], []))
let step ~width_of ~dims s input =
  match S.handle ~blocked:false ~dimensions:dims ~width_of s input with
  | S.Updated s -> s
  | S.Closed -> raise (F.Refused "bulk-session-closed")
  | S.Publish _ -> raise (F.Refused "unexpected-bulk-publish")
let fixture =
  "(bakhlo-daily 3)\n(scope corrected-entries explicit-plans)\n\
   (measures (measure \"jpy\" 0) (measure \"eur\" 2))\n\
   (labels (provided (label \"cash\" \"Cash\" \"Synthetic\") (label \"food\" \"Food\" \"Synthetic\")))\n\
   (approved-loci (provided \"cash\" \"food\"))\n(entries)\n(plans)\n\
   (support (zero-origin (\"food\" \"jpy\") (\"food\" \"eur\")) (openings)\n\
   (observations (observation (reflected) (quantities (\"cash\" \"jpy\" 1000) (\"cash\" \"eur\" 10000))))\n\
   (presence (not-supplied)))\n"
let plan id day measure cents : B.plan =
  { id; day; measure; changes = ["cash", Z.neg cents; "food", cents]; paid_by=None; cancelled_on=None }
let self_check ~width_of () =
  let directory = "scratch/scheduled-bulk-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let book = get (B.of_string fixture) in
  let p1 = plan "bulk-a" "2026-10-15" "eur" (Z.of_int 1200)
  and p2 = plan "bulk-b" "2026-10-16" "eur" (Z.of_int 2500)
  and p3 = plan "bulk-jpy" "2026-10-17" "jpy" (Z.of_int 90) in
  let book = List.fold_left (fun book p -> get (B.put_plan book ~replace:false p))
      book [p1; p2; p3] in
  let source = List.hd (B.plans book) in
  let base = B.to_string book in
  let path = directory ^ "/controller.sexp" in
  F.write_new path base;
  let state = C.initial ~config_home:directory (F.load path)
    |> fun s -> C.open_route s Ui_workspace.Scheduled
    |> fun s -> Interaction_check_fixture.with_plan_query s source.id in
  let opened = Interaction_check_fixture.batch_plan_selected state in
  require (match Interaction_check_fixture.session_of opened with Some (Record_editors.Scheduled_bulk _) -> true | _ -> false)
    "controller-opens-bulk-for-selected-plan";
  let ckey state button = Option.get (H.handle ~dimensions:(140,40) ~width_of state (key button)) in
  let controller_preview = List.fold_left (fun state event ->
      Option.get (H.handle ~dimensions:(140,40) ~width_of state event)) opened (text "40.00")
    |> fun state -> ckey state `Enter
    |> fun state -> ckey state (`ASCII 'a')
    |> fun state -> ckey state `Enter in
  let not_published = ckey controller_preview `Enter in
  require (F.read path = base && Option.is_some (Interaction_check_fixture.session_of not_published))
    "controller-back-is-read-only";
  let publishable = ckey controller_preview `Tab |> fun state -> ckey state `End in
  let saved = ckey publishable `Enter in
  let cold = F.load path in
  require ((Interaction_check_fixture.no_modal saved)
           && List.for_all (fun id ->
             let plan = List.find (fun (plan:B.plan) -> plan.id = id) (B.plans cold.book) in
             plan.changes = ["cash", Z.of_int (-4000); "food", Z.of_int 4000])
             [p1.id; p2.id]
           && List.find (fun (plan:B.plan) -> plan.id = p3.id) (B.plans cold.book) = p3)
    "controller-publishes-whole-reviewed-batch-cold";
  let stale = Daily_interaction_context.reload publishable |> fun state -> ckey state `Enter in
  require (stale.blocked && F.read path = cold.bytes
           && match Interaction_check_fixture.session_of stale with Some (Record_editors.Scheduled_bulk editor) -> S.base_bytes editor = base | _ -> false)
    "controller-reload-cannot-bless-stale-batch";
  let held = C.open_record state |> fun state -> ckey state (`ASCII 'x')
    |> fun state -> ckey state `Escape in
  let refused = Interaction_check_fixture.batch_plan_selected held in
  require (C.has_record_draft held && refused.record = held.record
           && (Interaction_check_fixture.no_modal refused) && F.read path = cold.bytes)
    "controller-held-record-prevents-batch";
  let s = get (S.create ~book ~base_bytes:base ~from_day:source.day source) in
  let terminal_source = { source with paid_by = Some "closed" } in
  require (Result.is_error (S.create ~book ~base_bytes:base ~from_day:source.day terminal_source))
    "terminal-source-refused";
  require (S.base_bytes s = base) "captured-base";
  List.iter (fun dims ->
    let rows = S.screen ~dimensions:dims ~width_of s in
    require (List.length rows <= max 0 (snd dims)) "parameter-screen-height")
    [0,0; 1,1; 32,9; 48,14; 80,24; 120,36];
  let empty = get (S.create ~book ~base_bytes:base ~from_day:source.day source) in
  let empty = List.fold_left (step ~width_of ~dims:(80,24)) empty (text "1.00") in
  let empty = step ~width_of ~dims:(80,24) empty (key `Tab) in
  let empty = List.fold_left (step ~width_of ~dims:(80,24)) empty
      (List.init (String.length source.day) (fun _ -> key `Backspace)) in
  let empty = List.fold_left (step ~width_of ~dims:(80,24)) empty (text "2026-10-20") in
  let empty = step ~width_of ~dims:(80,24) empty (key `Enter) in
  let empty = step ~width_of ~dims:(80,24) empty (key (`ASCII 'j')) in
  let empty = step ~width_of ~dims:(80,24) empty (key (`ASCII ' ')) in
  ignore (step ~width_of ~dims:(80,24) empty (key `End));
  let nav = get (S.create ~book ~base_bytes:base ~from_day:source.day source) in
  let nav = List.fold_left (step ~width_of ~dims:(80,24)) nav (text "40.00") in
  let nav = step ~width_of ~dims:(80,24) nav (key `Enter) in
  let nav = step ~width_of ~dims:(80,24) nav (key `End) in
  let nav = step ~width_of ~dims:(80,24) nav (key (`ASCII ' ')) in
  let nav = step ~width_of ~dims:(80,24) nav (key `Home) in
  let nav = step ~width_of ~dims:(80,24) nav (key (`ASCII ' ')) in
  let nav = step ~width_of ~dims:(80,24) nav (key `Enter) in
  let nav = step ~width_of ~dims:(80,24) nav (key `End) in
  let nav = step ~width_of ~dims:(80,24) nav (key `Tab) in
  (match S.handle ~blocked:false ~dimensions:(80,24) ~width_of nav (key `Enter) with
   | S.Publish (plans, _) ->
       require (List.map (fun (p:B.plan) -> p.id) plans = ["bulk-a"; "bulk-b"])
         "home-end-select-plan-identities"
   | _ -> raise (F.Refused "home-end-selection-did-not-publish"));
  let s = List.fold_left (step ~width_of ~dims:(80,24)) s (text "1234567890123456789012.34") in
  let s = step ~width_of ~dims:(80,24) s (key `Enter) in
  let s = step ~width_of ~dims:(80,24) s (key (`ASCII 'a')) in
  let s = step ~width_of ~dims:(80,24) s (key `Enter) in
  let s = step ~width_of ~dims:(80,24) s (key `Enter) in
  let s = step ~width_of ~dims:(80,24) s (key `Enter) in
  let s = step ~width_of ~dims:(80,24) s (key `End) in
  let s = step ~width_of ~dims:(80,24) s (key `Tab) in
  let s = step ~width_of ~dims:(32,9) s (key `Enter) in
  let s = step ~width_of ~dims:(80,24) s (key `End) in
  match S.handle ~blocked:false ~dimensions:(80,24) ~width_of s (key `Enter) with
  | S.Publish (plans, captured) ->
      require (captured = base && List.length plans = 2) "selected-replacements";
      let path = directory ^ "/book.sexp" in
      F.write_new path base;
      let session = F.load path in
      (match A.commit_plan_batch ~session ~base_bytes:captured plans with
       | A.Published _ -> ()
       | _ -> raise (F.Refused "batch-commit-failed"));
      let cold = F.load path in
      let a = List.find (fun (p:B.plan) -> p.id="bulk-a") (B.plans cold.book)
      and b = List.find (fun (p:B.plan) -> p.id="bulk-b") (B.plans cold.book) in
      require (List.map snd a.changes = [Z.of_string "-123456789012345678901234"; Z.of_string "123456789012345678901234"]
        && List.map snd b.changes = [Z.of_string "-123456789012345678901234"; Z.of_string "123456789012345678901234"]) "exact-cold-quantities";
      require (a.day=p1.day && b.day=p2.day && a.measure="eur" && a.paid_by=None && a.cancelled_on=None) "metadata-preserved";
      let unchanged = F.read path in
      let jpy = List.find (fun (p:B.plan) -> p.id="bulk-jpy") (B.plans cold.book) in
      require (jpy = p3) "unselected-plan-preserved";
      let invalid = { (List.nth plans 1) with changes=["not-approved", Z.of_int (-4000); "food", Z.of_int 4000] } in
      require (match A.commit_plan_batch ~session ~base_bytes:session.bytes [List.hd plans; invalid] with
        | A.Refused _ -> true | _ -> false) "late-invalid-plan-refused";
      require (F.read path=unchanged) "late-invalid-no-partial-write";
      let duplicate = A.commit_plan_batch ~session ~base_bytes:session.bytes [List.hd plans; List.hd plans] in
      require (match duplicate with A.Refused _ -> true | _ -> false) "duplicate-refused";
      require (F.read path=unchanged) "duplicate-no-write";
      require (match A.commit_plan_batch ~session ~base_bytes:"stale" plans with A.Conflict_base_changed -> true | _ -> false) "stale-refused";
      require (match A.commit_plan_batch ~session ~base_bytes:session.bytes [] with A.Refused _ -> true | _ -> false) "empty-refused";
      let records_path = directory ^ "/records.sexp" in
      let records_before = B.to_records_string cold.book in
      F.write_new records_path records_before;
      let records_session = F.load records_path in
      require (match A.commit_plan_batch ~session:records_session ~base_bytes:records_session.bytes plans with
        | A.Refused _ -> true | _ -> false) "records-refused";
      require (F.read records_path = records_before) "records-no-write";
      print_endline "PASS: Scheduled bulk amount editing preserves metadata, exact decimal quanta, candidate/selection boundaries, Back default, terminal/stale/Records refusal and atomic cold reload."
  | _ -> raise (F.Refused "publish-choice-navigation")
