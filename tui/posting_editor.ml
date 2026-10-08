(* Multiple postings editor state and pure manipulations. *)
module B = Bakhlo_sexp.Daily_book
module R = Posting_draft

type field =
  | Posting_day
  | Posting_memo
  | Posting_locus
  | Posting_sign
  | Posting_amount

type t = {
  draft : R.t;
  row : int;
  field : field;
  visible : bool;
  notice : string option;
}

let create draft = {
  draft;
  row = 0;
  field = Posting_amount;
  visible = true;
  notice = None;
}

let next_field = function
  | Posting_day -> Posting_memo
  | Posting_memo -> Posting_locus
  | Posting_locus -> Posting_sign
  | Posting_sign -> Posting_amount
  | Posting_amount -> Posting_day

let previous_field = function
  | Posting_day -> Posting_amount
  | Posting_memo -> Posting_day
  | Posting_locus -> Posting_memo
  | Posting_sign -> Posting_locus
  | Posting_amount -> Posting_sign

let field_label = function
  | Posting_day -> "日付"
  | Posting_memo -> "メモ"
  | Posting_locus -> "科目"
  | Posting_sign -> "符号（← - / → +）"
  | Posting_amount -> "金額（正の値）"

let selected_row t = List.nth_opt t.draft.rows t.row

let update_selected_row t f =
  {
    t with
    draft =
      {
        t.draft with
        rows = List.mapi (fun n row -> if n = t.row then f row else row) t.draft.rows;
      };
    notice = None;
  }

let update_row_at t n f =
  {
    t with
    draft =
      {
        t.draft with
        rows = List.mapi (fun i row -> if i = n then f row else row) t.draft.rows;
      };
    notice = None;
  }

let set_notice t notice = { t with notice }

let move_row t step =
  let count = List.length t.draft.rows in
  { t with row = max 0 (min (max 0 (count - 1)) (t.row + step)) }

let move_field t f = { t with field = f t.field }

let toggle_visibility t = { t with visible = not t.visible }
let hide t = { t with visible = false }
let show t = { t with visible = true }

let add_row t =
  let rows = t.draft.rows @ [ { R.key = None; locus = ""; negative = false; amount = "" } ] in
  {
    t with
    draft = { t.draft with rows };
    row = List.length t.draft.rows;
    field = Posting_locus;
    notice = None;
  }

let remove_row t =
  let rows = List.filteri (fun n _ -> n <> t.row) t.draft.rows in
  {
    t with
    draft = { t.draft with rows };
    row = min t.row (max 0 (List.length rows - 1));
    notice = None;
  }

let set_sign t negative =
  update_selected_row t (fun row -> { row with negative })

let status book t =
  match R.residual book t.draft with
  | Error why -> "下書き差額不明: " ^ why
  | Ok n ->
      "下書き差額: "
      ^ B.format book t.draft.measure n
      ^ " " ^ t.draft.measure
      ^ if Z.equal n Z.zero then "（0・数量のみ整合）" else "（0でない・記帳不可）"

let line book n (row : R.row) measure =
  Printf.sprintf "%d %s%s %s %s [%s]" (n + 1)
    (if row.negative then "-" else "+")
    row.amount measure (B.label book row.locus) row.locus
