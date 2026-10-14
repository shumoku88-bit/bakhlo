(* Scheduled occurrence creation session aligned with LOAM ScheduledCreation.lean.
   Edits one explicit due date plus signed single-Measure postings (2 to 6 rows).
   No Description, recurrence, routing, or Actual evidence. *)

module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module A = Daily_actions
module O = Daily_overlays
module Panel = Ui_panel
module Fm = Daily_form
let tr = Ui_text.tr

type row = { locus : string; amount : string }

type draft_tx = {
  scheduled_on : string;
  measure : string;
  changes : (string * Z.t) list;
  positive_total : Z.t;
}

type mode =
  | Editing
  | Preview of {
      draft : draft_tx;
      choice : int; (* 0: Publish, 1: Edit, 2: Cancel *)
      scroll : int;
    }

type t = {
  book : B.t;
  measure : string;
  day : string;
  rows : row list;
  focus : int;
  cursor : int option;
  candidate : int;
  notice : string;
  mode : mode;
}

type outcome =
  | Updated of t
  | Closed
  | Publish of draft_tx

let is_preview t =
  match t.mode with
  | Preview _ -> true
  | Editing -> false

let day t = t.day
let measure t = t.measure
let notice t = t.notice
let focus t = t.focus
let rows_count t = List.length t.rows
let with_notice t notice = { t with notice }

let with_publish_error t message =
  { t with mode = Editing; notice = message }

let create ~book ~day ~measure =
  {
    book;
    measure;
    day;
    rows = [ { locus = ""; amount = "" }; { locus = ""; amount = "" } ];
    focus = 0;
    cursor = None;
    candidate = 0;
    notice = "";
    mode = Editing;
  }

let create_from_scheduled ~book (plan : B.plan) =
  let rows =
    List.map
      (fun (locus, quanta) ->
        let amount_str =
          if Z.sign quanta > 0 then "+" ^ Z.to_string quanta
          else Z.to_string quanta
        in
        { locus; amount = amount_str })
      plan.changes
  in
  let count = List.length rows in
  if count < 2 then
    Error "This Scheduled occurrence is outside the practical balanced-Movement next-Scheduled editor."
  else if count > 6 then
    Error "This Scheduled occurrence has more than six postings; the next-Scheduled editor will not truncate it."
  else
    Ok
      {
        book;
        measure = plan.measure;
        day = "";
        rows;
        focus = 0;
        cursor = None;
        candidate = 0;
        notice = "Completion is already published. Enter the next due date, or Esc for completion only.";
        mode = Editing;
      }

let field_count t = 1 + (List.length t.rows * 2)
let first_action t = field_count t
let action_count = 4 (* Add, Drop, Preview, Cancel *)
let focus_count t = first_action t + action_count

let move_focus t back =
  let count = focus_count t in
  let delta = if back then -1 else 1 in
  let next = (t.focus + delta + count) mod count in
  { t with focus = next; cursor = None; candidate = 0; notice = "" }

let active_locus t =
  if t.focus = 0 || t.focus >= first_action t then None
  else
    let offset = t.focus - 1 in
    if offset mod 2 <> 0 then None
    else
      let index = offset / 2 in
      match List.nth_opt t.rows index with
      | Some r -> Some r.locus
      | None -> None

let candidates t =
  match active_locus t with
  | None -> []
  | Some query -> O.locus_candidates t.book query

let move_candidate t back =
  match active_locus t with
  | None -> { t with candidate = 0 }
  | Some _ ->
      let options = candidates t in
      let count = List.length options in
      if count = 0 then { t with candidate = 0 }
      else
        let delta = if back then -1 else 1 in
        let next = (t.candidate + delta + count) mod count in
        { t with candidate = next }

let value t =
  if t.focus = 0 then t.day
  else if t.focus < first_action t then
    let offset = t.focus - 1 in
    let index = offset / 2 in
    match List.nth_opt t.rows index with
    | None -> ""
    | Some r -> if offset mod 2 = 0 then r.locus else r.amount
  else ""

let set_value t v =
  if t.focus = 0 then { t with day = v }
  else if t.focus < first_action t then
    let offset = t.focus - 1 in
    let index = offset / 2 in
    let rows =
      List.mapi
        (fun i r ->
          if i = index then
            if offset mod 2 = 0 then { r with locus = v }
            else { r with amount = v }
          else r)
        t.rows
    in
    { t with rows }
  else t

let accept_candidate t =
  match active_locus t with
  | None -> t
  | Some _ ->
      let options = candidates t in
      if options = [] then t
      else
        let index = t.candidate mod List.length options in
        let id = List.nth options index in
        let next = set_value t id in
        { next with cursor = None; candidate = 0; notice = "" }

let accept_candidate_and_advance t =
  let committed = accept_candidate t in
  move_focus committed false

let append_row t =
  if List.length t.rows >= 6 then
    { t with notice = tr "This editor supports up to six posting rows." }
  else
    let rows = t.rows @ [ { locus = ""; amount = "" } ] in
    let new_focus = 1 + ((List.length rows - 1) * 2) in
    { t with rows; focus = new_focus; cursor = None; candidate = 0; notice = "" }

let drop_row t =
  if List.length t.rows <= 2 then t
  else
    let rec drop_last = function
      | [] | [ _ ] -> []
      | x :: xs -> x :: drop_last xs
    in
    let rows = drop_last t.rows in
    { t with rows; focus = 0; cursor = None; candidate = 0; notice = "" }

(* Ctrl-U: automatic balancing remainder / suspense row filling *)
let auto_fill_suspense t =
  let parse_amt str =
    let clean = String.trim str in
    let clean =
      if String.starts_with ~prefix:"+" clean then
        String.sub clean 1 (String.length clean - 1)
      else clean
    in
    try Some (int_of_string clean) with _ -> None
  in
  let is_suspense loc =
    let l = String.lowercase_ascii loc in
    l = "unresolved" || Base.String.is_prefix l ~prefix:"suspense"
  in
  let total = ref 0 in
  let non_empty_count = ref 0 in
  let suspense_idx = ref None in
  List.iteri
    (fun i r ->
      if String.trim r.locus <> "" || String.trim r.amount <> "" then
        incr non_empty_count;
      if is_suspense r.locus then suspense_idx := Some i;
      match parse_amt r.amount with
      | Some a -> total := !total + a
      | None -> ())
    t.rows;
  let remainder = - !total in
  if remainder = 0 then
    match !suspense_idx with
    | Some idx when List.length t.rows > 2 ->
        let rows = List.filteri (fun i _ -> i <> idx) t.rows in
        { t with rows; notice = tr "Remainder balanced; removed suspense posting." }
    | _ -> { t with notice = tr "Postings are already balanced." }
  else
    let rem_str =
      if remainder > 0 then "+" ^ string_of_int remainder
      else string_of_int remainder
    in
    match !suspense_idx with
    | Some idx ->
        let rows =
          List.mapi
            (fun i r -> if i = idx then { r with amount = rem_str } else r)
            t.rows
        in
        { t with rows; notice = tr "Adjusted suspense posting to balance remainder." }
    | None ->
        let empty_idx =
          let rec find i = function
            | [] -> None
            | r :: rest ->
                if String.trim r.locus = "" && String.trim r.amount = "" then Some i
                else find (i + 1) rest
          in
          find 0 t.rows
        in
        match empty_idx with
        | Some idx ->
            let rows =
              List.mapi
                (fun i r ->
                  if i = idx then { locus = "unresolved"; amount = rem_str } else r)
                t.rows
            in
            { t with rows; notice = tr "Filled empty posting with suspense remainder." }
        | None ->
            if List.length t.rows < 6 then
              let rows = t.rows @ [ { locus = "unresolved"; amount = rem_str } ] in
              { t with rows; notice = tr "Added suspense posting to balance remainder." }
            else
              { t with notice = tr "Cannot add suspense posting; maximum of 6 rows reached." }

let insert t text =
  let cur_val = value t in
  if t.focus = 0 then
    let allowed =
      let buf = Buffer.create (String.length text) in
      String.iter
        (fun c ->
          if (c >= '0' && c <= '9') || c = '-' then Buffer.add_char buf c)
        text;
      Buffer.contents buf
    in
    if allowed = "" then t
    else
      let updated, cursor = Fm.insert_at ~value:cur_val ~cursor:t.cursor allowed in
      let truncated =
        if String.length updated > 10 then String.sub updated 0 10 else updated
      in
      let next = set_value t truncated in
      { next with cursor = Some (min (String.length truncated) cursor); candidate = 0; notice = "" }
  else if t.focus < first_action t && (t.focus - 1) mod 2 = 1 then
    (* Amount field: only digits, signs, commas *)
    let allowed =
      let buf = Buffer.create (String.length text) in
      String.iter
        (fun c ->
          if (c >= '0' && c <= '9') || c = '-' || c = '+' || c = ',' then
            Buffer.add_char buf c)
        text;
      Buffer.contents buf
    in
    if allowed = "" then t
    else
      let updated, cursor = Fm.insert_at ~value:cur_val ~cursor:t.cursor allowed in
      let next = set_value t updated in
      { next with cursor = Some cursor; candidate = 0; notice = "" }
  else
    let updated, cursor = Fm.insert_at ~value:cur_val ~cursor:t.cursor text in
    let next = set_value t updated in
    { next with cursor = Some cursor; candidate = 0; notice = "" }

let erase t =
  let cur_val = value t in
  let updated, cursor = Fm.erase_at ~value:cur_val ~cursor:t.cursor in
  let next = set_value t updated in
  { next with cursor = Some cursor; candidate = 0; notice = "" }

(* Validation logic aligned with LOAM ScheduledCreation.lean:132-157 *)
let validate_draft t : (draft_tx, string) result =
  let date_str = String.trim t.day in
  match A.normalize_date date_str with
  | Error _ -> Error (tr "Scheduled date must be a real calendar date in YYYY-MM-DD form.")
  | Ok canon_date when not (A.is_valid_canonical_date canon_date) ->
      Error (tr "Scheduled date must be a real calendar date in YYYY-MM-DD form.")
  | Ok canon_date ->
      let rec check_rows acc pos_total = function
        | [] -> Ok (List.rev acc, pos_total)
        | r :: rest ->
            let loc = String.trim r.locus in
            let amt_str = String.trim r.amount in
            let amt_clean =
              if String.starts_with ~prefix:"+" amt_str then
                String.sub amt_str 1 (String.length amt_str - 1)
              else amt_str
            in
            let amt_opt =
              try
                let clean = String.concat "" (String.split_on_char ',' amt_clean) in
                Some (Z.of_string clean)
              with _ -> None
            in
            match amt_opt with
            | None ->
                Error
                  (A.format_message "Enter a nonzero signed integer %s amount for every posting." t.measure)
            | Some z when Z.equal z Z.zero ->
                Error
                  (A.format_message "Enter a nonzero signed integer %s amount for every posting." t.measure)
            | Some amt ->
                if loc = "" then Error (tr "Enter a valid Locus token for every posting.")
                else
                  let new_pos = if Z.sign amt > 0 then Z.add pos_total amt else pos_total in
                  check_rows ((loc, amt) :: acc) new_pos rest
      in
      match check_rows [] Z.zero t.rows with
      | Error err -> Error err
      | Ok (changes, positive_total) ->
          let total = List.fold_left (fun acc (_, a) -> Z.add acc a) Z.zero changes in
          if not (Z.equal total Z.zero) then Error (tr "Scheduled posting totals differ.")
          else if Z.sign positive_total <= 0 then
            Error (tr "Scheduled creation requires a positive balanced total.")
          else
            Ok
              {
                scheduled_on = canon_date;
                measure = t.measure;
                changes;
                positive_total;
              }

let preview t =
  match validate_draft t with
  | Error msg -> { t with notice = msg }
  | Ok draft ->
      { t with mode = Preview { draft; choice = 0; scroll = 0 }; notice = "" }

let dimensions (width, height) =
  if width >= 72 && height >= 19 then
    (min 80 (width - 4), min 32 (height - 2))
  else (max 0 width, max 0 height)

let footer t =
  match t.mode with
  | Preview _ ->
      [ "Tab/Left/Right select  Enter confirm  Esc cancel";
        "Up/Down/PgUp/PgDn/Home/End review postings" ]
  | Editing ->
      [ "Tab/Shift-Tab focus  Enter accept/next  Esc cancel";
        "Up/Down Locus  Right accept  C-u balance remainder" ]

let preview_capacity height =
  max 0 (height - 9)

let is_date_char c =
  (c >= '0' && c <= '9') || c = '-'

let handle ~blocked ~dimensions:((width, height) as _dim) ~width_of t (input : Ui_input.input) =
  match input with
  | `Key (`Escape, []) -> (
      match t.mode with
      | Preview _ -> Updated { t with mode = Editing; notice = "" }
      | Editing -> Closed)
  | `Key (button, mods) -> (
      let button =
        match (button, mods) with
        | `ASCII c, [ `Ctrl ] -> `ASCII (Char.lowercase_ascii c)
        | _ -> button
      in
      match t.mode with
      | Preview { draft; choice; scroll } -> (
          let capacity = preview_capacity height in
          let max_scroll = max 0 (List.length draft.changes + 1 - capacity) in
          match (button, mods) with
          | (`Tab, []) | (`Arrow `Right, []) ->
              Updated { t with mode = Preview { draft; choice = (choice + 1) mod 3; scroll } }
          | (`Tab, [ `Shift ]) | (`Arrow `Left, []) ->
              Updated { t with mode = Preview { draft; choice = (choice + 2) mod 3; scroll } }
          | (`Arrow `Up, []) | (`ASCII 'k', []) ->
              Updated { t with mode = Preview { draft; choice; scroll = max 0 (scroll - 1) } }
          | (`Arrow `Down, []) | (`ASCII 'j', []) ->
              Updated { t with mode = Preview { draft; choice; scroll = min max_scroll (scroll + 1) } }
          | (`Page `Up, []) | (`ASCII 'u', [ `Ctrl ]) ->
              Updated { t with mode = Preview { draft; choice; scroll = max 0 (scroll - max 1 capacity) } }
          | (`Page `Down, []) | (`ASCII 'd', [ `Ctrl ]) ->
              Updated { t with mode = Preview { draft; choice; scroll = min max_scroll (scroll + max 1 capacity) } }
          | (`Home, []) ->
              Updated { t with mode = Preview { draft; choice; scroll = 0 } }
          | (`End, []) ->
              Updated { t with mode = Preview { draft; choice; scroll = max_scroll } }
          | (`Enter, []) ->
              if choice = 0 then
                if blocked then
                  Updated { t with notice = tr "Writes are stopped; the draft is retained." }
                else if capacity < 2 then
                  Updated { t with notice = tr "Enlarge terminal to review Scheduled postings before publishing." }
                else Publish draft
              else if choice = 1 then
                Updated { t with mode = Editing; notice = "" }
              else Closed
          | _ -> Updated t)
      | Editing -> (
          match (button, mods) with
          | (`Tab, []) -> Updated (move_focus t false)
          | (`Tab, [ `Shift ]) -> Updated (move_focus t true)
          | (`Backspace, []) when t.focus < first_action t -> Updated (erase t)
          | (`ASCII 'u', [ `Ctrl ]) -> Updated (auto_fill_suspense t)
          | (`ASCII 'n', [ `Ctrl ]) -> Updated (append_row t)
          | (`ASCII 'd', [ `Ctrl ]) -> Updated (drop_row t)
          | (`Arrow `Left, []) ->
              let len = String.length (value t) in
              let cur = Option.value ~default:len t.cursor in
              Updated { t with cursor = Some (max 0 (cur - 1)) }
          | (`Arrow `Right, []) ->
              if (active_locus t) <> None then Updated (accept_candidate t)
              else
                let len = String.length (value t) in
                let cur = Option.value ~default:len t.cursor in
                Updated { t with cursor = Some (min len (cur + 1)) }
          | (`Home, []) -> Updated { t with cursor = Some 0 }
          | (`End, []) ->
              Updated { t with cursor = Some (String.length (value t)) }
          | ((`Arrow `Up | `ASCII 'k'), []) -> Updated (move_candidate t true)
          | ((`Arrow `Down | `ASCII 'j'), []) -> Updated (move_candidate t false)
          | (`Enter, []) ->
              let act = first_action t in
              let foc = t.focus in
              if (active_locus t) <> None then
                Updated (accept_candidate_and_advance t)
              else if foc < act then
                if foc + 1 = act then Updated (preview t)
                else Updated (move_focus t false)
              else if foc = act then Updated (append_row t)
              else if foc = act + 1 then Updated (drop_row t)
              else if foc = act + 2 then Updated (preview t)
              else Closed
          | (`ASCII c, []) when t.focus < first_action t && Char.code c >= 32 && Char.code c <> 127 ->
              if t.focus = 0 && not (is_date_char c) then Updated t
              else if t.focus = 0 && String.length (value t) >= 10 && t.cursor = None then Updated t
              else Updated (insert t (String.make 1 c))
          | (`Uchar c, []) when t.focus < first_action t && O.printable_uchar c ->
              if t.focus = 0 then Updated t
              else Updated (insert t (O.utf8 c))
          | _ -> Updated t))
  | `End -> Closed
  | `Resize _ | `Mouse _ | `Paste _ -> Updated t

(* Rendering helpers *)
let raw style text = (style, text)

let sub_border ~width_of ~width ?(style = O.Frame) ?(sub = "") title =
  if width < 4 then (style, O.pad ~width_of width "")
  else
    let left_decor = "╭ " and right_decor = if sub = "" then "╮" else " " ^ sub ^ " ╮" in
    let min_decor = width_of left_decor + width_of right_decor in
    if width <= min_decor then (style, O.pad ~width_of width (O.clip_text ~width_of width "╭──╮"))
    else
      let available = width - min_decor in
      let sub_room = if sub = "" then 0 else min (available / 2) (width_of sub + 1) in
      let title_room = max 0 (available - sub_room) in
      let title_clipped = O.clip_text ~width_of title_room (tr title) in
      let sub_clipped = if sub = "" then "" else " " ^ O.clip_text ~width_of (max 0 (sub_room - 1)) sub in
      let used = width_of left_decor + width_of title_clipped + width_of sub_clipped + width_of right_decor in
      let rule_len = max 0 (width - used) in
      let raw = left_decor ^ title_clipped ^ " " ^ O.rule ~width_of (max 0 (rule_len - 1)) ^ sub_clipped ^ right_decor in
      (style, O.pad ~width_of width (O.clip_text ~width_of width raw))

let sub_bottom ~width_of ~width ?(style = O.Frame) ?(title = "") () =
  if width < 2 then (style, O.pad ~width_of width "")
  else
    let left_decor = if title = "" then "╰" else "╰ " in
    let right_decor = "╯" in
    let min_decor = width_of left_decor + width_of right_decor in
    if width <= min_decor then (style, O.pad ~width_of width (O.clip_text ~width_of width "╰──╯"))
    else
      let available = width - min_decor in
      let title_text = if title = "" then "" else O.clip_text ~width_of (max 0 (available - 2)) title ^ " " in
      let rule_len = max 0 (available - width_of title_text) in
      let raw = left_decor ^ title_text ^ O.rule ~width_of rule_len ^ right_decor in
      (style, O.pad ~width_of width (O.clip_text ~width_of width raw))

let inner_line ~width_of ~width style text =
  let left = "│" and right = "│" in
  let room = max 0 (width - width_of left - width_of right) in
  let clipped = O.clip_text ~width_of room text in
  let pad = String.make (max 0 (room - width_of clipped)) ' ' in
  (style, left ^ clipped ^ pad ^ right)

let screen ~book:_ ~dimensions:((width, height) as _dim) ~width_of t =
  match t.mode with
  | Preview { draft; choice; scroll } ->
      let title = raw O.Heading (tr "Scheduled / New / Preview") in
      let summary_rows =
        [
          sub_border ~width_of ~width ~style:O.Frame (tr "Summary");
          inner_line ~width_of ~width O.Plain (" " ^ tr "Due:" ^ " " ^ draft.scheduled_on);
          inner_line ~width_of ~width O.Plain (" " ^ tr "Measure:" ^ " " ^ draft.measure);
          inner_line ~width_of ~width O.Chrome (" " ^ tr "No Actual or recurrence is created.");
          sub_bottom ~width_of ~width ~style:O.Frame ();
        ]
      in
      let posting_rows =
        List.map
          (fun (locus, amt) ->
            let signed = if Z.sign amt > 0 then "+" ^ Z.to_string amt else Z.to_string amt in
            Printf.sprintf " %s  %s %s" locus signed draft.measure)
          draft.changes
        @ [ Printf.sprintf " %s: %s %s" (tr "Balanced total") (Z.to_string draft.positive_total) draft.measure ]
      in
      let cap = preview_capacity height in
      let visible_postings =
        posting_rows
        |> List.filteri (fun i _ -> i >= scroll && i < scroll + cap)
        |> List.map (fun line -> inner_line ~width_of ~width O.Plain line)
      in
      let count = List.length posting_rows in
      let progress = Printf.sprintf "%d/%d lines" (min (scroll + cap) count) count in
      let review_panel =
        [ sub_border ~width_of ~width ~style:O.Focused_frame (tr "Expected postings" ^ "  " ^ progress) ]
        @ visible_postings
        @ [ sub_bottom ~width_of ~width ~style:O.Focused_frame () ]
      in
      let action_labels = [ "Publish Scheduled"; "Edit"; "Cancel" ] in
      let actions_str =
        action_labels
        |> List.mapi (fun i l ->
            if choice = i then "[" ^ tr l ^ "]" else " " ^ tr l ^ " ")
        |> String.concat "  "
      in
      let notice_row =
        if t.notice <> "" then [ raw O.Status ("! " ^ t.notice) ] else []
      in
      let footer_rows =
        notice_row
        @ [ raw O.Active (" " ^ actions_str);
            raw O.Chrome (tr " Tab/Left/Right select  Enter confirm  Esc cancel");
            raw O.Chrome (tr " Up/Down review postings") ]
      in
      [ title ] @ summary_rows @ review_panel @ footer_rows
  | Editing ->
      let title = raw O.Heading (tr "Scheduled / New / Edit") in
      let field_row label value is_active cursor =
        let cursor_marker = if is_active then "_" else "" in
        let disp_val = if value = "" then cursor_marker else value in
        let style = if is_active then O.Active else O.Plain in
        let padded_label = O.pad ~width_of 14 (label ^ ":") in
        inner_line ~width_of ~width style (" " ^ padded_label ^ " " ^ disp_val)
      in
      let fields_panel_content =
        [ field_row (tr "Due") t.day (t.focus = 0) t.cursor ]
        @ List.concat
            (List.mapi
               (fun i r ->
                 let l_foc = t.focus = 1 + (i * 2) in
                 let a_foc = t.focus = 2 + (i * 2) in
                 [
                   field_row (A.format_message "Posting %d" (i + 1)) r.locus l_foc t.cursor;
                   field_row ("  " ^ t.measure) r.amount a_foc t.cursor;
                 ])
               t.rows)
      in
      let fields_style = if t.focus < first_action t then O.Focused_frame else O.Frame in
      let fields_panel =
        [ sub_border ~width_of ~width ~style:fields_style (tr "Due / Signed postings") ]
        @ fields_panel_content
        @ [ sub_bottom ~width_of ~width ~style:fields_style () ]
      in
      let candidates_panel =
        if height < 19 then []
        else
          let options = candidates t in
          let count = List.length options in
          let selected = if count = 0 then 0 else t.candidate mod count in
          let cap = 4 in
          let start = max 0 (selected - cap + 1) in
          let visible =
            options
            |> List.filteri (fun i _ -> i >= start && i < start + cap)
            |> List.mapi (fun off id ->
                let idx = start + off in
                let prefix = if idx = selected then "> " else "  " in
                let style = if idx = selected then O.Active else O.Plain in
                let label = B.label t.book id in
                let display = id ^ (if label = "" then "" else "  " ^ label) in
                inner_line ~width_of ~width style (prefix ^ display))
          in
          let header = Printf.sprintf "%s (%d/%d)" (tr "Locus candidates") (if count = 0 then 0 else selected + 1) count in
          [ sub_border ~width_of ~width ~style:O.Frame header ]
          @ (if visible = [] then [ inner_line ~width_of ~width O.Chrome (tr "  (no matching candidates)") ] else visible)
          @ [ sub_bottom ~width_of ~width ~style:O.Frame () ]
      in
      let act_start = first_action t in
      let action_labels =
        if width < 58 then [ "Add"; "Drop"; "Preview"; "Cancel" ]
        else [ "Add posting"; "Drop last row"; "Preview"; "Cancel" ]
      in
      let actions_str =
        action_labels
        |> List.mapi (fun i l ->
            if t.focus = act_start + i then "[" ^ tr l ^ "]" else " " ^ tr l ^ " ")
        |> String.concat " "
      in
      let notice_row =
        if t.notice <> "" then [ raw O.Status ("! " ^ t.notice) ] else []
      in
      let footer_rows =
        notice_row
        @ [ raw O.Active (" " ^ actions_str);
            raw O.Chrome (tr " Tab/Shift-Tab focus  Enter accept/next  Esc cancel");
            raw O.Chrome (tr " Up/Down Locus  Right accept  C-u balance remainder") ]
      in
      [ title ] @ fields_panel @ candidates_panel @ footer_rows

let cursor_position ~book:_ ~dimensions:((width, height) as _dim) ~width_of t =
  match t.mode with
  | Preview _ -> None
  | Editing ->
      if t.focus >= first_action t then None
      else
        (* Title is row 0. Fields panel starts at row 1.
           Border top is row 1.
           Focus 0 (Due) is row 2.
           Posting i locus is row 3 + 2*i.
           Posting i amount is row 4 + 2*i. *)
        let line_idx =
          if t.focus = 0 then 2
          else 2 + t.focus
        in
        let cur_val = value t in
        let offset =
          match t.cursor with
          | Some c -> min (String.length cur_val) c
          | None -> String.length cur_val
        in
        let prefix_len = 2 + 14 + 2 (* "│ " + 14-char padded label + " " *) in
        let col = prefix_len + width_of (String.sub cur_val 0 offset) in
        if col < width && line_idx < height then Some (col, line_idx)
        else None
