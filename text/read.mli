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

val of_string : string -> (Bakhlo_application.Current_quantity_query.t, error) result
