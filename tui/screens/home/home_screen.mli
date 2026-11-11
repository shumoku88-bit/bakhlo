(** Home: the bonsai entrance. Every key opens another route; it keeps no state. *)

type t

val create : unit -> t
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view
