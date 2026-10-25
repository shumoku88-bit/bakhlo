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

val to_txt : Daily_book.t -> sidecars -> (T.t, string) result
(** Refuses what [book.txt] v0 cannot represent: presence with coordinates, a malformed
    sidecar, and anything {!T.of_string} refuses in the printed result. Effect keys are
    kept. The value returned is the one read back from that text. *)

val to_text : Daily_book.t -> sidecars -> (string, string) result
(** [T.to_string] of {!to_txt}, without printing twice: the text {!to_txt} admitted. *)

val of_txt : T.t -> (Daily_book.t * sidecars, string) result
(** Admitted by {!Daily_book.of_payload}. An exchange refers to the only negative Effect
    of its source Measure and the only positive one of its destination Measure, by their
    keys; an unkeyed one gets a fixed key. Any other shape refuses. *)

val text : ?sidecars:sidecars -> Daily_book.t -> string
(** [T.to_string] of {!to_txt}, for fixtures and tools. Raises [Invalid_argument] with
    the refusal code. *)

val changes :
  T.book -> Daily_book.t -> ?sidecars:sidecars -> Book_log.op list -> (T.book, string) result
(** [changes txt after ops]: [txt] with the changes [ops] made, [after] being the book
    after them; with [sidecars], also its roles and Attention. Admitted by
    {!T.change}, so the untouched TXs are neither checked nor printed again. When
    [txt] holds [to_txt] of the book before the operations, the result holds
    [to_txt after] (test/daily_book_oracle_tests.ml). *)
