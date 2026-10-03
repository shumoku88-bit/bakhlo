(** Pure decoding of ONLY the noncanonical synthetic fixture grammar. Tabs separate
    fields; identities remain exact, nonempty, unescaped. EVENT id ISO-date / EFFECT
    locus measure signed-decimal / END-EVENT; CORRECTION target replacement; GROUP /
    REFLECT root / ASSERT locus measure signed-decimal / END-GROUP. Header is
    LOAM-OCAML-ACTUAL-FIXTURE<TAB>1; END and final newline mandatory. No blank/comment,
    extra/unknown/keyed/metadata/support-family rows are silently ignored. *)
type error = { line : int; message : string }
val decode : string -> (Loam_application.Actual_quantity_preview.command, error) result

type current =
  { source : Loam_application.Actual_source.command
  ; zero_origins : Loam_domain.Effect_coordinate.t list
  ; groups : Loam_application.Current_quantity_groups.group list
  }

(** ONLY version 2, same blocks plus top-level ZERO-ORIGIN locus measure.
    Still synthetic/noncanonical. Full metadata, keys, opening/presence, Exchange,
    reversal and validity revisions refuse. Source admission is a separate step. *)
val decode_current : string -> (current, error) result
