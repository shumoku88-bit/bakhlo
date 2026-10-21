(* Pure modal form component for Bakhlo TUI dialogs and workflows. *)

type button = { label : string; is_cancel : bool }

type field_kind =
  | Text of { value : string; placeholder : string }
  | Choice of { options : string list; selected : int }
  | Buttons of { buttons : button list; selected : int }

type field = { id : string; label : string; kind : field_kind }

type t = {
  id : string;
  payload : string;
  title : string;
  summary : string list;
  fields : field list;
  focused : int;
  notice : string;
}

type event = Updated of t | Submit of t | Cancel

let id t = t.id
let payload t = t.payload
let title t = t.title
let notice t = t.notice
let set_notice t notice = { t with notice }
let focused t = t.focused

let set_focused t idx =
  let count = List.length t.fields in
  if count = 0 then { t with focused = 0 } else { t with focused = max 0 (min (count - 1) idx) }

let get_field t fid = List.find_opt (fun (f : field) -> f.id = fid) t.fields

let update_field t fid fn =
  let fields =
    List.map (fun (f : field) -> if f.id = fid then { f with kind = fn f.kind } else f) t.fields
  in
  { t with fields }

let get_text t fid =
  match get_field t fid with Some { kind = Text { value; _ }; _ } -> Some value | _ -> None

let set_text t fid new_val =
  update_field t fid (function Text t -> Text { t with value = new_val } | other -> other)

let get_choice t fid =
  match get_field t fid with
  | Some { kind = Choice { selected; _ }; _ } -> Some selected
  | _ -> None

let get_choice_value t fid =
  match get_field t fid with
  | Some { kind = Choice { options; selected }; _ } ->
      if selected >= 0 && selected < List.length options then Some (List.nth options selected)
      else None
  | _ -> None

let set_choice t fid sel =
  update_field t fid (function
    | Choice c ->
        let count = List.length c.options in
        let s = if count = 0 then 0 else max 0 (min (count - 1) sel) in
        Choice { c with selected = s }
    | other -> other)

let get_button t fid =
  match get_field t fid with
  | Some { kind = Buttons { selected; _ }; _ } -> Some selected
  | _ -> None

let get_selected_button t =
  match List.find_opt (fun f -> match f.kind with Buttons _ -> true | _ -> false) t.fields with
  | Some { kind = Buttons { buttons; selected }; _ } ->
      if selected >= 0 && selected < List.length buttons then Some (List.nth buttons selected)
      else None
  | _ -> None

let text_field ~id ~label ?(value = "") ?(placeholder = "") () =
  { id; label; kind = Text { value; placeholder } }

let choice_field ~id ~label ~options ?(selected = 0) () =
  let count = List.length options in
  let sel = if count = 0 then 0 else max 0 (min (count - 1) selected) in
  { id; label; kind = Choice { options; selected = sel } }

let buttons_field ~id ~buttons ?(selected = 0) () =
  let count = List.length buttons in
  let sel = if count = 0 then 0 else max 0 (min (count - 1) selected) in
  { id; label = ""; kind = Buttons { buttons; selected = sel } }

let action_buttons ?(id = "action") ?(confirm = "Confirm") ?(cancel = "Cancel") () =
  buttons_field ~id
    ~buttons:[ { label = confirm; is_cancel = false }; { label = cancel; is_cancel = true } ]
    ()

let create ~id ?(payload = "") ~title ?(summary = []) ?(fields = []) ?(notice = "") () =
  { id; payload; title; summary; fields; focused = 0; notice }

let focused_field t =
  if t.focused >= 0 && t.focused < List.length t.fields then Some (List.nth t.fields t.focused)
  else None

let is_focused_on_text t =
  match focused_field t with Some { kind = Text _; _ } -> true | _ -> false

let is_last_editable_field t index =
  let rec check i = function
    | [] -> true
    | { kind = Text _; _ } :: _ when i > index -> false
    | { kind = Choice _; _ } :: _ when i > index -> false
    | _ :: rest -> check (i + 1) rest
  in
  check 0 t.fields

let primary_button t =
  let rec find = function
    | [] -> None
    | { kind = Buttons { buttons; selected }; _ } :: _ -> (
        if selected >= 0 && selected < List.length buttons then Some (List.nth buttons selected)
        else match buttons with b :: _ -> Some b | [] -> None)
    | _ :: rest -> find rest
  in
  find t.fields

let find_field_index t fid =
  let rec find idx = function
    | [] -> idx
    | (f : field) :: _ when f.id = fid -> idx
    | _ :: rest -> find (idx + 1) rest
  in
  find 0 t.fields

let handle_input t (input : Ui_input.input) : event =
  let count = List.length t.fields in
  let move_focus delta =
    if count = 0 then Updated t
    else
      let next = (t.focused + delta + count) mod count in
      Updated { t with focused = next }
  in
  match input with
  | `Key (`Escape, []) -> Cancel
  | `Key (`ASCII ('q' | 'Q'), []) when not (is_focused_on_text t) -> Cancel
  | `Key (`Enter, [ `Ctrl ]) -> (
      match primary_button t with Some (b : button) when b.is_cancel -> Cancel | _ -> Submit t)
  | `Key (`Tab, [ `Shift ]) -> move_focus (-1)
  | `Key (`Tab, []) -> move_focus 1
  | _ -> (
      match focused_field t with
      | None -> ( match input with `Key (`Enter, []) -> Submit t | _ -> Updated t)
      | Some (field : field) -> (
          match field.kind with
          | Text { value; _ } -> (
              match input with
              | `Key (`Arrow `Up, []) -> move_focus (-1)
              | `Key (`Arrow `Down, []) -> move_focus 1
              | `Key (`Enter, []) ->
                  if is_last_editable_field t t.focused then
                    match primary_button t with
                    | Some (b : button) when b.is_cancel -> Cancel
                    | _ -> Submit t
                  else move_focus 1
              | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 ->
                  let updated = value ^ String.make 1 c in
                  Updated (set_text { t with notice = "" } field.id updated)
              | `Key (`Uchar c, []) when Ui_render.printable_uchar c ->
                  let updated = value ^ Ui_render.utf8 c in
                  Updated (set_text { t with notice = "" } field.id updated)
              | `Key (`Backspace, []) ->
                  let updated = Daily_form.backspace value in
                  Updated (set_text { t with notice = "" } field.id updated)
              | _ -> Updated t)
          | Choice { options; selected } -> (
              let n = List.length options in
              let change_choice delta =
                if n = 0 then Updated t
                else
                  let sel = (selected + delta + n) mod n in
                  Updated (set_choice t field.id sel)
              in
              match input with
              | `Key (`Arrow `Up, []) -> move_focus (-1)
              | `Key (`Arrow `Down, []) -> move_focus 1
              | `Key ((`Arrow `Left | `ASCII 'h'), []) -> change_choice (-1)
              | `Key ((`Arrow `Right | `ASCII 'l'), []) | `Key (`ASCII ' ', []) -> change_choice 1
              | `Key (`Enter, []) ->
                  if is_last_editable_field t t.focused then
                    match primary_button t with
                    | Some (b : button) when b.is_cancel -> Cancel
                    | _ -> Submit t
                  else move_focus 1
              | _ -> Updated t)
          | Buttons { buttons; selected } -> (
              let n = List.length buttons in
              let change_button delta =
                if n = 0 then Updated t
                else
                  let sel = (selected + delta + n) mod n in
                  let updated =
                    update_field t field.id (function
                      | Buttons b -> Buttons { b with selected = sel }
                      | other -> other)
                  in
                  Updated updated
              in
              match input with
              | `Key (`Arrow `Up, []) -> move_focus (-1)
              | `Key (`Arrow `Down, []) -> move_focus 1
              | `Key ((`Arrow `Left | `ASCII 'h'), []) -> change_button (-1)
              | `Key ((`Arrow `Right | `ASCII 'l'), []) -> change_button 1
              | `Key (`Enter, []) ->
                  if selected >= 0 && selected < n then
                    let (btn : button) = List.nth buttons selected in
                    if btn.is_cancel then Cancel else Submit t
                  else Submit t
              | _ -> Updated t)))

let render_rows ~width ~height ~width_of t =
  let module O = Ui_render in
  let width = max 0 width and height = max 0 height in
  let plain text = (O.Plain, O.clip_text ~width_of width text) in
  let summary = List.concat_map (O.wrap_text ~width_of width) t.summary in
  let summary = List.map plain (if summary = [] then [] else summary @ [ "" ]) in
  let render_field (f : field) =
    let focused = find_field_index t f.id = t.focused in
    let prompt = if f.label = "" then "" else f.label ^ ": " in
    match f.kind with
    | Text { value; _ } when focused ->
        let prompt = O.clip_text ~width_of (max 0 (width - 1)) prompt in
        let inset = width_of prompt in
        let text, caret =
          O.input_text ~width_of ~width:(width - inset) ~cursor:None ~caret:"|" value
        in
        (Option.fold ~none:O.Plain ~some:(fun col -> O.Input (inset + col)) caret, prompt ^ text)
    | Text { value; placeholder } ->
        plain (prompt ^ if value = "" && placeholder <> "" then "(" ^ placeholder ^ ")" else value)
    | Choice { options; selected } ->
        let value =
          if selected < 0 then "" else Option.value ~default:"" (List.nth_opt options selected)
        in
        ( (if focused then O.Active else O.Plain),
          O.clip_text ~width_of width
            (prompt ^ if focused then "< " ^ value ^ " >" else "  " ^ value) )
    | Buttons { buttons; selected } ->
        let text =
          List.mapi
            (fun i (b : button) -> (if i = selected then "> " else "  ") ^ "[" ^ b.label ^ "]")
            buttons
          |> String.concat "    "
        in
        ((if focused then O.Active else O.Plain), O.clip_text ~width_of width text)
  in
  let fields, buttons =
    List.partition (fun f -> match f.kind with Buttons _ -> false | _ -> true) t.fields
  in
  let notice = if t.notice = "" then [ "" ] else O.wrap_text ~width_of width t.notice in
  let notice = List.map (fun text -> (O.Status, text)) notice in
  let rows =
    summary @ List.map render_field fields @ notice
    @ if buttons = [] then [] else plain "" :: List.map render_field buttons
  in
  let rec position id = function
    | [] -> 0
    | (f : field) :: _ when f.id = id -> 0
    | _ :: rest -> 1 + position id rest
  in
  let focus =
    match focused_field t with
    | None -> 0
    | Some field -> (
        match field.kind with
        | Buttons _ ->
            List.length summary + List.length fields + List.length notice + 1
            + position field.id buttons
        | _ -> List.length summary + position field.id fields)
  in
  let view =
    Ui_panel.window ~capacity:height ~count:(List.length rows) ~scroll:0 ~selected:(Some focus)
  in
  let shown = List.filteri (fun i _ -> i >= view.start && i - view.start < height) rows in
  List.mapi
    (fun i row ->
      if
        i + view.start <> focus
        && ((i = 0 && view.start > 0) || (i = height - 1 && view.start < view.last))
      then (O.Status, O.clip_text ~width_of width "… more")
      else row)
    shown
