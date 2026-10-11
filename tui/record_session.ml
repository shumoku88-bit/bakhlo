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
type review = { transaction : A.transaction; base_bytes : string; action : int; scroll : int }
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
type outcome = Updated of t | Closed of t | Publish of A.transaction * string * t

let mode t = t.mode
let with_notice t notice = { t with notice }
let has_draft t =
  match t.mode with
  | A.Edit _ | A.Pay _ -> true
  | A.New -> t.description <> "" || List.exists (fun row -> row.amount <> "" || row.locus <> "") t.rows

let create ~book:_ ~day ~measure () =
  { mode = A.New; day; description = ""; measure;
    rows = [{key=None; locus=""; amount=""}; {key=None; locus=""; amount=""}];
    focus=1; cursor=None; candidate=0; notice=""; review=None; paste=None }

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
let field_count t = action_start t + 4
let row_index t = max 0 ((t.focus-3)/2)
let is_locus t = t.focus>=3 && t.focus<action_start t && (t.focus-3) mod 2=0
let is_amount t = t.focus>=3 && t.focus<action_start t && (t.focus-3) mod 2=1
let editable_structure t = match t.mode with A.Edit _ -> false | A.New | A.Pay _ -> true
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
        | A.New | A.Pay _ -> false in
      if text<>"" && negative text <> original_negative then
        with_notice t (tr "Correction keeps the posting sign; edit its amount magnitude.")
      else reset {t with rows=List.mapi (fun i row -> if i=row_index t then {row with amount=text} else row) t.rows}
    else reset {t with rows=List.mapi (fun i row -> if i<>row_index t then row
      else if is_locus t then {row with locus=text} else {row with amount=text}) t.rows}
  else t

let move_focus t delta =
  let count = field_count t in
  {t with focus=(t.focus+delta+count) mod count; cursor=None; candidate=0; notice=""}

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
  else
    match A.build_transaction ~book ~mode:t.mode (A.Multiple {day=t.day; memo=t.description; draft=draft t}) with
    | Error error -> with_notice t error.A.message
    | Ok transaction -> {t with review=Some {transaction; base_bytes; action=0; scroll=0}; notice=""; paste=None}

let insert t text =
  let updated, cursor=Fm.insert_at ~value:(value t) ~cursor:t.cursor text in
  let next=set_value t updated in
  if value next=updated then {next with cursor=Some cursor} else next

let erase t =
  let updated,cursor=Fm.erase_at ~value:(value t) ~cursor:t.cursor in
  let next=set_value t updated in
  if value next=updated then {next with cursor=Some cursor} else next

let review_lines ~book review = O.preview_lines book review.transaction
let review_geometry ~book ~dimensions:(width,height) ~width_of t review =
  let feedback=if t.notice="" then 1 else List.length (O.wrap_text ~width_of (max 1 width) t.notice) in
  let available=max 0 (height-feedback-6) in
  let lines=List.concat_map (O.wrap_text ~width_of (max 1 (width-4))) (review_lines ~book review) in
  let last=max 0 (List.length lines-available) in
  (available,lines,min last (max 0 review.scroll),last)

let scroll_review ~book ~dimensions ~width_of t delta endpoint =
  match t.review with None -> t | Some review ->
    let capacity,_,scroll,last=review_geometry ~book ~dimensions ~width_of t review in
    let next=match endpoint with Some false -> 0 | Some true -> last
      | None -> scroll + delta * (if abs delta=1 then 1 else max 1 capacity) in
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
                let capacity,_,_,_=review_geometry ~book ~dimensions ~width_of t review in
                if width<32 || height<12 || capacity<1 then
                  update (with_notice t (tr "Not enough room to review publication; enlarge the terminal."))
                else Publish (review.transaction,review.base_bytes,t)
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
  let text=if active then
      let pos=Fm.cursor_pos ~value:text cursor in
      let left=O.visible (String.sub text 0 pos) in
      let right=O.visible (String.sub text pos (String.length text-pos)) in
      let left=tail ~width_of (max 0 (room-1)) left in
      left ^ "|" ^ O.clip_text ~width_of (max 0 (room-width_of left-1)) right
    else O.clip_text ~width_of room (if text="" then "_" else text)
  in
  O.pad ~width_of label_width (tr label ^ ":") ^ text

let framed ~width_of ~width ~height ~title ~focused ~bottom rows =
  if width<4 || height<2 then [] else
  let rows=List.filteri (fun i _ -> i<height-2) rows in
  O.panel_border ~width ~style:(if focused then O.Focused_frame else O.Frame) ~width_of (tr title)
  :: rows @ List.init (max 0 (height-2-List.length rows)) (fun _ -> O.panel_line ~width ~width_of O.Plain "")
  @ [O.panel_bottom ~width ~style:(if focused then O.Focused_frame else O.Frame) ~title:bottom ~width_of ()]

let screen ~book ~dimensions:(width,height) ~width_of t =
  let width=max 0 width and height=max 0 height in
  let raw style text=style,O.clip_text ~width_of width text in
  let feedback=if t.notice="" then [raw O.Chrome ""] else
      List.map (raw O.Status) (O.wrap_text ~width_of (max 1 width) t.notice) in
  let operations=match t.review with
    | None -> [raw O.Chrome (tr "Tab/Shift-Tab focus   Enter next / preview   Esc cancel");
        raw O.Chrome (tr "Ctrl-n add row   Ctrl-d drop row   Up/Down choose Locus")]
    | Some _ -> [raw O.Chrome (tr "Up/Down review   Page Up/Down page   Home/End edges");
        raw O.Chrome (tr "Tab/Left/Right action   Enter confirm   Esc cancel")] in
  let actions=match t.review with
    | None -> List.mapi (fun i label -> (if t.focus=action_start t+i then "> " else "") ^ "[" ^ tr label ^ "]") ["Preview";"Add row";"Drop row";"Cancel"]
    | Some r -> List.mapi (fun i label -> (if r.action=i then "> " else "") ^ "[" ^ tr label ^ "]") ["Publish";"Edit";"Cancel"] in
  let footer=feedback @ [raw O.Heading (String.concat "  " actions)] @ operations in
  let footer=if List.length footer<=height then footer else
      let kept=List.filteri (fun i _ -> i<max 0 (height-1)) footer in
      kept @ (if height=0 then [] else [raw O.Status (tr "More feedback/help; enlarge terminal.")]) in
  let body_capacity=max 0 (height-List.length footer) in
  let body=if width<32 || height<12 then
      [raw O.Heading (tr "Record"); raw O.Status (tr "Enlarge terminal to review and publish (32 columns x 12 rows).");
       raw O.Chrome (tr "Esc cancels; the draft is retained.")]
    else match t.review with
    | Some r ->
        let _,lines,scroll,_=review_geometry ~book ~dimensions:(width,height) ~width_of t r in
        let panel_height=max 0 (body_capacity-1) in
        let capacity=max 0 (panel_height-2) in
        [raw O.Heading (tr "Record / Preview")]
        @ framed ~width_of ~width ~height:panel_height ~title:"Movement / signed postings" ~focused:true
            ~bottom:(Printf.sprintf "%d-%d / %d" (if lines=[] then 0 else scroll+1)
              (min (List.length lines) (scroll+capacity)) (List.length lines))
            (lines |> List.filteri (fun i _ -> i>=scroll && i<scroll+capacity)
              |> List.map (O.panel_line ~width ~width_of O.Plain))
    | None ->
        let field index label text pane_width=
          O.panel_line ~width:pane_width ~width_of (if t.focus=index then O.Active else O.Plain)
            (field_text ~width_of (max 0 (pane_width-4)) (t.focus=index) t.cursor label text) in
        let fields pane_width = [field 0 "Date" t.day pane_width; field 1 "Description" t.description pane_width;
          field 2 "Measure" t.measure pane_width] @ List.concat (List.mapi (fun i row ->
            [field (3+2*i) (A.format_message "Posting %d" (i+1)) row.locus pane_width;
             field (4+2*i) "Amount" row.amount pane_width]) t.rows) in
        let heading=raw O.Heading (match t.mode with A.New -> tr "Record / Edit"
          | A.Edit _ -> tr "Actual / Correct" | A.Pay _ -> tr "Scheduled / Complete") in
        let pane_height=body_capacity-6 in
        if (width>=72 && pane_height>=6) || (width<72 && pane_height>=11) then
          let wide=width>=72 in
          let left=if wide then width*3/5 else width in
          let right=if wide then width-left-1 else width in
          let posting_height=if wide then pane_height else pane_height-6 in
          let candidate_height=if wide then pane_height else 6 in
          let posting_fields=fields left |> List.filteri (fun i _ -> i>=3) in
          let capacity=max 1 (posting_height-2) in
          let selected=max 0 (t.focus-3) in
          let start=max 0 (min (List.length posting_fields-capacity) (selected-capacity+1)) in
          let posting_rows=List.filteri (fun i _ -> i>=start && i<start+capacity) posting_fields in
          let postings=framed ~width_of ~width:left ~height:posting_height ~title:"Postings"
            ~focused:(t.focus>=3 && t.focus<action_start t) ~bottom:(Printf.sprintf "%d / %d rows" (min (List.length t.rows) ((start+capacity+1)/2)) (List.length t.rows)) posting_rows in
          let choices=candidates ~book t in
          let n=List.length choices in
          let selected=if n=0 then 0 else t.candidate mod n in
          let capacity=max 0 (candidate_height-3) in
          let start=max 0 (selected-capacity+1) in
          let candidate_rows=choices |> List.mapi (fun i id -> i,id)
            |> List.filter (fun (i,_) -> i>=start && i<start+capacity)
            |> List.map (fun (i,id) -> O.panel_line ~width:right ~width_of (if i=selected then O.Plain else O.Chrome)
              ((if i=selected then "> " else "  ") ^ id ^ "  " ^ B.label book id)) in
          let candidate_rows=if candidate_rows=[] then [O.panel_line ~width:right ~width_of O.Chrome (tr "No matching candidate")] else candidate_rows in
          let candidates=framed ~width_of ~width:right ~height:candidate_height ~title:"Locus candidates" ~focused:false
            ~bottom:(Printf.sprintf "%d / %d" (if n=0 then 0 else selected+1) n)
            (candidate_rows @ [O.panel_line ~width:right ~width_of O.Chrome (tr "Admitted Locus only")]) in
          [heading] @ framed ~width_of ~width ~height:5 ~title:"Movement" ~focused:(t.focus<3) ~bottom:"" (fields width |> List.filteri (fun i _ -> i<3))
          @ (if wide then List.map2 (fun (style,left_row) (_,right_row) -> style,left_row ^ " " ^ right_row) postings candidates
            else postings @ candidates)
        else
          let panel_height=max 0 (body_capacity-1) in
          let all=fields width in
          let capacity=max 0 (panel_height-3) in
          let start=max 0 (min (List.length all-capacity) (t.focus-capacity+1)) in
          let shown=List.filteri (fun i _ -> i>=start && i<start+capacity) all in
          let choice=match candidates ~book t with [] -> tr "Locus: no matching candidate"
            | choices -> let id=List.nth choices (t.candidate mod List.length choices) in
                tr "Locus candidates:" ^ " " ^ id ^ "  " ^ B.label book id in
          [heading] @ framed ~width_of ~width ~height:panel_height ~title:"Fields" ~focused:true
            ~bottom:(Printf.sprintf "%d-%d / %d" (start+1) (min (List.length all) (start+capacity)) (List.length all))
            (shown @ [O.panel_line ~width ~width_of O.Chrome choice])
  in
  let body=List.filteri (fun i _ -> i<body_capacity) body in
  body @ List.init (max 0 (body_capacity-List.length body)) (fun _ -> raw O.Plain "") @ footer
