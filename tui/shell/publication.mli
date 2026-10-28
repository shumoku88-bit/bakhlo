(** Publishing to the book file: each change the Shell asks for, onto the revision its
    draft was made from, and reloading after an outcome that could not be confirmed. *)

type uncertain_evidence =
  | Expected_revision of string  (** The file revision had the save landed. *)

type outcome =
  | Published of Book_file.t
  | Conflict_base_changed  (** The book changed after the draft was made. *)
  | Conflict
  | Uncertain of { message : string; evidence : uncertain_evidence }
  | Storage_failed of string
  | Refused of string

val of_file_outcome : Book_file.outcome -> outcome
val transaction : session:Book_file.t -> base_revision:string -> Draft.transaction -> outcome
val payload : session:Book_file.t -> base_revision:string -> Draft.payload -> outcome

val plan_batch :
  ?replace:bool ->
  session:Book_file.t ->
  base_revision:string ->
  Bakhlo_household.Book.plan list ->
  outcome
(** Refuses an empty batch or an occurrence selected twice. *)

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
  | Pending_unconfirmed of Book_file.t
  | Edit_base_changed of Book_file.t
  | Reloaded of Book_file.t
  | Reload_failed of string

val reload :
  session:Book_file.t -> pending:uncertain_evidence option -> mode:Draft.mode -> reload_outcome
