(* The accounting-role and Attention sections of book.txt in the text formats the
   screens read (accounting-roles.tsv, attention.loam), and book.txt text for
   fixtures and tools. *)
module T = Bakhlo_book_txt.Book_txt
module B = Daily_book

type sidecars = { roles : string; attention : string }

let no_sidecars = { roles = ""; attention = "" }

exception Refused of string

let refuse why = raise (Refused why)

let roles_header = "LOAM-ACCOUNTING-ROLE-MAP\t1"
let attention_header = "LOAM-ATTENTION-MEMORY\t1"

(* The header, then rows; only the final line may be empty. "" is no file. *)
let rows ~header text =
  if text = "" then []
  else
    match String.split_on_char '\n' text with
    | first :: rest when first = header ->
        let rec body = function
          | [] | [ "" ] -> []
          | "" :: _ -> refuse "blank-row"
          | r :: rest -> r :: body rest
        in
        body rest
    | _ -> refuse "bad-header"

let role_of = function
  | "ASSET" -> T.Asset
  | "LIABILITY" -> T.Liability
  | "EQUITY" -> T.Equity
  | "INCOME" -> T.Income
  | "EXPENSE" -> T.Expense
  | _ -> refuse "accounting-role-kind"

let role_name = function
  | T.Asset -> "ASSET"
  | T.Liability -> "LIABILITY"
  | T.Equity -> "EQUITY"
  | T.Income -> "INCOME"
  | T.Expense -> "EXPENSE"

let roles_of text =
  List.map
    (fun row ->
      match String.split_on_char '\t' row with
      | [ "ROLE"; l; kind ] -> (l, role_of kind)
      | _ -> refuse "accounting-role-row")
    (try rows ~header:roles_header text with Refused why -> refuse ("accounting-roles-" ^ why))

(* attention.loam rows are book.txt's ITEM/CLOSE lines: admit them through Book_txt. *)
let attention_of text =
  let body = try rows ~header:attention_header text with Refused why -> refuse ("attention-" ^ why) in
  match T.of_string (String.concat "" (List.map (fun r -> r ^ "\n") (("BOOK\t1" :: body) @ [ "END" ]))) with
  | Ok t -> (t.items, t.closes)
  | Error e -> refuse ("attention-" ^ T.code_name e.code)

let lines header rows = if rows = [] then "" else String.concat "\n" (header :: rows) ^ "\n"

let attention_text (items, closes) =
  let printed = T.to_string { (T.of_string "BOOK\t1\nEND\n" |> Result.get_ok) with items; closes } in
  let body = String.split_on_char '\n' printed |> List.filter (fun l -> l <> "" && l <> "BOOK\t1" && l <> "END") in
  lines attention_header body

let roles_text roles = lines roles_header (List.map (fun (l, r) -> "ROLE\t" ^ l ^ "\t" ^ role_name r) roles)
let sidecars_of book = { roles = roles_text (B.roles book); attention = attention_text (B.attention book) }

let with_sidecars book s =
  match (roles_of s.roles, attention_of s.attention) with
  | roles, (items, closes) -> B.with_sections book ~roles ~items ~closes
  | exception Refused why -> Error why

let text ?(sidecars = no_sidecars) book =
  match with_sidecars book sidecars with
  | Ok book -> T.print (B.txt book)
  | Error why -> invalid_arg why

let book text =
  match T.read text with
  | Error e -> invalid_arg (Printf.sprintf "%s at line %d" (T.code_name e.code) e.line)
  | Ok txt -> ( match B.of_txt txt with Ok book -> book | Error why -> invalid_arg why)
