(** ONLY the noncanonical synthetic fixture grammar. Tabs separate exact nonempty
    unescaped identities. Header LOAM-OCAML-ACTUAL-FIXTURE<TAB>2; final END/newline
    mandatory. EVENT id [ISO-date] / EFFECT locus measure signed-decimal or
    KEYED-EFFECT key locus measure signed-decimal / END-EVENT; supplied Event date
    creates explicit base evidence, omitted date creates none. Top-level VALIDITY-BASE
    event-id ISO-date; VALIDITY-REVISION revision-id event-id ISO-date;
    VALIDITY-CORRECTION BASE|REVISION target-id replacement-revision-id.
    Forward references allowed; no date/identity allocation, duplicate-base overwrite
    or latest-date/list winner.
    CORRECTION target replacement; DESCRIPTION event-id text (top-level, forward
    references allowed, one literal unescaped text field; empty/spaces valid,
    no tab/newline encoding); top-level MERCHANT event-id external-party-id or
    NONMERCHANT event-id (forward references, exact nonempty identities, no inference;
    no row means unresolved). Top-level ORIGINAL-AMOUNT root measure signed-decimal
    (forward references; positivity/root membership admitted by source, not parser).
    Top-level EXCHANGE event-id source-key destination-key (forward references,
    source-qualified shape; no inferred key/rate/fee/role or correction replacement).
    ZERO-ORIGIN locus measure; OPENING locus measure
    event-id; GROUP / REFLECT root / ASSERT locus measure signed-decimal / END-GROUP.
    At most one PRESENCE / REFLECT root / PRESENT locus measure / END-PRESENCE block.
    Absence is [None]; even an empty explicit block cannot be repeated/overwritten.
    Blank/comment/unknown and unsupported metadata/history rows refuse, never disappear.
    Semantic admission follows decoding; only Event key uniqueness is structurally
    admitted at END-EVENT.
    The parser does not Movement-narrow neutral Effects or manufacture support. *)
type t =
  { source : Loam_application.Actual_source.command
  ; zero_origins : Loam_domain.Effect_coordinate.t list
  ; openings : Loam_application.Current_quantity_query.opening list
  ; groups : Loam_application.Current_quantity_groups.group list
  ; presence : Loam_application.Current_quantity_query.presence option
  }
type error =
  | Syntax of { line : int; message : string }
  | Invalid_event of
      { line : int; event : Loam_domain.Identifier.Event.t; error : Loam_domain.Event.error }
val decode : string -> (t, error) result
