(** One-time conversion of a Bakhlo household into the common [book.txt]
    (docs/COMMON_FORMAT.ja.md, user decision 2026-10-24). Pure: the caller reads one
    coherent copy and writes the result. What the format cannot represent refuses;
    nothing is dropped except empty memos, which the format writes as no memo. *)

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

val convert : input -> (Bakhlo_book_txt.Book_txt.t * report, string) result
(** The result was printed, admitted by {!Bakhlo_book_txt.Book_txt.of_string} and read
    back equal. It was then compared with the source book: the same entries in recorded
    order (id, date, memo, Effects, reversal, original amount, Merchant, exchange), the
    same plans, and an equal current quantity at every coordinate that any Effect or
    support line names (exact equals [Known], no support equals [Unknown]).
    [Error] is a stable refusal code. *)
