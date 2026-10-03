(** ONLY the noncanonical synthetic fixture grammar. Tabs separate exact nonempty
    unescaped identities. Header LOAM-OCAML-ACTUAL-FIXTURE<TAB>2; final END/newline
    mandatory. EVENT id ISO-date / EFFECT locus measure signed-decimal or
    KEYED-EFFECT key locus measure signed-decimal / END-EVENT;
    CORRECTION target replacement; ZERO-ORIGIN locus measure; OPENING locus measure
    event-id; GROUP / REFLECT root / ASSERT locus measure signed-decimal / END-GROUP.
    At most one PRESENCE / REFLECT root / PRESENT locus measure / END-PRESENCE block.
    Absence is [None]; even an empty explicit block cannot be repeated/overwritten.
    No blank/comment/unknown, metadata/history rows are ignored. Semantic admission follows
    decoding; only Event key uniqueness is structurally admitted at END-EVENT.
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
