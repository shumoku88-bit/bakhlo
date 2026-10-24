(** One-time conversion of a Bakhlo household into the common [book.txt]
    (docs/COMMON_FORMAT.ja.md, user decision 2026-10-24), with an independent comparison.
    Pure: the caller reads one coherent copy and writes the result. The conversion itself
    is {!Bakhlo_sexp.Daily_txt.to_txt}. *)

type input = {
  book : string;  (** [book.sexp] bytes: snapshot plus appended records *)
  accounting_roles : string option;  (** [config/accounting-roles.tsv], if present *)
  attention : string option;  (** [attention.loam], if present *)
  settlements : string option;  (** [settlements.tsv]; any content refuses (not in v0) *)
}

type report = {
  entries : int;
  plans : int;
  coordinates : int;  (** Locus x Measure pairs whose current quantity was compared *)
  known : int;
  unknown : int;
  added_loci : string list;  (** LOCUS lines for loci the book had no label for *)
  hidden_loci : string list;  (** loci outside the book's approved new-write loci *)
  empty_memos : int;  (** [Some ""] memos written as no memo *)
}

val check : Bakhlo_sexp.Daily_book.t -> Bakhlo_book_txt.Book_txt.t -> (report, string) result
(** Compare a book with its [book.txt] value: the same entries in recorded order (id,
    date, memo with an empty memo as none, Effects, reversal, original amount, Merchant,
    exchange presence), the same plans, and an equal current quantity at every coordinate
    any Effect or support line names (Daily_book's exact answer equals [Known], no support
    equals [Unknown]). The normalisation fields of the report are empty. *)

val convert : input -> (Bakhlo_book_txt.Book_txt.t * report, string) result
(** Load, convert with {!Bakhlo_sexp.Daily_txt.to_txt}, then {!check}. [Error] is a stable
    refusal code; nothing is partially converted. *)
