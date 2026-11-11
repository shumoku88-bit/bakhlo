(* English-first source-message catalog. Do not apply tr to household identifiers,
   labels, descriptions, or stored data. A future locale has one explicit seam. *)
let tr message = message

(* Translate the template, then insert household values, which are never translated. *)
let format_message format =
  Printf.sprintf (Scanf.format_from_string (tr (string_of_format format)) format)
