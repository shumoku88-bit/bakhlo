(* From a reviewed request to a publication outcome.

   Suppose a plan was reviewed against revision A. Before Publish, the Shell
   reloads revision B. The old review must not silently become a request against
   B. If only another writer has saved B, the Shell may still hold A: that is a
   different conflict, detected when Book_file checks the file under its lock.
   A draft's base, the current session and the file are three distinct things.

   Book owns admission; Book_file owns replacement. Here we turn the Shell's
   requests into book changes and keep the evidence needed to interpret their
   outcomes. tui/scenarios/book_publication_recovery_checks.ml exercises the
   two conflict gates and the read-only resolution of uncertain publications. *)
module F = Book_file
module B = Bakhlo_household.Book

let tr = Ui_text.tr

type uncertain_evidence = Expected_revision of string

type outcome =
  | Published of F.t
  | Conflict_base_changed
  | Conflict
  | Uncertain of { message : string; evidence : uncertain_evidence }
  | Storage_failed of string
  | Refused of string

(* 1. Translate the result without throwing away what can be checked later.

   An uncertain result is not just a warning string: its candidate revision
   lets a later reload establish whether those bytes are now present. *)
let of_file_outcome = function
  | F.Written session -> Published session
  | F.Conflict -> Conflict
  | F.Refused_input why -> Refused why
  | F.Uncertain { expected } ->
      Uncertain { message = tr "Save outcome is uncertain."; evidence = Expected_revision expected }

let changes ~session requested : outcome =
  try of_file_outcome (F.publish session requested) with
  | Unix.Unix_error (err, fn, arg) ->
      Storage_failed (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)
  | Sys_error msg -> Storage_failed msg

(* 2. A reviewed request keeps its original base.

   This gate compares the request to the supplied session. Passing it does
   not mean the file is unchanged: Book_file still checks that separately.
   Neither conflict updates the request's base or retries it on a newer book. *)
let onto ~session ~base_revision requested =
  if base_revision <> session.F.revision then Conflict_base_changed else changes ~session requested

let transaction ~session ~base_revision (tx : Bakhlo_household.Record.transaction) : outcome =
  onto ~session ~base_revision
    [ B.Put_entry { replace = tx.replace; entry = tx.entry; plan = tx.plan } ]

let plan ~session ~base_revision ~replace (plan : B.plan) : outcome =
  onto ~session ~base_revision [ B.Put_plan { replace; plan } ]

(* A selected occurrence represents one change, even in a batch. Refuse a
   repeated ID rather than let order decide which version wins; submit the
   whole accepted selection to the writer as one publication. *)
let plan_batch ?(replace = true) ~session ~base_revision (plans : B.plan list) : outcome =
  if base_revision <> session.F.revision then Conflict_base_changed
  else if plans = [] then Refused (tr "No Scheduled changes selected.")
  else
    let ids = List.map (fun (p : B.plan) -> p.id) plans in
    if List.length (List.sort_uniq String.compare ids) <> List.length ids then
      Refused (tr "A Scheduled occurrence may be selected only once.")
    else changes ~session (List.map (fun plan -> B.Put_plan { replace; plan }) plans)

let cancel_plan ~session ~base_revision ~id ~day : outcome =
  onto ~session ~base_revision [ B.Cancel_plan { id; day } ]

(* A real reversal adds a fact; it does not erase mistaken input. Keep the
   original and negate each posting in a new linked entry. Book still decides
   whether that candidate is admissible, including any exchange constraints. *)
let reverse_entry ~session ~base_revision ~id ~day : outcome =
  if base_revision <> session.F.revision then Conflict_base_changed
  else
    match B.find_entry session.book id with
    | None -> Refused (tr "The Actual occurrence is unavailable.")
    | Some target ->
        if target.reversal_of <> None then
          Refused (tr "This entry is already a Reversal; it cannot be reversed.")
        else if
          List.exists (fun (e : B.entry) -> e.reversal_of = Some target.id) (B.entries session.book)
        then Refused (tr "This entry has already been reversed.")
        else
          let inverse_effects =
            List.map (fun (e : B.posting) -> { e with amount = Z.neg e.amount }) target.effects
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
          changes ~session [ B.Put_entry { replace = false; entry = reversal; plan = None } ]

let correct_entry_date ~session ~base_revision ~id ~day : outcome =
  onto ~session ~base_revision [ B.Correct_entry_date { id; day } ]

let observations ~session ~base_revision rows : outcome =
  onto ~session ~base_revision [ B.Observe rows ]

(* These section updates have no separate reviewed base in this API. They
   use the supplied session; the writer's file-conflict check still applies. *)
let roles ~session roles : outcome = changes ~session [ B.Set_roles roles ]

let attention ~session ~items ~closes : outcome =
  changes ~session [ B.Set_attention { items; closes } ]

let classify_merchant ~session ~base_revision ~id ~disposition : outcome =
  onto ~session ~base_revision [ B.Classify_merchant { id; disposition } ]

let payload ~session ~base_revision = function
  | Draft.Entry_tx tx -> transaction ~session ~base_revision tx
  | Draft.Plan_tx { plan = p; replace } -> plan ~session ~base_revision ~replace p

let set_locus_label ~session ~base_revision ~id ~label ?help () : outcome =
  onto ~session ~base_revision [ B.Set_locus_label { id; label; help } ]

(* Save a new Locus and its optional role together, so a successful first
   write cannot leave the role waiting on a second save that might fail. *)
let add_locus ~session ?role name : outcome =
  let name = String.trim name in
  if String.equal name "" then Refused (tr "Enter the new Locus token.")
  else
    let role =
      match role with
      | None -> []
      | Some role ->
          [ B.Set_roles (Locus_roles.set_role (B.roles session.F.book) name (Some role)) ]
    in
    match changes ~session (B.Add_locus name :: role) with
    | Refused "duplicate-locus" ->
        Refused (Ui_text.format_message "Locus %s is already admitted." name)
    | Refused "locus-policy-not-supplied" -> Refused (tr "Locus admission policy is not supplied.")
    | Refused why -> Refused (Ui_text.format_message "Locus admission refused (%s)" why)
    | result -> result

type reload_outcome =
  | Pending_confirmed of F.t
  | Pending_unconfirmed of F.t
  | Edit_base_changed of F.t
  | Reloaded of F.t
  | Reload_failed of string

(* 3. Reload answers what is present; it never submits a request.

   Check a pending candidate first: if its bytes are present, the save can be
   confirmed even when the old editor's base has changed. Without a pending
   publication, changed contents invalidate Edit and Plan_edit instead. The
   other modes return Reloaded; their editor/preview checks belong to callers.
   A non-matching pending revision remains unconfirmed, not safe to repeat. *)
let reload ~session ~pending ~mode : reload_outcome =
  try
    let loaded = F.reload session in
    match pending with
    | Some (Expected_revision revision) when loaded.revision = revision -> Pending_confirmed loaded
    | Some _ -> Pending_unconfirmed loaded
    | None -> (
        match mode with
        | (Bakhlo_household.Record.Edit _ | Plan_edit _) when loaded.revision <> session.revision ->
            Edit_base_changed loaded
        | Bakhlo_household.Record.New | Pay _ | Edit _ | Plan_new | Plan_edit _ -> Reloaded loaded)
  with
  | F.Refused why -> Reload_failed why
  | Unix.Unix_error _ | Sys_error _ -> Reload_failed "IO-error"
