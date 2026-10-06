(** One pure, whole-document read entrance for the versioned synthetic profile.
    Input errors precede source errors, which precede whole-support admission errors.
    No file/runtime/terminal types, I/O, clock, fallback or partial successful image.
    The existing opaque query image retains supplied source, corrections, optional
    descriptions and separate support declarations/cuts. Query via
    [Current_quantity_query.query]: exact Quantity/coordinate/premise, Known_present
    (no scalar), or typed Support_unknown. Its source/frontier/groups/presence
    accessors expose supporting provenance without a second answer schema.
    All answers are conditional on this supplied profile, not external completeness,
    factual truth, household balance or durable publication. *)
type error =
  | Input of Input.error
  | Source of Bakhlo_application.Actual_source.error
  | Support of Bakhlo_application.Current_quantity_query.error

type document
(** Whole-admitted original bytes and their EXACT existing quantity image, sealed by
    this profile's Input -> Source -> Support gates. Ordinary immutable OCaml values;
    unsafe escape hatches are outside the contract. No file/snapshot/currentness token,
    authorization, durable receipt, independent completeness or external truth.
    Reuse avoids repeating pure admission of the same bytes, NOT acquisition/current
    evidence checks. Bytes/image are owner evidence, not a least-disclosure projection. *)

val document_of_string : string -> (document, error) result
val document_bytes : document -> string
val document_image : document -> Bakhlo_application.Current_quantity_query.t

val of_string : string -> (Bakhlo_application.Current_quantity_query.t, error) result
(** Same whole admission as [document_of_string], returning just the existing image. *)
