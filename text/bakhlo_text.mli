module Input = Input
(** Pure experimental representation/read entrance; lexical helper stays private. *)

module Read = Read

module Propose = Propose
(** Pure whole-admitted ordinary Movement candidates for this experimental profile;
    no canonical encoder/storage choice or permission to publish. *)

module Canonical_sexp = Canonical_sexp
(** Syntax-only probe for the candidate versioned S-expression surface. It is not
    a household schema decoder, admission path, canonical store or publication API. *)
