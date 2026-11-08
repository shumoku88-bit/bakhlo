(** Every (Locus, Measure) an entry touched in a window, with its traffic. Pinned in
    test/reports ([TRANSACTIONS-FLOW]). *)

type move = { day : string; id : string; amount : Z.t }
(** One effect on the row: its entry's day and ID and the signed amount. *)

type row = {
  locus : string;
  measure : string;
  increase : Z.t;  (** The sum of the positive effects. *)
  decrease : Z.t;  (** The sum of the negative effects (negative or zero). *)
  net : Z.t;
  gross : Z.t;  (** Increase minus decrease: all the traffic. *)
  moves : move list;  (** In recorded order. *)
}

val compute : Book.t -> start:string -> stop:string -> row list
(** The entries dated in [\[start, stop)]: the largest gross first, then by Locus and
    Measure. *)
