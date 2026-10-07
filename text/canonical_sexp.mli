(** Minimal syntax-only boundary for the candidate canonical S-expression surface.

    This module recognizes one leading [(bakhlo 1)] marker and retains every following
    top-level S-expression structurally and in order. It does not decode household schema,
    admit evidence, infer missing collections, perform I/O, preserve comments/layout bytes,
    or authorize canonical storage. *)

type syntax_error = {
  line : int;
  column : int;
  message : string;
}

type error =
  | Syntax of syntax_error
  | Missing_format_marker
  | Invalid_format_marker
  | Unsupported_format_version of string
  | Duplicate_format_marker

type t
(** Opaque parsed syntax document. Unknown body forms are retained structurally. *)

val of_string : string -> (t, error) result
(** Parse all top-level forms and require exactly one leading [(bakhlo 1)] marker. *)

val to_string : t -> string
(** Deterministic human-readable S-expression rendering.

    Structural information is preserved across parse/render/parse. Original whitespace,
    quoting choices and comments are not promised to survive. *)
