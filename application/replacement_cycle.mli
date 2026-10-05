(** Private mechanism for single-successor replacement relations. Callers own
    endpoint closure, uniqueness and semantic association; no source admission here. *)
module Make (Key : sig
  type t

  val equal : t -> t -> bool

  include Base.Comparator.S with type t := t
end) : sig
  val check : successor:(Key.t -> Key.t option) -> starts:Key.t list -> (unit, Key.t list) result
  (** Starts in supplied order; returns a real edge-following cycle, repeating its
      start. No chronology/rotation authority. Persistent sets and tail recursion. *)
end
