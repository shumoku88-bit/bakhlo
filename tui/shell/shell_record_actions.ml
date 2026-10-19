(* Record actions a route owner requests with an explicit Entry/Plan target:
   each opens the matching editor or Record, or explains the refusal. *)
open Shell_state

let edit_target state target =
  if state.blocked then state
  else if has_record_draft state then
    {
      state with
      message = tr "A draft is retained. Resume or discard it before editing.";
    }
  else
    match target with
    | Some (Screen.Entry entry) -> (
        match S.of_edit ~book:state.session.book entry with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | Some (Screen.Plan plan) -> (
        match S.of_edit_plan ~book:state.session.book plan with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | None -> { state with message = tr "Select an Actual or Scheduled occurrence to edit." }

let correct_date_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before changing a date." }
  else match target with
  | Some (Screen.Entry entry) ->
      { (open_editor state (Record_editors.Date_correction (Date.create ~base_bytes:state.session.bytes entry)))
        with message = "" }
  | _ -> { state with message = tr "Select an Actual entry to change its date." }


let cancel_plan_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before cancelling a Scheduled occurrence." }
  else
    match target with
    | Some (Screen.Plan plan) ->
        if plan.paid_by <> None then
          { state with message = tr "This Scheduled occurrence is already completed." }
        else if plan.cancelled_on <> None then
          { state with message = tr "This Scheduled occurrence is already cancelled." }
        else
          {
            state with
            screens = (open_editor state (Record_editors.Scheduled_cancel (Cancel.create
              ~book:state.session.book ~base_bytes:state.session.bytes ~day:(F.today ()) plan))).screens;
            message = "";
          }
    | _ -> { state with message = tr "Select an open Scheduled occurrence to cancel." }

let batch_plan_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before batch editing." }
  else match target with
  | Some (Screen.Plan plan) -> (
      match Bulk.create ~book:state.session.book ~base_bytes:state.session.bytes ~from_day:plan.day plan with
      | Ok editor -> { (open_editor state (Record_editors.Scheduled_bulk editor)) with message = "" }
      | Error message -> { state with message })
  | _ -> { state with message = tr "Select an open Scheduled occurrence for batch amount editing." }

let extend_plan_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before generating plans." }
  else match target with
  | Some (Screen.Plan plan) -> (
      match Gen.create ~book:state.session.book ~base_bytes:state.session.bytes ~source:plan with
      | Ok editor -> { (open_editor state (Record_editors.Scheduled_generate editor)) with message = "" }
      | Error message -> { state with message })
  | _ -> { state with message = tr "Select an open Scheduled occurrence to generate." }

let reverse_entry_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before reversing." }
  else
    match target with
    | Some (Screen.Entry entry) ->
        if entry.reversal_of <> None then
          { state with message = tr "This entry is already a Reversal; it cannot be reversed." }
        else if List.exists (fun (e : B.entry) -> e.reversal_of = Some entry.id) (B.entries state.session.book) then
          { state with message = tr "This entry has already been reversed." }
        else
          {
            state with
            screens = (open_editor state (Record_editors.Reversal (Rev.create ~book:state.session.book
              ~base_bytes:state.session.bytes ~day:(F.today ()) entry))).screens;
            message = "";
          }
    | _ -> { state with message = tr "Select an Actual entry to reverse." }
let classify_merchant_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before classifying." }
  else
    match target with
    | Some (Screen.Entry entry) -> (
        match entry.merchant with
        | Some disposition ->
            let disp_text =
              match disposition with
              | Bakhlo_application.Event_merchants.Nonmerchant -> "Nonmerchant"
              | Merchant p -> "Merchant " ^ D.Identifier.External_party.to_string p
            in
            { state with message = "Merchant already classified: " ^ disp_text ^ "." }
        | None ->
            {
              state with
              screens = (open_editor state (Record_editors.Event_merchant
                (Merchant.create ~base_bytes:state.session.bytes entry))).screens;
              message = "";
            })
    | _ -> { state with message = tr "Select an Actual entry to classify Merchant." }


let pay_target state target =
  if state.blocked then state
  else if has_record_draft state then
    {
      state with
      message = tr "A draft is retained. Resume or discard it before completing Scheduled.";
    }
  else
    match target with
    | Some (Screen.Plan plan) -> (
        match S.of_plan ~day:(F.today ()) ~book:state.session.book plan with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | Some (Screen.Entry _) | None ->
        { state with message = tr "Select a Scheduled occurrence to complete." }
