module B = Bakhlo_sexp.Daily_book
module F = Daily_file
module A = Daily_actions
module S = Scheduled_generation_session
module C = Daily_interaction_state
module H = Daily_interaction

let require = F.require
let get = function Ok x -> x | Error why -> raise (F.Refused why)
let key button = `Key (button, [])
let text s = List.init (String.length s) (fun i -> `Key (`ASCII s.[i], []))

let step ~width_of ~dims s input =
  match S.handle ~blocked:false ~dimensions:dims ~width_of s input with
  | S.Updated s -> s
  | S.Closed -> raise (F.Refused "generate-session-closed")
  | S.Publish _ -> raise (F.Refused "unexpected-generate-publish")

let fixture =
  "(bakhlo-daily 3)\n(scope corrected-entries explicit-plans)\n\
   (measures (measure \"jpy\" 0) (measure \"eur\" 2))\n\
   (labels (provided (label \"cash\" \"Cash\" \"Synthetic\") (label \"food\" \"Food\" \"Synthetic\")))\n\
   (approved-loci (provided \"cash\" \"food\"))\n(entries)\n(plans)\n\
   (support (zero-origin (\"food\" \"jpy\") (\"food\" \"eur\")) (openings)\n\
   (observations (observation (reflected) (quantities (\"cash\" \"jpy\" 1000) (\"cash\" \"eur\" 10000))))\n\
   (presence (not-supplied)))\n"

let plan id day measure cents : B.plan =
  { id; day; measure; changes = ["cash", Z.neg cents; "food", cents]; paid_by = None; cancelled_on = None }

let self_check ~width_of () =
  let directory = "scratch/scheduled-generate-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let book = get (B.of_string fixture) in
  let source = plan "source-plan" "2026-10-15" "eur" (Z.of_int 5000) in
  let book = get (B.put_plan book ~replace:false source) in
  let base = B.to_string book in
  let path = directory ^ "/controller.sexp" in
  F.write_new path base;

  (* 1. Controller integration *)
  let state = C.initial ~config_home:directory (F.load path)
    |> fun s -> C.open_route s Ui_workspace.Scheduled
    |> fun s -> C.sync { s with workspace = Ui_workspace.set_query s.workspace source.id } in
  let opened = C.extend_plan_selected state in
  require (match opened.C.overlay with C.Scheduled_generate _ -> true | _ -> false)
    "controller-extend_plan_selected-opens-generate";
  let opened_by_key = Option.get (H.handle ~dimensions:(140, 40) ~width_of state (key (`ASCII 'g'))) in
  require (match opened_by_key.C.overlay with C.Scheduled_generate _ -> true | _ -> false)
    "controller-key-g-opens-generate";
  let ckey state button = Option.get (H.handle ~dimensions:(140, 40) ~width_of state (key button)) in
  let cstep state event = Option.get (H.handle ~dimensions:(140, 40) ~width_of state event) in

  (* Cancel in parameters closes overlay without write *)
  let cancelled = ckey opened `Escape in
  require (cancelled.overlay = C.No_overlay && F.read path = base)
    "controller-generate-cancel-leaves-disk-unchanged";

  (* 2. Terminal source refusal *)
  let closed_source = { source with paid_by = Some "entry-1" } in
  require (Result.is_error (S.create ~book ~base_bytes:base ~source:closed_source))
    "terminal-source-rejected-by-create";

  (* 3. Session creation & parameter boundaries *)
  let s = get (S.create ~book ~base_bytes:base ~source) in
  require (S.base_bytes s = base) "captured-base-bytes";

  (* Screen resize bounds at various dimensions *)
  List.iter (fun dims ->
    let rows = S.screen ~dimensions:dims ~width_of s in
    require (List.length rows <= max 0 (snd dims)) "generate-screen-height")
    [0, 0; 1, 1; 32, 9; 48, 14; 80, 24; 120, 36];

  (* Clear through date and enter invalid date *)
  let clear s = List.fold_left (step ~width_of ~dims:(80, 24)) s
      (List.init 12 (fun _ -> key `Backspace)) in
  let bad_date = clear s |> fun s -> List.fold_left (step ~width_of ~dims:(80, 24)) s (text "2026-02-30") in
  let bad_date = step ~width_of ~dims:(80, 24) bad_date (key `Enter) in
  (match bad_date with
   | s when S.screen ~dimensions:(80, 24) ~width_of s
            |> List.exists (fun (_, l) -> Base.String.is_substring l ~substring:"real Gregorian date") -> ()
   | _ -> raise (F.Refused "invalid-date-notice-expected"));

  (* Through date earlier than source date *)
  let early = clear s |> fun s -> List.fold_left (step ~width_of ~dims:(80, 24)) s (text "2026-09-01") in
  let early = step ~width_of ~dims:(80, 24) early (key `Enter) in
  (match early with
   | s when S.screen ~dimensions:(80, 24) ~width_of s
            |> List.exists (fun (_, l) -> Base.String.is_substring l ~substring:"strictly later than source date") -> ()
   | _ -> raise (F.Refused "early-date-notice-expected"));

  (* Through date too close (no occurrences) *)
  let too_close = clear s |> fun s -> List.fold_left (step ~width_of ~dims:(80, 24)) s (text "2026-10-20") in
  let too_close = step ~width_of ~dims:(80, 24) too_close (key `Enter) in
  (match too_close with
   | s when S.screen ~dimensions:(80, 24) ~width_of s
            |> List.exists (fun (_, l) -> Base.String.is_substring l ~substring:"No occurrences generated") -> ()
   | _ -> raise (F.Refused "no-occurrences-notice-expected"));

  (* 4. Valid generation preview and protective default *)
  let valid = clear s |> fun s -> List.fold_left (step ~width_of ~dims:(80, 24)) s (text "2028-02-15") in
  let preview = step ~width_of ~dims:(80, 24) valid (key `Enter) in
  (* Default action is Cancel: Enter closes session *)
  (match S.handle ~blocked:false ~dimensions:(80, 24) ~width_of preview (key `Enter) with
   | S.Closed -> ()
   | _ -> raise (F.Refused "default-action-must-be-cancel"));

  (* Escape in preview returns to parameter form *)
  let back = step ~width_of ~dims:(80, 24) preview (key `Escape) in
  let back_rows = S.screen ~dimensions:(80, 24) ~width_of back in
  require (List.exists (fun (_, l) -> Base.String.is_substring l ~substring:"Cadence") back_rows)
    "escape-in-preview-returns-to-form";

  (* 5. Gate checks before publish *)
  let preview = step ~width_of ~dims:(80, 24) back (key `Enter) in
  (* Switch to Publish all: Tab *)
  let to_publish = step ~width_of ~dims:(80, 24) preview (key `Tab) in
  (* Dimension gate: width < 46 refuses *)
  let tiny_refused = step ~width_of ~dims:(32, 9) to_publish (key `Enter) in
  require (List.exists (fun (_, l) -> Base.String.is_substring l ~substring:"Enlarge terminal")
             (S.screen ~dimensions:(32, 9) ~width_of tiny_refused))
    "tiny-terminal-refuses-publish";

  (* Review to end gate: Home then Enter without End refuses at height 16 where rows (19) > capacity (14) *)
  let unreviewed = step ~width_of ~dims:(80, 16) to_publish (key `Home) in
  let unreviewed = step ~width_of ~dims:(80, 16) unreviewed (key `Enter) in
  require (List.exists (fun (_, l) -> Base.String.is_substring l ~substring:"Review to the end")
             (S.screen ~dimensions:(80, 16) ~width_of unreviewed))
    "unreviewed-refuses-publish";

  (* Scroll to End and publish successfully *)
  let ended = step ~width_of ~dims:(80, 16) to_publish (key `End) in
  (match S.handle ~blocked:false ~dimensions:(80, 16) ~width_of ended (key `Enter) with
   | S.Publish (plans, captured) ->
       require (captured = base) "captured-base-matches";
       (* Monthly from 2026-10-15 through 2028-02-15 exclusive: 15 occurrences *)
       require (List.length plans = 15) "generated-occurrence-count";
       require ((List.hd plans).day = "2026-11-15" && (List.nth plans 14).day = "2028-01-15")
         "generated-occurrence-dates";
       require (List.for_all (fun (p : B.plan) -> p.measure = "eur" && p.changes = source.changes) plans)
         "generated-occurrence-exact-changes";

       (* Commit via A.commit_plan_batch *)
       let book_path = directory ^ "/book.sexp" in
       F.write_new book_path base;
       let sess = F.load book_path in
       (match A.commit_plan_batch ~replace:false ~session:sess ~base_bytes:captured plans with
        | A.Published _ -> ()
        | _ -> raise (F.Refused "atomic-commit-failed"));

       (* Cold restart readback proves all plans are present on disk *)
       let cold = F.load book_path in
       require (B.entry_count cold.book = 0) "entries-untouched";
       require (List.length (B.plans cold.book) = 16) "plans-count-is-sixteen";
       List.iter (fun (p : B.plan) ->
         let found = List.find (fun (cp : B.plan) -> cp.id = p.id) (B.plans cold.book) in
         require (found.day = p.day && found.measure = p.measure && found.changes = p.changes
                  && found.paid_by = None && found.cancelled_on = None)
           "cold-reloaded-plan-attributes-exact") plans;
   | _ -> raise (F.Refused "valid-publish-failed"));

  (* 6. Controller end-to-end publish *)
  let cclear s = List.fold_left cstep s (List.init 12 (fun _ -> key `Backspace)) in
  let controller_run = cclear opened |> fun s -> List.fold_left cstep s (text "2027-01-01") in
  let controller_preview = ckey controller_run `Enter in
  let controller_to_publish = ckey controller_preview `Tab in
  let controller_ended = ckey controller_to_publish `End in
  let published_state = ckey controller_ended `Enter in
  let cold_controller = F.load path in
  require (published_state.overlay = C.No_overlay
           && List.length (B.plans cold_controller.book) = 3) (* source + 2026-11-15 + 2026-12-15 *)
    "controller-publishes-all-generated-plans-atomically";

  (* 7. Stale base protection on reload *)
  let stale = C.reload controller_run |> fun s -> ckey s `Enter in
  require (stale.blocked && F.read path = cold_controller.bytes
           && match stale.overlay with C.Scheduled_generate editor -> S.base_bytes editor = base | _ -> false)
    "controller-reload-cannot-bless-stale-generation";

  (* 8. Held record draft prevents extend *)
  let held = C.open_record state |> fun s -> ckey s (`ASCII 'x') |> fun s -> ckey s `Escape in
  let refused = C.extend_plan_selected held in
  require (C.has_record_draft held && refused.record = held.record
           && refused.overlay = C.No_overlay && F.read path = cold_controller.bytes)
    "controller-held-record-prevents-extend";

  print_endline "PASS: Scheduled generation proposes explicit dates, preserves exact quanta, validates boundaries, enforces Cancel default, end/tiny gates, stale reload refusal and atomic cold commit."
