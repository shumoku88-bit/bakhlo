(* Scheduled occurrence creation session aligned with LOAM ScheduledCreation.lean.
   Edits one explicit due date plus signed single-Measure postings (2 to 6 rows).
   No Description, recurrence, routing, or Actual evidence. *)

module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module A = Daily_draft
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
  offer_pace : bool;  (* LOAM: an ordinary creation, not a continuation's next Scheduled *)
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
let offers_expected_pace t = t.offer_pace

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
    offer_pace = true;
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
        offer_pace = false;
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

let notice_rows ~width ~height ~width_of t =
  let rows = if t.notice = "" then [""] else O.wrap_text ~width_of width ("! " ^ t.notice) in
  let capacity = max 1 (height - 7) in
  if List.length rows <= capacity then rows
  else List.filteri (fun i _ -> i < capacity - 1) rows @ [tr "… more"]

let preview_capacity ~dimensions:(width, height) ~width_of t =
  max 0 (height - 9 - (List.length (notice_rows ~width ~height ~width_of t) - 1))

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
          let capacity = preview_capacity ~dimensions:(width, height) ~width_of t in
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
              Updated { t with cursor = Some (Fm.move_cursor ~value:(value t) ~cursor:t.cursor (-1)) }
          | (`Arrow `Right, []) ->
              if active_locus t <> None then Updated (accept_candidate t)
              else
                Updated { t with cursor = Some (Fm.move_cursor ~value:(value t) ~cursor:t.cursor 1) }
          | (`Home, []) -> Updated { t with cursor = Some 0 }
          | (`End, []) ->
              Updated { t with cursor = Some (String.length (value t)) }
          (* Only arrows move candidates; j and k are text in a Locus such as "bank". *)
          | (`Arrow `Up, []) -> Updated (move_candidate t true)
          | (`Arrow `Down, []) -> Updated (move_candidate t false)
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

(* Root rows are budgeted before painting; only the field viewport scrolls. *)
let screen ~book:_ ~dimensions:(width, height) ~width_of t =
  let width = max 0 width and height = max 0 height in
  let line style text = style, O.pad ~width_of width text in
  let title_rows title =
    if height >= 6 then [line O.Heading (tr title)] else [] in
  let hint_count = min 2 (max 0 (height - 7)) in
  let hints = footer t |> List.filteri (fun i _ -> i < hint_count)
      |> List.map (fun text -> line O.Chrome (tr text)) in
  let notices = if height < 3 then [] else
      notice_rows ~width ~height ~width_of t
      |> List.map (line O.Status) in
  let actions ~selected labels =
    if height < 2 then [] else
      let labels = List.mapi (fun i label ->
          if selected = i then "[" ^ tr label ^ "]" else tr label) labels in
      let text = String.concat " " labels in
      let text = if width_of text <= width then text else
          let prefix = labels |> List.filteri (fun i _ -> i <= selected)
              |> String.concat " " in
          O.tail_text ~width_of width prefix in
      [line O.Active text] in
  let field_panel ~height:panel_height ~focused ~selected ~title rows =
    let framed = width >= 7 && panel_height >= 3 in
    let capacity = if framed then Panel.capacity ~height:panel_height ~heading:false
      else panel_height in
    let count = List.length rows in
    let view = Panel.window ~capacity ~count ~scroll:0 ~selected in
    let shown = rows |> List.filteri (fun i _ ->
        i >= view.start && i - view.start < view.capacity) in
    let title = if capacity < count then
        Printf.sprintf "%s  %d–%d/%d …" title (view.start + 1)
          (min count (view.start + capacity)) count else title in
    if framed then Panel.frame_rows ~width_of ~width ~height:panel_height
        ~focused ~title shown
    else List.map (fun (style, text) -> line style text) shown in
  match t.mode with
  | Preview { draft; choice; scroll } ->
      let title = title_rows "Scheduled / New / Preview" in
      let actions = actions ~selected:choice
          (if width < 58 then ["Publish"; "Edit"; "Cancel"]
           else ["Publish Scheduled"; "Edit"; "Cancel"]) in
      let room = max 0 (height - List.length title - List.length notices
          - List.length actions - List.length hints) in
      let summary = [
          line O.Plain (tr "Due:" ^ " " ^ draft.scheduled_on ^ "  "
            ^ tr "Measure:" ^ " " ^ draft.measure);
          line O.Chrome (tr "No Actual or recurrence is created.");
        ] |> List.filteri (fun i _ -> i < max 0 (room - 2)) in
      let panel_height = max 0 (room - List.length summary) in
      let cap = min (preview_capacity ~dimensions:(width, height) ~width_of t)
          (Panel.capacity ~height:panel_height ~heading:false) in
      let posting_rows = List.map (fun (locus, amt) ->
          let signed = if Z.sign amt > 0 then "+" ^ Z.to_string amt else Z.to_string amt in
          Printf.sprintf "%s  %s %s" locus signed draft.measure) draft.changes
        @ [Printf.sprintf "%s: %s %s" (tr "Balanced total")
             (Z.to_string draft.positive_total) draft.measure] in
      let view = Panel.window ~capacity:cap ~count:(List.length posting_rows)
          ~scroll ~selected:None in
      let shown = posting_rows |> List.filteri (fun i _ ->
          i >= view.start && i - view.start < cap)
          |> List.map (fun text -> O.Plain, text) in
      let title = Printf.sprintf "%s  %d/%d lines" (tr "Expected postings")
          (min (List.length posting_rows) (view.start + cap)) (List.length posting_rows) in
      let panel = if panel_height >= 2 && width >= 6 then
          Panel.frame_rows ~width_of ~width ~height:panel_height ~focused:true ~title shown
        else [] in
      title_rows "Scheduled / New / Preview" @ summary @ panel @ notices @ actions @ hints
  | Editing ->
      let title = title_rows "Scheduled / New / Edit" in
      let act_start = first_action t in
      let actions = actions ~selected:(t.focus - act_start)
          (if width < 58 then ["Add"; "Drop"; "Preview"; "Cancel"]
           else ["Add posting"; "Drop last row"; "Preview"; "Cancel"]) in
      let room = max 0 (height - List.length title - List.length notices
          - List.length actions - List.length hints) in
      let candidate_height = if height >= 19 then
          min 6 (max 0 (room - (field_count t + 2))) else 0 in
      let candidate_height = if candidate_height < 3 then 0 else candidate_height in
      let panel_height = room - candidate_height in
      let framed = width >= 7 && panel_height >= 3 in
      let field_width = if framed then width - 6 else width in
      let field_row index label value =
        let active = t.focus = index in
        let label_width = min 14 (max 0 (field_width / 2 - 1)) in
        let prompt = if label_width = 0 then "" else
            O.pad ~width_of label_width (label ^ ":") ^ " " in
        let inset = width_of prompt in
        if active then
          let text, caret = O.input_text ~width_of ~width:(field_width - inset)
              ~cursor:t.cursor ~caret:"|" value in
          (Option.fold ~none:O.Plain ~some:(fun col -> O.Input (inset + col)) caret,
           prompt ^ text)
        else O.Plain, O.clip_text ~width_of field_width (prompt ^ value) in
      let fields = field_row 0 (tr "Due") t.day
        :: List.concat (List.mapi (fun i r -> [
             field_row (1 + 2 * i) (A.format_message "Posting %d" (i + 1)) r.locus;
             field_row (2 + 2 * i) ("  " ^ t.measure) r.amount;
           ]) t.rows) in
      let fields = field_panel ~height:panel_height ~focused:(t.focus < act_start)
          ~selected:(if t.focus < act_start then Some t.focus else None)
          ~title:(tr "Due / Signed postings") fields in
      let candidate_panel = if candidate_height = 0 then [] else
          let options = candidates t in
          let count = List.length options in
          let selected = if count = 0 then None else Some (t.candidate mod count) in
          let rows = if count = 0 then [tr "(no matching candidates)"] else
              List.map (fun id ->
                  let label = B.label t.book id in
                  id ^ (if label = "" then "" else "  " ^ label)) options in
          Panel.frame ~width_of ~width ~height:candidate_height ~focused:true
            ~title:(tr "Locus candidates") ~scroll:0 ~selected rows in
      title @ fields @ candidate_panel @ notices @ actions @ hints
