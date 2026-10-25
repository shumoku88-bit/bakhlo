(* Editor sessions over Actual and Scheduled records: reversal, date
   correction, Merchant classification, cancellation, post-completion
   continuation, batch amount editing, explicit generation and plan creation.
   At most one is open; it floats over the current route. Every publication
   is reviewed against the bytes the session started from, and the Shell
   reports each outcome; a failed one leaves the session open in its review. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Att = Attention_data
module Rev = Reversal_session
module Date = Date_correction_session
module Merchant = Merchant_session
module Cancel = Scheduled_cancellation_session
module Cont = Scheduled_continuation_session
module Bulk = Scheduled_bulk_session
module Gen = Scheduled_generation_session
module Sch = Scheduled_session

let tr = Ui_text.tr

type session =
  | Reversal of Rev.t
  | Date_correction of Date.t
  | Event_merchant of Merchant.t
  | Scheduled_cancel of Cancel.t
  | Scheduled_continuation of Cont.t
  | Scheduled_bulk of Bulk.t
  | Scheduled_generate of Gen.t
  | Scheduled_create of Sch.t

(* [defer] is the Attention id a continuation Defer is waiting to save. *)
type t = { active : session option; defer : string option }

let config_files = []
let create () = { active = None; defer = None }
let modal t = Option.is_some t.active
let active t = t.active
let open_session session _t = { active = Some session; defer = None }

let base = function
  | Reversal e -> Some (Rev.base_revision e)
  | Date_correction e -> Some (Date.base_revision e)
  | Event_merchant e -> Some (Merchant.base_revision e)
  | Scheduled_cancel e -> Some (Cancel.base_revision e)
  | Scheduled_continuation e -> Some (Cont.base_revision e)
  | Scheduled_bulk e -> Some (Bulk.base_revision e)
  | Scheduled_generate e -> Some (Gen.base_revision e)
  | Scheduled_create _ -> None

let stay t = (t, Screen.Stay)
let keep session = { active = Some session; defer = None }

let continuation_input (env : Screen.env) prompt outcome =
  let updated message = keep (Scheduled_continuation (Cont.with_notice prompt message)) in
  match outcome with
  | Cont.Updated prompt -> stay (keep (Scheduled_continuation prompt))
  | Cont.Closed candidate ->
      ( { active = None; defer = None },
        if env.blocked then Screen.Stay
        else
          Screen.Message
            (match candidate with
            | None -> "Completion retained. No additional Scheduled created."
            | Some p ->
                "Completion retained. Kept later Scheduled " ^ Daily_overlays.visible p.B.id
                ^ "; no additional Scheduled created.") )
  | Cont.Add source -> (
      if env.blocked then stay (updated "Writes stopped; completion remains published.")
      else
        match Sch.create_from_scheduled ~book:env.book source with
        | Ok editor ->
            ( keep (Scheduled_create editor),
              Screen.Message "Completion remains published; adding an independent Scheduled." )
        | Error why -> stay (updated why))
  | Cont.Defer source -> (
      if env.blocked then stay (updated "Writes stopped; completion remains published.")
      else
        let update =
          Result.bind env.attention (fun expected ->
              let id = Att.next_id expected in
              let context =
                "Decide continuation after " ^ source.B.id ^ " (scheduled " ^ source.day ^ "): "
                ^ String.concat "; "
                    (List.map
                       (fun (locus, amount) ->
                         locus ^ " "
                         ^ B.format env.book source.measure amount
                         ^ " " ^ source.measure)
                       source.changes)
              in
              Result.map
                (fun next -> (expected, next, id))
                (Att.add_item expected ~id ~context ~due:Att.Due_undetermined))
        in
        match update with
        | Error why ->
            ( updated "Defer not confirmed; reload to inspect before retrying.",
              Screen.Message ("Completion remains published. Defer not confirmed: " ^ why) )
        | Ok (expected, next, id) ->
            ( { active = Some (Scheduled_continuation prompt); defer = Some id },
              Screen.Save_attention { expected; next } ))

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  let blocked = env.blocked and width_of = geometry.width_of in
  let body = geometry.body in
  match t.active with
  | None -> (t, Screen.Ignored)
  | Some (Scheduled_bulk e) -> (
      match Bulk.handle ~blocked ~dimensions:(Bulk.dimensions body) ~width_of e input with
      | Bulk.Updated e -> stay (keep (Scheduled_bulk e))
      | Bulk.Closed -> stay (create ())
      | Bulk.Publish (plans, base) ->
          ( keep
              (Scheduled_bulk
                 (Bulk.with_publish_error e
                    "Batch publication not confirmed. Review the notice below.")),
            Screen.Publish (Plan_batch { plans; replace = true; base }) ))
  | Some (Scheduled_generate e) -> (
      match
        Gen.handle ~new_id:env.new_id ~blocked ~dimensions:(Gen.dimensions body) ~width_of e input
      with
      | Gen.Updated e -> stay (keep (Scheduled_generate e))
      | Gen.Closed -> stay (create ())
      | Gen.Publish (plans, base) ->
          ( keep
              (Scheduled_generate
                 (Gen.with_publish_error e
                    "Generation publication not confirmed. Review the notice below.")),
            Screen.Publish (Plan_batch { plans; replace = false; base }) ))
  | Some (Scheduled_continuation prompt) ->
      continuation_input env prompt
        (Cont.handle ~dimensions:(Cont.dimensions body) ~width_of prompt input)
  | Some (Scheduled_cancel e) -> (
      match Cancel.handle ~blocked ~dimensions:(Cancel.dimensions body) ~width_of e input with
      | Cancel.Updated e -> stay (keep (Scheduled_cancel e))
      | Cancel.Closed -> stay (create ())
      | Cancel.Publish (id, day, base) ->
          ( keep (Scheduled_cancel (Cancel.with_publish_error e)),
            Screen.Publish (Cancel_plan { id; day; base }) ))
  | Some (Date_correction e) -> (
      match Date.handle ~blocked ~dimensions:(Date.dimensions body) ~width_of e input with
      | Date.Updated e -> stay (keep (Date_correction e))
      | Date.Closed -> stay (create ())
      | Date.Publish (transaction, base) ->
          ( keep (Date_correction (Date.edit e)),
            Screen.Publish
              (Correct_entry_date { id = transaction.entry.id; day = transaction.entry.day; base })
          ))
  | Some (Event_merchant e) -> (
      match Merchant.handle ~blocked ~dimensions:(Merchant.dimensions body) ~width_of e input with
      | Merchant.Updated e -> stay (keep (Event_merchant e))
      | Merchant.Closed -> (create (), Screen.Message (tr "Merchant classification cancelled."))
      | Merchant.Publish (id, disposition, base) ->
          let disp_text =
            match disposition with
            | Bakhlo_sexp.Records.Nonmerchant -> "Nonmerchant"
            | Merchant p -> "Merchant " ^ D.Identifier.External_party.to_string p
          in
          ( keep (Event_merchant (Merchant.edit e)),
            Screen.Publish
              (Classify_merchant
                 {
                   id;
                   disposition;
                   base;
                   message = Printf.sprintf "Published %s for %s." disp_text id;
                 }) ))
  | Some (Reversal e) -> (
      match Rev.handle ~blocked ~dimensions:(Rev.dimensions body) ~width_of e input with
      | Rev.Updated e -> stay (keep (Reversal e))
      | Rev.Closed -> stay (create ())
      | Rev.Publish (id, day, base) ->
          ( keep (Reversal (Rev.with_publish_error e)),
            Screen.Publish (Reverse_entry { id; day; base }) ))
  | Some (Scheduled_create e) -> (
      match Sch.handle ~blocked ~dimensions:(Sch.dimensions body) ~width_of e input with
      | Sch.Updated e -> stay (keep (Scheduled_create e))
      | Sch.Closed -> stay (create ())
      | Sch.Publish draft ->
          let failed = keep (Scheduled_create (Sch.with_publish_error e "Publish failed.")) in
          if blocked then stay failed
          else
            let plan =
              {
                B.id = env.new_id ();
                day = draft.Sch.scheduled_on;
                measure = draft.Sch.measure;
                changes = draft.Sch.changes;
                paid_by = None;
                cancelled_on = None;
              }
            in
            ( failed,
              Screen.Publish
                (Create_plan { plan; base = env.revision; offer_pace = Sch.offers_expected_pace e })
            ))

let published _env _geometry outcome t =
  match outcome with
  | Screen.Published -> stay (create ())
  | Screen.Publish_refused _ | Screen.Publish_conflict | Screen.Publish_stopped -> stay t

(* Only a continuation Defer saves the Attention memory. *)
let saved _env _geometry result t =
  match (t.active, t.defer, result) with
  | Some (Scheduled_continuation _), Some id, Ok () ->
      ( create (),
        Screen.Message
          ("Completion retained. Deferred continuation as " ^ id
         ^ "; no additional Scheduled created.") )
  | Some (Scheduled_continuation prompt), Some _, Error why ->
      ( keep
          (Scheduled_continuation
             (Cont.with_notice prompt "Defer not confirmed; reload to inspect before retrying.")),
        Screen.Message ("Completion remains published. Defer not confirmed: " ^ why) )
  | _ -> stay t

let stale_message = function
  | Reversal _ ->
      tr "Reversal target generation changed. Date retained; cancel, reload and reselect."
  | Date_correction _ ->
      tr "Date correction target generation changed. Cancel, reload and reselect."
  | Event_merchant _ ->
      tr
        "Merchant classification target generation changed. Draft retained; cancel, reload and \
         reselect."
  | Scheduled_cancel _ ->
      tr "Scheduled cancellation target generation changed. Keep, reload and reselect."
  | Scheduled_continuation _ ->
      tr "Completion remains published. Later-plan evidence changed; close and reload to inspect."
  | Scheduled_bulk _ -> tr "Batch target generation changed. Cancel, reload and reselect."
  | Scheduled_generate _ -> tr "Generation target generation changed. Cancel, reload and reselect."
  | Scheduled_create _ -> ""

let reloaded (env : Screen.env) t =
  match t.active with
  | Some session when match base session with Some b -> b <> env.revision | None -> false ->
      (t, Screen.Stop_writes (Some (stale_message session)))
  | _ -> stay t

let view (env : Screen.env) (geometry : Screen.geometry) t =
  let width_of = geometry.width_of and body = geometry.body in
  let frame caret pane rows =
    Ui_overlay.centered ~width_of ~screen:geometry.screen ~body ~pane_width:(fst pane) ~caret rows
  in
  let overlay, footer =
    match t.active with
    | None -> (None, [])
    | Some (Scheduled_bulk e) ->
        let pane = Bulk.dimensions body in
        ( frame `Free pane (Bulk.screen ~dimensions:pane ~width_of e),
          if env.blocked then
            [ "Writes stopped; batch retained"; "Ctrl-r inspect/reload  Esc cancel" ]
          else Bulk.footer e )
    | Some (Scheduled_generate e) ->
        let pane = Gen.dimensions body in
        ( frame `Free pane (Gen.screen ~dimensions:pane ~width_of e),
          if env.blocked then
            [ "Writes stopped; generation retained"; "Ctrl-r inspect/reload  Esc cancel" ]
          else Gen.footer e )
    | Some (Scheduled_continuation e) ->
        let pane = Cont.dimensions body in
        (frame `None pane (Cont.screen ~dimensions:pane ~width_of e), Cont.footer e)
    | Some (Scheduled_cancel e) ->
        let pane = Cancel.dimensions body in
        ( frame `Free pane (Cancel.screen ~dimensions:pane ~width_of e),
          if env.blocked then [ "Writes stopped; date retained"; "Ctrl-r inspect/reload  q keep" ]
          else Cancel.footer e )
    | Some (Date_correction e) ->
        let pane = Date.dimensions body in
        ( frame `Free pane (Date.screen ~dimensions:pane ~width_of e),
          if env.blocked then [ "Writes stopped; date retained"; "Ctrl-r inspect/reload  q keep" ]
          else Date.footer e )
    | Some (Event_merchant e) ->
        let pane = Merchant.dimensions body in
        ( frame `Bounded pane (Merchant.screen ~dimensions:pane ~width_of e),
          if env.blocked then [ "Writes stopped; date retained"; "Ctrl-r inspect/reload  q keep" ]
          else Merchant.footer e )
    | Some (Reversal e) ->
        let pane = Rev.dimensions body in
        ( frame `Bounded pane (Rev.screen ~dimensions:pane ~width_of e),
          if env.blocked then [ "Writes stopped; date retained"; "Ctrl-r inspect/reload  q keep" ]
          else Rev.footer e )
    | Some (Scheduled_create e) ->
        let pane = Sch.dimensions body in
        (frame `Bounded pane (Sch.screen ~book:env.book ~dimensions:pane ~width_of e), Sch.footer e)
  in
  {
    Screen.title = tr "Edit";
    subtitle = Default;
    rows = lazy [];
    footer;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
