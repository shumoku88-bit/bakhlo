(* Explicit calendar-year scope for an S-expression Daily book.
   This pure gate does not derive opening balances or resolve cross-year links. *)
module B = Daily_book

let valid_year year = year >= 1 && year <= 9999

let of_string text =
  if String.length text <> 4 ||
     not (String.for_all (fun c -> c >= '0' && c <= '9') text)
  then Error "annual-year-invalid"
  else
    match int_of_string_opt text with
    | Some year when valid_year year -> Ok year
    | _ -> Error "annual-year-invalid"

let file_name year = Printf.sprintf "%04d.sexp" year

let check_path ~year path =
  if not (valid_year year) then Error "annual-year-invalid"
  else if Filename.basename path <> file_name year then
    Error "annual-file-name-mismatch"
  else Ok ()

let check_book ~year book =
  if not (valid_year year) then Error "annual-year-invalid"
  else
    let prefix = Printf.sprintf "%04d-" year in
    match List.find_opt
      (fun (e : B.entry) -> not (String.starts_with ~prefix e.day))
      (B.entries book)
    with
    | None -> Ok ()
    | Some e -> Error ("annual-entry-outside-year:" ^ e.id)
