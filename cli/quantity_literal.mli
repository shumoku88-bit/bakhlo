val parse : string -> Bakhlo_domain.Quantity.t option
(** Shared CLI lexical rule: exactly [+-]?[0-9]+. No whitespace, radix,
    underscore, float or normalization. Signed/zero/leading-zero/huge literals
    remain representable; this is not Movement/Actual/support admission. *)
