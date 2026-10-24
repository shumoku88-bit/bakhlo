(** Daily_book <-> the common [book.txt] ({!Bakhlo_book_txt.Book_txt}). The book also
    carries the accounting roles and Attention, which the TUI still reads in their
    sidecar text formats; [sidecars] are those texts. Pure.

    For a [book.txt] value [b], [to_txt (of_txt b)] is [b] again, so loading and saving
    without a change rewrites the same bytes. The other direction keeps every entry,
    plan and current quantity but may normalise representation (labels for unlabelled
    loci, an empty memo as no memo, a reflected-root cut as ANCHOR plus ALSO). *)

module T = Bakhlo_book_txt.Book_txt

type sidecars = {
  roles : string;  (** [accounting-roles.tsv] text; [""] when there are no roles *)
  attention : string;  (** [attention.loam] text; [""] when there is no Attention *)
}

val no_sidecars : sidecars

type normalised = {
  added_loci : string list;  (** LOCUS lines for loci without a label *)
  hidden_loci : string list;  (** loci outside the approved new-write loci *)
  empty_memos : int;  (** [Some ""] memos written as no memo *)
}

val to_txt : Daily_book.t -> sidecars -> (T.t * normalised, string) result
(** Refuses what [book.txt] v0 cannot represent: presence with coordinates, Effect keys
    outside an exchange, a malformed sidecar, and anything {!T.of_string} refuses in the
    printed result. The value returned is the one read back from that text. *)

val of_txt : T.t -> (Daily_book.t * sidecars, string) result
(** Admitted by {!Daily_book.of_payload}. An exchange's two keyed Effects are the only
    negative Effect of its source Measure and the only positive one of its destination
    Measure; any other shape refuses. *)

val text : ?sidecars:sidecars -> Daily_book.t -> string
(** [T.to_string] of {!to_txt}, for fixtures and tools. Raises [Invalid_argument] with
    the refusal code. *)
