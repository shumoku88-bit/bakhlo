(** locus_roles.ml - Accounting roles for Loci and persistence for accounting-roles.tsv *)

type role = Daily_overlays.accounting_role = Asset | Liability | Equity | Income | Expense

let role_to_string = function
  | Asset -> "ASSET"
  | Liability -> "LIABILITY"
  | Equity -> "EQUITY"
  | Income -> "INCOME"
  | Expense -> "EXPENSE"

(* Display labels and parsing are Daily_overlays'; this module owns the file. *)
let role_label = Daily_overlays.role_to_string
let role_of_string = Daily_overlays.role_of_string

type t = (string * role) list

let empty = []

let set_role t locus = function
  | None -> List.remove_assoc locus t
  | Some role -> (locus, role) :: List.remove_assoc locus t

let of_string = Daily_overlays.parse_accounting_roles

let to_string t =
  let header = "LOAM-ACCOUNTING-ROLE-MAP\t1\n" in
  let lines =
    List.sort (fun (a, _) (b, _) -> String.compare a b) t
    |> List.map (fun (locus, role) -> Printf.sprintf "ROLE\t%s\t%s" locus (role_to_string role))
  in
  header ^ String.concat "\n" lines ^ if lines = [] then "" else "\n"

let file_name = "accounting-roles.tsv"
