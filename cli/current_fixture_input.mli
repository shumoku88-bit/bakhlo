(** ONLY the noncanonical synthetic fixture grammar. Tabs separate exact nonempty
    unescaped identities. Header LOAM-OCAML-ACTUAL-FIXTURE<TAB>2; final END/newline
    mandatory. EVENT id ISO-date / EFFECT locus measure signed-decimal / END-EVENT;
    CORRECTION target replacement; ZERO-ORIGIN locus measure; GROUP / REFLECT root /
    ASSERT locus measure signed-decimal / END-GROUP. No blank/comment/unknown,
    metadata/keyed/other-support/history rows are ignored. Semantic admission follows
    decoding; the parser does not narrow neutral Effects or manufacture support. *)
type t =
  { source : Loam_application.Actual_source.command
  ; zero_origins : Loam_domain.Effect_coordinate.t list
  ; groups : Loam_application.Current_quantity_groups.group list
  }
type error = { line : int; message : string }
val decode : string -> (t, error) result
