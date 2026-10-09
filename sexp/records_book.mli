module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query
module X = Sexplib0.Sexp

(** Records S-expression Format v1 specification and codec.
    Pure representation, independent of filesystem, publication, or concurrency engine.
    Preserves multi-currency, infinite-precision quanta, correction lineages, explicit plans,
    observations/cuts, request origins/tokens, and uninterpreted extensions. *)

type header = {
  version : int;
  measures : (string * int) list;
  labels : (string * string * string) list option;
  approved_loci : string list option;
  origins : D.Effect_coordinate.t list;
  openings : Q.opening list;
  observations : A.Current_quantity_groups.group list;
  presence : Q.presence option;
  opaque : X.t list;
}

type entry = {
  id : string;
  day : string;
  token : string option;
  memo : string option;
  effects : D.Effect.t list;
  reversal_of : string option;
  exchange : (string * string) option;
  opaque : X.t list;
}

type plan = {
  id : string;
  day : string;
  measure : string;
  changes : (string * Z.t) list;
  paid_by : string option;
  cancelled_on : string option;
  opaque : X.t list;
}

type observation = {
  id : string option;
  reflected_roots : string list;
  quantities : (string * string * Z.t) list;
  opaque : X.t list;
}

type origin = {
  token : string;
  event_id : string;
  opaque : X.t list;
}

type add_locus = {
  locus : string;
  opaque : X.t list;
}

type payload =
  | Header of header
  | Entry of entry
  | Plan of plan
  | Observation of observation
  | Origin of origin
  | Add_locus of add_locus
  | Opaque of X.t

type frame = {
  lsn : int;
  crc : string;
  payload : payload;
}

type t = {
  header : header;
  frames : frame list;
}

(** Serialization & Deserialization *)

val of_string : string -> (t, string) result
(** Parse a complete Records S-expression stream.
    Validates frame checksums, LSN sequence, and header compatibility. *)

val to_string : t -> string
(** Serialize to canonical deterministic line-delimited records with CRC32 checksums. *)

val encode_payload : payload -> X.t
(** Convert a payload variant into its canonical S-expression form. *)

val encode_frame : int -> payload -> frame
(** Construct a valid frame with computed CRC32 and sequence number. *)


val serialize_frame : frame -> string
(** Render a single frame to a single line S-expression string. *)

val parse_frame : string -> (frame, string) result
(** Parse and checksum-verify a single frame from its S-expression text. *)

(** Accessors *)

val header : t -> header
val frames : t -> frame list
val entries : t -> entry list
val plans : t -> plan list
val observations : t -> observation list
val origins : t -> origin list
val added_loci : t -> string list
val opaque_records : t -> X.t list

(** Torn-write & Log Inspection *)

type corruption =
  | No_corruption
  | Mid_file of { byte_offset : int; reason : string }

type inspection = {
  valid_frames : frame list;
  last_lsn : int;
  trailing_torn_bytes : int;
  corruption : corruption;
}

val inspect_string : string -> inspection
(** Scan log stream for valid frames, trailing partial torn writes, and mid-file corruption. *)
