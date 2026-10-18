(* Input dispatch; state transitions and painting have separate owners. *)
open Daily_interaction_state
open Daily_interaction_context

let handle ?(dimensions = (80, 24)) ?(width_of = String.length) state (input : input) =
  let state =
    if is_record_browser state && not state.record_visible then
      let _, view = browser_viewport ~dimensions ~width_of state in
      { state with scroll = view.start }
    else state in
  if state.paste_blocked then
    match input with
    | `Paste `End ->
        Some
          {
            state with
            paste_blocked = false;
            message =
              (if state.blocked then state.message
               else tr "Paste ignored outside Record input; no commands were run.");
          }
    | `End -> None
    | _ -> Some state
  else if input = `Paste `Start && ((not state.record_visible) || Option.is_none state.record) then
    Some { state with paste_blocked = true }
  else if state.record_visible then
    match state.record with
    | None -> Some { state with record_visible = false }
    | Some record -> (
        match
          S.handle ~book:state.session.book ~base_bytes:state.session.bytes ~blocked:state.blocked
            ~dimensions:(record_dimensions ~dimensions ~width_of state)
            ~width_of record input
        with
        | S.Updated record -> Some { state with record = Some record }
        | S.Closed record -> Some { state with record = Some record; record_visible = false }
        | S.Publish (payload, base_bytes, record) ->
            let draft = { state with record = Some record } in
            Some
              (if state.blocked then draft
               else
                 apply_commit_result state ~draft
                   (A.commit_payload ~session:state.session ~base_bytes payload)))
  else
    match state.overlay with
    | Scheduled_bulk editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [`Ctrl]) -> Some (reload state)
        | _ -> (
            match Bulk.handle ~blocked:state.blocked
              ~dimensions:(bulk_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Bulk.Updated editor -> Some { state with overlay = Scheduled_bulk editor }
            | Bulk.Closed -> Some { state with overlay = No_overlay }
            | Bulk.Publish (plans, base_bytes) ->
                let draft = { state with overlay = Scheduled_bulk
                  (Bulk.with_publish_error editor "Batch publication not confirmed. Review the notice below.") } in
                Some (apply_commit_result state ~draft
                  (A.commit_plan_batch ~session:state.session ~base_bytes plans))))
    | Scheduled_generate editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [`Ctrl]) -> Some (reload state)
        | _ -> (
            match Gen.handle ~blocked:state.blocked
              ~dimensions:(generate_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Gen.Updated editor -> Some { state with overlay = Scheduled_generate editor }
            | Gen.Closed -> Some { state with overlay = No_overlay }
            | Gen.Publish (plans, base_bytes) ->
                let draft = { state with overlay = Scheduled_generate
                  (Gen.with_publish_error editor "Generation publication not confirmed. Review the notice below.") } in
                Some (apply_commit_result state ~draft
                  (A.commit_plan_batch ~replace:false ~session:state.session ~base_bytes plans))))
    | Scheduled_continuation prompt -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            let updated message =
              { state with overlay = Scheduled_continuation (Cont.with_notice prompt message) } in
            match Cont.handle ~dimensions:(continuation_dimensions ~dimensions ~width_of state) ~width_of prompt input with
            | Cont.Updated prompt -> Some { state with overlay = Scheduled_continuation prompt }
            | Cont.Closed candidate ->
                Some { state with overlay = No_overlay;
                  message = (if state.blocked then state.message else
                    match candidate with
                    | None -> "Completion retained. No additional Scheduled created."
                    | Some p -> "Completion retained. Kept later Scheduled " ^ O.visible p.id ^
                        "; no additional Scheduled created.") }
            | Cont.Add source ->
                if state.blocked then Some (updated "Writes stopped; completion remains published.")
                else (match Sch.create_from_scheduled ~book:state.session.book source with
                  | Ok editor -> Some { state with overlay = Scheduled_create editor;
                      message = "Completion remains published; adding an independent Scheduled." }
                  | Error why -> Some (updated why))
            | Cont.Defer source ->
                if state.blocked then Some (updated "Writes stopped; completion remains published.")
                else
                  let result = Result.bind state.attention (fun expected ->
                    let id = Att.next_id expected in
                    let context = "Decide continuation after " ^ source.id ^ " (scheduled " ^ source.day ^ "): " ^
                      String.concat "; " (List.map (fun (locus, amount) ->
                        locus ^ " " ^ B.format state.session.book source.measure amount ^ " " ^ source.measure) source.changes) in
                    Result.bind (Att.add_item expected ~id ~context ~due:Att.Due_undetermined) (fun attention ->
                      Result.map (fun () -> attention, id) (Att.save_file state.attention_path ~expected attention))) in
                  (match result with
                   | Ok (attention, id) -> Some { state with overlay = No_overlay; attention = Ok attention;
                       message = "Completion retained. Deferred continuation as " ^ id ^ "; no additional Scheduled created." }
                   | Error why -> Some { (updated "Defer not confirmed; reload to inspect before retrying.") with
                       message = "Completion remains published. Defer not confirmed: " ^ why })))
    | Scheduled_cancel editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            match Cancel.handle ~blocked:state.blocked
              ~dimensions:(cancellation_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Cancel.Updated editor -> Some { state with overlay = Scheduled_cancel editor }
            | Cancel.Closed -> Some { state with overlay = No_overlay }
            | Cancel.Publish (id, day, base_bytes) ->
                let draft = { state with overlay = Scheduled_cancel (Cancel.with_publish_error editor) } in
                Some (apply_commit_result state ~draft
                  (A.commit_cancel_plan ~session:state.session ~base_bytes ~id ~day))))
    | Date_correction editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            match Date.handle ~blocked:state.blocked
              ~dimensions:(date_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Date.Updated editor -> Some { state with overlay = Date_correction editor }
            | Date.Closed -> Some { state with overlay = No_overlay }
            | Date.Publish (tx, base_bytes) ->
                let draft = { state with overlay = Date_correction (Date.edit editor) } in
                Some (apply_commit_result state ~draft
                  (A.commit_transaction ~session:state.session ~base_bytes tx))))
    | Event_merchant editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            match Merchant.handle ~blocked:state.blocked
              ~dimensions:(merchant_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Merchant.Updated editor -> Some { state with overlay = Event_merchant editor }
            | Merchant.Closed -> Some { state with overlay = No_overlay; message = tr "Merchant classification cancelled." }
            | Merchant.Publish (target_id, disposition, base_bytes) ->
                let draft = { state with overlay = Event_merchant (Merchant.edit editor) } in
                let disp_text =
                  match disposition with
                  | Bakhlo_application.Event_merchants.Nonmerchant -> "Nonmerchant"
                  | Merchant p -> "Merchant " ^ D.Identifier.External_party.to_string p
                in
                let pub_msg = Printf.sprintf "Published %s for %s." disp_text target_id in
                Some (apply_commit_result ~published_message:pub_msg state ~draft
                  (A.commit_classify_merchant ~session:state.session ~base_bytes ~id:target_id ~disposition))))
    | Reversal editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            match Rev.handle ~blocked:state.blocked
              ~dimensions:(reversal_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Rev.Updated editor -> Some { state with overlay = Reversal editor }
            | Rev.Closed -> Some { state with overlay = No_overlay }
            | Rev.Publish (id, day, base_bytes) ->
                let draft = { state with overlay = Reversal (Rev.with_publish_error editor) } in
                Some (apply_commit_result state ~draft
                  (A.commit_reverse_entry ~session:state.session ~base_bytes ~id ~day))))
    | Scheduled_create editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            let dim = scheduled_dimensions ~dimensions ~width_of state in
            match Sch.handle ~blocked:state.blocked ~dimensions:dim ~width_of editor input with
            | Sch.Updated editor -> Some { state with overlay = Scheduled_create editor }
            | Sch.Closed -> Some { state with overlay = No_overlay }
            | Sch.Publish draft ->
                let plan =
                  {
                    B.id = Daily_actions.F.new_id ();
                    day = draft.Sch.scheduled_on;
                    measure = draft.Sch.measure;
                    changes = draft.Sch.changes;
                    paid_by = None;
                    cancelled_on = None;
                  }
                in
                let draft_state =
                  { state with overlay = Scheduled_create (Sch.with_publish_error editor "Publish failed.") }
                in
                Some
                  (if state.blocked then draft_state
                   else
                     apply_commit_result state ~draft:draft_state
                       (A.commit_payload ~session:state.session ~base_bytes:state.session.bytes
                          (A.Plan_tx { plan; replace = false })))))
    | Commands menu -> (
        match M.handle menu input with
        | M.Updated menu -> Some { state with overlay = Commands menu }
        | M.Closed -> Some { state with overlay = No_overlay }
        | M.Chosen action -> Some (open_command state action))
    | Themes { selected; original; return_menu } -> (
        let count = List.length P.all_themes in
        match input with
        | `Key ((`Escape | `ASCII 'q'), []) ->
            Some
              { state with theme = original; overlay = Commands return_menu }
        | `Key ((`Arrow `Up | `Arrow `Left | `ASCII 'k'), [])
        | `Key ((`Arrow `Down | `Arrow `Right | `ASCII 'j'), []) ->
            let delta =
              match input with `Key ((`Arrow `Up | `Arrow `Left | `ASCII 'k'), []) -> -1 | _ -> 1
            in
            let selected = max 0 (min (count - 1) (selected + delta)) in
            Some
              {
                state with
                theme = List.nth P.all_themes selected;
                overlay = Themes { selected; original; return_menu };
              }
        | `Key (`Enter, []) ->
            let notice =
              match P.save_theme ?config_home:state.config_home state.theme with
              | Ok () -> tr "Theme saved."
              | Error _ -> tr "Theme changed for this session only; settings could not be saved."
            in
            Some { state with overlay = No_overlay; ui_notice = Some notice }
        | _ -> Some state)
    | Jump value -> (
        match input with
        | `Key (`Escape, []) -> Some { state with overlay = No_overlay }
        | `Key (`Enter, []) ->
            Some (update_calendar { state with overlay = No_overlay } (Cal.Jump value))
        | _ ->
            Some
              (match input_text value input with
              | None -> state
              | Some value -> { state with overlay = Jump value }))
    | Search value -> (
        match input with
        | `Key (`Escape, []) ->
            Some
              (sync { state with overlay = No_overlay; workspace = W.set_query state.workspace "" })
        | `Key (`Enter, []) ->
            Some
              (sync
                 { state with overlay = No_overlay; workspace = W.set_query state.workspace value })
        | _ ->
            Some
              (match input_text value input with
              | None -> state
              | Some value ->
                  if state.workspace.route = W.Actual then
                    sync { state with overlay = Search value;
                      workspace = W.set_query state.workspace value }
                  else { state with overlay = Search value }))
    | Modal_form form -> (
        let result =
          match Form.id form, input with
          | "observe_preview", `Key (`ASCII ('e' | 'E'), []) -> Form.Cancel
          | "observe_preview", `Key (`Tab, mods)
              when mods = [] || mods = [`Shift] ->
              Form.handle_input form (`Key (`Arrow (if mods = [] then `Right else `Left), []))
          | "observe_quantity", `Key (`Tab, mods) when mods = [] || mods = [`Shift] ->
              let action = Form.find_field_index form "action" in
              let position = if Form.focused form = action then
                  action + Option.value ~default:0 (Form.get_button form "action")
                else Form.focused form in
              let next = (position + (if mods = [] then 1 else 5)) mod 6 in
              let form = Form.set_focused form (min action next) in
              let form = Form.update_field form "action" (function
                | Form.Buttons buttons -> Form.Buttons { buttons with selected = max 0 (next - action) }
                | field -> field) in
              Form.Updated form
          | _, `Key (`ASCII ('r' | 'R'), [`Ctrl]) -> Form.Updated form
          | _ -> Form.handle_input form input in
        match result with
        | Form.Cancel ->
            let observe_edit =
              Form.id form = "observe_preview"
              && (input = `Key (`ASCII 'e', []) || input = `Key (`ASCII 'E', [])
                  || (input = `Key (`Enter, []) && Form.get_button form "action" = Some 1)) in
            if observe_edit then
              Some (match state.observe_draft with
                | Some draft -> edit_observe state draft
                | None -> { state with overlay = No_overlay })
            else if Form.id form = "observe_quantity" || Form.id form = "observe_preview" then
              Some { state with overlay = No_overlay; observe_draft = None }
            else
            (match state.label_review, state.exchange_review with
             | Some (editing, _, _, _), _ when Form.id form = "review_locus_label" ->
                 Some { state with overlay = Modal_form editing; label_review = None }
             | _, Some (editing, _, _) when Form.id form = "review_exchange" ->
                 Some { state with overlay = Modal_form editing; exchange_review = None }
             | _ -> Some { state with overlay = No_overlay; label_review = None; exchange_review = None })
        | Form.Updated _ when input = `Key (`ASCII 'r', [`Ctrl])
                              || input = `Key (`ASCII 'R', [`Ctrl]) ->
            Some (reload state)
        | Form.Updated updated -> Some { state with overlay = Modal_form updated }
        | Form.Submit submitted -> (
            match Form.id submitted with
            | "balance_print_refused" -> Some { state with overlay = No_overlay }
            | "annual_rollover" ->
                let body_w, body_h = body_dimensions ~dimensions ~width_of state in
                let pane_w = min 64 (max 8 (body_w - 4)) in
                let rows = Form.render_rows ~width:(max 0 (pane_w - 6)) ~height:10000 ~width_of submitted in
                if pane_w < 48 || List.length rows + 4 > body_h then
                  let reset = Form.update_field submitted "decision" (function
                    | Form.Buttons buttons -> Form.Buttons { buttons with selected = 0 }
                    | other -> other) in
                  Some { state with overlay = Modal_form (Form.set_notice reset
                      "Enlarge the terminal to review both paths before creating a year.") }
                else if state.blocked || has_record_draft state
                     || Form.payload submitted <> state.session.bytes then
                  Some { state with overlay = No_overlay;
                    message = "Annual review expired or a draft/recovery is held. Reopen the review." }
                else
                  (try
                     let session = F.rollover ~session:state.session in
                     Some { (initial ?config_home:state.config_home session) with
                       message = "Next annual book created and verified from disk. Prior year is read-only." }
                   with
                   | F.Refused why ->
                       Some { state with overlay = No_overlay; message = "Annual rollover refused: " ^ why }
                   | Unix.Unix_error _ | Sys_error _ ->
                       Some { state with overlay = No_overlay; blocked = true;
                         message = "Annual creation result is uncertain. Inspect both years; do not retry blindly." })
            | "discard_record" ->
                let width, height = body_dimensions ~dimensions ~width_of state in
                if width < 48 || height < 12 then
                  Some { (request_discard state) with
                    message = (if state.blocked then state.message
                      else tr "Enlarge the terminal to confirm draft discard.") }
                else Some (discard { state with overlay = No_overlay })
            | "add_attention" ->
                let context = Option.value ~default:"" (Form.get_text submitted "context") in
                let due_kind_idx = Option.value ~default:0 (Form.get_choice submitted "due_kind") in
                let due_date = Option.value ~default:"" (Form.get_text submitted "due_date") in
                if String.trim context = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter a short household matter description.")) }
                else
                  let due_res =
                    match due_kind_idx with
                    | 0 -> Ok Att.No_due_date
                    | 1 -> Ok Att.Due_undetermined
                    | 2 ->
                        (match A.normalize_date due_date with
                        | Error _ -> Error (tr "Invalid date (YYYY-MM-DD).")
                        | Ok canon_day ->
                            if not (A.is_valid_canonical_date canon_day) then
                              Error (tr "Enter a real calendar date in YYYY-MM-DD form.")
                            else Ok (Att.Due_on canon_day))
                    | _ -> Ok Att.No_due_date
                  in
                  (match due_res with
                  | Error notice ->
                      Some { state with overlay = Modal_form (Form.set_notice submitted notice) }
                  | Ok due ->
                      Some (commit_attention state submitted
                        (fun t -> Att.add_item t ~id:(Att.next_id t) ~context ~due)
                        "Attention added and read back."))
            | "resolve_attention" ->
                let item_id = Form.payload submitted in
                Some (commit_attention state submitted
                  (fun t -> Att.close_item t ~id:item_id ~known_on:(F.today ()) ~kind:Att.Resolved)
                  (Printf.sprintf "Resolved %s." item_id))
            | "drop_attention" ->
                let item_id = Form.payload submitted in
                Some (commit_attention state submitted
                  (fun t -> Att.close_item t ~id:item_id ~known_on:(F.today ()) ~kind:Att.Dropped)
                  (Printf.sprintf "Dropped %s." item_id))
            | "admit_locus" ->
                let token = Option.value ~default:"" (Form.get_text submitted "token") |> String.trim in
                let role_idx = Option.value ~default:0 (Form.get_choice submitted "role") in
                let role_opt = role_of_index role_idx in
                if token = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter the new Locus token.")) }
                else
                  let res = A.commit_add_locus ~session:state.session token in
                  (match res with
                  | A.Refused why ->
                      Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                  | A.Conflict | A.Conflict_base_changed ->
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "File changed on disk. Reload to inspect.")) }
                  | A.Published _ | A.Idempotent_duplicate _ ->
                      (match role_opt with
                      | Some r ->
                          let path = Roles.file_path ?config_home:state.config_home state.session.F.path in
                          let roles = Roles.load_file path in
                          let updated_roles = Roles.set_role roles token (Some r) in
                          let _ = Roles.save_file path updated_roles in
                          ()
                      | None -> ());
                      let next_state = { state with overlay = No_overlay; message = Printf.sprintf "Admitted locus %s." token } in
                      Some (apply_commit_result next_state ~draft:next_state res)
                  | _ ->
                      let next_state = { state with overlay = No_overlay; message = Printf.sprintf "Admitted locus %s." token } in
                      Some (apply_commit_result next_state ~draft:next_state res))
            | "set_locus_role" ->
                let locus = Form.payload submitted in
                let role_idx = Option.value ~default:0 (Form.get_choice submitted "role") in
                let role_opt = role_of_index role_idx in
                let path = Roles.file_path ?config_home:state.config_home state.session.F.path in
                let roles = Roles.load_file path in
                let updated_roles = Roles.set_role roles locus role_opt in
                (match Roles.save_file path updated_roles with
                | Error why ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                | Ok () ->
                    let role_str = match role_opt with None -> "None" | Some r -> Roles.role_label r in
                    Some { state with overlay = No_overlay; message = Printf.sprintf "Set accounting role for %s to %s." locus role_str })
            | "set_locus_label" ->
                let locus = Form.payload submitted in
                let label_val = Option.value ~default:"" (Form.get_text submitted "label") |> String.trim in
                let help_val = Option.value ~default:"" (Form.get_text submitted "help") |> String.trim in
                let valid_str s =
                  s <> "" && String.length s <= 80
                  && String.for_all (fun c -> Char.code c >= 32 && Char.code c <> 127) s
                in
                if not (valid_str label_val) then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Display name must be 1-80 characters without control characters.")) }
                else
                  let existing_help = B.help state.session.book locus in
                  let resolved_help =
                    if help_val <> "" then help_val
                    else if existing_help <> "" then existing_help
                    else label_val
                  in
                  if not (valid_str resolved_help) then
                    Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Help description must be 1-80 characters without control characters.")) }
                  else
                    Some { state with overlay = Modal_form (review_locus_label locus label_val resolved_help);
                                      label_review = Some (submitted, locus, label_val, resolved_help) }
            | "review_locus_label" ->
                (match state.label_review with
                 | None -> Some { state with overlay = No_overlay; message = tr "Locus label review expired; reopen setup." }
                 | Some (_editing, locus, label_val, help_val) ->
                     let body_w, body_h = body_dimensions ~dimensions ~width_of state in
                     let pane_w = min 64 (max 8 (body_w - 4)) in
                     let rows = Form.render_rows ~width:(max 0 (pane_w - 6)) ~height:10000 ~width_of submitted in
                     if pane_w < 48 || List.length rows + 2 > body_h then
                       Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enlarge the terminal to review locus label before saving.")) }
                     else
                       let res = A.commit_set_locus_label ~session:state.session ~base_bytes:state.session.bytes ~id:locus ~label:label_val ~help:help_val () in
                       (match res with
                        | A.Refused why ->
                            Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                        | A.Conflict | A.Conflict_base_changed ->
                            Some { state with overlay = Modal_form (Form.set_notice submitted (tr "File changed on disk. Reload to inspect.")) }
                        | A.Published _ | A.Idempotent_duplicate _ | _ ->
                            let next_state = { state with overlay = No_overlay; label_review = None; message = Printf.sprintf "Saved display name for %s." locus } in
                            Some (apply_commit_result next_state ~draft:next_state res)))
            | "exchange" ->
                let date_str = Option.value ~default:"" (Form.get_text submitted "date") |> String.trim in
                let memo_str = Option.value ~default:"" (Form.get_text submitted "memo") |> String.trim in
                let src_locus = Option.value ~default:"" (Form.get_text submitted "source_locus") |> String.trim in
                let src_measure = Option.value ~default:"" (Form.get_text submitted "source_measure") |> String.trim in
                let src_amount_str = Option.value ~default:"" (Form.get_text submitted "source_amount") |> String.trim in
                let dst_locus = Option.value ~default:"" (Form.get_text submitted "destination_locus") |> String.trim in
                let dst_measure = Option.value ~default:"" (Form.get_text submitted "destination_measure") |> String.trim in
                let dst_amount_str = Option.value ~default:"" (Form.get_text submitted "destination_amount") |> String.trim in
                let valid_token s =
                  s <> "" && not (String.contains s ' ') && not (String.contains s '\t')
                  && not (String.contains s '\n') && not (String.contains s '\r')
                in
                (match A.normalize_date date_str with
                | Error _ ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Invalid date (YYYY-MM-DD).")) }
                | Ok canon_day ->
                    if not (A.is_valid_canonical_date canon_day) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter a real calendar date in YYYY-MM-DD form.")) }
                    else if not (valid_token src_locus) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Source Locus must be a nonempty single-line token.")) }
                    else if not (valid_token dst_locus) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Destination Locus must be a nonempty single-line token.")) }
                    else if not (valid_token src_measure) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Source Measure must be a nonempty single-line token.")) }
                    else if not (valid_token dst_measure) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Destination Measure must be a nonempty single-line token.")) }
                    else if String.equal src_measure dst_measure then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Source and destination Measures must differ.")) }
                    else
                      (match B.parse_amount state.session.book src_measure src_amount_str with
                      | Error why ->
                          let msg =
                            if why = "non-positive-amount" then tr "Source amount must be positive."
                            else if why = "division-by-zero" then tr "Source amount divides by zero."
                            else if why = "indivisible-amount" then tr "Source result cannot fit the Measure scale."
                            else if why = "measure-scale-not-supplied" then
                              Printf.sprintf "Measure '%s' scale is not configured." src_measure
                            else tr "Source amount is invalid."
                          in
                          Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                      | Ok src_quanta ->
                          (match B.parse_amount state.session.book dst_measure dst_amount_str with
                          | Error why ->
                              let msg =
                                if why = "non-positive-amount" then tr "Destination amount must be positive."
                                else if why = "division-by-zero" then tr "Destination amount divides by zero."
                                else if why = "indivisible-amount" then tr "Destination result cannot fit the Measure scale."
                                else if why = "measure-scale-not-supplied" then
                                  Printf.sprintf "Measure '%s' scale is not configured." dst_measure
                                else tr "Destination amount is invalid."
                              in
                              Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                          | Ok dst_quanta ->
                              let approved = B.approved_loci state.session.book in
                              let unapproved =
                                match approved with
                                | None -> []
                                | Some ids ->
                                    let check loc = if not (List.mem loc ids) then [ loc ] else [] in
                                    check src_locus @ check dst_locus
                              in
                              if unapproved <> [] then
                                let msg = Printf.sprintf "Locus '%s' is not admitted." (String.concat ", " unapproved) in
                                Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                              else
                                let src_effect =
                                  D.Effect.create
                                    ~key:(Some (Result.get_ok (D.Identifier.Effect_key.of_string "exchange-source")))
                                    ~locus:(Result.get_ok (D.Identifier.Locus.of_string src_locus))
                                    ~measure:(Result.get_ok (D.Identifier.Measure.of_string src_measure))
                                    ~quantity:(D.Quantity.of_quanta (Z.neg src_quanta))
                                in
                                let dst_effect =
                                  D.Effect.create
                                    ~key:(Some (Result.get_ok (D.Identifier.Effect_key.of_string "exchange-destination")))
                                    ~locus:(Result.get_ok (D.Identifier.Locus.of_string dst_locus))
                                    ~measure:(Result.get_ok (D.Identifier.Measure.of_string dst_measure))
                                    ~quantity:(D.Quantity.of_quanta dst_quanta)
                                in
                                let memo = if memo_str = "" then None else Some memo_str in
                                let entry =
                                  {
                                    B.id = F.new_id ();
                                    day = canon_day;
                                    memo;
                                    effects = [ src_effect; dst_effect ];
                                    reversal_of = None;
                                    exchange = Some ("exchange-source", "exchange-destination");
                                    original_amount = None;
                                    merchant = None;
                                  }
                                in
                                let tx = { A.entry; replace = false; plan = None } in
                                let src_fmt = B.format state.session.book src_measure src_quanta in
                                let dst_fmt = B.format state.session.book dst_measure dst_quanta in
                                let rev_form = exchange_review_form ~canon_day ~memo ~src_locus ~src_measure ~src_quanta_str:src_fmt ~dst_locus ~dst_measure ~dst_quanta_str:dst_fmt in
                                Some { state with overlay = Modal_form rev_form;
                                                  exchange_review = Some (submitted, tx, state.session.bytes) })))
            | "review_exchange" ->
                (match state.exchange_review with
                 | None -> Some { state with overlay = No_overlay; message = tr "Exchange review expired; reopen." }
                 | Some (_editing, tx, base_bytes) ->
                     let body_w, body_h = body_dimensions ~dimensions ~width_of state in
                     let pane_w = min 64 (max 8 (body_w - 4)) in
                     let rows = Form.render_rows ~width:(max 0 (pane_w - 6)) ~height:10000 ~width_of submitted in
                     if pane_w < 48 || List.length rows + 2 > body_h then
                       Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enlarge the terminal to review the full exchange before publishing.")) }
                     else
                       let res = A.commit_transaction ~session:state.session ~base_bytes tx in
                       (match res with
                        | A.Refused why ->
                            Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                        | A.Conflict | A.Conflict_base_changed ->
                            Some { state with overlay = Modal_form (Form.set_notice submitted (tr "File changed on disk. Reload to inspect.")) }
                        | A.Published _ | A.Idempotent_duplicate _ | _ ->
                            let next_state = { state with overlay = No_overlay; exchange_review = None; message = tr "Exchange recorded." } in
                            Some (apply_commit_result next_state ~draft:next_state res)))
            | "add_settlement" ->
                let label_str = Option.value ~default:"" (Form.get_text submitted "label") |> String.trim in
                let debtor = Option.value ~default:"" (Form.get_text submitted "debtor") |> String.trim in
                let creditor = Option.value ~default:"" (Form.get_text submitted "creditor") |> String.trim in
                let measure = Option.value ~default:"" (Form.get_text submitted "measure") |> String.trim in
                let amount_str = Option.value ~default:"" (Form.get_text submitted "amount") |> String.trim in
                if debtor = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter debtor endpoint.")) }
                else if creditor = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter creditor endpoint.")) }
                else if measure = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter measure token.")) }
                else
                  (match B.parse_amount state.session.book measure amount_str with
                  | Error why ->
                      let msg =
                        if why = "non-positive-amount" then tr "Committed amount must be positive."
                        else if why = "division-by-zero" then tr "Amount divides by zero."
                        else if why = "indivisible-amount" then tr "Result cannot fit the Measure scale."
                        else if why = "measure-scale-not-supplied" then
                          Printf.sprintf "Measure '%s' scale is not configured." measure
                        else tr "Invalid amount."
                      in
                      Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                  | Ok committed ->
                      let label = if label_str = "" then None else Some label_str in
                      Some (commit_settlements state submitted
                        (fun t -> Stl.add_row t ~id:(Stl.next_id t) ?label ~debtor ~creditor ~measure ~committed ())
                        "Commitment added and read back."))
            | "action_settlement" ->
                let id = Form.payload submitted in
                let kind_idx = Option.value ~default:0 (Form.get_choice submitted "action_kind") in
                let amount_str = Option.value ~default:"" (Form.get_text submitted "amount") |> String.trim in
                (match Result.bind state.settlements (fun t ->
                   match Stl.find_row t id with Some r -> Ok r | None -> Error "Commitment not found.") with
                | Error why ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                | Ok r ->
                    if kind_idx = 2 then
                      Some (commit_settlements state submitted
                        (fun t -> Stl.retract_row t ~id)
                        (Printf.sprintf "Retracted commitment %s." id))
                    else
                      (match B.parse_amount state.session.book r.measure amount_str with
                      | Error why ->
                          let msg =
                            if why = "non-positive-amount" then tr "Amount must be positive."
                            else if why = "division-by-zero" then tr "Amount divides by zero."
                            else if why = "indivisible-amount" then tr "Result cannot fit the Measure scale."
                            else if why = "measure-scale-not-supplied" then
                              Printf.sprintf "Measure '%s' scale is not configured." r.measure
                            else tr "Invalid amount."
                          in
                          Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                      | Ok amount ->
                          let verb = if kind_idx = 0 then "Settled" else "Reduced" in
                          Some (commit_settlements state submitted
                            (fun t -> if kind_idx = 0 then Stl.settle_row t ~id ~amount
                              else Stl.reduce_row t ~id ~amount)
                            (Printf.sprintf "%s %s on %s." verb (Z.to_string amount) id))))
        | "observe_quantity" ->
            let refused why = Some { state with overlay = Modal_form (Form.set_notice submitted why) } in
            (match state.observe_draft with
             | None -> refused "Observation session expired. Cancel and reopen."
             | Some draft ->
                 if Form.focused submitted = Form.find_field_index submitted "action"
                    && Form.get_button submitted "action" = Some 1 then
                   if draft.rows = [] then refused "Add at least one observed quantity before Preview."
                   else
                     let pending =
                       (Option.value ~default:"" (Form.get_text submitted "locus"),
                        Option.value ~default:"" (Form.get_text submitted "measure"),
                        Option.value ~default:"" (Form.get_text submitted "amount")) in
                     Some { state with observe_draft = Some { draft with pending };
                       overlay = Modal_form (observe_preview_form state draft.rows ~notice:"") }
                 else
                   let locus = String.trim (Option.value ~default:"" (Form.get_text submitted "locus")) in
                   let measure = String.lowercase_ascii (String.trim (Option.value ~default:"" (Form.get_text submitted "measure"))) in
                   let amount = String.trim (Option.value ~default:"" (Form.get_text submitted "amount")) in
                   if not (config_token locus && config_token measure) then
                     refused "Enter single-line Locus and Measure tokens."
                   else match B.parse_signed_amount state.session.book measure amount with
                   | Error why -> refused ("Invalid observed amount: " ^ why)
                   | Ok quantity ->
                       let rows = draft.rows @ [locus, measure, quantity] in
                       Some { state with observe_draft = Some
                           { draft with rows; pending = ("", measure, "") };
                         overlay = Modal_form (observe_quantity_form ~default_measure:measure ~rows state) })
        | "observe_preview" ->
            let refused ?(blocked = state.blocked) why =
              Some { state with blocked; overlay = Modal_form (Form.set_notice submitted why) } in
            (match state.observe_draft with
             | None -> refused "Observation session expired. Cancel and reopen."
             | Some draft ->
                 if state.blocked || draft.uncertain || draft.base_bytes <> state.session.bytes then
                   refused ~blocked:true "Observation stopped. Cancel and reload to inspect; do not retry this image."
                 else if not (review_fits ~dimensions ~width_of state submitted) then
                   refused "Enlarge the terminal to review every observation before publishing."
                 else
                   match B.observe_quantities state.session.book draft.rows with
                   | Error why -> refused ("Observation refused: " ^ why)
                   | Ok book ->
                       let outcome =
                         try F.publish state.session book
                         with F.Refused why -> F.Refused_input why in
                       (match outcome with
                        | F.Written session ->
                            Some (sync { state with session; overlay = No_overlay; observe_draft = None;
                              message = Printf.sprintf "Observed %d coordinates together." (List.length draft.rows) })
                        | F.Conflict -> refused ~blocked:true "File changed on disk. Draft retained; cancel and reload to inspect."
                        | F.Refused_input why -> refused ("Observation save refused: " ^ why)
                        | F.Uncertain ->
                            Some { state with blocked = true;
                              observe_draft = Some { draft with uncertain = true };
                              overlay = Modal_form (Form.set_notice submitted
                                "Observation save uncertain. Do not retry; reload to inspect.") }))
        | _ -> Some state))
    | No_overlay -> (
        let key = match input with `Key (key, mods) -> Some (key, mods) | _ -> None in
        let normalize (key, mods) =
          match key with `ASCII c -> (`ASCII (Char.lowercase_ascii c), mods) | _ -> (key, mods)
        in
        match Option.map normalize key with
        | Some (`ASCII 'q', [ `Ctrl ]) -> None
        | Some (`ASCII 'r', [ `Ctrl ]) -> Some (reload state)
        | Some (`ASCII 'n', [ `Ctrl ]) -> Some (request_discard state)
        | _ when state.workspace.route = W.Actual -> (
            match input with
            | `Key (`ASCII ' ', []) when not (Act.search_editing state.actual_workspace) ->
                Some { state with overlay = Commands M.initial }
            | `Key (`ASCII ('c' | 'C' | 'e' | 'E'), []) when not (Act.search_editing state.actual_workspace) ->
                Some (edit_selected state)
            | `Key (`ASCII ('x' | 'X'), []) when not (Act.search_editing state.actual_workspace) ->
                Some (reverse_entry_selected state)
            | `Key (`ASCII ('d' | 'D'), []) when not (Act.search_editing state.actual_workspace) ->
                Some (correct_date_selected state)
            | `Key (`ASCII ('m' | 'M'), []) when not (Act.search_editing state.actual_workspace) ->
                Some (classify_merchant_selected state)
            | _ ->
                let actual_dim = actual_dimensions ~dimensions ~width_of state in
                let next_ws, cmd =
                  Act.handle ~book:state.session.book ~dimensions:actual_dim ~width_of state.actual_workspace input
                in
                let state =
                  sync_actual_to_workspace
                    { state with actual_workspace = next_ws; message = Act.notice next_ws }
                in
                (match cmd with
                | Act.Stay -> Some state
                | Act.Open_selected entry ->
                    let drilled = open_route state (W.Selected_day entry.day) in
                    let browser = { drilled.workspace.selected_day with
                      selected_id = Some (W.Actual_row, entry.id);
                      query = ""; locus = None; day = None } in
                    let drilled = sync { drilled with workspace = W.update_browser drilled.workspace browser } in
                    Some { drilled with drill_parent = Some W.Actual; drill_book = Some state.session.book }
                | Act.Record_new -> Some (open_record state)
                | Act.Back -> Some (open_route state W.Home)
                | Act.Redraw -> Some state))
        | _ when state.workspace.route = W.Balances ->
            let balance_view_text = read_pace_config state "balance-view.tsv" in
            let owner =
              if Balances.selected state.balances_owner <> state.workspace.balance_selected then
                Balances.set_selected state.workspace.balance_selected state.balances_owner
              else state.balances_owner
            in
            let next_owner, cmd =
              Balances.handle
                ~blocked:state.blocked
                ~book:state.session.book
                ~measure:state.workspace.measure
                ~roles:(accounting_roles state)
                ~balance_view_text
                ~dimensions
                ~width_of
                owner
                input
            in
            let next_pane =
              match Balances.pane next_owner with
              | `List -> W.Calendar
              | `Detail -> W.Detail
            in
            let state =
              { state with
                balances_owner = next_owner;
                workspace =
                  { state.workspace with
                    balance_selected = Balances.selected next_owner;
                    pane = next_pane;
                  };
                message =
                  (if Balances.notice next_owner <> "" then
                     Balances.notice next_owner
                   else state.message);
              }
            in
            (match cmd with
            | Balances.Stay -> Some state
            | Balances.Back_to_home -> Some (open_route state W.Home)
            | Balances.Open_commands -> Some { state with overlay = Commands M.initial }
            | Balances.Cycle_measure direction ->
                let measures = List.map fst (B.measures state.session.book) in
                let next_measure =
                  match measures with
                  | [] -> state.workspace.measure
                  | ms ->
                      let rec next = function
                        | [] -> List.hd ms
                        | [ x ] -> List.hd ms
                        | x :: y :: _ when x = state.workspace.measure -> y
                        | _ :: rest -> next rest
                      in
                      let rec prev acc = function
                        | [] -> List.hd (List.rev ms)
                        | [ x ] when x = state.workspace.measure -> (match acc with None -> x | Some p -> p)
                        | x :: _ when x = state.workspace.measure -> (match acc with None -> List.hd (List.rev ms) | Some p -> p)
                        | x :: rest -> prev (Some x) rest
                      in
                      match direction with
                      | `Next -> next ms
                      | `Prev -> prev None ms
                in
                Some { state with workspace = { state.workspace with measure = next_measure } }
            | Balances.Observe { locus; measure; amount } ->
                let default_amount =
                  match amount with Some z -> Z.to_string z | None -> ""
                in
                let form = observe_quantity_form ~default_locus:locus ~default_measure:measure ?current_amount:(if default_amount = "" then None else Some default_amount) state in
                let form = Form.set_focused form (Form.find_field_index form "amount") in
                Some
                  {
                    state with
                    overlay = Modal_form form;
                    observe_draft =
                      Some
                        {
                          rows = [];
                          base_bytes = state.session.bytes;
                          pending = ("", state.workspace.measure, "");
                          uncertain = false;
                        };
                  }
            | Balances.Save_balance_view { expected; content } ->
                let admission =
                  try
                    let book = (F.reload state.session).book in
                    if B.approved_loci book = B.approved_loci state.session.book
                       && B.measures book = B.measures state.session.book then Ok ()
                    else Error "Admitted Loci or Measures changed; reopen setup."
                  with F.Refused why | Sys_error why -> Error why
                    | Unix.Unix_error (err, _, _) -> Error (Unix.error_message err) in
                let result = Result.bind admission (fun () ->
                  write_config_file state "balance-view.tsv" ~expected content) in
                (match result with
                | Ok () ->
                    let saved_owner = Balances.notify_saved next_owner in
                    Some
                      {
                        state with
                        balances_owner = saved_owner;
                        message = "Visible Balance accounts saved. Unknown values remain '?'.";
                      }
                | Error why ->
                    let failed_owner = Balances.notify_save_failed next_owner why in
                    Some { state with balances_owner = failed_owner })
            | Balances.Reload -> Some (reload state))
        | _ when state.workspace.route = W.Daily_pace ->
            let daily_pace_tsv = read_pace_config state "daily-pace.tsv" in
            let boundary_presets_tsv = read_pace_config state "boundary-presets.tsv" in
            let annual_bounds =
              match annual_history_bounds state with
              | Ok opt -> opt
              | Error _ -> None
            in
            let next_owner, cmd =
              Daily_pace.handle
                ~blocked:state.blocked
                ~book:state.session.book
                ~measure:state.workspace.measure
                ~daily_pace_tsv
                ~boundary_presets_tsv
                ~annual_bounds
                ~today:(F.today ())
                ~dimensions
                ~width_of
                state.daily_pace_owner
                input
            in
            let next_pane =
              match Daily_pace.pane next_owner with
              | `Calendar -> W.Calendar
              | `Detail -> W.Detail
            in
            let state =
              { state with
                daily_pace_owner = next_owner;
                workspace = { state.workspace with pane = next_pane };
                scroll = Daily_pace.detail_scroll next_owner;
                message =
                  (if Daily_pace.notice next_owner <> "" then
                     Daily_pace.notice next_owner
                   else state.message);
              }
            in
            (match cmd with
            | Daily_pace.Stay -> Some state
            | Daily_pace.Back_to_home -> Some (open_route state W.Home)
            | Daily_pace.Open_commands -> Some { state with overlay = Commands M.initial }
            | Daily_pace.Cycle_measure direction ->
                let measures = List.map fst (B.measures state.session.book) in
                let next_measure =
                  match measures with
                  | [] -> state.workspace.measure
                  | ms ->
                      let rec next = function
                        | [] -> List.hd ms
                        | [ x ] -> List.hd ms
                        | x :: y :: _ when x = state.workspace.measure -> y
                        | _ :: rest -> next rest
                      in
                      let rec prev acc = function
                        | [] -> List.hd (List.rev ms)
                        | [ x ] when x = state.workspace.measure -> (match acc with None -> x | Some p -> p)
                        | x :: _ when x = state.workspace.measure -> (match acc with None -> List.hd (List.rev ms) | Some p -> p)
                        | x :: rest -> prev (Some x) rest
                      in
                      match direction with
                      | `Next -> next ms
                      | `Prev -> prev None ms
                in
                Some { state with workspace = { state.workspace with measure = next_measure } }
            | Daily_pace.Save_pool { expected; content } ->
                let result = write_config_file state "daily-pace.tsv" ~expected content in
                (match result with
                | Ok () ->
                    let saved = Daily_pace.notify_pool_saved next_owner in
                    Some { state with daily_pace_owner = saved; message = Daily_pace.notice saved }
                | Error why ->
                    let failed = Daily_pace.notify_pool_save_failed next_owner why in
                    Some { state with daily_pace_owner = failed })
            | Daily_pace.Save_cycle { expected; content } ->
                let result = write_config_file state "boundary-presets.tsv" ~expected content in
                (match result with
                | Ok () ->
                    let saved = Daily_pace.notify_cycle_saved next_owner in
                    Some { state with daily_pace_owner = saved; message = Daily_pace.notice saved }
                | Error why ->
                    let failed = Daily_pace.notify_cycle_save_failed next_owner why in
                    Some { state with daily_pace_owner = failed })
            | Daily_pace.Reload -> Some (reload state))
        | Some (`ASCII ' ', []) -> Some { state with overlay = Commands M.initial }
        | Some (`Uchar c, []) when Uchar.to_int c = 32 ->
            Some { state with overlay = Commands M.initial }
        | Some ((`Escape | `ASCII 'q'), []) when state.workspace.route = W.Home ->
            None
        | Some (`ASCII 'g', []) when state.workspace.route = W.Home ->
            Some (open_route state W.Calendar)
        | Some (`Enter, []) when state.workspace.route = W.Home ->
            Some (open_route state W.Calendar)
        | Some (`ASCII 'g', []) when state.workspace.route = W.Calendar ->
            Some (open_route state W.Home)
        | Some (`ASCII 'g', []) when (match state.workspace.route with W.Selected_day _ -> true | _ -> false) ->
            Some (open_route state W.Loci)
        | Some ((`Escape | `ASCII 'q'), []) ->
            if state.workspace.route = W.Loci || state.workspace.route = W.Settlements then
              Some (open_route state W.Home)
            else if state.workspace.route = W.Attention || state.workspace.route = W.Income_expense || state.workspace.route = W.Transactions_flow || state.workspace.route = W.Stock_flow then
              if state.workspace.pane = W.Detail then
                Some { state with workspace = { state.workspace with pane = W.Calendar }; scroll = 0 }
              else Some (open_route state W.Home)
            else if state.workspace.route = W.Calendar then
              if state.workspace.pane = W.Detail then
                Some { state with workspace = { state.workspace with pane = W.Calendar }; scroll = 0 }
              else if fst (Option.get key) = `Escape && state.workspace.calendar.zoom <> Cal.Day then
                Some
                  (sync
                     {
                       state with
                       workspace =
                         {
                           state.workspace with
                           calendar =
                             {
                               state.workspace.calendar with
                               zoom =
                                 (match state.workspace.calendar.zoom with
                                 | Cal.Year -> Cal.Month
                                 | Cal.Month -> Cal.Day
                                 | Cal.Day -> Cal.Day);
                             };
                         };
                     })
              else Some (open_route state W.Home)
            else Some (back state)
        | Some (`ASCII ('1' .. '5' as c), []) when state.workspace.route = W.Income_expense ->
            let preset = match c with
              | '1' -> IncExp.Month
              | '2' -> IncExp.Cycle
              | '3' -> IncExp.Previous_cycle
              | '4' -> IncExp.Year
              | _ -> IncExp.All_time in
            Some { state with income_expense = { state.income_expense with preset; period_offset = 0 }; scroll = 0 }
        | Some (`ASCII ('[' | ']'), []) when state.workspace.route = W.Income_expense ->
            let delta = if fst (Option.get key) = `ASCII '[' then -1 else 1 in
            Some { state with income_expense = { state.income_expense with period_offset = state.income_expense.period_offset + delta }; scroll = 0 }
        | Some (`ASCII 'p', []) when state.workspace.route = W.Income_expense ->
            (match checked_report_period state state.income_expense.preset state.income_expense.period_offset with
             | Error why -> Some { state with message = why }
             | Ok period ->
                 let roles = accounting_roles state in
                 let rep = IncExp.compute_report ~book:state.session.book ~roles ~period in
                 let lines = IncExp.print_summary ~book:state.session.book ~report:rep in
                 let form = Form.create ~id:"income_expense_print_preview" ~title:(tr "Income & Expense / Print Preview")
                   ~summary:lines ~fields:[ Form.action_buttons ~confirm:(tr "Done") ~cancel:(tr "Close") () ] () in
                 Some { state with overlay = Modal_form form })
        | Some ((`Enter | `ASCII 'i' | `Tab | `ASCII 'w'), []) when state.workspace.route = W.Income_expense ->
            Some { state with workspace = { state.workspace with pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar) }; scroll = 0 }
        | Some (`ASCII ('1' .. '5' as c), []) when state.workspace.route = W.Transactions_flow ->
            let preset = match c with
              | '1' -> IncExp.Month
              | '2' -> IncExp.Cycle
              | '3' -> IncExp.Previous_cycle
              | '4' -> IncExp.Year
              | '5' -> IncExp.All_time
              | _ -> IncExp.Month
            in
            Some { state with transactions_flow = { state.transactions_flow with preset; period_offset = 0; selected_row = 0 }; scroll = 0 }
        | Some (`ASCII ('[' | ']'), []) when state.workspace.route = W.Transactions_flow ->
            let delta = if fst (Option.get key) = `ASCII '[' then -1 else 1 in
            Some { state with transactions_flow = { state.transactions_flow with period_offset = state.transactions_flow.period_offset + delta; selected_row = 0 }; scroll = 0 }
        | Some (`ASCII 'p', []) when state.workspace.route = W.Transactions_flow ->
            (match checked_report_period state state.transactions_flow.preset state.transactions_flow.period_offset with
             | Error why -> Some { state with message = why }
             | Ok period ->
                 let rep = Flow.compute_report ~book:state.session.book ~period in
                 let lines = Flow.print_summary ~book:state.session.book ~report:rep in
                 let form = Form.create ~id:"transactions_flow_print_preview" ~title:(tr "Transactions Flow / Print Preview")
                   ~summary:lines ~fields:[ Form.action_buttons ~confirm:(tr "Done") ~cancel:(tr "Close") () ] () in
                 Some { state with overlay = Modal_form form })
        | Some ((`Enter | `ASCII 'i' | `Tab | `ASCII 'w'), []) when state.workspace.route = W.Transactions_flow ->
            Some { state with workspace = { state.workspace with pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar) }; scroll = 0 }
        | Some (`ASCII ('1' .. '5' as c), []) when state.workspace.route = W.Stock_flow ->
            let preset = match c with
              | '1' -> IncExp.Month
              | '2' -> IncExp.Cycle
              | '3' -> IncExp.Previous_cycle
              | '4' -> IncExp.Year
              | '5' -> IncExp.All_time
              | _ -> IncExp.Month
            in
            Some { state with stock_flow = { preset; period_offset = 0 }; scroll = 0 }
        | Some (`ASCII ('[' | ']'), []) when state.workspace.route = W.Stock_flow ->
            let delta = if fst (Option.get key) = `ASCII '[' then -1 else 1 in
            Some { state with stock_flow = { state.stock_flow with period_offset = state.stock_flow.period_offset + delta }; scroll = 0 }
        | Some (`ASCII 'p', []) when state.workspace.route = W.Stock_flow ->
            (match stock_flow_result state with
             | Ok rep ->
                 let lines = StockFlow.print_summary ~book:state.session.book ~report:rep in
                 let form = Form.create ~id:"stock_flow_print_preview" ~title:(tr "Stock–Flow / Print Preview")
                   ~summary:lines ~fields:[ Form.action_buttons ~confirm:(tr "Done") ~cancel:(tr "Close") () ] () in
                 Some { state with overlay = Modal_form form }
             | Error why ->
                 Some { state with message = why })
        | Some ((`Enter | `ASCII 'i' | `Tab | `ASCII 'w'), []) when state.workspace.route = W.Stock_flow ->
            Some { state with workspace = { state.workspace with pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar) }; scroll = 0 }
        | Some ((`Enter | `ASCII 'i' | `Tab | `ASCII 'w'), []) when state.workspace.route = W.Attention ->
            Some { state with workspace = { state.workspace with pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar) }; scroll = 0 }
        | Some (`ASCII 'b', []) when (match state.workspace.route with
            | W.Scheduled | W.Selected_day _ -> true | _ -> false) ->
            Some (batch_plan_selected state)
        | Some (`ASCII 'g', []) when state.workspace.route = W.Scheduled ->
            Some (extend_plan_selected state)
        | Some (`ASCII 'v', []) when state.workspace.route = W.Scheduled ->
            Some (sync { state with workspace = W.toggle_schedule_view ~book:state.session.book state.workspace;
              message = (if state.blocked then state.message else "") })
        | Some ((`ASCII 'h' | `Arrow `Left | `ASCII 'l' | `Arrow `Right), [])
          when is_scheduled_months state && state.workspace.pane = W.Calendar ->
            let delta = match Option.map normalize key with
              | Some ((`ASCII 'h' | `Arrow `Left), _) -> -1 | _ -> 1 in
            (match Months.shift state.workspace.months delta with
             | Ok months -> Some { state with workspace = { state.workspace with months } }
             | Error message -> Some { state with message = (if state.blocked then state.message else message) })
        | Some (`ASCII ('f' | '/'), []) when is_scheduled_months state ->
            Some { state with message = (if state.blocked then state.message else
              "Months uses all current-open plans; v opens filtered List.") }
        | Some (`Enter, []) when is_scheduled_months state -> Some (pay_selected state)
        | Some (`ASCII 'r', []) when is_scheduled_months state -> Some (edit_selected state)
        | Some ((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)), [])
          when is_record_browser state ->
            Some { state with workspace = { state.workspace with
              pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar) };
              scroll = 0 }
        | Some ((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)), [])
        | Some (`ASCII ('u' | 'd'), [ `Ctrl ]) when is_record_browser state ->
            let height, view = browser_viewport ~dimensions ~width_of state in
            let detail = state.workspace.pane = W.Detail in
            let page = max 1 (if detail then view.capacity else if is_scheduled_months state then 8 else
              Panel.capacity ~height ~heading:(state.workspace.route = W.Actual)) in
            let delta = match Option.map normalize key with
              | Some (`Home, _) -> -max_int
              | Some (`End, _) -> max_int
              | Some (`Page `Up, _) | Some (`ASCII 'u', [ `Ctrl ]) -> -page
              | Some (`Page `Down, _) | Some (`ASCII 'd', [ `Ctrl ]) -> page
              | Some ((`ASCII 'k' | `Arrow `Up), _) -> -1
              | _ -> 1 in
            if detail then
              Some { state with scroll = Panel.move ~last:view.last ~position:view.start delta }
            else Some { state with scroll = 0;
              workspace = W.move_selection ~book:state.session.book state.workspace delta }
        | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
            Some
              {
                state with
                workspace =
                  {
                    state.workspace with
                    pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar);
                  };
                scroll = (if is_record_browser state then state.scroll else 0);
              }
        | Some (`ASCII 't', []) when state.workspace.route = W.Calendar ->
            Some (update_calendar state (Cal.Today (F.today ())))
        | Some (`ASCII 'z', []) when state.workspace.route = W.Calendar ->
            Some (update_calendar state Cal.Cycle_zoom)
        | Some (`ASCII '/', []) ->
            Some
              {
                state with
                overlay = (if state.workspace.route = W.Calendar then Jump ""
                  else Search (W.browser state.workspace).query);
              }
        | Some (`ASCII 'n', []) when state.workspace.route = W.Attention ->
            Some { state with overlay = Modal_form (add_attention_form ~today:(F.today ())) }
        | Some (`ASCII 'r', []) when state.workspace.route = W.Attention -> (
            match selected_attention state with
            | None -> Some { state with message = tr "No attention item selected to resolve." }
            | Some item -> Some { state with overlay = Modal_form (resolve_attention_form ~today:(F.today ()) item) })
        | Some (`ASCII 'x', []) when state.workspace.route = W.Attention -> (
            match selected_attention state with
            | None -> Some { state with message = tr "No attention item selected to drop." }
            | Some item -> Some { state with overlay = Modal_form (drop_attention_form ~today:(F.today ()) item) })
        | Some (`ASCII 'n', []) when state.workspace.route = W.Loci ->
            let count = List.length (admitted_loci state) in
            Some { state with overlay = Modal_form (admit_locus_form ~count) }
        | Some (`ASCII 'r', []) when state.workspace.route = W.Loci -> (
            match selected_locus state with
            | None -> Some { state with message = tr "No locus selected." }
            | Some locus ->
                let roles = accounting_roles state in
                let current_role = List.assoc_opt locus roles in
                Some { state with overlay = Modal_form (set_locus_role_form ~locus ~current_role) })
        | Some (`ASCII ('l' | 'e'), []) when state.workspace.route = W.Loci -> (
            match selected_locus state with
            | None -> Some { state with message = tr "No locus selected." }
            | Some locus ->
                let current_label = B.label state.session.book locus in
                let current_label = if current_label = locus then "" else current_label in
                let current_help = B.help state.session.book locus in
                Some { state with overlay = Modal_form (set_locus_label_form ~locus ~current_label ~current_help) })
        | Some (`ASCII 'n', []) when state.workspace.route = W.Settlements ->
            Some { state with overlay = Modal_form (add_settlement_form state) }
        | Some (`ASCII 'a', []) when state.workspace.route = W.Settlements -> (
            match selected_settlement state with
            | None -> Some { state with message = tr "No commitment selected." }
            | Some r -> Some { state with overlay = Modal_form (action_settlement_form r) })
        | Some (`ASCII 's', []) when state.workspace.route = W.Settlements ->
            Some (cycle_settlement_scope state)
        | Some (`ASCII 'r', []) | Some (`ASCII 'n', [])
          when state.workspace.route = W.Scheduled ->
            Some (open_plan_record state)
        | Some (`ASCII 'r', []) | Some (`ASCII 'n', []) -> Some (open_record state)
        | Some (`ASCII 'a', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Actual)
        | Some (`ASCII 's', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Scheduled)
        | Some (`ASCII 'b', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Balances)
        | Some (`ASCII 'd', []) when (match state.workspace.route with W.Selected_day _ -> true | _ -> false) ->
            Some (correct_date_selected state)
        | Some (`ASCII 'm', []) when (match state.workspace.route with W.Selected_day _ -> true | _ -> false) ->
            Some (classify_merchant_selected state)
        | Some (`ASCII 'd', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Daily_pace)
        | Some (`ASCII 'i', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Attention)
        | Some (`ASCII 'o', [])
          when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            let default_locus, default_measure, current_amount = (None, None, None) in
            let form = observe_quantity_form ?default_locus ?default_measure ?current_amount state in
            let form =
              if default_locus <> None then
                Form.set_focused form (Form.find_field_index form "amount")
              else form
            in
            Some { state with overlay = Modal_form form;
              observe_draft = Some { rows = []; base_bytes = state.session.bytes;
                pending = ("", state.workspace.measure, ""); uncertain = false } }
        | Some (`ASCII 's', []) when state.workspace.route = W.Actual ->
            Some (sync { state with workspace = W.cycle_order state.workspace })
        | Some (`ASCII 'f', [])
          when state.workspace.route = W.Actual || state.workspace.route = W.Scheduled ->
            Some (sync { state with workspace = W.toggle_day_filter state.workspace })
        | Some (`ASCII 'x', []) when state.workspace.route = W.Scheduled ->
            Some (cancel_plan_selected state)
        | Some (`ASCII 'x', []) when state.workspace.route = W.Actual ->
            Some (reverse_entry_selected state)
        | Some (`ASCII 'x', []) -> (
            match selected state with
            | Some (W.Scheduled_plan _) -> Some (cancel_plan_selected state)
            | Some (W.Actual_entry _) -> Some (reverse_entry_selected state)
            | _ -> Some state)
        | Some (`ASCII 'c', []) when state.workspace.route = W.Scheduled ->
            Some (pay_selected state)
        | Some (`ASCII 'e', []) when state.workspace.route = W.Scheduled ->
            Some (edit_selected state)
        | Some (`ASCII 'c', []) | Some (`ASCII 'e', []) | Some (`ASCII 'e', [ `Ctrl ]) ->
            Some (edit_selected state)
        | Some (`ASCII 'i', []) ->
            Some { state with workspace = { state.workspace with pane = W.Detail }; scroll = 0 }
        | Some (`Enter, []) ->
            if state.workspace.route = W.Calendar && state.workspace.pane = W.Calendar then
              Some (update_calendar state Cal.Drill)
            else if state.workspace.route = W.Calendar then
              match selected state with
              | None -> Some state
              | Some row -> Some (open_route state (W.Selected_day (W.date row)))
            else
              Some { state with workspace = { state.workspace with pane = W.Detail }; scroll = 0 }
        | (Some ((`ASCII 'h' | `Arrow `Left), []) | Some ((`ASCII 'l' | `Arrow `Right), []))
          when state.workspace.route = W.Calendar && state.workspace.pane = W.Calendar ->
            let action =
              match Option.get key with
              | (`ASCII 'h' | `Arrow `Left), _ -> Cal.Left
              | _ -> Cal.Right
            in
            Some (update_calendar state action)
        | Some ((`ASCII 'k' | `Arrow `Up), []) | Some ((`ASCII 'j' | `Arrow `Down), []) ->
            let delta =
              match Option.map normalize key with
              | Some ((`ASCII 'k' | `Arrow `Up), _) -> -1
              | _ -> 1
            in
            if state.workspace.route = W.Calendar && state.workspace.pane = W.Calendar then
              Some (update_calendar state (if delta < 0 then Cal.Up else Cal.Down))
            else if state.workspace.pane = W.Detail && state.workspace.route <> W.Calendar && state.workspace.route <> W.Home then
              Some { state with scroll = max 0 (state.scroll + delta) }
            else if state.workspace.route = W.Attention then
              if state.workspace.pane = W.Detail then
                Some { state with scroll = max 0 (state.scroll + delta) }
              else
                Some (move_attention state delta)
            else if state.workspace.route = W.Loci then
              Some (move_locus state delta)
            else if state.workspace.route = W.Settlements then
              Some (move_settlement state delta)
            else if state.workspace.route = W.Stock_flow then
              Some { state with scroll = Panel.move ~last:max_int ~position:state.scroll delta }
            else if state.workspace.route = W.Transactions_flow then
              if state.workspace.pane = W.Detail then
                Some { state with scroll = max 0 (state.scroll + delta) }
              else
                Some { state with transactions_flow = { state.transactions_flow with selected_row = max 0 (state.transactions_flow.selected_row + delta) }; scroll = 0 }
            else
              Some
                {
                  state with
                  workspace = W.move_selection ~book:state.session.book state.workspace delta;
                  scroll = 0;
                }
        | Some (`Page _, []) | Some (`ASCII ('u' | 'd'), [ `Ctrl ]) ->
            let delta =
              match Option.map normalize key with
              | Some (`Page `Up, _) | Some (`ASCII 'u', _) -> -1
              | _ -> 1
            in
            let step = delta * max 1 (snd dimensions - 8) in
            if state.workspace.route = W.Income_expense then
              Some { state with scroll = max 0 (state.scroll + step) }
            else if state.workspace.route = W.Transactions_flow then
              if state.workspace.pane = W.Detail then
                Some { state with scroll = max 0 (state.scroll + step) }
              else
                Some { state with transactions_flow = { state.transactions_flow with selected_row = max 0 (state.transactions_flow.selected_row + step) }; scroll = 0 }
            else if state.workspace.route = W.Stock_flow then
              Some { state with scroll = max 0 (state.scroll + step) }
            else if state.workspace.route = W.Attention then
              if state.workspace.pane = W.Detail then
                Some { state with scroll = max 0 (state.scroll + step) }
              else
                Some (move_attention state step)
            else if
              state.workspace.pane = W.Calendar && state.workspace.route <> W.Home
              && state.workspace.route <> W.Daily_pace
              || (state.workspace.route = W.Home && state.workspace.pane = W.Detail)
            then
              Some
                {
                  state with
                  workspace = W.move_selection ~book:state.session.book state.workspace step;
                  scroll = 0;
                }
            else Some { state with scroll = max 0 (state.scroll + step) }
        | Some (`Home, []) ->
            if state.workspace.route = W.Income_expense then
              Some { state with scroll = 0 }
            else if state.workspace.route = W.Transactions_flow then
              if state.workspace.pane = W.Detail then
                Some { state with scroll = 0 }
              else
                Some { state with transactions_flow = { state.transactions_flow with selected_row = 0 }; scroll = 0 }
            else if state.workspace.route = W.Stock_flow then
              Some { state with scroll = 0 }
            else if state.workspace.route = W.Attention then
              if state.workspace.pane = W.Detail then
                Some { state with scroll = 0 }
              else
                Some (move_attention state (-max_int))
            else
              Some
                {
                  state with
                  scroll = 0;
                  workspace = W.move_selection ~book:state.session.book state.workspace (-max_int);
                }
        | Some (`End, []) ->
            if state.workspace.route = W.Income_expense then
              Some { state with scroll = max_int / 4 }
            else if state.workspace.route = W.Transactions_flow then
              if state.workspace.pane = W.Detail then
                Some { state with scroll = max_int / 4 }
              else
                Some { state with transactions_flow = { state.transactions_flow with selected_row = max_int / 4 }; scroll = 0 }
            else if state.workspace.route = W.Stock_flow then
              Some { state with scroll = max_int / 4 }
            else if state.workspace.route = W.Attention then
              if state.workspace.pane = W.Detail then
                Some { state with scroll = max_int / 4 }
              else
                Some (move_attention state max_int)
            else
              Some
                {
                  state with
                  scroll = max_int / 4;
                  workspace = W.move_selection ~book:state.session.book state.workspace max_int;
                }
        | _ -> ( match input with `End -> None | _ -> Some state))

