(* Single publication coordinator. Pure candidate construction lives in Daily_draft. *)
include Daily_draft
module F = Daily_file

(* Transitional caller adapters preserve existing controller/test contracts. *)
let get = function Ok x -> x | Error why -> raise (F.Refused why)
let get_id = function Ok x -> x | Error D.Identifier.Empty -> raise (F.Refused "empty-identity")
let prepare_pay ~book plan = Daily_draft.prepare_pay ~today:(F.today ()) ~book plan
let build_transaction ~book ~mode content =
  Daily_draft.build_transaction ~new_id:F.new_id ~book ~mode content
let build_plan ~book ~mode ~day ~draft =
  Daily_draft.build_plan ~new_id:F.new_id ~book ~mode ~day ~draft

let recovery_message =
  tr "Unconfirmed save evidence exists. Writes stopped; exit and use --inspect-recovery."

let recovery_notice ~session =
  try if F.unfinished_names session.F.path = [] then None else Some recovery_message
  with F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
    Some (tr "Recovery evidence is unavailable. Writes stopped; unavailable is not empty.")

type uncertain_evidence =
  | Monolithic_candidate of string
  | Unspecified_evidence of string

type commit_result =
  | Published of F.t
  | Conflict_base_changed
  | Conflict
  | Recovery_blocked
  | Uncertain of { message : string; evidence : uncertain_evidence }
  | Storage_failed of string
  | Refused of string

let publish_candidate ~session candidate : commit_result =
  try
    match F.publish session candidate with
    | F.Written session -> Published session
    | F.Conflict -> Conflict
    | F.Refused_input "recovery-required" -> Recovery_blocked
    | F.Refused_input why -> Refused why
    | F.Uncertain ->
        Uncertain
          {
            message = tr "Monolithic publication outcome is uncertain.";
            evidence = Monolithic_candidate (B.to_string candidate);
          }
  with
  | Unix.Unix_error (err, fn, arg) ->
      Storage_failed (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)
  | Sys_error msg -> Storage_failed msg

let commit_transaction ~session ~base_bytes (tx : transaction) : commit_result =
  if base_bytes <> session.F.bytes then Conflict_base_changed
  else
    match B.put_entry session.book ~replace:tx.replace tx.entry ~plan:tx.plan with
    | Error why -> Refused why
    | Ok candidate -> publish_candidate ~session candidate

let commit_plan ~session ~base_bytes ~replace (plan : B.plan) : commit_result =
  if base_bytes <> session.F.bytes then Conflict_base_changed
  else
    match B.put_plan session.book ~replace plan with
    | Error why -> Refused why
    | Ok candidate -> publish_candidate ~session candidate

let commit_plan_batch ?(replace = true) ~session ~base_bytes (plans : B.plan list) : commit_result =
  if base_bytes <> session.F.bytes then Conflict_base_changed
  else if plans = [] then Refused (tr "No Scheduled changes selected.")
  else
    let ids = List.map (fun (p : B.plan) -> p.id) plans in
    if List.length (List.sort_uniq String.compare ids) <> List.length ids then
      Refused (tr "A Scheduled occurrence may be selected only once.")
    else
      let candidate = List.fold_left (fun result plan ->
        Result.bind result (fun book -> B.put_plan book ~replace plan))
        (Ok session.book) plans in
      match candidate with
      | Error why -> Refused why
      | Ok candidate -> publish_candidate ~session candidate

let commit_cancel_plan ~session ~base_bytes ~id ~day : commit_result =
  if base_bytes <> session.F.bytes then Conflict_base_changed
  else
    match B.cancel_plan session.book ~id ~day with
    | Error why -> Refused why
    | Ok candidate -> publish_candidate ~session candidate

let commit_reverse_entry ~session ~base_bytes ~id ~day : commit_result =
  if base_bytes <> session.F.bytes then Conflict_base_changed
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
          match B.put_entry session.book ~replace:false reversal ~plan:None with
          | Error why -> Refused why
          | Ok candidate -> publish_candidate ~session candidate
let commit_classify_merchant ~session ~base_bytes ~id ~disposition : commit_result =
  if base_bytes <> session.F.bytes then Conflict_base_changed
  else
    match B.classify_merchant session.book ~id ~disposition with
    | Error why -> Refused why
    | Ok candidate -> publish_candidate ~session candidate


let commit_payload ~session ~base_bytes = function
  | Entry_tx tx -> commit_transaction ~session ~base_bytes tx
  | Plan_tx { plan; replace } -> commit_plan ~session ~base_bytes ~replace plan

let commit_set_locus_label ~session ~base_bytes ~id ~label ?help () : commit_result =
  if base_bytes <> session.F.bytes then Conflict_base_changed
  else
    match B.set_locus_label session.book ~id ~label ?help () with
    | Error why -> Refused why
    | Ok candidate -> publish_candidate ~session candidate
let commit_add_locus ~session name : commit_result =
  let name = String.trim name in
  if String.equal name "" then Refused (tr "Enter the new Locus token.")
  else
    match B.add_locus session.F.book name with
    | Error "duplicate-locus" -> Refused (format_message "Locus %s is already admitted." name)
    | Error "locus-policy-not-supplied" -> Refused (tr "Locus admission policy is not supplied.")
    | Error why -> Refused (format_message "Locus admission refused (%s)" why)
    | Ok candidate -> publish_candidate ~session candidate

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
        | Some (Monolithic_candidate bytes) when loaded.bytes = bytes -> Pending_confirmed loaded
        | Some (Unspecified_evidence bytes) when loaded.bytes = bytes -> Pending_confirmed loaded
        | Some _ -> Pending_unconfirmed loaded
        | None -> (
            match mode with
            | (Edit _ | Plan_edit _) when loaded.bytes <> session.bytes -> Edit_base_changed loaded
            | New | Pay _ | Edit _ | Plan_new | Plan_edit _ -> Reloaded loaded))
  with
  | F.Refused why -> Reload_failed why
  | Unix.Unix_error _ | Sys_error _ -> Reload_failed "IO-error"
