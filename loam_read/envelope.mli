(** Physical LOAM HouseholdImage v2 framing only. UTF-8 Unicode scalar counts,
    ordered exact body bytes, unique unescaped section names. Unknown sections
    survive; absent is not present-empty. No semantic family admission or I/O. *)
type section = { name : string; body : string }
type t
type error =
  | Invalid_utf8 of { byte_offset : int }
  | Framing of { byte_offset : int; problem : string }
val of_string : string -> (t, error) result
val sections : t -> section list
