(** Pure decoding of ONLY the noncanonical synthetic fixture grammar. Tabs separate
    fields; identities remain exact, nonempty, unescaped. EVENT id ISO-date / EFFECT
    locus measure signed-decimal / END-EVENT; CORRECTION target replacement; GROUP /
    REFLECT root / ASSERT locus measure signed-decimal / END-GROUP. Header is
    LOAM-OCAML-ACTUAL-FIXTURE<TAB>1; END and final newline mandatory. No blank/comment,
    extra/unknown/keyed/metadata/support-family rows are silently ignored. *)
type error = { line : int; message : string }
val decode : string -> (Loam_application.Actual_quantity_preview.command, error) result
