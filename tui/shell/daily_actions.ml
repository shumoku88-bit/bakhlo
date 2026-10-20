(* Single publication coordinator. Pure candidate construction lives in Daily_draft. *)
include Daily_draft
module F = Daily_file
module L = Bakhlo_sexp.Book_log

(* Transitional caller adapters preserve existing controller/test contracts. *)
let get = function Ok x -> x | Error why -> raise (F.Refused why)
let get_id = function Ok x -> x | Error D.Identifier.Empty -> raise (F.Refused "empty-identity")
let prepare_pay ~book plan = Daily_draft.prepare_pay ~today:(F.today ()) ~book plan
let build_transaction ~book ~mode content =
  Daily_draft.build_transaction ~new_id:F.new_id ~book ~mode content
let build_plan ~book ~mode ~day ~draft =
  Daily_draft.build_plan ~new_id:F.new_id ~book ~mode ~day ~draft

let recovery_message =
  tr "An interrupted save left an incomplete final record. Writes stopped; exit and use --inspect-recovery."

let recovery_notice ~session = if session.F.torn then Some recovery_message else None

(* The file revision had the save landed. *)
type uncertain_evidence = Expected_revision of string

type commit_result =
  | Published of F.t
  | Conflict_base_changed
  | Conflict
  | Recovery_blocked
  | Uncertain of { message : string; evidence : uncertain_evidence }
  | Storage_failed of string
  | Refused of string

let publish_ops ~session ops : commit_result =
  try
    match F.append session ops with
    | F.Written session -> Published session
    | F.Conflict -> Conflict
    | F.Refused_input "torn-tail" -> Recovery_blocked
    | F.Refused_input why -> Refused why
    | F.Uncertain { expected } ->
        Uncertain { message = tr "Save outcome is uncertain."; evidence = Expected_revision expected }
  with
  | Unix.Unix_error (err, fn, arg) ->
      Storage_failed (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)
  | Sys_error msg -> Storage_failed msg

let commit_transaction ~session ~base_revision (tx : transaction) : commit_result =
  if base_revision <> session.F.revision then Conflict_base_changed
  else
    publish_ops ~session [ L.Put_entry { replace = tx.replace; entry = tx.entry; plan = tx.plan } ]

let commit_plan ~session ~base_revision ~replace (plan : B.plan) : commit_result =
  if base_revision <> session.F.revision then Conflict_base_changed
  else
    publish_ops ~session [ L.Put_plan { replace; plan } ]

let commit_plan_batch ?(replace = true) ~session ~base_revision (plans : B.plan list) : commit_result =
  if base_revision <> session.F.revision then Conflict_base_changed
  else if plans = [] then Refused (tr "No Scheduled changes selected.")
  else
    let ids = List.map (fun (p : B.plan) -> p.id) plans in
    if List.length (List.sort_uniq String.compare ids) <> List.length ids then
      Refused (tr "A Scheduled occurrence may be selected only once.")
    else
      publish_ops ~session (List.map (fun plan -> L.Put_plan { replace; plan }) plans)

let commit_cancel_plan ~session ~base_revision ~id ~day : commit_result =
  if base_revision <> session.F.revision then Conflict_base_changed
  else
    publish_ops ~session [ L.Cancel_plan { id; day } ]

let commit_reverse_entry ~session ~base_revision ~id ~day : commit_result =
  if base_revision <> session.F.revision then Conflict_base_changed
  else
    match B.find_entry session.book id with
    | None -> Refused (tr "The Actual occurrence is unavailable.")
    | Some target ->
        if target.reversal_of <> None then
          Refused (tr "This entry is already a Reversal; it cannot be reversed.")
        else if List.exists (fun (e : B.entry) -> e.reversal_of = Some target.id) (B.entries session.book) then
          Refused (tr "This entry has already been reversed.")
        else
          let inverse_effects =
            List.map
              (fun e ->
                D.Effect.create ~key:(D.Effect.key e) ~locus:(D.Effect.locus e)
                  ~measure:(D.Effect.measure e)
                  ~quantity:(D.Quantity.neg (D.Effect.quantity e)))
              target.effects
          in
          let reversal : B.entry =
            {
              id = F.new_id ();
              day;
              memo =
                Some
                  ("Reversal of " ^ target.id
                  ^ match target.memo with Some m -> ": " ^ m | None -> "");
              effects = inverse_effects;
              reversal_of = Some target.id;
              exchange = None;
              original_amount = None;
              merchant = None;
            }
          in
          publish_ops ~session [ L.Put_entry { replace = false; entry = reversal; plan = None } ]
let commit_classify_merchant ~session ~base_revision ~id ~disposition : commit_result =
  if base_revision <> session.F.revision then Conflict_base_changed
  else
    publish_ops ~session [ L.Classify_merchant { id; disposition } ]


let commit_payload ~session ~base_revision = function
  | Entry_tx tx -> commit_transaction ~session ~base_revision tx
  | Plan_tx { plan; replace } -> commit_plan ~session ~base_revision ~replace plan

let commit_set_locus_label ~session ~base_revision ~id ~label ?help () : commit_result =
  if base_revision <> session.F.revision then Conflict_base_changed
  else
    publish_ops ~session [ L.Set_locus_label { id; label; help } ]
let commit_add_locus ~session name : commit_result =
  let name = String.trim name in
  if String.equal name "" then Refused (tr "Enter the new Locus token.")
  else
    match publish_ops ~session [ L.Add_locus name ] with
    | Refused "duplicate-locus" -> Refused (format_message "Locus %s is already admitted." name)
    | Refused "locus-policy-not-supplied" -> Refused (tr "Locus admission policy is not supplied.")
    | Refused why -> Refused (format_message "Locus admission refused (%s)" why)
    | result -> result

type reload_result =
  | Pending_confirmed of F.t
  | Pending_unconfirmed of F.t
  | Edit_base_changed of F.t
  | Reloaded of F.t
  | Recovery_required of F.t * string
  | Reload_failed of string

let reload ~session ~pending ~mode : reload_result =
  try
    let loaded = F.reload session in
    match recovery_notice ~session:loaded with
    | Some notice -> Recovery_required (loaded, notice)
    | None -> (
        match pending with
        | Some (Expected_revision revision) when loaded.revision = revision -> Pending_confirmed loaded
        | Some _ -> Pending_unconfirmed loaded
        | None -> (
            match mode with
            | (Edit _ | Plan_edit _) when loaded.revision <> session.revision -> Edit_base_changed loaded
            | New | Pay _ | Edit _ | Plan_new | Plan_edit _ -> Reloaded loaded))
  with
  | F.Refused why -> Reload_failed why
  | Unix.Unix_error _ | Sys_error _ -> Reload_failed "IO-error"
