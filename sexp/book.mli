module D = Bakhlo_domain
(** Development-only [bakhlo 1 ordinary-quantity] evidence book, not a full-household
    codec or adopted physical store. Only explicit Measure interpretation, ordinary
    Actual Events with base day/description, Event corrections, independently cut
    exact observations and zero origins are supported. Other fields/families refuse.
    Collections distinguish provided, provided-empty and not-supplied; missing is
    NEVER defaulted. Signed integer quanta and identities retain exact meanings.
    Comments/whitespace are retained in [original_bytes], not canonical printing. *)

module A = Bakhlo_application

type family = Measures | Events | Event_corrections | Observations | Zero_origin
type supply = Provided | Empty | Not_supplied
type measure = { id : D.Identifier.Measure.t; decimal_scale : Z.t }
type t

type error =
  | Syntax of Parsexp.Parse_error.t
  | Wire of { at : string; problem : string }
  | Event of { event : D.Identifier.Event.t; error : D.Event.error }
  | Movement of D.Movement.error list
  | Source of A.Actual_source.error
  | Support of A.Current_quantity_query.error

val of_string : string -> (t, error) result
(** Whole syntax/wire/declared-Measure/source/support admission before any query.
    Unsupported, duplicate/missing fields, dangling references and overlapping
    support refuse the WHOLE book. No filtering, fallback or guessed chronology. *)

val original_bytes : t -> string

val to_string : t -> string
(** Deterministic shallow readable printing of every retained in-profile fact,
    including superseded Events, Effect occurrences/keys and independent cuts.
    Interpretation and collection supply states survive; no derived balance cache.
    This is semantic canonicalization, not source-byte/comment preservation. *)

val measures : t -> measure list
val supply : t -> family -> supply

val image : t -> A.Current_quantity_query.t
(** Conditional quantities over this supplied source; not household truth. *)

type candidate

val base : candidate -> t
val document : candidate -> t
val append : base:t -> event:string -> (candidate, error) result

val correct : base:t -> target:D.Identifier.Event.t -> event:string -> (candidate, error) result
(** [event] is exactly ONE explicit Event S-expression. Positive/negative Effects
    must satisfy existing ordinary single-Measure Movement admission; identities,
    date and optional description are supplied, never allocated/inherited. Append
    originals and an explicit correction relation, whole-admit, print and reread.
    The immutable base remains intact. A proposal or a fresh staged file is NOT
    publication permission, selected-generation ownership, receipt or durable Saved. *)
