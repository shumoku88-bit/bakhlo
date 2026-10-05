val render : Bakhlo_application.Current_quantity_answer.answer -> string
(** Friendly terminal rendering of ONLY the projected quantity answer. Does not accept
    a raw query image/answer or acquire evidence. No source/Effect/history inspection,
    hidden arithmetic, guessed scalar, currency/display-scale inference or AI/NL model.
    Unknown guidance names checks, not an asserted cause, auto-repair or recording action.
    Conditional on supplied evidence; not household truth or spending permission. *)
