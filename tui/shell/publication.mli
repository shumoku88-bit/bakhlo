(** Publish a reviewed request without silently changing what was reviewed.

    A [base_revision] belongs to the request, not merely to the current session.
    An outdated request and a file changed by another writer are distinct
    conflicts. Book owns admission and Book_file owns the file checks; this
    module translates requests and retains uncertain-save evidence for reload.

    APIs without [base_revision] use the supplied session directly, but still
    go through the writer's file-conflict check. *)

type uncertain_evidence =
  | Expected_revision of string  (** The file revision had the save landed. *)

type outcome =
  | Published of Book_file.t
  | Conflict_base_changed
      (** The request's base differs from the supplied session; the writer was not called. *)
  | Conflict  (** The writer found that the file no longer matches the supplied session. *)
  | Uncertain of { message : string; evidence : uncertain_evidence }
  | Storage_failed of string
  | Refused of string

val of_file_outcome : Book_file.outcome -> outcome

val transaction :
  session:Book_file.t -> base_revision:string -> Bakhlo_household.Record.transaction -> outcome

val payload : session:Book_file.t -> base_revision:string -> Draft.payload -> outcome

val plan_batch :
  ?replace:bool ->
  session:Book_file.t ->
  base_revision:string ->
  Bakhlo_household.Book.plan list ->
  outcome
(** Refuses a stale base, an empty batch or an occurrence selected twice.
    The whole selection is submitted in one publication, not one save per plan. *)

val cancel_plan : session:Book_file.t -> base_revision:string -> id:string -> day:string -> outcome

val reverse_entry :
  session:Book_file.t -> base_revision:string -> id:string -> day:string -> outcome
(** A new entry with every Effect negated, linked to [id]; refuses a Reversal or an
    entry already reversed. *)

val correct_entry_date :
  session:Book_file.t -> base_revision:string -> id:string -> day:string -> outcome

val classify_merchant :
  session:Book_file.t ->
  base_revision:string ->
  id:string ->
  disposition:Bakhlo_household.Book.disposition ->
  outcome

val observations :
  session:Book_file.t -> base_revision:string -> (string * string * Z.t) list -> outcome

val set_locus_label :
  session:Book_file.t ->
  base_revision:string ->
  id:string ->
  label:string ->
  ?help:string ->
  unit ->
  outcome

val add_locus : session:Book_file.t -> ?role:Locus_roles.role -> string -> outcome
(** Admit a Locus and, when given, its accounting role, in one save. *)

val roles : session:Book_file.t -> (string * Locus_roles.role) list -> outcome
(** Replace the accounting roles section. *)

val attention :
  session:Book_file.t ->
  items:Attention_data.item list ->
  closes:Attention_data.close list ->
  outcome
(** Replace the Attention section. *)

type reload_outcome =
  | Pending_confirmed of Book_file.t
      (** The candidate's revision is present now; not proof of a past user acknowledgement. *)
  | Pending_unconfirmed of Book_file.t
      (** A book was loaded, but it does not confirm the candidate. Do not retry blindly. *)
  | Edit_base_changed of Book_file.t
      (** With no pending candidate, Edit or Plan_edit observed a changed session revision. *)
  | Reloaded of Book_file.t
  | Reload_failed of string

val reload :
  session:Book_file.t ->
  pending:uncertain_evidence option ->
  mode:Bakhlo_household.Record.mode ->
  reload_outcome
(** Read and classify; never write or retry. Pending evidence takes precedence
    over edit-base checks. Without it, Edit and Plan_edit detect a changed
    revision; other modes return [Reloaded] and leave editor checks to callers.
    The Shell owns retaining drafts and stopping/resuming writes from this result. *)
