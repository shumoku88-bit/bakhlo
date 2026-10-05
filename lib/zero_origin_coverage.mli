type t
(** Independent finite declaration that a coordinate's selected history starts
    at exact zero. Activity, presentation selection, and catalog membership are
    not origin evidence. Construction does not verify the declaration's truth. *)

type error = Duplicate_coordinate of { position : int; coordinate : Effect_coordinate.t }

val empty : t
(** No coordinate has origin support. This does not establish any zero balance. *)

val of_coordinates : Effect_coordinate.t list -> (t, error) result
(** Reject the first repeated exact coordinate, at its one-based input position.
    Do not silently normalize independently supplied factual evidence. *)

val covers : t -> Effect_coordinate.t -> bool
