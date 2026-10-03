(** Shared CLI lexical rule: exactly [+-]?[0-9]+. No whitespace, radix,
    underscore, float or normalization. Signed/zero/leading-zero/huge literals
    remain representable; this is not Movement/Actual/support admission. *)
val parse : string -> Loam_domain.Quantity.t option
