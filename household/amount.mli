(** Exact money at the text boundary.

    Amounts are integers in the currency's smallest unit (quanta), not floats.
    The caller supplies the admitted Measure scale [decimals], in [0..9]:
    at scale 0, [123] means 123 whole units; at scale 2, it means 1.23.
    This module does not look up Measures or perform I/O.

    Two input contracts are deliberately separate: [parse_positive] can
    calculate a receipt amount, while [parse_signed] reads a signed decimal,
    including zero. Their common unit lets either result be printed by [format]. *)

val format : decimals:int -> Z.t -> string
(** Signed decimal display with exactly [decimals] fractional digits.
    At scale 2, [-1] prints as [-0.01]; no quantum is lost to rounding. *)

val parse_positive : decimals:int -> string -> (Z.t, string) result
(** Positive decimal or arithmetic expression (+, -, *, /, parentheses).

    At scale 0, [(500+300)/2] gives [400] and [(100/3)*3] gives [100],
    but [100/3] is refused: intermediate fractions are exact, and the final
    result must be positive and fit the scale. No rounding is performed.

    A decimal literal must also respect the written precision: at scale 2,
    [1.000] is refused, while the expression [1.000+0] gives [100] quanta.
    Full-width digits and operators are normalized before parsing. Commas
    must form groups of three after an initial group of one to three digits. *)

val parse_signed : decimals:int -> string -> (Z.t, string) result
(** Decimal text including zero and an optional leading ASCII sign; no expressions.
    At scale 2, [-1.23] gives [-123] quanta and [0] gives [0].

    Outer ASCII whitespace is trimmed before the sign is read, then full-width
    digits are normalized. A full-width leading sign is not accepted.
    Decimal precision and grouping follow the literal rules of [parse_positive]. *)
