(** locus_roles.ml - Accounting roles for Loci and persistence for accounting-roles.tsv *)

type role = Daily_overlays.accounting_role = Asset | Liability | Equity | Income | Expense

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

let all_roles =
  [
    (Asset, "Asset");
    (Liability, "Liability");
    (Equity, "Equity");
    (Income, "Income");
    (Expense, "Expense");
  ]

type t = (string * role) list

let empty = []
let get_role t locus = List.assoc_opt locus t

let set_role t locus = function
  | None -> List.remove_assoc locus t
  | Some role -> (locus, role) :: List.remove_assoc locus t

let of_string text =
  let lines = String.split_on_char '\n' text in
  List.filter_map
    (fun line ->
      let line = String.trim line in
      if line = "" || String.starts_with ~prefix:";" line || String.starts_with ~prefix:"#" line
      then None
      else if String.starts_with ~prefix:"LOAM-ACCOUNTING-ROLE-MAP" line then None
      else
        let parts = String.split_on_char '\t' line in
        match parts with
        | [ "ROLE"; locus; role_str ] -> (
            match role_of_string role_str with
            | Some r -> Some (String.trim locus, r)
            | None -> None)
        | [ locus; role_str ] -> (
            match role_of_string role_str with
            | Some r -> Some (String.trim locus, r)
            | None -> None)
        | _ -> None)
    lines

let to_string t =
  let header = "LOAM-ACCOUNTING-ROLE-MAP\t1\n" in
  let lines =
    List.sort (fun (a, _) (b, _) -> String.compare a b) t
    |> List.map (fun (locus, role) -> Printf.sprintf "ROLE\t%s\t%s" locus (role_to_string role))
  in
  header ^ String.concat "\n" lines ^ if lines = [] then "" else "\n"

let file_name = "accounting-roles.tsv"
