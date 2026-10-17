(* English-first Record editor. Drafts and preview navigation are local state;
   only an explicit selected Publish action requests the existing publisher. *)
module B = Bakhlo_sexp.Daily_book
module A = Daily_actions
module D = Bakhlo_domain
module R = Posting_draft
module O = Daily_overlays
module Fm = Daily_form
let tr = Ui_text.tr

type original_editor = { measure : string; amount : string; focus : int }
type row = { key : D.Identifier.Effect_key.t option; locus : string; amount : string }
type review = { payload : A.payload; base_bytes : string; action : int; scroll : int }
type t = {
  mode : A.mode;
  day : string;
  description : string;
  measure : string;
  initial_day : string;
  initial_measure : string;
  rows : row list;
  focus : int;
  cursor : int option;
  candidate : int;
  notice : string;
  review : review option;
  paste : (string * bool) option;
  original_amount : (string * Z.t) option;
  original_editor : original_editor option;
}
type outcome = Updated of t | Closed of t | Publish of A.payload * string * t

let mode t = t.mode
let with_notice t notice = { t with notice }
let is_plan t = match t.mode with A.Plan_new | A.Plan_edit _ -> true | A.New | A.Edit _ | A.Pay _ -> false
let has_draft t =
  match t.mode with
  | A.Edit _ | A.Pay _ | A.Plan_edit _ -> true
  | A.New | A.Plan_new -> t.day <> t.initial_day || t.measure <> t.initial_measure
      || t.description <> "" || t.original_amount <> None || List.exists (fun (r : row) -> r.amount <> "" || r.locus <> "") t.rows

let create ~book:_ ~day ~measure () =
  { mode = A.New; day; description = ""; measure; initial_day = day; initial_measure = measure;
    rows = [{key=None; locus=""; amount=""}; {key=None; locus=""; amount=""}];
    focus=1; cursor=None; candidate=0; notice=""; review=None; paste=None;
    original_amount=None; original_editor=None }

let create_plan ~book:_ ~day ~measure () =
  { mode = A.Plan_new; day; description = ""; measure; initial_day = day; initial_measure = measure;
    rows = [{key=None; locus=""; amount=""}; {key=None; locus=""; amount=""}];
    focus=0; cursor=None; candidate=0; notice=""; review=None; paste=None;
    original_amount=None; original_editor=None }

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
            rows=rows_of_draft draft; original_amount=entry.original_amount})

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
    | None -> move_focus t 1

let add_row t =
  if not (editable_structure t) then with_notice t (tr "Correction keeps the posting structure.")
  else if List.length t.rows >= 6 then with_notice t (tr "This editor supports up to six posting rows.")
  else {t with rows=t.rows @ [{key=None;locus="";amount=""}]; focus=action_start t;
    candidate=0; cursor=None; notice=""}

let drop_row t =
  if not (editable_structure t) then with_notice t (tr "Correction keeps the posting structure.")
  else if List.length t.rows<=2 then with_notice t (tr "Keep at least two postings.")
  else
    let index = min (List.length t.rows-1) (row_index t) in
    let rows=List.filteri (fun i _ -> i<>index) t.rows in
    {t with rows; focus=3 + 2 * min index (List.length rows-1); cursor=None; candidate=0; notice=""}

let parse_row_amount ~book ~measure amount_str =
  let trimmed = String.trim amount_str in
  if trimmed = "" then Error "empty"
  else
    let negative = String.starts_with ~prefix:"-" trimmed in
    let signed = negative || String.starts_with ~prefix:"+" trimmed in
    let core = if signed then String.sub trimmed 1 (String.length trimmed - 1) else trimmed in
    match B.parse_amount book measure (String.trim core) with
    | Error why -> Error why
    | Ok quanta ->
        if Z.equal quanta Z.zero then Error "zero"
        else Ok (if negative then Z.neg quanta else quanta)

let format_signed ~book ~measure (amount : Z.t) =
  (if Z.sign amount > 0 then "+" else "") ^ B.format book measure amount

let fill_unresolved_remainder ~book t =
  if not (editable_structure t) then with_notice t (tr "Correction keeps the posting structure.")
  else if t.measure = "" then
    with_notice t (tr "Enter a valid Measure before filling the unresolved remainder.")
  else
    let is_approved locus =
      match B.approved_loci book with
      | None -> true
      | Some list -> List.mem locus list
    in
    if not (is_approved "suspense") then
      with_notice t (tr "Unresolved recording is not enabled yet. Admit the 'suspense' Locus first.")
    else
      let rec check_rows idx sum count_suspense susp_idx = function
        | [] -> Ok (sum, count_suspense, susp_idx)
        | row :: rest ->
            let locus = String.trim row.locus in
            if locus = "" then
              Error (tr "Complete every current Locus before filling the unresolved remainder.")
            else if not (is_approved locus) then
              Error (tr "Every current posting must use an admitted Locus.")
            else
              match parse_row_amount ~book ~measure:t.measure row.amount with
              | Error "zero" ->
                  Error (tr "Complete every current nonzero amount before filling the unresolved remainder.")
              | Error _ ->
                  Error (A.format_message "Posting %d amount '%s' is not a valid nonzero amount for unresolved remainder assistance."
                           (idx + 1) row.amount)
              | Ok amt ->
                  let is_susp = (locus = "suspense") in
                  let new_count = if is_susp then count_suspense + 1 else count_suspense in
                  let new_susp_idx = if is_susp then Some idx else susp_idx in
                  check_rows (idx + 1) (Z.add sum amt) new_count new_susp_idx rest
      in
      match check_rows 0 Z.zero 0 None t.rows with
      | Error msg -> with_notice t msg
      | Ok (_, count_susp, _) when count_susp > 1 ->
          with_notice t (tr "Keep at most one unresolved posting before using this action.")
      | Ok (sum, _, _) when Z.equal sum Z.zero ->
          with_notice t (tr "This Movement is already balanced; there is no unresolved remainder.")
      | Ok (sum, _, susp_idx_opt) ->
          let adjustment = Z.neg sum in
          (match susp_idx_opt with
          | None ->
              if List.length t.rows >= 6 then
                with_notice t (tr "No row is available for the unresolved remainder.")
              else
                let new_row = { key = None; locus = "suspense"; amount = format_signed ~book ~measure:t.measure adjustment } in
                let next_rows = t.rows @ [ new_row ] in
                { t with rows = next_rows; focus = action_start { t with rows = next_rows }; candidate = 0; cursor = None; notice = "" }
          | Some idx ->
              let row = List.nth t.rows idx in
              match parse_row_amount ~book ~measure:t.measure row.amount with
              | Error _ -> with_notice t (tr "The existing unresolved amount is not valid.")
              | Ok current ->
                  let adjusted = Z.add current adjustment in
                  if Z.equal adjusted Z.zero then
                    let next_rows = List.filteri (fun i _ -> i <> idx) t.rows in
                    { t with rows = next_rows; focus = action_start { t with rows = next_rows }; candidate = 0; cursor = None; notice = "" }
                  else
                    let next_rows = List.mapi (fun i r ->
                      if i = idx then { r with amount = format_signed ~book ~measure:t.measure adjusted }
                      else r) t.rows in
                    { t with rows = next_rows; focus = action_start { t with rows = next_rows }; candidate = 0; cursor = None; notice = "" })

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
    match t.original_amount with
    | Some (m, _) when not (List.mem_assoc m (B.measures book)) ->
        with_notice t (A.format_message "Measure '%s' scale is not configured in this book." m)
    | _ ->
        (match A.build_transaction ~book ~mode:t.mode (A.Multiple {day=t.day; memo=t.description; draft=draft t; original_amount=t.original_amount}) with
        | Error error -> with_notice t error.A.message
        | Ok transaction ->
            {t with review=Some {payload=A.Entry_tx transaction; base_bytes; action=0; scroll=0}; notice=""; paste=None})

let insert t text =
  let updated, cursor=Fm.insert_at ~value:(value t) ~cursor:t.cursor text in
  let next=set_value t updated in
  if value next=updated then {next with cursor=Some cursor; candidate=0} else {next with candidate=0}

let erase t =
  let updated,cursor=Fm.erase_at ~value:(value t) ~cursor:t.cursor in
  let next=set_value t updated in
  if value next=updated then {next with cursor=Some cursor; candidate=0} else {next with candidate=0}

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
  (* Same title, panel borders, gate, action and navigation rows as screen. *)
  let action_height = if height >= 7 then 1 else 0 in
  let gate_height = if height >= 14 then 2 else 0 in
  let available=max 0 (height-feedback-5-action_height-gate_height) in
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

let is_date_char = function
  | '0' .. '9' | '-' | '/' | '.' -> true
  | _ -> false
let format_amount_str ~scale quanta =
  if scale = 0 then Z.to_string quanta
  else
    let is_neg = Z.sign quanta < 0 in
    let s = Z.to_string (Z.abs quanta) in
    let len = String.length s in
    let whole, frac =
      if len <= scale then ("0", String.make (scale - len) '0' ^ s)
      else (String.sub s 0 (len - scale), String.sub s (len - scale) scale)
    in
    (if is_neg then "-" else "") ^ whole ^ "." ^ frac

let parse_original_quanta ~scale amount_str =
  let trimmed = String.trim amount_str in
  if trimmed = "" then Error `Invalid
  else if String.starts_with ~prefix:"-" trimmed then Error `Non_positive
  else
    let core = if String.starts_with ~prefix:"+" trimmed then String.sub trimmed 1 (String.length trimmed - 1) else trimmed in
    let core = String.concat "" (String.split_on_char ',' core) in
    let is_digit c = c >= '0' && c <= '9' in
    match String.split_on_char '.' core with
    | [ whole ] ->
        let whole = String.trim whole in
        if whole = "" || not (String.for_all is_digit whole) then Error `Invalid
        else
          let q = Z.mul (Z.of_string whole) (Z.pow (Z.of_int 10) scale) in
          if Z.sign q <= 0 then Error `Non_positive else Ok q
    | [ whole; fraction ] ->
        let whole = String.trim whole in
        let fraction = String.trim fraction in
        let whole_ok = whole = "" || String.for_all is_digit whole in
        let frac_ok = fraction <> "" && String.for_all is_digit fraction in
        if not (whole_ok && frac_ok) then Error `Invalid
        else if String.length fraction > scale then Error `Precision
        else
          let whole_val = if whole = "" then Z.zero else Z.of_string whole in
          let frac_padded = fraction ^ String.make (scale - String.length fraction) '0' in
          let frac_val = if frac_padded = "" then Z.zero else Z.of_string frac_padded in
          let q = Z.add (Z.mul whole_val (Z.pow (Z.of_int 10) scale)) frac_val in
          if Z.sign q <= 0 then Error `Non_positive else Ok q
    | _ -> Error `Invalid

let handle ~book ~base_bytes ~blocked ~dimensions ~width_of t (input:Ui_input.input) =
  let update t=Updated t in
  match input,t.paste with
  | `Paste `Start, _ -> update {t with paste=Some ("",false)}
  | `Paste `End, Some (text,invalid) ->
      let t={t with paste=None} in
      if blocked then update t
      else if invalid || not (safe_text text) then update (with_notice t (tr "Paste refused: use one printable line; no control keys."))
      else (match t.original_editor with
      | Some ed ->
          let cur_val = if ed.focus = 0 then ed.measure else ed.amount in
          let updated, cur = Fm.insert_at ~value:cur_val ~cursor:t.cursor text in
          let next_ed = if ed.focus = 0 then { ed with measure = updated } else { ed with amount = updated } in
          update { t with original_editor = Some next_ed; cursor = Some cur; notice = "" }
      | None ->
          if t.review<>None || t.focus>=action_start t then update t
          else if t.focus = 0 && not (String.for_all is_date_char (String.trim text)) then
            update (with_notice t (tr "Invalid date format; enter YYYY-MM-DD."))
          else update (insert t text))
  | `Key (`ASCII c,[]), Some (text,invalid) ->
      update {t with paste=Some (text ^ String.make 1 c, invalid || Char.code c<32 || Char.code c=127)}
  | `Key (`Uchar c,[]), Some (text,invalid) ->
      update {t with paste=Some (text ^ O.utf8 c,invalid || not (O.printable_uchar c))}
  | `Key _, Some (text,_) -> update {t with paste=Some (text,true)}
  | `Key (`Escape,[]), None -> Closed {t with original_editor=None; review=None; paste=None}
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
          (match t.original_editor with
          | Some ed ->
              (match button,mods with
              | `Tab,[] | `Tab,[`Shift] ->
                  update { t with original_editor = Some { ed with focus = 1 - ed.focus }; cursor = None; notice = "" }
              | `ASCII 'd',[`Ctrl] ->
                  update { t with original_amount = None; original_editor = None; cursor = None; notice = tr "Original amount cleared." }
              | `ASCII 'o',[`Ctrl] ->
                  update { t with original_editor = None; cursor = None; notice = "" }
              | `Enter,[] ->
                  let trimmed_m = String.trim ed.measure in
                  if trimmed_m = "" || not (safe_text trimmed_m) || String.contains trimmed_m ' '
                     || Result.is_error (D.Identifier.Measure.of_string trimmed_m) then
                    update (with_notice t (tr "Enter a nonempty single-line original Measure token."))
                  else (
                    match List.assoc_opt trimmed_m (B.measures book) with
                    | None ->
                        update (with_notice t (A.format_message "Measure '%s' scale is not configured in this book." trimmed_m))
                    | Some scale ->
                        if ed.focus = 0 then
                          update { t with original_editor = Some { ed with focus = 1 }; cursor = None; notice = "" }
                        else
                          (match parse_original_quanta ~scale ed.amount with
                          | Error `Precision | Error `Invalid ->
                              update (with_notice t (A.format_message "Enter a positive original amount with at most %d decimal places." scale))
                          | Error `Non_positive ->
                              update (with_notice t (tr "Original amount must be positive."))
                          | Ok quanta ->
                              update { t with original_amount = Some (trimmed_m, quanta); original_editor = None; cursor = None; notice = "" }))
              | `Arrow `Left,[] | `Arrow `Right,[] ->
                  let cur_val = if ed.focus = 0 then ed.measure else ed.amount in
                  let step = if button = `Arrow `Left then -1 else 1 in
                  update { t with cursor = Some (Fm.move_cursor ~value:cur_val ~cursor:t.cursor step) }
              | `Home,[] -> update { t with cursor = Some 0 }
              | `End,[] -> update { t with cursor = None }
              | `Backspace,[] ->
                  let cur_val = if ed.focus = 0 then ed.measure else ed.amount in
                  let updated, cur = Fm.erase_at ~value:cur_val ~cursor:t.cursor in
                  let next_ed = if ed.focus = 0 then { ed with measure = updated } else { ed with amount = updated } in
                  update { t with original_editor = Some next_ed; cursor = Some cur; notice = "" }
              | `ASCII c,[] when Char.code c >= 32 && Char.code c <> 127 ->
                  let cur_val = if ed.focus = 0 then ed.measure else ed.amount in
                  let updated, cur = Fm.insert_at ~value:cur_val ~cursor:t.cursor (String.make 1 c) in
                  let next_ed = if ed.focus = 0 then { ed with measure = updated } else { ed with amount = updated } in
                  update { t with original_editor = Some next_ed; cursor = Some cur; notice = "" }
              | `Uchar c,[] when O.printable_uchar c ->
                  let cur_val = if ed.focus = 0 then ed.measure else ed.amount in
                  let updated, cur = Fm.insert_at ~value:cur_val ~cursor:t.cursor (O.utf8 c) in
                  let next_ed = if ed.focus = 0 then { ed with measure = updated } else { ed with amount = updated } in
                  update { t with original_editor = Some next_ed; cursor = Some cur; notice = "" }
              | _ -> update t)
          | None ->
              (match button,mods with
              | `ASCII 'o',[`Ctrl] ->
                  if is_plan t then update t
                  else (match t.mode with
                  | A.Edit _ -> update (with_notice t (tr "Original amount is not changed by the current Correction editor."))
                  | A.Pay _ -> update (with_notice t (tr "Original amount is available from new Actual Record, not Scheduled completion."))
                  | A.New -> (
                      match t.original_amount with
                      | None ->
                          let ed = { measure = ""; amount = ""; focus = 0 } in
                          update { t with original_editor = Some ed; cursor = None; notice = "" }
                      | Some (m, q) -> (
                          match List.assoc_opt m (B.measures book) with
                          | Some scale ->
                              let ed = { measure = m; amount = format_amount_str ~scale q; focus = 0 } in
                              update { t with original_editor = Some ed; cursor = None; notice = "" }
                          | None ->
                              update (with_notice t (A.format_message "Measure '%s' scale is not configured in this book." m))))
                  | A.Plan_new | A.Plan_edit _ -> update t)
              | `Tab,[] -> update (move_focus t 1)
              | `Tab,[`Shift] -> update (move_focus t (-1))
              | `ASCII 'n',[`Ctrl] -> update (add_row t)
              | `ASCII 'd',[`Ctrl] -> update (drop_row t)
              | `ASCII 'u',[`Ctrl] -> update (fill_unresolved_remainder ~book t)
              | `ASCII 's',[`Ctrl] -> update (preview ~book ~base_bytes ~blocked t)
          | `Enter,[] ->
              if is_locus t then update (accept ~book t)
              else if t.focus=action_start t || t.focus=action_start t-1 then
                update (preview ~book ~base_bytes ~blocked t)
              else if t.focus=action_start t+1 then update (add_row t)
              else if t.focus=action_start t+2 then drop_row t |> update
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
              if t.focus = 0 && not (is_date_char c) then update t
              else if t.focus = 0 && String.length (value t) >= 10 && t.cursor = None then update t
              else update (insert t (String.make 1 c))
          | `Uchar c,[] when t.focus<action_start t && O.printable_uchar c ->
              if t.focus = 0 then update t
              else update (insert t (O.utf8 c))
          | _ -> update t)))
  | `End,_ -> Closed {t with paste=None;review=None}
  | `Resize _,_ | `Mouse _,_ | `Paste `End,None -> update t


let field_text ~width_of width active cursor label text =
  let label_width=min 13 (max 0 (width/2)) in
  let room=max 0 (width-label_width) in
  let text,caret=if active then O.input_text ~width_of ~width:room ~cursor ~caret:"|" text
    else O.clip_text ~width_of room (if text="" then "_" else text),None
  in
  O.pad ~width_of label_width (tr label ^ ":") ^ text,
  Option.map (fun cell -> label_width + cell) caret

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
  let content = O.clip_text ~width_of room text in
  let padded = content ^ String.make (max 0 (room - width_of content)) ' ' in
  (style, left ^ padded ^ right)

let original_amount_screen ~book:_ ~dimensions:(width,height) ~width_of t (ed : original_editor) =
  let width = max 0 width and height = max 0 height in
  let raw style text = style, O.pad ~width_of width text in
  let title_row = raw O.Heading (tr "Record / Original amount") in
  let feedback = notice_lines ~dimensions:(width,height) ~width_of t in
  let feedback_rows = List.map (raw O.Status) feedback in
  let nav1 = tr "Tab/Shift-Tab focus   [Enter] next/attach" in
  let nav2 = tr "Ctrl-D clear   Ctrl-O return   [Esc] cancel" in
  let navigation = [ raw O.Chrome nav1; raw O.Chrome nav2 ] in
  let footer_h = List.length navigation + List.length feedback_rows in
  let avail = max 0 (height - 1 - footer_h) in
  let m_text, m_caret = field_text ~width_of (width - 2) (ed.focus = 0) t.cursor "Measure" ed.measure in
  let a_text, a_caret = field_text ~width_of (width - 2) (ed.focus = 1) t.cursor "Amount" ed.amount in
  let m_s = match m_caret with Some c -> O.Input (1 + c) | None -> O.Plain in
  let a_s = match a_caret with Some c -> O.Input (1 + c) | None -> O.Plain in
  let fields_panel = [
    sub_border ~width_of ~width ~style:O.Focused_frame "Original amount";
    inner_line ~width_of ~width m_s m_text;
    inner_line ~width_of ~width a_s a_text;
    sub_bottom ~width_of ~width ~style:O.Focused_frame ();
  ] in
  let meaning_h = max 0 (avail - 4) in
  let meaning_panel =
    if meaning_h < 3 then []
    else
      let expl = [
        tr "Merchant/card amount; not another posting.";
        tr "No FX inference or Movement Measure change.";
        tr "Attach to draft; Publish later in Preview.";
      ] in
      let cap = max 0 (meaning_h - 2) in
      let expl_lines = List.concat_map (O.wrap_text ~width_of (max 1 (width - 4))) expl in
      let shown_expl = List.filteri (fun i _ -> i < cap) expl_lines in
      let expl_rows = List.map (fun s -> inner_line ~width_of ~width O.Chrome s) shown_expl in
      let pad_len = max 0 (cap - List.length expl_rows) in
      let pad_rows = List.init pad_len (fun _ -> inner_line ~width_of ~width O.Plain "") in
      [ sub_border ~width_of ~width ~style:O.Frame "Meaning" ]
      @ expl_rows @ pad_rows
      @ [ sub_bottom ~width_of ~width ~style:O.Frame () ]
  in
  let all_rows = [ title_row ] @ fields_panel @ meaning_panel @ feedback_rows @ navigation in
  List.filteri (fun i _ -> i < height) all_rows
  @ List.init (max 0 (height - List.length all_rows)) (fun _ -> raw O.Plain "")

let screen ~book ~dimensions:(width,height) ~width_of t =
  let width = max 0 width and height = max 0 height in
  let raw style text = style, O.pad ~width_of width text in
  let navigation = match t.review with
    | None ->
        let orig_nav = if is_plan t then "" else "  C-o original" in
        if width < 50 then [tr "Tab field  Enter next / Preview"; tr ("C-n/d rows  C-u remainder" ^ orig_nav ^ "  Esc draft")]
        else [tr "Tab/Shift-Tab field  Enter next / Preview"; tr ("C-n/d rows  C-u remainder" ^ orig_nav ^ "  Esc hold draft")]
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
        let feedback = notice_lines ~dimensions:(width,height) ~width_of t in
        let action_height = if height >= 7 then 1 else 0 in
        let gate_height = if height >= 14 then 2 else 0 in
        let nav_height = List.length navigation in
        let footer_height = List.length feedback + gate_height + action_height + nav_height in
        (* title row (1) + panel borders (2) *)
        let panel_height = max 3 (height - footer_height - 1) in
        let capacity = max 0 (panel_height - 2) in
        let shown_capacity, lines, scroll, _ =
          review_geometry ~book ~dimensions:(width,height) ~width_of t review in
        let shown_capacity = min capacity shown_capacity in
        let shown = lines |> List.filteri (fun i _ -> i >= scroll && i < scroll + shown_capacity) in
        let shown_rows = List.map (fun text -> inner_line ~width_of ~width O.Plain text) shown in
        let pad_rows = List.init (max 0 (capacity - List.length shown_rows)) (fun _ -> inner_line ~width_of ~width O.Plain "") in
        let more = (if scroll > 0 then " ▲" else "") ^ (if scroll + shown_capacity < List.length lines then " ▼" else "") in
        let bottom = Printf.sprintf "%d/%d lines%s" (min (List.length lines) (scroll + shown_capacity)) (List.length lines) more in
        let panel =
          [ sub_border ~width_of ~width ~style:O.Focused_frame "Movement / signed postings" ]
          @ shown_rows @ pad_rows
          @ [ sub_bottom ~width_of ~width ~style:O.Focused_frame ~title:bottom () ]
        in
        let gate_rows =
          if gate_height = 0 then []
          else [ raw O.Chrome (tr "Publication gate");
                 raw O.Chrome ("  " ^ tr "recheck evidence + Locus admission") ]
        in
        let feedback_rows = List.map (raw O.Status) feedback in
        let action_rows = if action_height = 0 then [] else [ raw O.Heading (action_line ~width_of width t) ] in
        let all_rows = [ raw O.Heading title ] @ panel @ feedback_rows @ gate_rows @ action_rows @ navigation in
        List.filteri (fun i _ -> i < height) all_rows
        @ List.init (max 0 (height - List.length all_rows)) (fun _ -> raw O.Plain "")
    | None -> (
        match t.original_editor with
        | Some ed -> original_amount_screen ~book ~dimensions:(width,height) ~width_of t ed
        | None ->
            let orig_summary_rows =
              if is_plan t then []
              else
                let summary =
                  match t.original_amount with
                  | None -> tr "Original amount: (none)   Ctrl-O add"
                  | Some (m, q) ->
                      tr "Original amount: " ^ B.format book m q ^ " " ^ m ^ tr "   Ctrl-O edit"
                in
                [ raw O.Chrome summary ]
            in
            let orig_summary_h = if is_plan t then 0 else 1 in
            let feedback = notice_lines ~dimensions:(width,height) ~width_of t in
            let action_height = if height >= 7 then 1 else 0 in
            let footer_height = 2 + action_height + orig_summary_h + List.length feedback in
            let available = max 0 (height - footer_height) in
            let body_height = max 0 (available - 1) in
            let pane_height = body_height - 5 in
            let wide = width >= 72 in
            if (wide && pane_height >= 7) || ((not wide) && pane_height >= 11) then
          let title_row = raw O.Heading title in
          (* Movement panel (height 5) *)
          let movement_focused = t.focus < 3 in
          let m_style = if movement_focused then O.Focused_frame else O.Frame in
          let d_text, d_caret = field_text ~width_of (width - 2) (t.focus = 0) t.cursor "Date" t.day in
          let d_style = match d_caret with Some c -> O.Input (1 + c) | None -> O.Plain in
          let m_text, m_caret =
            if is_plan t then
              let label_w = min 13 (max 0 ((width - 2) / 2)) in
              O.pad ~width_of label_w (tr "Description" ^ ":") ^ " " ^ tr "(not applicable)", None
            else field_text ~width_of (width - 2) (t.focus = 1) t.cursor "Description" t.description
          in
          let m_f_style = match m_caret with Some c -> O.Input (1 + c) | None -> O.Plain in
          let q_text, q_caret = field_text ~width_of (width - 2) (t.focus = 2) t.cursor "Measure" t.measure in
          let q_style = match q_caret with Some c -> O.Input (1 + c) | None -> O.Plain in
          let movement_panel = [
            sub_border ~width_of ~width ~style:m_style "Movement";
            inner_line ~width_of ~width d_style d_text;
            inner_line ~width_of ~width m_f_style m_text;
            inner_line ~width_of ~width q_style q_text;
            sub_bottom ~width_of ~width ~style:m_style ();
          ] in
          let make_postings_panel ~p_width ~p_height =
            let postings_focused = t.focus >= 3 && t.focus < action_start t in
            let p_style = if postings_focused then O.Focused_frame else O.Frame in
            let posting_data_cap = max 0 (p_height - 3) in
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
                  let l_text, l_caret = field_text ~width_of (p_width - 2) (t.focus = locus_idx) t.cursor
                      (A.format_message "Posting %d" (abs_idx + 1)) row.locus in
                  let a_text, a_caret = field_text ~width_of (p_width - 2) (t.focus = amount_idx) t.cursor
                      "Amount" row.amount in
                  let l_s = match l_caret with Some c -> O.Input (1 + c) | None -> O.Plain in
                  let a_s = match a_caret with Some c -> O.Input (1 + c) | None -> O.Plain in
                  [ inner_line ~width_of ~width:p_width l_s l_text;
                    inner_line ~width_of ~width:p_width a_s a_text ])
              |> List.concat
            in
            let p_context = O.clip_text ~width_of (p_width - 2)
                (A.format_message "Signed %s · decimal scale per Measure" t.measure) in
            let p_context_line = inner_line ~width_of ~width:p_width O.Chrome p_context in
            let p_pad_len = max 0 ((p_height - 2) - List.length posting_rows - 1) in
            let p_pad = List.init p_pad_len (fun _ -> inner_line ~width_of ~width:p_width O.Plain "") in
            [ sub_border ~width_of ~width:p_width ~style:p_style "Postings" ]
            @ posting_rows @ p_pad @ [ p_context_line ]
            @ [ sub_bottom ~width_of ~width:p_width ~style:p_style ~title:p_sub () ]
          in
          let make_candidates_panel ~c_width ~c_height =
            let cand_focused = is_locus t in
            let c_style = if cand_focused then O.Focused_frame else O.Frame in
            let cand_data_cap = max 0 (c_height - 4) in
            let choices = candidates ~book t in
            let count = List.length choices in
            let chosen = if count = 0 then 0 else t.candidate mod count in
            let c_start = min (max 0 (count - cand_data_cap)) (max 0 (chosen - cand_data_cap + 1)) in
            let c_more = (if c_start > 0 then " ▲" else "") ^ (if c_start + cand_data_cap < count then " ▼" else "") in
            let c_sub = if count = 0 then "0 candidates" else Printf.sprintf "%d/%d%s" (chosen + 1) count c_more in
            let candidate_lines =
              if count = 0 then [ inner_line ~width_of ~width:c_width O.Chrome (tr "No matching Locus") ]
              else
                choices |> List.filteri (fun i _ -> i >= c_start && i < c_start + cand_data_cap)
                |> List.mapi (fun rel_i id ->
                    let abs_i = c_start + rel_i in
                    let is_chosen = cand_focused && abs_i = chosen in
                    let label = B.label book id in
                    let display = (if is_chosen then "> " else "  ") ^ id ^ (if label = "" then "" else "  " ^ label) in
                    let s = if is_chosen then O.Plain else O.Chrome in
                    inner_line ~width_of ~width:c_width s (O.clip_text ~width_of (c_width - 2) display))
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
            let help_line = inner_line ~width_of ~width:c_width O.Chrome (O.clip_text ~width_of (c_width - 2) help_text) in
            let admit_line = inner_line ~width_of ~width:c_width O.Chrome (tr "Admitted Locus only") in
            let c_pad_len = max 0 ((c_height - 2) - List.length candidate_lines - 2) in
            let c_pad = List.init c_pad_len (fun _ -> inner_line ~width_of ~width:c_width O.Plain "") in
            [ sub_border ~width_of ~width:c_width ~style:c_style "Locus candidates" ]
            @ candidate_lines @ c_pad @ [ help_line; admit_line ]
            @ [ sub_bottom ~width_of ~width:c_width ~style:c_style ~title:c_sub () ]
          in
          let lower_panes =
            if wide then
              let left_width = width * 3 / 5 in
              let right_width = width - left_width - 1 in
              List.map2 (fun (left_style,left_text) (right_style,right_text) ->
                O.Columns (left_width,left_style,right_style),
                O.pad ~width_of left_width left_text ^ " " ^ O.pad ~width_of right_width right_text)
                (make_postings_panel ~p_width:left_width ~p_height:pane_height)
                (make_candidates_panel ~c_width:right_width ~c_height:pane_height)
            else
              (make_postings_panel ~p_width:width ~p_height:(pane_height - 6))
              @ (make_candidates_panel ~c_width:width ~c_height:6)
          in
          let feedback_rows = List.map (raw O.Status) feedback in
          let action_rows = if action_height = 0 then [] else [ raw O.Heading (action_line ~width_of width t) ] in
              let all_rows = [ title_row ] @ movement_panel @ lower_panes @ feedback_rows @ orig_summary_rows @ action_rows @ navigation in
              List.filteri (fun i _ -> i < height) all_rows
              @ List.init (max 0 (height - List.length all_rows)) (fun _ -> raw O.Plain "")
        else
          (* Compact / degraded layout (width < 72 or low height) *)
          let title_row = raw O.Heading title in
          let feedback = notice_lines ~dimensions:(width,height) ~width_of t in
          let action_height = if height >= 7 then 1 else 0 in
          let nav_height = List.length navigation in
          let footer_height = List.length feedback + action_height + orig_summary_h + nav_height in
          let panel_height = max 3 (height - footer_height - 1) in
          let capacity = max 0 (panel_height - 2) in
          let field index label value =
            let text, caret = field_text ~width_of (width - 2) (t.focus = index) t.cursor label value in
            let style = match caret with Some cell -> O.Input (1 + cell) | None -> O.Plain in
            inner_line ~width_of ~width style text
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
          let field_capacity = if capacity >= 3 then capacity - 1 else capacity in
          let rec find_idx i = function
            | [] -> min (max 0 (List.length fields - 1)) t.focus
            | idx :: rest -> if idx = t.focus then i else find_idx (i + 1) rest
          in
          let selected = find_idx 0 field_indices in
          let last = max 0 (List.length fields - field_capacity) in
          let start = max 0 (min last (selected - field_capacity + 1)) in
          let shown = fields |> List.filteri (fun index _ -> index >= start && index < start + field_capacity) in
          let choices = candidates ~book t in
          let count = List.length choices in
          let chosen = if count = 0 then 0 else t.candidate mod count in
          let summary_text =
            if not (is_locus t) then tr "Locus: focus a Locus field"
            else if count = 0 then tr "Locus: no matching candidate"
            else match List.nth_opt choices chosen with
            | Some id ->
                let label = B.label book id in
                "↑/↓ Enter: " ^ id ^ (if label = "" then "" else "  " ^ label)
            | None -> "↑/↓ Enter: choose candidate"
          in
          let summary_row = [ inner_line ~width_of ~width O.Chrome (O.clip_text ~width_of (width - 2) summary_text) ] in
          let panel_content =
            if capacity >= 3 then shown @ summary_row
            else shown
          in
          let pad_len = max 0 (capacity - List.length panel_content) in
          let pad_rows = List.init pad_len (fun _ -> inner_line ~width_of ~width O.Plain "") in
          let more = (if start > 0 then " ▲" else "") ^ (if start + field_capacity < List.length fields then " ▼" else "") in
          let bottom = Printf.sprintf "%d/%d fields%s" (min (List.length fields) (start + field_capacity)) (List.length fields) more in
          let panel =
            [ sub_border ~width_of ~width ~style:O.Focused_frame "Fields" ]
            @ panel_content @ pad_rows
            @ [ sub_bottom ~width_of ~width ~style:O.Focused_frame ~title:bottom () ]
          in
          let feedback_rows = List.map (raw O.Status) feedback in
          let action_rows = if action_height = 0 then [] else [ raw O.Heading (action_line ~width_of width t) ] in
              let all_rows = [ title_row ] @ panel @ feedback_rows @ orig_summary_rows @ action_rows @ navigation in
              List.filteri (fun i _ -> i < height) all_rows
              @ List.init (max 0 (height - List.length all_rows)) (fun _ -> raw O.Plain ""))
