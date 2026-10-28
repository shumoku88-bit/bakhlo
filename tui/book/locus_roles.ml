(** locus_roles.ml - Accounting roles for Loci and the accounting-roles.tsv text format *)

type role = Bakhlo_book_txt.Book_txt.role = Asset | Liability | Equity | Income | Expense

let role_to_string = function
  | Asset -> "ASSET"
  | Liability -> "LIABILITY"
  | Equity -> "EQUITY"
  | Income -> "INCOME"
  | Expense -> "EXPENSE"

let role_label = function
  | Asset -> "Asset"
  | Liability -> "Liability"
  | Equity -> "Equity"
  | Income -> "Income"
  | Expense -> "Expense"

let role_of_string s =
  match String.uppercase_ascii (String.trim s) with
  | "ASSET" -> Some Asset
  | "LIABILITY" -> Some Liability
  | "EQUITY" -> Some Equity
  | "INCOME" -> Some Income
  | "EXPENSE" -> Some Expense
  | _ -> None

type t = (string * role) list

let empty = []

let set_role t locus = function
  | None -> List.remove_assoc locus t
  | Some role -> (locus, role) :: List.remove_assoc locus t

(* accounting-roles.tsv: one "ROLE<TAB>Locus<TAB>role" (or "Locus<TAB>role") row per
   Locus. Blank lines, ";" or "#" comments and the LOAM-ACCOUNTING-ROLE-MAP header
   are skipped; any other row, an unknown role or a repeated Locus refuses the whole
   file, so a typo never silently leaves a Locus without its role. *)
let of_string text =
  let row number line =
    let refuse why = Error (Printf.sprintf "line %d: %s" number why) in
    let assign locus role =
      let locus = String.trim locus in
      match role_of_string role with
      | _ when locus = "" -> refuse "the Locus is empty"
      | Some role -> Ok (Some (locus, role))
      | None -> refuse (Printf.sprintf "unknown role %S" (String.trim role))
    in
    let line = String.trim line in
    if
      line = ""
      || String.starts_with ~prefix:";" line
      || String.starts_with ~prefix:"#" line
      || String.starts_with ~prefix:"LOAM-ACCOUNTING-ROLE-MAP" line
    then Ok None
    else
      match String.split_on_char '\t' line with
      | [ "ROLE"; locus; role ] | [ locus; role ] -> assign locus role
      | _ -> refuse "expected ROLE<TAB>Locus<TAB>role"
  in
  let rec loop number acc = function
    | [] -> Ok (List.rev acc)
    | line :: rest -> (
        match row number line with
        | Error _ as error -> error
        | Ok None -> loop (number + 1) acc rest
        | Ok (Some (locus, _)) when List.mem_assoc locus acc ->
            Error (Printf.sprintf "line %d: Locus %S has a second role" number locus)
        | Ok (Some assignment) -> loop (number + 1) (assignment :: acc) rest)
  in
  loop 1 [] (String.split_on_char '\n' text)

let to_string t =
  let header = "LOAM-ACCOUNTING-ROLE-MAP\t1\n" in
  let lines =
    List.sort (fun (a, _) (b, _) -> String.compare a b) t
    |> List.map (fun (locus, role) -> Printf.sprintf "ROLE\t%s\t%s" locus (role_to_string role))
  in
  header ^ String.concat "\n" lines ^ if lines = [] then "" else "\n"

let file_name = "accounting-roles.tsv"
