(** Why an amount was not taken, in one sentence the household can act on. *)

val say :
  book:Bakhlo_household.Book.t ->
  measure:string ->
  ?field:string ->
  ?signed:bool ->
  string ->
  string
(** [say ~book ~measure ~field why]: the core's refusal code [why] from reading an
    amount in [measure], as ["<field>: <what to do>."]. [field] names the box the
    amount was typed in (default ["Amount"]); [signed] for a seen balance, which
    takes a sign and no arithmetic. amount_refusal.ml lists every sentence. *)
