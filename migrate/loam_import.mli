(** One-time import of a LOAM household into a Bakhlo book (user decision
    2026-10-21). Pure: the caller reads one coherent generation and writes the
    result. The book holds the current state only; correction history, retired or
    replaced plans, superseded Merchant facts and budget sections stay in the LOAM
    record. Settlement relations and anything the reader cannot represent refuse.
    The result is admitted by {!Bakhlo_sexp.Daily_book.of_payload} and every
    coordinate's quantity and premise must equal LOAM's own image. *)

type input = {
  household : string;  (** [household.loam] bytes *)
  measure_presentation : string;  (** [config/measure-presentation.tsv] bytes *)
  locus_catalog : string option;  (** [config/locus-catalog.tsv] bytes, if present *)
}

val book : input -> (Bakhlo_sexp.Daily_book.t, string) result
(** [Error] is a stable refusal code; nothing is partially imported. *)

val attention : string -> (string option, string) result
(** The household's Attention section body, which Bakhlo's Attention file reads
    unchanged; [None] when the household has no Attention section. *)

val accounting_roles : string -> (string, string) result
(** The household AccountingRole section, which is Bakhlo's [accounting-roles.tsv];
    a missing, malformed, duplicated or space-padded row refuses. *)
