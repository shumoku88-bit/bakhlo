module B = Bakhlo_sexp.Daily_book
module F = Daily_file
module A = Daily_actions
module S = Scheduled_generation_session
module C = Shell_state
module H = Shell_input

let require = F.require
let get = function Ok x -> x | Error why -> raise (F.Refused why)
let key button = `Key (button, [])
let text s = List.init (String.length s) (fun i -> `Key (`ASCII s.[i], []))

let step ~width_of ~dims s input =
  match S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:dims ~width_of s input with
  | S.Updated s -> s
  | S.Closed -> raise (F.Refused "generate-session-closed")
  | S.Publish _ -> raise (F.Refused "unexpected-generate-publish")

let fixture =
  "(bakhlo-daily 3)\n\
   (scope corrected-entries explicit-plans)\n\
   (measures (measure \"jpy\" 0) (measure \"eur\" 2))\n\
   (labels (provided (label \"cash\" \"Cash\" \"Synthetic\") (label \"food\" \"Food\" \
   \"Synthetic\")))\n\
   (approved-loci (provided \"cash\" \"food\"))\n\
   (entries)\n\
   (plans)\n\
   (support (zero-origin (\"food\" \"jpy\") (\"food\" \"eur\")) (openings)\n\
   (observations (observation (reflected) (quantities (\"cash\" \"jpy\" 1000) (\"cash\" \"eur\" \
   10000))))\n\
   (presence (not-supplied)))\n"

let plan id day measure cents : B.plan =
  {
    id;
    day;
    measure;
    changes = [ ("cash", Z.neg cents); ("food", cents) ];
    paid_by = None;
    cancelled_on = None;
  }

let self_check ~width_of () =
  let directory = "scratch/scheduled-generate-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let book = get (B.of_string fixture) in
  let source = plan "source-plan" "2026-10-15" "eur" (Z.of_int 5000) in
  let book = get (B.put_plan book ~replace:false source) in
  let base = Bakhlo_sexp.Daily_txt.text book in
  let path = directory ^ "/controller.sexp" in
  F.write_new path base;
  let base_rev = F.revision_of_bytes base in

  (* Monitored cadence requires an explicit observed date; no silent fallback. *)
  require
    (Result.is_error (S.create ~cadence_months:1 ~book ~base_revision:base_rev ~source ()))
    "cadence-requires-observed-date";

  (* 1. Controller integration *)
  let state =
    C.initial ~config_home:directory (F.load path) |> fun s ->
    C.open_route s Ui_workspace.Scheduled |> fun s ->
    Interaction_check_fixture.with_plan_query s source.id
  in
  let opened = Interaction_check_fixture.extend_plan_selected state in
  require
    (match Interaction_check_fixture.session_of opened with
    | Some (Record_editors.Scheduled_generate _) -> true
    | _ -> false)
    "controller-extend_plan_selected-opens-generate";
  let opened_by_key =
    Option.get (H.handle ~dimensions:(140, 40) ~width_of state (key (`ASCII 'g')))
  in
  require
    (match Interaction_check_fixture.session_of opened_by_key with
    | Some (Record_editors.Scheduled_generate _) -> true
    | _ -> false)
    "controller-key-g-opens-generate";
  let ckey state button =
    Option.get (H.handle ~dimensions:(140, 40) ~width_of state (key button))
  in
  let cstep state event = Option.get (H.handle ~dimensions:(140, 40) ~width_of state event) in

  (* Cancel in parameters closes overlay without write *)
  let cancelled = ckey opened `Escape in
  require
    (Interaction_check_fixture.no_modal cancelled && F.read path = base)
    "controller-generate-cancel-leaves-disk-unchanged";

  (* 2. Terminal source refusal *)
  let closed_source = { source with paid_by = Some "entry-1" } in
  require
    (Result.is_error (S.create ~book ~base_revision:base_rev ~source:closed_source ()))
    "terminal-source-rejected-by-create";

  (* 3. Session creation & parameter boundaries *)
  let s = get (S.create ~book ~base_revision:base_rev ~source ()) in
  require (S.base_revision s = base_rev) "captured-base-bytes";

  (* Screen resize bounds at various dimensions *)
  List.iter
    (fun dims ->
      let rows = S.screen ~dimensions:dims ~width_of s in
      require (List.length rows <= max 0 (snd dims)) "generate-screen-height")
    [ (0, 0); (1, 1); (32, 9); (48, 14); (80, 24); (120, 36) ];

  (* Clear through date and enter invalid date *)
  let clear s =
    List.fold_left (step ~width_of ~dims:(80, 24)) s (List.init 12 (fun _ -> key `Backspace))
  in
  let still_form label state =
    match
      S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 24) ~width_of state
        (key `Escape)
    with
    | S.Closed -> ()
    | _ -> raise (F.Refused label)
  in
  let bad_date =
    clear s |> fun s -> List.fold_left (step ~width_of ~dims:(80, 24)) s (text "2026-02-30")
  in
  let bad_date = step ~width_of ~dims:(80, 24) bad_date (key `Enter) in
  still_form "invalid-date-must-remain-in-form" bad_date;

  (* Through date earlier than source date *)
  let early =
    clear s |> fun s -> List.fold_left (step ~width_of ~dims:(80, 24)) s (text "2026-09-01")
  in
  let early = step ~width_of ~dims:(80, 24) early (key `Enter) in
  still_form "early-date-must-remain-in-form" early;

  (* Through date too close (no occurrences) *)
  let too_close =
    clear s |> fun s -> List.fold_left (step ~width_of ~dims:(80, 24)) s (text "2026-10-20")
  in
  let too_close = step ~width_of ~dims:(80, 24) too_close (key `Enter) in
  still_form "no-occurrence-must-remain-in-form" too_close;

  (* 4. Valid generation preview and protective default *)
  let valid =
    clear s |> fun s -> List.fold_left (step ~width_of ~dims:(80, 24)) s (text "2028-02-15")
  in
  let preview = step ~width_of ~dims:(80, 24) valid (key `Enter) in
  (* Default action is Cancel: Enter closes session *)
  (match
     S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 24) ~width_of preview
       (key `Enter)
   with
  | S.Closed -> ()
  | _ -> raise (F.Refused "default-action-must-be-cancel"));

  (* Escape in preview returns to the parameter form: Enter there must
     regenerate the same preview, proven by the 15-date publication below. *)
  let back = step ~width_of ~dims:(80, 24) preview (key `Escape) in

  (* 5. Gate checks before publish *)
  let preview = step ~width_of ~dims:(80, 24) back (key `Enter) in
  (* Switch to Publish all: Tab *)
  let to_publish = step ~width_of ~dims:(80, 24) preview (key `Tab) in
  (* Dimension gate: publishing at 32x9 would raise from [step]; returning proves refusal. *)
  ignore (step ~width_of ~dims:(32, 9) to_publish (key `Enter));

  (* Review to end gate: Home then Enter must not publish at height 16,
     where rows (19) exceed capacity (14). [to_publish] stays for End. *)
  let unreviewed = step ~width_of ~dims:(80, 16) to_publish (key `Home) in
  ignore (step ~width_of ~dims:(80, 16) unreviewed (key `Enter));

  (* Scroll to End and publish successfully *)
  let ended = step ~width_of ~dims:(80, 16) to_publish (key `End) in
  (match
     S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 16) ~width_of ended
       (key `Enter)
   with
  | S.Publish (plans, captured) ->
      require (captured = base_rev) "captured-base-matches";
      (* Monthly from 2026-10-15 through 2028-02-15 exclusive: 15 occurrences *)
      require (List.length plans = 15) "generated-occurrence-count";
      require
        ((List.hd plans).day = "2026-11-15" && (List.nth plans 14).day = "2028-01-15")
        "generated-occurrence-dates";
      require
        (List.for_all (fun (p : B.plan) -> p.measure = "eur" && p.changes = source.changes) plans)
        "generated-occurrence-exact-changes";

      (* Commit via A.commit_plan_batch *)
      let book_path = directory ^ "/book.sexp" in
      F.write_new book_path base;
      let sess = F.load book_path in
      (match A.commit_plan_batch ~replace:false ~session:sess ~base_revision:captured plans with
      | A.Published _ -> ()
      | _ -> raise (F.Refused "atomic-commit-failed"));

      (* Cold restart readback proves all plans are present on disk *)
      let cold = F.load book_path in
      require (B.entry_count cold.book = 0) "entries-untouched";
      require (List.length (B.plans cold.book) = 16) "plans-count-is-sixteen";
      List.iter
        (fun (p : B.plan) ->
          let found = List.find (fun (cp : B.plan) -> cp.id = p.id) (B.plans cold.book) in
          require
            (found.day = p.day && found.measure = p.measure && found.changes = p.changes
           && found.paid_by = None && found.cancelled_on = None)
            "cold-reloaded-plan-attributes-exact")
        plans
  | _ -> raise (F.Refused "valid-publish-failed"));

  (* 6. Controller end-to-end publish *)
  let cclear s = List.fold_left cstep s (List.init 12 (fun _ -> key `Backspace)) in
  let controller_run = cclear opened |> fun s -> List.fold_left cstep s (text "2027-01-01") in
  let controller_preview = ckey controller_run `Enter in
  let controller_to_publish = ckey controller_preview `Tab in
  let controller_ended = ckey controller_to_publish `End in
  let published_state = ckey controller_ended `Enter in
  let cold_controller = F.load path in
  require
    (Interaction_check_fixture.no_modal published_state
    && List.length (B.plans cold_controller.book) = 3)
    (* source + 2026-11-15 + 2026-12-15 *)
    "controller-publishes-all-generated-plans-atomically";

  (* 7. Stale base protection on reload *)
  let stale = Shell_dispatch.reload controller_run |> fun s -> ckey s `Enter in
  require
    (stale.blocked
    && F.read_revision path = cold_controller.revision
    &&
    match Interaction_check_fixture.session_of stale with
    | Some (Record_editors.Scheduled_generate editor) -> S.base_revision editor = base_rev
    | _ -> false)
    "controller-reload-cannot-bless-stale-generation";

  (* 8. Held record draft prevents extend *)
  let held =
    C.open_record state |> fun s ->
    ckey s (`ASCII 'x') |> fun s -> ckey s `Escape
  in
  let refused = Interaction_check_fixture.extend_plan_selected held in
  require
    (C.has_record_draft held && refused.record = held.record
    && Interaction_check_fixture.no_modal refused
    && F.read_revision path = cold_controller.revision)
    "controller-held-record-prevents-extend";

  (* 9. Monitored replenishment: explicit observation date, horizons, missing days. *)
  let huge = Z.of_string (String.make 600 '9') in
  let huge_plan : B.plan =
    {
      id = "huge";
      day = "2026-10-15";
      measure = "jpy";
      changes = [ ("cash", Z.neg huge); ("food", huge) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let extra =
    [
      plan "old-19" "2025-08-19" "eur" (Z.of_int 5000);
      plan "old-20" "2025-08-20" "eur" (Z.of_int 5000);
      plan "month-end" "2026-01-31" "eur" (Z.of_int 5000);
      plan "leap" "2024-02-29" "eur" (Z.of_int 5000);
      plan "max" "9999-12-15" "eur" (Z.of_int 5000);
      huge_plan;
    ]
  in
  let book2 = List.fold_left (fun b p -> get (B.put_plan b ~replace:false p)) book extra in
  let base2 = Bakhlo_sexp.Daily_txt.text book2 in
  let rev2 = F.revision_of_bytes base2 in
  let open_plan id = List.find (fun (p : B.plan) -> p.id = id) (B.plans book2) in
  let monitored ?cadence ?observed (s : B.plan) =
    S.create ?cadence_months:cadence ?observed_at:observed ~book:book2 ~base_revision:rev2 ~source:s
      ()
  in
  let editor ?cadence ?observed s = get (monitored ?cadence ?observed s) in
  let feed t inputs = List.fold_left (step ~width_of ~dims:(80, 24)) t inputs in
  let tap t b = step ~width_of ~dims:(80, 24) t (key b) in
  let press ?(dims = (80, 24)) t b = step ~width_of ~dims t (key b) in
  let replace t s = feed (feed t (List.init 12 (fun _ -> key `Backspace))) (text s) in
  let pick t n = feed t (List.init n (fun _ -> key (`Arrow `Right))) in
  let preview_horizon t = tap t `Enter in
  let publish t =
    match
      S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 24) ~width_of
        (feed t [ key `Tab; key `End ])
        (key `Enter)
    with
    | S.Publish (plans, captured) -> (plans, captured)
    | _ -> raise (F.Refused "monitored-publish-expected")
  in
  let days plans = List.map (fun (p : B.plan) -> p.day) plans in
  let next ?(cadence = 1) ?(observed = "2026-10-21") ?(index = 0) s =
    pick (editor ~cadence ~observed s) index
  in

  require
    (Result.is_error (monitored ~cadence:2 source) && Result.is_error (monitored ~cadence:12 source))
    "e-monitored-cadence-requires-observed-date";
  List.iter
    (fun day ->
      require
        (Result.is_error (monitored ~cadence:1 ~observed:day source))
        "e-monitored-rejects-invalid-observed-date")
    [ ""; "2026-2-01"; "2026-02-30"; "2026-13-01"; "2026-02-29"; "not-a-date" ];
  List.iter
    (fun day ->
      require
        (Result.is_ok (monitored ~cadence:1 ~observed:day source))
        "e-monitored-accepts-canonical-observed-date")
    [ "2026-01-01"; "2026-12-31"; "2028-02-29" ];
  List.iter
    (fun cadence ->
      require
        (Result.is_ok (monitored ~cadence ~observed:"2026-10-21" source))
        "e-each-monitored-cadence-accepted")
    [ 1; 2; 3; 6; 12 ];
  require
    (Result.is_error (monitored ~cadence:5 ~observed:"2026-10-21" source))
    "e-unsupported-cadence-refused";

  let n1 = publish (preview_horizon (next source)) in
  require (days (fst n1) = [ "2026-11-15" ] && snd n1 = rev2) "e-next1-exact-date-and-base";
  require
    (List.for_all
       (fun (p : B.plan) ->
         p.measure = source.measure && p.changes = source.changes && p.paid_by = None
         && p.cancelled_on = None)
       (fst n1))
    "e-published-source-metadata-exact";
  List.iter
    (fun button ->
      match
        S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 24) ~width_of
          (next source)
          (key (`ASCII button))
      with
      | S.Closed -> ()
      | _ -> raise (F.Refused "e-horizon-q-cancels"))
    [ 'q'; 'Q' ];
  let n3 = publish (preview_horizon (next ~index:1 source)) in
  require (days (fst n3) = [ "2026-11-15"; "2026-12-15"; "2027-01-15" ]) "e-next3-exact-dates";
  let next6_days =
    [ "2026-11-15"; "2026-12-15"; "2027-01-15"; "2027-02-15"; "2027-03-15"; "2027-04-15" ]
  in
  let n6 = publish (preview_horizon (next ~index:2 source)) in
  require (days (fst n6) = next6_days) "e-next6-exact-dates";
  require
    (List.length (List.sort_uniq String.compare (List.map (fun (p : B.plan) -> p.id) (fst n6))) = 6)
    "e-each-draft-has-a-fresh-id";
  let reopened = publish (preview_horizon (tap (preview_horizon (next ~index:2 source)) `Escape)) in
  require (days (fst reopened) = next6_days) "e-preview-escape-retains-horizon";
  let cadence_days cadence expected =
    let plans, _ = publish (preview_horizon (next ~cadence ~index:1 source)) in
    require (days plans = expected) "e-preset-cadence-exact-dates"
  in
  cadence_days 2 [ "2026-12-15"; "2027-02-15"; "2027-04-15" ];
  cadence_days 3 [ "2027-01-15"; "2027-04-15"; "2027-07-15" ];
  cadence_days 6 [ "2027-04-15"; "2027-10-15"; "2028-04-15" ];
  cadence_days 12 [ "2027-10-15"; "2028-10-15"; "2029-10-15" ];

  (* Preset exceeding the supported calendar refuses without closing. *)
  let overflow = preview_horizon (next ~observed:"9999-12-15" (open_plan "max")) in
  (match
     S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 24) ~width_of overflow
       (key `Enter)
   with
  | S.Updated _ -> ()
  | _ -> raise (F.Refused "e-horizon-overflow-must-stay"));
  (match
     S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 24) ~width_of overflow
       (key `Escape)
   with
  | S.Closed -> ()
  | _ -> raise (F.Refused "e-horizon-overflow-escape-cancels"));

  (* 10. Custom exclusive fill limit: refusals retain the typed draft. *)
  let custom t = tap (pick t 3) `Enter in
  let custom_enter t limit = tap (replace t limit) `Enter in
  let custom_refused limit =
    let t = custom_enter (custom (editor ~cadence:1 ~observed:"2026-10-21" source)) limit in
    let reopened = tap (tap t `Escape) `Enter in
    require
      (List.exists
         (fun (_, line) -> Base.String.is_substring line ~substring:limit)
         (S.screen ~dimensions:(80, 24) ~width_of reopened))
      "e-custom-draft-retained";
    let t = tap reopened `Enter in
    let plans, _ = publish (custom_enter t "2026-12-15") in
    require (days plans = [ "2026-11-15" ]) "e-custom-limit-refusal-then-valid"
  in
  List.iter custom_refused [ "2026-10-20"; "2026-10-21"; "2026-10-15"; "2026-11-31"; "not-a-date" ];
  let custom_pub =
    publish (custom_enter (custom (editor ~cadence:1 ~observed:"2026-10-21" source)) "2026-12-15")
  in
  require (days (fst custom_pub) = [ "2026-11-15" ]) "e-custom-limit-exclusive";

  (* 11. Missing nominal day: explicit resolution, no clamping, range gates. *)
  let resolve t wrong right =
    let t = tap t `Enter in
    let t = tap (feed t (text wrong)) `Enter in
    let t = feed t (List.init (String.length wrong) (fun _ -> key `Backspace)) in
    tap (feed t (text right)) `Enter
  in
  let missing ?(cadence = 1) id observed wrong right expected =
    let prompt = preview_horizon (editor ~cadence ~observed (open_plan id)) in
    let plans, _ = publish (resolve prompt wrong right) in
    require (days plans = expected) "e-missing-day-resolved-explicitly"
  in
  missing "month-end" "2026-01-31" "2026-02-30" "2026-02-28" [ "2026-02-28" ];
  missing "month-end" "2026-01-31" "2026-01-30" "2026-02-28" [ "2026-02-28" ];
  missing "month-end" "2026-01-31" "2026-03-01" "2026-02-28" [ "2026-02-28" ];
  (* Resolver accepts any canonical date inside [observed, limit): a date in the
     source month, before the source day, and outside the missing slot's month. *)
  missing "month-end" "2026-01-01" "2026-02-30" "2026-01-15" [ "2026-01-15" ];
  missing ~cadence:12 "leap" "2025-01-01" "2025-02-29" "2025-02-28" [ "2025-02-28" ];
  let retained_resolution =
    let prompt =
      preview_horizon (editor ~cadence:1 ~observed:"2026-01-31" (open_plan "month-end"))
    in
    publish (preview_horizon (tap (resolve prompt "2026-02-30" "2026-02-28") `Escape))
  in
  require (days (fst retained_resolution) = [ "2026-02-28" ]) "e-preview-escape-retains-resolution";
  let prompt = preview_horizon (editor ~cadence:1 ~observed:"2026-01-31" (open_plan "month-end")) in
  (match
     S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 24) ~width_of prompt
       (key `Escape)
   with
  | S.Closed -> ()
  | _ -> raise (F.Refused "e-missing-escape-cancels-generation"));

  (* A custom limit typed before a missing-day prompt survives Preview Esc:
     Enter re-validates it without retyping or losing the resolution. *)
  let custom_missing =
    let t =
      custom_enter
        (custom (editor ~cadence:1 ~observed:"2026-01-31" (open_plan "month-end")))
        "2026-03-01"
    in
    let t = resolve t "2026-02-30" "2026-02-28" in
    let t = tap (preview_horizon (tap t `Escape)) `Enter in
    publish t
  in
  require
    (days (fst custom_missing) = [ "2026-02-28" ])
    "e-custom-limit-survives-missing-date-and-preview-escape";

  (* 12. Old source: past candidates are omitted, observation day is inclusive. *)
  let old_source id limit =
    let t = custom_enter (custom (editor ~cadence:1 ~observed:"2026-10-20" (open_plan id))) limit in
    days (fst (publish t))
  in
  require (old_source "old-19" "2026-12-01" = [ "2026-11-19" ]) "e-old-source-skips-past";
  require
    (old_source "old-20" "2026-12-01" = [ "2026-10-20"; "2026-11-20" ])
    "e-observed-day-inclusive";
  let past_preset = preview_horizon (next ~observed:"2026-10-20" (open_plan "old-20")) in
  (match
     S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 24) ~width_of past_preset
       (key `Escape)
   with
  | S.Closed -> ()
  | _ -> raise (F.Refused "e-expired-preset-does-not-open-preview-or-reanchor"));

  (* 13. Hidden preview safety: blocked, tiny, review-to-end. *)
  let blocked =
    match
      S.handle ~new_id:Daily_file.new_id ~blocked:true ~dimensions:(80, 24) ~width_of
        (tap (preview_horizon (next source)) `Tab)
        (key `Enter)
    with
    | S.Updated t -> t
    | _ -> raise (F.Refused "e-blocked-must-retain-drafts")
  in
  let blocked_pub =
    match
      S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 24) ~width_of
        (press blocked `End) (key `Enter)
    with
    | S.Publish (plans, _) -> plans
    | _ -> raise (F.Refused "e-blocked-retained-then-published")
  in
  require (days blocked_pub = [ "2026-11-15" ]) "e-blocked-drafts-retained";
  let big = custom_enter (custom (editor ~cadence:1 ~observed:"2026-10-21" source)) "2028-02-01" in
  let to_publish = tap big `Tab in
  let tiny =
    match
      S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(32, 9) ~width_of to_publish
        (key `Enter)
    with
    | S.Updated t -> t
    | _ -> raise (F.Refused "e-tiny-must-not-publish")
  in
  (match
     S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(32, 9) ~width_of tiny
       (key `Enter)
   with
  | S.Updated _ -> ()
  | _ -> raise (F.Refused "e-tiny-stays-open"));
  let unreviewed = press ~dims:(80, 16) to_publish `Home in
  let unreviewed =
    match
      S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 16) ~width_of unreviewed
        (key `Enter)
    with
    | S.Updated t -> t
    | _ -> raise (F.Refused "e-review-gate-must-refuse")
  in
  let ended = press ~dims:(80, 16) unreviewed `End in
  (match
     S.handle ~new_id:Daily_file.new_id ~blocked:false ~dimensions:(80, 16) ~width_of ended
       (key `Enter)
   with
  | S.Publish (plans, _) ->
      require
        (List.length plans = 15
        && (List.hd plans).day = "2026-11-15"
        && (List.nth plans 14).day = "2028-01-15")
        "e-end-gate-publishes-all-explicit-dates"
  | _ -> raise (F.Refused "e-end-gate-must-publish"));

  (* 14. Exact huge quantities survive an atomic cold commit; stale base refuses. *)
  let huge_pub =
    let plans, captured = publish (preview_horizon (next ~observed:"2026-10-21" huge_plan)) in
    require (days plans = [ "2026-11-15" ]) "e-huge-exact-date";
    require
      (List.for_all
         (fun (p : B.plan) ->
           p.measure = "jpy" && p.changes = huge_plan.changes && p.paid_by = None
           && p.cancelled_on = None)
         plans)
      "e-huge-exact-quanta";
    (plans, captured)
  in
  let e_path = directory ^ "/e-atomic.sexp" in
  F.write_new e_path base2;
  let sess = F.load e_path in
  (match A.commit_plan_batch ~replace:false ~session:sess ~base_revision:rev2 (fst huge_pub) with
  | A.Published _ -> ()
  | _ -> raise (F.Refused "e-atomic-cold-commit-failed"));
  let cold = F.load e_path in
  let cold_plan = List.find (fun (p : B.plan) -> p.day = "2026-11-15") (B.plans cold.book) in
  require
    (cold_plan.changes = huge_plan.changes
    && cold_plan.measure = "jpy" && cold_plan.paid_by = None && cold_plan.cancelled_on = None
    && B.entry_count cold.book = 0)
    "e-atomic-cold-exact-huge-quanta";
  let fresh = publish (preview_horizon (next ~observed:"2026-10-21" huge_plan)) in
  let changed_book =
    get (B.put_plan cold.book ~replace:false (plan "outside" "2026-10-16" "eur" (Z.of_int 1)))
  in
  let tmp = e_path ^ ".tmp" in
  F.write_new tmp (Bakhlo_sexp.Daily_txt.text changed_book);
  Unix.rename tmp e_path;
  let stale_sess = F.load e_path in
  require
    (match
       A.commit_plan_batch ~replace:false ~session:stale_sess ~base_revision:rev2 (fst fresh)
     with
    | A.Conflict_base_changed -> true
    | _ -> false)
    "e-stale-batch-refused";
  let after = F.load e_path in
  require
    (not (List.exists (fun (p : B.plan) -> p.id = (List.hd (fst fresh)).id) (B.plans after.book)))
    "e-stale-batch-writes-nothing";

  print_endline
    "PASS: Scheduled generation proposes explicit dates, preserves exact quanta, validates \
     boundaries, enforces Cancel default, end/tiny gates, stale reload refusal and atomic cold \
     commit."
