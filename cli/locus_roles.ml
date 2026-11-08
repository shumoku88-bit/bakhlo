type role = Bakhlo_book_txt.Book_txt.role = Asset | Liability | Equity | Income | Expense

let role_label = function
  | Asset -> "Asset"
  | Liability -> "Liability"
  | Equity -> "Equity"
  | Income -> "Income"
  | Expense -> "Expense"

type t = (string * role) list

let empty = []

(* Kept in Locus order, as the book has always written them. *)
let set_role t locus role =
  let others = List.remove_assoc locus t in
  let roles = match role with None -> others | Some role -> (locus, role) :: others in
  List.sort (fun (a, _) (b, _) -> String.compare a b) roles
