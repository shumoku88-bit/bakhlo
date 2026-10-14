(* Pure modal form component for Bakhlo TUI dialogs and workflows. *)

type button = {
  label : string;
  is_cancel : bool;
}

type field_kind =
  | Text of { value : string; placeholder : string }
  | Choice of { options : string list; selected : int }
  | Buttons of { buttons : button list; selected : int }

type field = {
  id : string;
  label : string;
  kind : field_kind;
}

type t = {
  id : string;
  payload : string;
  title : string;
  summary : string list;
  fields : field list;
  focused : int;
  notice : string;
}

type event =
  | Updated of t
  | Submit of t
  | Cancel

let id t = t.id
let payload t = t.payload
let title t = t.title
let notice t = t.notice
let set_notice t notice = { t with notice }
let focused t = t.focused

let set_focused t idx =
  let count = List.length t.fields in
  if count = 0 then { t with focused = 0 }
  else { t with focused = max 0 (min (count - 1) idx) }

let get_field t fid =
  List.find_opt (fun (f : field) -> f.id = fid) t.fields

let update_field t fid fn =
  let fields =
    List.map
      (fun (f : field) -> if f.id = fid then { f with kind = fn f.kind } else f)
      t.fields
  in
  { t with fields }

let get_text t fid =
  match get_field t fid with
  | Some { kind = Text { value; _ }; _ } -> Some value
  | _ -> None

let set_text t fid new_val =
  update_field t fid (function
    | Text t -> Text { t with value = new_val }
    | other -> other)

let get_choice t fid =
  match get_field t fid with
  | Some { kind = Choice { selected; _ }; _ } -> Some selected
  | _ -> None

let get_choice_value t fid =
  match get_field t fid with
  | Some { kind = Choice { options; selected }; _ } ->
      if selected >= 0 && selected < List.length options then
        Some (List.nth options selected)
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
      if selected >= 0 && selected < List.length buttons then
        Some (List.nth buttons selected)
      else None
  | _ -> None

let get_selected_button_index t =
  match List.find_opt (fun f -> match f.kind with Buttons _ -> true | _ -> false) t.fields with
  | Some { kind = Buttons { selected; _ }; _ } -> selected
  | _ -> 0

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
    ~buttons:[
      { label = confirm; is_cancel = false };
      { label = cancel; is_cancel = true };
    ]
    ()

let create ~id ?(payload = "") ~title ?(summary = []) ?(fields = []) ?(notice = "") () =
  { id; payload; title; summary; fields; focused = 0; notice }

let focused_field t =
  if t.focused >= 0 && t.focused < List.length t.fields then
    Some (List.nth t.fields t.focused)
  else None

let is_focused_on_text t =
  match focused_field t with
  | Some { kind = Text _; _ } -> true
  | _ -> false

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
    | { kind = Buttons { buttons; selected }; _ } :: _ ->
        if selected >= 0 && selected < List.length buttons then
          Some (List.nth buttons selected)
        else (match buttons with b :: _ -> Some b | [] -> None)
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
      match primary_button t with
      | Some (b : button) when b.is_cancel -> Cancel
      | _ -> Submit t)
  | `Key (`Tab, [ `Shift ]) -> move_focus (-1)
  | `Key (`Tab, []) -> move_focus 1
  | _ -> (
      match focused_field t with
      | None -> (
          match input with
          | `Key (`Enter, []) -> Submit t
          | _ -> Updated t)
      | Some (field : field) -> (
          match field.kind with
          | Text { value; _ } -> (
              match input with
              | `Key (`Arrow `Up, []) -> move_focus (-1)
              | `Key (`Arrow `Down, []) -> move_focus 1
              | `Key (`Enter, []) ->
                  if is_last_editable_field t t.focused then (
                    match primary_button t with
                    | Some (b : button) when b.is_cancel -> Cancel
                    | _ -> Submit t)
                  else move_focus 1
              | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 ->
                  let updated = value ^ String.make 1 c in
                  Updated (set_text { t with notice = "" } field.id updated)
              | `Key (`Uchar c, []) when Daily_overlays.printable_uchar c ->
                  let updated = value ^ Daily_overlays.utf8 c in
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
              | `Key ((`Arrow `Right | `ASCII 'l'), []) | `Key (`ASCII ' ', []) ->
                  change_choice 1
              | `Key (`Enter, []) ->
                  if is_last_editable_field t t.focused then (
                    match primary_button t with
                    | Some (b : button) when b.is_cancel -> Cancel
                    | _ -> Submit t)
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
              | `Key (`Enter, []) -> (
                  if selected >= 0 && selected < n then
                    let (btn : button) = List.nth buttons selected in
                    if btn.is_cancel then Cancel else Submit t
                  else Submit t)
              | _ -> Updated t)))

let render_rows t : string list =
  let summary_rows =
    if t.summary = [] then []
    else t.summary @ [""]
  in
  let non_button_fields =
    List.filter (fun f -> match f.kind with Buttons _ -> false | _ -> true) t.fields
  in
  let button_fields =
    List.filter (fun f -> match f.kind with Buttons _ -> true | _ -> false) t.fields
  in
  let field_rows =
    List.map
      (fun (f : field) ->
        let global_idx = find_field_index t f.id in
        let is_focused = (global_idx = t.focused) in
        match f.kind with
        | Text { value; placeholder } ->
            let prompt = if f.label = "" then "" else f.label ^ ": " in
            let display_val =
              if value = "" && not is_focused then
                (if placeholder = "" then "" else "(" ^ placeholder ^ ")")
              else value
            in
            let cursor = if is_focused then "|" else "" in
            prompt ^ display_val ^ cursor
        | Choice { options; selected } ->
            let prompt = if f.label = "" then "" else f.label ^ ": " in
            let opt_str =
              if options = [] then ""
              else if selected >= 0 && selected < List.length options then
                List.nth options selected
              else ""
            in
            if is_focused then prompt ^ "< " ^ opt_str ^ " >"
            else prompt ^ "  " ^ opt_str
        | Buttons _ -> "")
      non_button_fields
  in
  let notice_rows =
    if t.notice = "" then []
    else [t.notice]
  in
  let button_rows =
    match button_fields with
    | [] -> []
    | buttons_list ->
        let rows =
          List.map
            (fun (f : field) ->
              match f.kind with
              | Buttons { buttons; selected } ->
                  let btn_strs =
                    List.mapi
                      (fun idx (b : button) ->
                        let prefix =
                          if idx = selected then "> "
                          else "  "
                        in
                        prefix ^ "[" ^ b.label ^ "]")
                      buttons
                  in
                  String.concat "    " btn_strs
              | _ -> "")
            buttons_list
        in
        [""] @ rows
  in
  summary_rows @ field_rows @ notice_rows @ button_rows
