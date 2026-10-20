module B = Bakhlo_sexp.Daily_book
module A = Daily_draft
type t
type outcome = Updated of t | Closed of t | Publish of A.payload * string * t
  | Enable_unresolved of t  (** Confirmed: admit the ordinary suspense Locus, then return. *)
val create : book:B.t -> day:string -> measure:string -> unit -> t
val create_plan : book:B.t -> day:string -> measure:string -> unit -> t
val of_edit : book:B.t -> B.entry -> (t, string) result
val of_edit_plan : book:B.t -> B.plan -> (t, string) result
val of_plan : ?day:string -> book:B.t -> B.plan -> (t, string) result
val mode : t -> A.mode
val border_intent : t -> [ `Create | `Change | `Cancel ]
val in_quick_capture : t -> bool
(** True while the LOAM quick capture is in front of a new Record. *)
val surface_dimensions : int * int -> int * int
(** Available space includes the two Record navigation rows. Use the returned
    dimensions for both input and rendering; narrow/short terminals stay full size. *)
val has_draft : t -> bool
val is_plan : t -> bool
val with_notice : t -> string -> t
val with_roles : (string * Daily_overlays.accounting_role) list -> t -> t
(** Accounting roles for quick capture's Locus words (the Shell reads them). *)
val after_unresolved_enabled : book:B.t -> t -> t
(** Back to the draft after suspense was admitted, filling the remainder as LOAM does. *)
val unresolved_not_enabled : t -> string -> t
val preview : new_id:(unit -> string) -> book:B.t -> base_revision:string -> blocked:bool -> t -> t
val handle : new_id:(unit -> string) -> book:B.t -> base_revision:string -> blocked:bool -> dimensions:int * int ->
  width_of:(string -> int) -> t -> Ui_input.input -> outcome
val screen : ?surface:Quick_capture.surface -> book:B.t -> dimensions:int * int -> width_of:(string -> int) -> t ->
  (Daily_overlays.style * string) list
(** [surface] places the quick capture's own bounded modal; without it the
    surface is derived from [dimensions]. *)
