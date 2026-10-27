(** Exact amount text, independent of the book and its Measure lookup.
    [decimals] is the admitted Measure scale, in [0..9]. *)

val format : decimals:int -> Z.t -> string
(** Signed decimal display with exactly [decimals] fractional digits. *)

val parse_positive : decimals:int -> string -> (Z.t, string) result
(** Positive decimal or arithmetic expression (+, -, *, /, parentheses).
    Decimal text must fit the scale; expressions use exact rational arithmetic and
    their final result must be positive and fit the scale. No rounding.
    Full-width digits and operators are normalized before parsing. *)

val parse_signed : decimals:int -> string -> (Z.t, string) result
(** Decimal text including zero and an optional leading ASCII sign; no expressions.
    Outer ASCII whitespace is trimmed before the sign is read, then full-width
    digits are normalized. Decimal precision and grouping follow [parse_positive]. *)
