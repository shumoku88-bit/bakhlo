(* English-first Record editor. Drafts and preview navigation are local state;
   only an explicit selected Publish action requests the existing publisher. *)
module B = Bakhlo_sexp.Daily_book
module A = Daily_actions
module D = Bakhlo_domain
module R = Posting_draft
module O = Daily_overlays
module Fm = Daily_form
let tr = Ui_text.tr

type row = { key : D.Identifier.Effect_key.t option; locus : string; amount : string }
type review = { payload : A.payload; base_bytes : string; action : int; scroll : int }
type t = {
  mode : A.mode;
  day : string;
  description : string;
  measure : string;
  rows : row list;
  focus : int;
  cursor : int option;
  candidate : int;
  notice : string;
  review : review option;
  paste : (string * bool) option;
}
type outcome = Updated of t | Closed of t | Publish of A.payload * string * t

let mode t = t.mode
let with_notice t notice = { t with notice }
let is_plan t = match t.mode with A.Plan_new | A.Plan_edit _ -> true | A.New | A.Edit _ | A.Pay _ -> false
let has_draft t =
  match t.mode with
  | A.Edit _ | A.Pay _ | A.Plan_edit _ -> true
  | A.Plan_new -> List.exists (fun row -> row.amount <> "" || row.locus <> "") t.rows
  | A.New -> t.description <> "" || List.exists (fun row -> row.amount <> "" || row.locus <> "") t.rows

let create ~book:_ ~day ~measure () =
  { mode = A.New; day; description = ""; measure;
    rows = [{key=None; locus=""; amount=""}; {key=None; locus=""; amount=""}];
    focus=1; cursor=None; candidate=0; notice=""; review=None; paste=None }

let create_plan ~book:_ ~day ~measure () =
  { mode = A.Plan_new; day; description = ""; measure;
    rows = [{key=None; locus=""; amount=""}; {key=None; locus=""; amount=""}];
    focus=0; cursor=None; candidate=0; notice=""; review=None; paste=None }

let rows_of_draft (draft : R.t) =
  List.map (fun (r:R.row) ->
    {key=r.key; locus=r.locus; amount=(if r.negative then "-" else "+") ^ r.amount}) draft.rows

let of_edit ~book entry =
  match A.prepare_edit ~book entry with
  | A.Edit_refused why -> Error why
  | A.Edit_single _ | A.Edit_multiple _ ->
      (match R.of_effects book entry.B.effects with
      | Error why -> Error why
      | Ok draft ->
          let t = create ~book ~day:entry.day ~measure:draft.measure () in
          Ok {t with mode=A.Edit entry; description=Option.value ~default:"" entry.memo;
            rows=rows_of_draft draft})

let of_edit_plan ~book (plan : B.plan) =
  if plan.paid_by <> None then Error (tr "This Scheduled occurrence is already completed.")
  else if plan.cancelled_on <> None then Error (tr "This Scheduled occurrence is cancelled.")
  else
    let effects =
      List.map (fun (locus, n) ->
        match D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string plan.measure with
        | Ok locus, Ok measure ->
            Some (D.Effect.create ~key:None ~locus ~measure ~quantity:(D.Quantity.of_quanta n))
        | Error _, _ | _, Error _ -> None) plan.changes
    in
    if List.exists Option.is_none effects then Error (tr "Invalid Scheduled coordinates.")
    else match R.of_effects book (List.filter_map Fun.id effects) with
    | Error why -> Error why
    | Ok draft ->
        let t = create_plan ~book ~day:plan.day ~measure:plan.measure () in
        Ok {t with mode = A.Plan_edit plan; rows = rows_of_draft draft}

let of_plan ?day ~book (plan:B.plan) =
  if plan.paid_by <> None then Error (tr "This Scheduled occurrence is already completed.")
  else if plan.cancelled_on <> None then Error (tr "This Scheduled occurrence is cancelled.")
  else
    let effects =
      List.map (fun (locus,n) ->
        match D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string plan.measure with
        | Ok locus, Ok measure ->
            Some (D.Effect.create ~key:None ~locus ~measure ~quantity:(D.Quantity.of_quanta n))
        | Error _, _ | _, Error _ -> None) plan.changes
    in
    if List.exists Option.is_none effects then Error (tr "Invalid Scheduled coordinates.")
    else match R.of_effects book (List.filter_map Fun.id effects) with
    | Error why -> Error why
    | Ok draft ->
        let t = create ~book ~day:(Option.value ~default:plan.day day) ~measure:plan.measure () in
        Ok {t with mode=A.Pay plan.id; rows=rows_of_draft draft}

let action_start t = 3 + 2 * List.length t.rows
let border_intent t =
  if (match t.review with Some review -> review.action = 2
      | None -> t.focus = action_start t + 3) then `Cancel
  else match t.mode with A.New | A.Plan_new -> `Create | A.Edit _ | A.Pay _ | A.Plan_edit _ -> `Change

let surface_dimensions (width, height) =
  let width = max 0 width and height = max 0 height in
  if width >= 76 && height >= 20 then (min 76 (width - 8), min 24 (height - 3))
  else (width, height)

let field_count t = action_start t + 4
let row_index t = max 0 ((t.focus-3)/2)
let is_locus t = t.focus>=3 && t.focus<action_start t && (t.focus-3) mod 2=0
let is_amount t = t.focus>=3 && t.focus<action_start t && (t.focus-3) mod 2=1
let editable_structure t = match t.mode with A.Edit _ -> false | A.New | A.Pay _ | A.Plan_new | A.Plan_edit _ -> true
let value t =
  if t.focus=0 then t.day else if t.focus=1 then t.description else if t.focus=2 then t.measure
  else match List.nth_opt t.rows (row_index t) with
    | None -> "" | Some r -> if is_locus t then r.locus else r.amount

let set_value t text =
  let reset t = {t with cursor=None; candidate=0; notice=""} in
  if t.focus=0 then reset {t with day=text}
  else if t.focus=1 then reset {t with description=text}
  else if t.focus=2 then
    if editable_structure t && List.for_all (fun row -> row.amount="") t.rows then reset {t with measure=text}
    else with_notice t (tr "Measure is fixed after amounts are entered or during correction.")
  else if t.focus < action_start t then
    if is_locus t && not (editable_structure t) then
      with_notice t (tr "Correction keeps posting Loci, signs, keys and structure.")
    else if is_amount t && not (editable_structure t) then
      let negative s = String.starts_with ~prefix:"-" s in
      let original_negative = match t.mode with
        | A.Edit entry ->
            (match List.nth_opt entry.B.effects (row_index t) with
             | Some posting -> Z.sign (A.quanta posting)<0 | None -> false)
        | A.New | A.Pay _ | A.Plan_new | A.Plan_edit _ -> false in
      if text<>"" && negative text <> original_negative then
        with_notice t (tr "Correction keeps the posting sign; edit its amount magnitude.")
      else reset {t with rows=List.mapi (fun i row -> if i=row_index t then {row with amount=text} else row) t.rows}
    else reset {t with rows=List.mapi (fun i row -> if i<>row_index t then row
      else if is_locus t then {row with locus=text} else {row with amount=text}) t.rows}
  else t

let move_focus t delta =
  let count = field_count t in
  let rec step f =
    let next = (f + delta + count) mod count in
    if is_plan t && next = 1 then (next + delta + count) mod count else next
  in
  {t with focus = step t.focus; cursor = None; candidate = 0; notice = ""}

let candidates ~book t = if is_locus t then O.locus_candidates book (value t) else []
let accept ~book t =
  if not (editable_structure t) then move_focus t 1
  else
    let choices = candidates ~book t in
    match List.nth_opt choices (if choices=[] then 0 else t.candidate mod List.length choices) with
    | Some id -> move_focus (set_value t id) 1
    | None -> with_notice t (tr "No admitted Locus matches this field.")

let add_row t =
  if not (editable_structure t) then with_notice t (tr "Correction keeps the posting structure.")
  else {t with rows=t.rows @ [{key=None;locus="";amount=""}]; focus=action_start t;
    candidate=0; cursor=None; notice=""}

let drop_row t =
  if not (editable_structure t) then with_notice t (tr "Correction keeps the posting structure.")
  else if List.length t.rows<=2 then with_notice t (tr "Keep at least two postings.")
  else
    let index = min (List.length t.rows-1) (row_index t) in
    let rows=List.filteri (fun i _ -> i<>index) t.rows in
    {t with rows; focus=3 + 2 * min index (List.length rows-1); cursor=None; candidate=0; notice=""}

let draft t =
  { R.measure=t.measure;
    rows=List.map (fun row ->
      let negative=String.starts_with ~prefix:"-" row.amount in
      let signed=negative || String.starts_with ~prefix:"+" row.amount in
      let amount=if signed then String.sub row.amount 1 (String.length row.amount-1) else row.amount in
      {R.key=row.key; locus=row.locus; negative; amount}) t.rows }

let preview ~book ~base_bytes ~blocked t =
  if blocked then with_notice t (tr "Writes are stopped; the draft is retained.")
  else if is_plan t then
    match A.build_plan ~book ~mode:t.mode ~day:t.day ~draft:(draft t) with
    | Error error -> with_notice t error.A.message
    | Ok (plan, replace) ->
        {t with review=Some {payload=A.Plan_tx {plan; replace}; base_bytes; action=0; scroll=0}; notice=""; paste=None}
  else
    match A.build_transaction ~book ~mode:t.mode (A.Multiple {day=t.day; memo=t.description; draft=draft t}) with
    | Error error -> with_notice t error.A.message
    | Ok transaction ->
        {t with review=Some {payload=A.Entry_tx transaction; base_bytes; action=0; scroll=0}; notice=""; paste=None}

let insert t text =
  let updated, cursor=Fm.insert_at ~value:(value t) ~cursor:t.cursor text in
  let next=set_value t updated in
  if value next=updated then {next with cursor=Some cursor} else next

let erase t =
  let updated,cursor=Fm.erase_at ~value:(value t) ~cursor:t.cursor in
  let next=set_value t updated in
  if value next=updated then {next with cursor=Some cursor} else next

let review_lines ~book review =
  match review.payload with
  | A.Entry_tx tx -> O.preview_lines book tx
  | A.Plan_tx { plan; replace } -> O.plan_preview_lines book ~replace plan
let notice_lines ~dimensions:(width,height) ~width_of t =
  let room = max 1 (width - 4) in
  let rows = if t.notice = "" then [""] else O.wrap_text ~width_of room t.notice in
  let capacity = max 0 (height - 6) in
  if capacity = 0 then []
  else if List.length rows <= capacity then rows
  else List.filteri (fun i _ -> i < capacity - 1) rows
    @ [O.clip_text ~width_of room (tr "More feedback; enlarge terminal.")]

let review_geometry ~book ~dimensions:(width,height) ~width_of t review =
  let feedback=List.length (notice_lines ~dimensions:(width,height) ~width_of t) in
  (* One outer frame, one action row, two navigation rows. *)
  let available=max 0 (height-feedback-5) in
  let lines=List.concat_map (O.wrap_text ~width_of (max 1 (width-4))) (review_lines ~book review) in
  let last=max 0 (List.length lines-available) in
  (available,lines,min last (max 0 review.scroll),last)

let scroll_review ~book ~dimensions ~width_of t delta endpoint =
  match t.review with None -> t | Some review ->
    let capacity,_,scroll,last=review_geometry ~book ~dimensions ~width_of t review in
    let next=match endpoint with Some false -> 0 | Some true -> last
      | None -> scroll + (if abs delta=1 then delta
          else (if delta<0 then -1 else 1) * max 1 capacity) in
    {t with review=Some {review with scroll=max 0 (min last next)}}

let safe_text text =
  let valid=ref true in
  Uutf.String.fold_utf_8 (fun () _ -> function
    | `Uchar c -> if not (O.printable_uchar c) then valid:=false
    | `Malformed _ -> valid:=false) () text;
  !valid

let handle ~book ~base_bytes ~blocked ~dimensions ~width_of t (input:Ui_input.input) =
  let update t=Updated t in
  match input,t.paste with
  | `Paste `Start, _ -> update {t with paste=Some ("",false)}
  | `Paste `End, Some (text,invalid) ->
      let t={t with paste=None} in
      if blocked then update t
      else if invalid || not (safe_text text) then update (with_notice t (tr "Paste refused: use one printable line; no control keys."))
      else if t.review<>None || t.focus>=action_start t then update t
      else update (insert t text)
  | `Key (`ASCII c,[]), Some (text,invalid) ->
      update {t with paste=Some (text ^ String.make 1 c, invalid || Char.code c<32 || Char.code c=127)}
  | `Key (`Uchar c,[]), Some (text,invalid) ->
      update {t with paste=Some (text ^ O.utf8 c,invalid || not (O.printable_uchar c))}
  | `Key _, Some (text,_) -> update {t with paste=Some (text,true)}
  | `Key (`Escape,[]), None -> Closed {t with review=None; paste=None}
  | `Key (button,mods), None ->
      let button=match button,mods with `ASCII c,[`Ctrl] -> `ASCII (Char.lowercase_ascii c) | _ -> button in
      (match t.review with
      | Some review ->
          (match button,mods with
          | `Tab,[] | `Arrow `Right,[] -> update {t with review=Some {review with action=(review.action+1) mod 3}}
          | `Tab,[`Shift] | `Arrow `Left,[] -> update {t with review=Some {review with action=(review.action+2) mod 3}}
          | `Arrow `Up,[] | `ASCII 'k',[] -> update (scroll_review ~book ~dimensions ~width_of t (-1) None)
          | `Arrow `Down,[] | `ASCII 'j',[] -> update (scroll_review ~book ~dimensions ~width_of t 1 None)
          | `Page `Up,[] | `ASCII 'u',[`Ctrl] -> update (scroll_review ~book ~dimensions ~width_of t (-2) None)
          | `Page `Down,[] | `ASCII 'd',[`Ctrl] -> update (scroll_review ~book ~dimensions ~width_of t 2 None)
          | `Home,[] -> update (scroll_review ~book ~dimensions ~width_of t 0 (Some false))
          | `End,[] -> update (scroll_review ~book ~dimensions ~width_of t 0 (Some true))
          | `Enter,[] ->
              if review.action=1 then update {t with review=None; notice=""}
              else if review.action=2 then Closed {t with review=None}
              else if blocked then update (with_notice t (tr "Writes are stopped; the draft is retained."))
              else let width,height=dimensions in
                let capacity,_,scroll,last=review_geometry ~book ~dimensions ~width_of t review in
                if width<32 || height<12 || capacity<1 then
                  update (with_notice t (tr "Not enough room to review publication; enlarge the terminal."))
                else if height<16 && last>0 then
                  update (with_notice t (tr "Not enough room for the whole preview; enlarge the terminal."))
                else if scroll<last then
                  update (with_notice t (tr "Review to the end before Publish."))
                else Publish (review.payload,review.base_bytes,t)
          | _ -> update t)
      | None when blocked -> update t
      | None ->
          (match button,mods with
          | `Tab,[] -> update (move_focus t 1)
          | `Tab,[`Shift] -> update (move_focus t (-1))
          | `ASCII 'n',[`Ctrl] -> update (add_row t)
          | `ASCII 'd',[`Ctrl] -> update (drop_row t)
          | `ASCII 's',[`Ctrl] -> update (preview ~book ~base_bytes ~blocked t)
          | `Enter,[] ->
              if is_locus t then update (accept ~book t)
              else if t.focus=action_start t || t.focus=action_start t-1 then
                update (preview ~book ~base_bytes ~blocked t)
              else if t.focus=action_start t+1 then update (add_row t)
              else if t.focus=action_start t+2 then update (drop_row t)
              else if t.focus=action_start t+3 then Closed t
              else update (move_focus t 1)
          | `Arrow `Up,[] | `Arrow `Down,[] when is_locus t ->
              let choices=candidates ~book t in
              let n=List.length choices in
              let delta=if button=`Arrow `Up then -1 else 1 in
              update {t with candidate=if n=0 then 0 else (t.candidate+delta+n) mod n}
          | `Arrow `Right,[] when is_locus t -> update (accept ~book t)
          | `Arrow `Left,[] | `Arrow `Right,[] ->
              let step=if button=`Arrow `Left then -1 else 1 in
              update {t with cursor=Some (Fm.move_cursor ~value:(value t) ~cursor:t.cursor step)}
          | `Home,[] -> update {t with cursor=Some 0}
          | `End,[] -> update {t with cursor=None}
          | `Backspace,[] when t.focus<action_start t -> update (erase t)
          | `ASCII c,[] when t.focus<action_start t && Char.code c>=32 && Char.code c<>127 ->
              update (insert t (String.make 1 c))
          | `Uchar c,[] when t.focus<action_start t && O.printable_uchar c -> update (insert t (O.utf8 c))
          | _ -> update t))
  | `End,_ -> Closed {t with paste=None;review=None}
  | `Resize _,_ | `Mouse _,_ | `Paste `End,None -> update t

let tail ~width_of room text =
  if width_of text<=room then text
  else
    let chars=Uutf.String.fold_utf_8 (fun xs _ -> function `Uchar c -> O.utf8 c::xs | `Malformed _ -> xs) [] text in
    let _,suffix=List.fold_left (fun (stopped,suffix) glyph ->
      if stopped || width_of (glyph ^ suffix)>max 0 (room-width_of "…") then true,suffix
      else false,glyph^suffix) (false,"") chars in
    O.clip_text ~width_of room ("…"^suffix)

let field_text ~width_of width active cursor label text =
  let label_width=min 13 (max 0 (width/2)) in
  let room=max 0 (width-label_width) in
  let text,caret=if active then
      let pos=Fm.cursor_pos ~value:text cursor in
      let left=O.visible (String.sub text 0 pos) in
      let right=O.visible (String.sub text pos (String.length text-pos)) in
      let left=tail ~width_of (max 0 (room-1)) left in
      left ^ "|" ^ O.clip_text ~width_of (max 0 (room-width_of left-1)) right,
      Some (label_width + width_of left)
    else O.clip_text ~width_of room (if text="" then "_" else text),None
  in
  O.pad ~width_of label_width (tr label ^ ":") ^ text,caret

let action_line ~width_of width t =
  let selected,labels =
    match t.review with
    | Some review -> Some review.action,["Publish";"Edit";"Cancel"]
    | None -> (if t.focus>=action_start t then Some (t.focus-action_start t) else None),
        ["Preview";"Add row";"Drop row";"Cancel"]
  in
  let label index text =
    (if selected=Some index then "> " else "") ^ "[" ^ tr text ^ "]"
  in
  let full=String.concat "  " (List.mapi label labels) in
  if width_of full<=width then full
  else match selected with
    | Some index -> label index (List.nth labels index)
    | None -> tr "[Preview] … [Cancel]"

let sub_border ~width_of ~width ?(style = O.Frame) ?(sub = "") title =
  if width < 4 then (style, O.pad ~width_of width "")
  else
    let left_decor = "╭─ " and right_decor = if sub = "" then "─╮" else " ─╮" in
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
    let left_decor = "╰─" and right_decor = "─╯" in
    let min_decor = width_of left_decor + width_of right_decor in
    if width <= min_decor then (style, O.pad ~width_of width (O.clip_text ~width_of width "╰──╯"))
    else
      let available = width - min_decor in
      let title_text = if title = "" then "" else " " ^ O.clip_text ~width_of (max 0 (available - 2)) title ^ " " in
      let rule_len = max 0 (available - width_of title_text) in
      let raw = left_decor ^ title_text ^ O.rule ~width_of rule_len ^ right_decor in
      (style, O.pad ~width_of width (O.clip_text ~width_of width raw))

let inner_line ~width_of ~width style text =
  let left = "│ " and right = " │" in
  let room = max 0 (width - width_of left - width_of right) in
  let content = O.clip_text ~width_of room text in
  let padded = content ^ String.make (max 0 (room - width_of content)) ' ' in
  (style, left ^ padded ^ right)

let combine_side_by_side ~width_of ~width ~left_width ~right_width left_rows right_rows =
  let max_len = max (List.length left_rows) (List.length right_rows) in
  let pad_rows rows w =
    let len = List.length rows in
    rows @ List.init (max 0 (max_len - len)) (fun _ -> (O.Plain, String.make w ' '))
  in
  let left_padded = pad_rows left_rows left_width in
  let right_padded = pad_rows right_rows right_width in
  List.map2 (fun (left_style, left_text) (right_style, right_text) ->
    let style = match left_style with
      | O.Input _ -> left_style
      | _ -> if left_style = O.Active || right_style = O.Active then O.Active
             else if left_style = O.Focused_frame || right_style = O.Focused_frame then O.Focused_frame
             else O.Plain
    in
    let raw = left_text ^ " " ^ right_text in
    (style, O.pad ~width_of width (O.clip_text ~width_of width raw))) left_padded right_padded

let screen ~book ~dimensions:(width,height) ~width_of t =
  let width = max 0 width and height = max 0 height in
  let raw style text = style, O.pad ~width_of width text in
  let navigation = match t.review with
    | None ->
        if width < 50 then [tr "Tab field  Enter next / Preview"; tr "C-n add  C-d drop  Esc hold draft"]
        else [tr "Tab/Shift-Tab field  Enter next / Preview"; tr "C-n add row  C-d drop row  Esc hold draft"]
    | Some _ ->
        if width < 50 then [tr "↑↓ review  PgUp/Dn  Home/End"; tr "Tab action  Enter choose  Esc hold"]
        else [tr "↑↓ review  PgUp/Dn page  Home/End"; tr "Tab action  Enter choose  Esc hold draft"]
  in
  let navigation = List.map (raw O.Chrome) navigation in
  let title = match t.review, t.mode with
    | Some _, A.Plan_new | Some _, A.Plan_edit _ -> tr "Scheduled / Preview"
    | Some _, _ -> tr "Record / Preview"
    | None, A.Plan_new -> tr "Scheduled / Create"
    | None, A.Plan_edit _ -> tr "Scheduled / Edit"
    | None, A.New -> tr "Record / Edit"
    | None, A.Edit _ -> tr "Actual / Correct"
    | None, A.Pay _ -> tr "Scheduled / Complete"
  in
  if width < 4 || height < 4 then
    let rows = raw O.Heading title :: navigation in
    List.filteri (fun i _ -> i < height) rows
    @ List.init (max 0 (height - List.length rows)) (fun _ -> raw O.Plain "")
  else
    match t.review with
    | Some review ->
        let inside = max 0 (width - 4) in
        let content_capacity = max 0 (height - 4) in
        let feedback = notice_lines ~dimensions:(width,height) ~width_of t in
        let action_height = if content_capacity > List.length feedback then 1 else 0 in
        let gate_height = if content_capacity - List.length feedback - action_height >= 10 then 2 else 0 in
        let capacity = max 0 (content_capacity - List.length feedback - action_height - gate_height) in
        let shown_capacity, lines, scroll, _ =
          review_geometry ~book ~dimensions:(width,height) ~width_of t review in
        let shown_capacity = min capacity shown_capacity in
        let shown = lines |> List.filteri (fun i _ -> i >= scroll && i < scroll + shown_capacity) in
        let shown_rows = List.map (fun text -> O.Plain, text) shown in
        let pad_rows = List.init (max 0 (capacity - List.length shown_rows)) (fun _ -> O.Plain, "") in
        let gate_rows =
          if gate_height = 0 then []
          else [ (O.Chrome, tr "Publication gate");
                 (O.Chrome, "  " ^ tr "recheck evidence + Locus admission") ]
        in
        let content =
          shown_rows @ pad_rows @ gate_rows
          @ List.map (fun text -> O.Status, text) feedback
          @ (if action_height = 0 then [] else [ O.Heading, action_line ~width_of inside t ])
        in
        let bottom =
          A.format_message "%d–%d / %d"
            (if lines = [] || shown_capacity = 0 then 0 else scroll + 1)
            (min (List.length lines) (scroll + shown_capacity))
            (List.length lines)
        in
        O.panel_border ~width ~style:O.Focused_frame ~width_of title
        :: List.map (fun (style, text) -> O.panel_line ~width ~width_of style text) content
        @ [ O.panel_bottom ~width ~style:O.Focused_frame ~title:bottom ~width_of () ]
        @ navigation
    | None ->
        let feedback = notice_lines ~dimensions:(width,height) ~width_of t in
        let action_height = if height >= 7 then 1 else 0 in
        let footer_height = 2 + action_height + List.length feedback in
        let available = max 0 (height - footer_height) in
        let body_height = max 0 (available - 1) in
        let pane_height = body_height - 5 in
        let wide = width >= 72 in
        if wide && pane_height >= 7 then
          (* Wide layout: Title + Movement panel + Postings (left 3/5) & Candidates (right 2/5) *)
          let title_row = raw O.Heading title in
          (* Movement panel (height 5) *)
          let movement_focused = t.focus < 3 in
          let m_style = if movement_focused then O.Focused_frame else O.Frame in
          let d_text, d_caret = field_text ~width_of (width - 4) (t.focus = 0) t.cursor "Date" t.day in
          let d_style = match d_caret with Some c -> O.Input (2 + c) | None -> O.Plain in
          let m_text, m_caret =
            if is_plan t then
              let label_w = min 13 (max 0 ((width - 4) / 2)) in
              O.pad ~width_of label_w (tr "Description" ^ ":") ^ " " ^ tr "(not applicable)", None
            else field_text ~width_of (width - 4) (t.focus = 1) t.cursor "Description" t.description
          in
          let m_f_style = match m_caret with Some c -> O.Input (2 + c) | None -> O.Plain in
          let q_text, q_caret = field_text ~width_of (width - 4) (t.focus = 2) t.cursor "Measure" t.measure in
          let q_style = match q_caret with Some c -> O.Input (2 + c) | None -> O.Plain in
          let movement_panel = [
            sub_border ~width_of ~width ~style:m_style "Movement";
            inner_line ~width_of ~width d_style d_text;
            inner_line ~width_of ~width m_f_style m_text;
            inner_line ~width_of ~width q_style q_text;
            sub_bottom ~width_of ~width ~style:m_style ();
          ] in
          (* Postings panel (left 3/5) *)
          let left_width = width * 3 / 5 in
          let right_width = width - left_width - 1 in
          let postings_focused = t.focus >= 3 && t.focus < action_start t in
          let p_style = if postings_focused then O.Focused_frame else O.Frame in
          let posting_data_cap = max 0 (pane_height - 3) in
          let posting_cap = max 1 (posting_data_cap / 2) in
          let active_posting = if postings_focused then (t.focus - 3) / 2 else 0 in
          let row_count = List.length t.rows in
          let p_start = min (max 0 (row_count - posting_cap)) (max 0 (active_posting - posting_cap + 1)) in
          let p_more = (if p_start > 0 then " ▲" else "") ^ (if p_start + posting_cap < row_count then " ▼" else "") in
          let p_sub = Printf.sprintf "%d/%d rows%s" (min row_count (p_start + posting_cap)) row_count p_more in
          let posting_rows =
            t.rows |> List.filteri (fun i _ -> i >= p_start && i < p_start + posting_cap)
            |> List.mapi (fun rel_idx row ->
                let abs_idx = p_start + rel_idx in
                let locus_idx = 3 + 2 * abs_idx in
                let amount_idx = 4 + 2 * abs_idx in
                let l_text, l_caret = field_text ~width_of (left_width - 4) (t.focus = locus_idx) t.cursor
                    (A.format_message "Posting %d" (abs_idx + 1)) row.locus in
                let a_text, a_caret = field_text ~width_of (left_width - 4) (t.focus = amount_idx) t.cursor
                    "Amount" row.amount in
                let l_s = match l_caret with Some c -> O.Input (2 + c) | None -> O.Plain in
                let a_s = match a_caret with Some c -> O.Input (2 + c) | None -> O.Plain in
                [ inner_line ~width_of ~width:left_width l_s l_text;
                  inner_line ~width_of ~width:left_width a_s a_text ])
            |> List.concat
          in
          let p_context = O.clip_text ~width_of (left_width - 4)
              (A.format_message "Signed %s · decimal scale per Measure" t.measure) in
          let p_context_line = inner_line ~width_of ~width:left_width O.Chrome p_context in
          let p_pad_len = max 0 ((pane_height - 2) - List.length posting_rows - 1) in
          let p_pad = List.init p_pad_len (fun _ -> inner_line ~width_of ~width:left_width O.Plain "") in
          let postings_panel =
            [ sub_border ~width_of ~width:left_width ~style:p_style "Postings" ]
            @ posting_rows @ p_pad @ [ p_context_line ]
            @ [ sub_bottom ~width_of ~width:left_width ~style:p_style ~title:p_sub () ]
          in
          (* Candidates panel (right 2/5) *)
          let cand_focused = is_locus t in
          let c_style = if cand_focused then O.Focused_frame else O.Frame in
          let cand_data_cap = max 0 (pane_height - 4) in
          let choices = candidates ~book t in
          let count = List.length choices in
          let chosen = if count = 0 then 0 else t.candidate mod count in
          let c_start = min (max 0 (count - cand_data_cap)) (max 0 (chosen - cand_data_cap + 1)) in
          let c_more = (if c_start > 0 then " ▲" else "") ^ (if c_start + cand_data_cap < count then " ▼" else "") in
          let c_sub = if count = 0 then "0 candidates" else Printf.sprintf "%d/%d%s" (chosen + 1) count c_more in
          let candidate_lines =
            if count = 0 then [ inner_line ~width_of ~width:right_width O.Chrome (tr "No matching Locus") ]
            else
              choices |> List.filteri (fun i _ -> i >= c_start && i < c_start + cand_data_cap)
              |> List.mapi (fun rel_i id ->
                  let abs_i = c_start + rel_i in
                  let is_chosen = cand_focused && abs_i = chosen in
                  let label = B.label book id in
                  let display = (if is_chosen then "> " else "  ") ^ id ^ (if label = "" then "" else "  " ^ label) in
                  let s = if is_chosen then (if cand_focused then O.Active else O.Chrome) else O.Plain in
                  inner_line ~width_of ~width:right_width s (O.clip_text ~width_of (right_width - 4) display))
          in
          let help_text =
            if not cand_focused then tr "Focus a Locus field"
            else if count = 0 then tr "No matching Locus"
            else match List.nth_opt choices chosen with
            | Some id ->
                let label = B.label book id in
                if label = "" then "↑/↓ choose · Enter accept" else "↳ " ^ label
            | None -> "↑/↓ choose · Enter accept"
          in
          let help_line = inner_line ~width_of ~width:right_width O.Chrome (O.clip_text ~width_of (right_width - 4) help_text) in
          let admit_line = inner_line ~width_of ~width:right_width O.Chrome (tr "Admitted Locus only") in
          let c_pad_len = max 0 ((pane_height - 2) - List.length candidate_lines - 2) in
          let c_pad = List.init c_pad_len (fun _ -> inner_line ~width_of ~width:right_width O.Plain "") in
          let candidates_panel =
            [ sub_border ~width_of ~width:right_width ~style:c_style "Locus candidates" ]
            @ candidate_lines @ c_pad @ [ help_line; admit_line ]
            @ [ sub_bottom ~width_of ~width:right_width ~style:c_style ~title:c_sub () ]
          in
          let lower_panes = combine_side_by_side ~width_of ~width ~left_width ~right_width postings_panel candidates_panel in
          let feedback_rows = List.map (raw O.Status) feedback in
          let action_rows = if action_height = 0 then [] else [ raw O.Heading (action_line ~width_of width t) ] in
          [ title_row ] @ movement_panel @ lower_panes @ feedback_rows @ action_rows @ navigation
        else
          (* Compact / degraded layout (width < 72 or low height) *)
          let inside = max 0 (width - 4) in
          let content_capacity = max 0 (height - 4) in
          let action_height = if content_capacity > List.length feedback then 1 else 0 in
          let capacity = max 0 (content_capacity - List.length feedback - action_height) in
          let field index label value =
            let text, caret = field_text ~width_of inside (t.focus = index) t.cursor label value in
            (match caret with Some cell -> O.Input (2 + cell) | None -> O.Plain), text
          in
          let field_indices =
            (if is_plan t then [0; 2] else [0; 1; 2])
            @ List.concat (List.mapi (fun index _ -> [3 + 2 * index; 4 + 2 * index]) t.rows)
          in
          let fields =
            (if is_plan t then [field 0 "Date" t.day; field 2 "Measure" t.measure]
             else [field 0 "Date" t.day; field 1 "Description" t.description; field 2 "Measure" t.measure])
            @ List.concat (List.mapi (fun index row ->
                [field (3 + 2 * index) (A.format_message "Posting %d" (index + 1)) row.locus;
                 field (4 + 2 * index) "Amount" row.amount]) t.rows)
          in
          let candidate_height = if capacity >= 12 then 3 else if capacity >= 4 then 1 else 0 in
          let field_capacity = max 0 (capacity - candidate_height) in
          let rec find_idx i = function
            | [] -> min (max 0 (List.length fields - 1)) t.focus
            | idx :: rest -> if idx = t.focus then i else find_idx (i + 1) rest
          in
          let selected = find_idx 0 field_indices in
          let last = max 0 (List.length fields - field_capacity) in
          let start = max 0 (min last (selected - field_capacity + 1)) in
          let shown = fields |> List.filteri (fun index _ -> index >= start && index < start + field_capacity) in
          let shown = shown @ List.init (max 0 (field_capacity - List.length shown)) (fun _ -> O.Plain, "") in
          let choices = candidates ~book t in
          let count = List.length choices in
          let chosen = if count = 0 then 0 else t.candidate mod count in
          let candidate_rows =
            if not (is_locus t) then
              List.init candidate_height (fun _ -> O.Chrome, "")
            else if candidate_height = 1 then
              [O.Chrome, (match List.nth_opt choices chosen with
                | None -> tr "No matching Locus"
                | Some id -> "› " ^ id ^ "  " ^ B.label book id)]
            else if candidate_height > 1 then
              let visible = candidate_height - 1 in
              let c_start = max 0 (min (max 0 (count - visible)) (chosen - visible + 1)) in
              (O.Chrome, tr "Locus candidates") ::
              (if count = 0 then [O.Chrome, tr "No matching Locus"]
               else choices |> List.mapi (fun index id -> index, id)
                 |> List.filter (fun (index, _) -> index >= c_start && index < c_start + visible)
                 |> List.map (fun (index, id) -> O.Chrome,
                     (if index = chosen then "› " else "  ") ^ id ^ "  " ^ B.label book id))
            else []
          in
          let rows = shown @ candidate_rows in
          let rows = List.filteri (fun index _ -> index < capacity) rows in
          let rows = rows @ List.init (max 0 (capacity - List.length rows)) (fun _ -> O.Plain, "") in
          let content = rows @ List.map (fun text -> O.Status, text) feedback
            @ (if action_height = 0 then [] else [O.Heading, action_line ~width_of inside t]) in
          let bottom =
            A.format_message "Fields %d–%d / %d"
              (if fields = [] || field_capacity = 0 then 0 else start + 1)
              (min (List.length fields) (start + field_capacity)) (List.length fields)
          in
          O.panel_border ~width ~style:O.Focused_frame ~width_of title
          :: List.map (fun (style, text) -> O.panel_line ~width ~width_of style text) content
          @ [O.panel_bottom ~width ~style:O.Focused_frame ~title:bottom ~width_of ()]
          @ navigation
