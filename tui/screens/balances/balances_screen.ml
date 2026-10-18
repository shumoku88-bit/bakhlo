(* Balances: current visible accounts and accounting-role view, the visible-
   account picker and print preview. The picker saves balance-view.tsv only
   through the Shell, with the bytes captured when it opened. *)

module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module O = Daily_overlays
module Form = Ui_form
module Panel = Ui_panel
module BalView = Balance_view_data

type mode = [ `Current | `Accounting ]
type pane = [ `List | `Detail ]
type overlay_frame = Ui_overlay.frame = {
  origin_x : int;
  origin_y : int;
  pane_width : int;
  pane_height : int;
  rows : (O.style * string) list;
  cursor : (int * int) option;
}


type command =
  | Stay
  | Back_to_home
  | Open_commands
  | Cycle_measure of [ `Next | `Prev ]
  | Observe of { locus : string; measure : string; amount : Z.t option }
  | Save_balance_view of { expected : string option; content : string }
  | Reload

type picker_state = {
  candidates : string list;
  chosen : string list;
  cursor : int;
  raw_before : string option;
  previous : BalView.t;
}

type overlay =
  | No_overlay
  | Config_picker of picker_state
  | Config_review of { picker : picker_state; form : Form.t }
  | Print_preview of { form : Form.t; scroll : int }

type t = {
  mode : mode;
  selected : int;
  pane : pane;
  detail_scroll : int;
  overlay : overlay;
  notice : string;
}

let create () = {
  mode = `Current;
  selected = 0;
  pane = `List;
  detail_scroll = 0;
  overlay = No_overlay;
  notice = "";
}

let mode t = t.mode
let pane t = t.pane
let selected t = t.selected
let notice t = t.notice
let set_selected selected t = { t with selected = max 0 selected }

let title t =
  match t.mode with
  | `Accounting -> "Balances / Accounting"
  | `Current -> "Balances / Current"

let browser_pane_widths width =
  if width < 80 then (width, width)
  else
    let left = max 36 (min 58 (width * 52 / 100)) in
    (left, width - left - 1)

let admitted_loci book =
  match B.approved_loci book with
  | Some loci when loci <> [] -> loci
  | _ ->
      let from_entries =
        List.concat_map
          (fun (e : B.entry) ->
            List.map (fun p -> D.Identifier.Locus.to_string (D.Effect.locus p)) e.effects)
          (B.entries book)
      in
      let from_plans =
        List.concat_map
          (fun (p : B.plan) -> List.map fst p.changes)
          (B.plans book)
      in
      List.sort_uniq String.compare (from_entries @ from_plans)

let balance_view_coords balance_view_text =
  match balance_view_text with
  | Error why -> Error why
  | Ok None -> Ok None
  | Ok (Some text) -> (
      match BalView.of_string text with
      | Ok coords ->
          Ok (Some (List.map (fun (c : BalView.coordinate) -> (c.locus, c.measure)) coords))
      | Error why -> Error why)

let items ~book ~measure:_ ~roles ~balance_view_text t =
  match t.mode with
  | `Accounting ->
      O.role_balance_items ~book ~roles
  | `Current -> (
      match balance_view_coords balance_view_text with
      | Ok coords -> O.current_balance_items ~book ~coords
      | Error why -> [ O.Header_row ("Balance view unavailable: " ^ why) ])

let selected_coordinate ~book ~measure ~roles ~balance_view_text t =
  let all_items = items ~book ~measure ~roles ~balance_view_text t in
  match List.nth_opt all_items t.selected with
  | Some (O.Account_row { locus; measure; _ }) -> Some (locus, measure)
  | _ -> None

let selected_account ~book ~measure ~roles ~balance_view_text t =
  let all_items = items ~book ~measure ~roles ~balance_view_text t in
  match List.nth_opt all_items t.selected with
  | Some (O.Account_row { locus; measure; value; _ }) ->
      let amount =
        match value with
        | O.Exact n -> Some n
        | _ -> None
      in
      Some (locus, measure, amount)
  | _ -> None

let balance_lines ?(width_of = String.length) ?(width = max_int) ~book items_list =
  List.map (O.balance_item_line ~width_of ~width ~book) items_list

let balance_print_fits rows =
  let rec fits bytes = function
    | [] -> true
    | row :: rest ->
        let size = String.length row + 1 in
        size <= 32768 - bytes && fits (bytes + size) rest
  in
  List.length rows <= 200 && fits 0 rows

let balance_print_preview ~book ~measure ~roles ~balance_view_text t =
  let refused summary =
    Form.create ~id:"balance_print_refused" ~title:(Ui_text.tr "Print Refused") ~summary
      ~fields:[ Form.action_buttons ~confirm:(Ui_text.tr "OK") ~cancel:(Ui_text.tr "Close") () ] ()
  in
  let view_error =
    match t.mode with
    | `Accounting -> None
    | `Current -> (
        match balance_view_coords balance_view_text with
        | Error why -> Some why
        | Ok _ -> None)
  in
  match view_error with
  | Some why ->
      refused
        [
          Ui_text.tr "Print refused: visible-account configuration is unavailable.";
          why;
          Ui_text.tr "Review balance-view.tsv before printing.";
        ]
  | None ->
      let header =
        match t.mode with
        | `Current ->
            [
              Ui_text.tr "Balances / Current";
              Ui_text.tr "Selected Locus × Measure; unknown is not zero.";
              "";
            ]
        | `Accounting ->
            [
              Ui_text.tr "Balances / Accounting";
              Ui_text.tr "Current role-based quantities; different Measures are not combined.";
              "";
            ]
      in
      let items_list = items ~book ~measure ~roles ~balance_view_text t in
      let summary = header @ balance_lines ~book items_list in
      if not (balance_print_fits summary) then
        refused
          [
            Ui_text.tr "Print refused: more than 200 lines or 32768 UTF-8 bytes.";
            Ui_text.tr "Narrow the balance selection first.";
          ]
      else
        Form.create ~id:"balance_print_preview"
          ~title:(Ui_text.tr "Balances / Print Preview")
          ~summary
          ~fields:[ Form.action_buttons ~confirm:(Ui_text.tr "Done") ~cancel:(Ui_text.tr "Close") () ]
          ()

let balance_display_review measure chosen =
  Form.create ~id:"review_balance_view" ~title:"Review visible accounts"
    ~summary:
      ([
         "Measure: " ^ measure;
         "Only the selected Measure's display rows will change.";
         "Unknown balances remain '?'.";
       ]
      @ (if chosen = [] then [ "  (no accounts chosen)" ]
         else List.map (fun (c : BalView.coordinate) -> "  " ^ c.locus) chosen))
    ~fields:[ Form.action_buttons ~confirm:"Save" ~cancel:"Edit" () ]
    ()

let print_fits = balance_print_fits
let print_preview_summary t =
  match t.overlay with
  | Print_preview { form; _ } -> Some form.Form.summary
  | _ -> None

let print_preview_form = balance_print_preview
let detail_viewport ~dimensions ~width_of ~book ~measure ~roles ~balance_view_text t =
  let usable_h = max 0 (snd dimensions - 5) in
  let stacked = fst dimensions >= 72 && fst dimensions < 120 && usable_h >= 18 in
  let right_width =
    if stacked then fst dimensions
    else if fst dimensions >= 80 then fst dimensions - max 36 (min 58 (fst dimensions * 52 / 100)) - 1
    else fst dimensions
  in
  let items_list = items ~book ~measure ~roles ~balance_view_text t in
  let detail =
    match List.nth_opt items_list t.selected with
    | None -> [ Ui_text.tr "No supplied Locus / Measure coordinates." ]
    | Some item -> O.balance_item_detail ~book item
  in
  let wrapped = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
  let detail_height = if stacked then usable_h - usable_h / 2 else usable_h in
  let view =
    Panel.window
      ~capacity:(Panel.capacity ~height:detail_height ~heading:false)
      ~count:(List.length wrapped) ~scroll:t.detail_scroll ~selected:None
  in
  (wrapped, view)

let open_config ~book ~measure ~balance_view_text t =
  match balance_view_text with
  | Error why ->
      { t with overlay = No_overlay; notice = "Balance setup unavailable: " ^ why }
  | Ok raw -> (
      let previous =
        match raw with
        | None -> Ok []
        | Some text -> BalView.of_string text
      in
      match previous with
      | Error why ->
          { t with overlay = No_overlay; notice = "Balance setup unavailable: " ^ why }
      | Ok prev ->
          let old =
            List.filter_map
              (fun (c : BalView.coordinate) -> if c.measure = measure then Some c.locus else None)
              prev
          in
          let approved = admitted_loci book in
          let candidates = old @ List.filter (fun l -> not (List.mem l old)) approved in
          let picker = {
            candidates;
            chosen = old;
            cursor = 0;
            raw_before = raw;
            previous = prev;
          } in
          { t with overlay = Config_picker picker; notice = "" })

let notify_saved t =
  {
    t with
    overlay = No_overlay;
    selected = 0;
    notice = "Visible Balance accounts saved. Unknown values remain '?'.";
  }

let notify_save_failed t why =
  match t.overlay with
  | Config_review { picker; form } ->
      let updated_form = Form.set_notice form why in
      { t with overlay = Config_review { picker; form = updated_form } }
  | _ -> { t with notice = "Save failed: " ^ why }
let active_form t =
  match t.overlay with
  | Print_preview { form; _ } -> Some form
  | Config_review { form; _ } -> Some form
  | _ -> None


let has_overlay t =
  match t.overlay with
  | No_overlay -> false
  | _ -> true

let overlay ~dimensions:((width, _) as _dimensions) ~body_dimensions:((body_w, body_h) as _body_dim) ~width_of t : overlay_frame option =
  match t.overlay with
  | No_overlay -> None
  | Config_picker picker ->
      let pane_w = min 64 (max 8 (body_w - 4)) in
      let pane_h = min body_h (max 5 (List.length picker.candidates + 3)) in
      let rows =
        List.map
          (fun locus ->
            (if List.mem locus picker.chosen then "[x] " else "[ ] ") ^ locus)
          picker.candidates
      in
      let rows =
        Panel.frame ~width_of ~width:pane_w ~height:pane_h ~focused:true
          ~title:"Balances / Visible accounts"
          ~heading:(Printf.sprintf "Chosen: %d; unknown stays '?'" (List.length picker.chosen))
          ~scroll:0 ~selected:(Some picker.cursor) rows
      in
      Some
        {
          origin_x = max 0 ((width - pane_w) / 2);
          origin_y = max 0 ((body_h - pane_h) / 2);
          pane_width = pane_w;
          pane_height = List.length rows;
          rows;
          cursor = None;
        }
  | Config_review { form; _ } ->
      let pane_w = min 64 (max 8 (body_w - 4)) in
      let content_width = max 0 (pane_w - 6) in
      let form_rows =
        Form.render_rows ~width:content_width
          ~height:(Panel.capacity ~height:body_h ~heading:false)
          ~width_of form
      in
      let pane_h = min body_h (max 5 (List.length form_rows + 2)) in
      let rows =
        Panel.frame_rows ~width_of ~width:pane_w ~height:pane_h ~focused:true
          ~title:(Form.title form) form_rows
      in
      let origin_x = max 0 ((width - pane_w) / 2) in
      let origin_y = max 0 ((body_h - pane_h) / 2) in
      let cursor =
        O.cursor_in_rows ~width_of ~width:pane_w rows
        |> Option.map (fun (col, row) -> (origin_x + col, origin_y + row))
      in
      Some
        {
          origin_x;
          origin_y;
          pane_width = pane_w;
          pane_height = List.length rows;
          rows;
          cursor;
        }
  | Print_preview { form; scroll } ->
      let pane_width = min 64 (max 8 (body_w - 4)) in
      let content =
        List.concat_map (O.wrap_text ~width_of (max 1 (pane_width - 6))) form.Form.summary
      in
      let pane_height = min body_h (max 3 (List.length content + 2)) in
      let rows =
        Panel.frame ~width_of ~width:pane_width ~height:pane_height ~focused:true
          ~title:(Form.title form) ~scroll ~selected:None content
      in
      Some
        {
          origin_x = max 0 ((width - pane_width) / 2);
          origin_y = max 0 ((body_h - List.length rows) / 2);
          pane_width;
          pane_height = List.length rows;
          rows;
          cursor = None;
        }
let cursor_position ~dimensions ~body_dimensions ~width_of t =
  match overlay ~dimensions ~body_dimensions ~width_of t with
  | Some frame -> frame.cursor
  | None -> None

let list_capacity ~dimensions:(width, height) =
  let usable_h = max 0 (height - 5) in
  let stacked = width >= 72 && width < 120 && usable_h >= 18 in
  let list_height = if stacked then usable_h / 2 else usable_h in
  Panel.capacity ~height:list_height ~heading:false

let handle ~blocked ~book ~measure ~roles ~balance_view_text ~dimensions ~width_of t (input : Ui_input.input) =
  match t.overlay with
  | Print_preview { form; scroll } -> (
      let pane_width = min 64 (max 8 (fst dimensions - 4)) in
      let content =
        List.concat_map (O.wrap_text ~width_of (max 1 (pane_width - 6))) form.Form.summary
      in
      let pane_height = min (snd dimensions) (max 3 (List.length content + 2)) in
      let view =
        Panel.window
          ~capacity:(Panel.capacity ~height:pane_height ~heading:false)
          ~count:(List.length content) ~scroll ~selected:None
      in
      match input with
      | `Key (`Home, _) ->
          ({ t with overlay = Print_preview { form; scroll = 0 } }, Stay)
      | `Key (`End, _) ->
          ({ t with overlay = Print_preview { form; scroll = view.last } }, Stay)
      | `Key ((`Page `Up | `ASCII 'u'), _) ->
          let next_scroll = Panel.move ~last:view.last ~position:view.start (-(max 1 view.capacity)) in
          ({ t with overlay = Print_preview { form; scroll = next_scroll } }, Stay)
      | `Key ((`Page `Down | `ASCII 'd'), _) ->
          let next_scroll = Panel.move ~last:view.last ~position:view.start (max 1 view.capacity) in
          ({ t with overlay = Print_preview { form; scroll = next_scroll } }, Stay)
      | `Key ((`ASCII 'k' | `Arrow `Up), _) ->
          let next_scroll = Panel.move ~last:view.last ~position:view.start (-1) in
          ({ t with overlay = Print_preview { form; scroll = next_scroll } }, Stay)
      | `Key ((`ASCII 'j' | `Arrow `Down), _) ->
          let next_scroll = Panel.move ~last:view.last ~position:view.start 1 in
          ({ t with overlay = Print_preview { form; scroll = next_scroll } }, Stay)
      | `Key ((`Escape | `Enter | `ASCII ('q' | 'Q')), _) ->
          ({ t with overlay = No_overlay }, Stay)
      | _ -> (t, Stay))
  | Config_picker picker -> (
      let move delta =
        let next_cursor =
          Panel.move ~last:(List.length picker.candidates - 1) ~position:picker.cursor delta
        in
        ({ t with overlay = Config_picker { picker with cursor = next_cursor } }, Stay)
      in
      match input with
      | `Key ((`Escape | `ASCII ('q' | 'Q')), []) ->
          ({ t with overlay = No_overlay }, Stay)
      | `Key ((`Arrow `Up | `ASCII 'k'), []) -> move (-1)
      | `Key ((`Arrow `Down | `ASCII 'j'), []) -> move 1
      | `Key (`ASCII ' ', []) ->
          let locus = List.nth picker.candidates picker.cursor in
          let chosen =
            if List.mem locus picker.chosen then
              List.filter (fun x -> x <> locus) picker.chosen
            else picker.chosen @ [ locus ]
          in
          ({ t with overlay = Config_picker { picker with chosen } }, Stay)
      | `Key (`Enter, []) ->
          let chosen_coords =
            List.map (fun locus -> { BalView.locus; measure }) picker.chosen
          in
          let form = balance_display_review measure chosen_coords in
          ({ t with overlay = Config_review { picker; form } }, Stay)
      | _ -> (t, Stay))
  | Config_review { picker; form } -> (
      match input with
      | `Key (`ASCII ('e' | 'E'), []) ->
          ({ t with overlay = Config_picker picker }, Stay)
      | `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] ->
          let direction = if mods = [] then `Right else `Left in
          (match Form.handle_input form (`Key (`Arrow direction, [])) with
          | Form.Updated next_form ->
              ({ t with overlay = Config_review { picker; form = next_form } }, Stay)
          | _ -> (t, Stay))
      | _ -> (
          match Form.handle_input form input with
          | Form.Cancel ->
              ({ t with overlay = Config_picker picker }, Stay)
          | Form.Updated next_form ->
              ({ t with overlay = Config_review { picker; form = next_form } }, Stay)
          | Form.Submit submitted ->
              if blocked then
                let updated = Form.set_notice submitted "Writes stopped. Cancel and reload to inspect." in
                ({ t with overlay = Config_review { picker; form = updated } }, Stay)
              else
                let pane_w = min 64 (max 8 (fst dimensions - 4)) in
                let body_h = max 0 (snd dimensions - 3) in
                let rows = Form.render_rows ~width:(max 0 (pane_w - 6)) ~height:max_int ~width_of submitted in
                let fits = pane_w >= 48 && List.length rows <= Panel.capacity ~height:body_h ~heading:false in
                if not fits then
                  let updated = Form.set_notice submitted "Enlarge the terminal to review every selected account before saving." in
                  ({ t with overlay = Config_review { picker; form = updated } }, Stay)
                else
                  let chosen_coords =
                    List.map (fun locus -> { BalView.locus; measure }) picker.chosen
                  in
                  let other =
                    List.filter (fun (c : BalView.coordinate) -> c.measure <> measure) picker.previous
                  in
                  let content = BalView.to_string (other @ chosen_coords) in
                  (t, Save_balance_view { expected = picker.raw_before; content })))
  | No_overlay -> (
      match input with
      | `Key ((`Escape | `ASCII ('q' | 'Q')), []) ->
          if t.pane = `Detail then
            ({ t with pane = `List; detail_scroll = 0 }, Stay)
          else (t, Back_to_home)
      | `Key ((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)), []) ->
          let next_pane = if t.pane = `List then `Detail else `List in
          ({ t with pane = next_pane; detail_scroll = 0 }, Stay)
      | `Key ((`Enter | `ASCII 'i'), []) when t.pane = `List ->
          ({ t with pane = `Detail; detail_scroll = 0 }, Stay)
      | `Key (`ASCII ' ', []) ->
          (t, Open_commands)
      | `Key (`Tab, []) ->
          (t, Cycle_measure `Next)
      | `Key (`Tab, [ `Shift ]) | `Key (`ASCII 'w', []) ->
          (t, Cycle_measure `Prev)
      | `Key (`ASCII 'v', []) ->
          let prev_coord = selected_coordinate ~book ~measure ~roles ~balance_view_text t in
          let next_mode = match t.mode with `Accounting -> `Current | `Current -> `Accounting in
          let t_next = { t with mode = next_mode } in
          let next_items = items ~book ~measure ~roles ~balance_view_text t_next in
          let sel =
            match prev_coord with
            | None -> 0
            | Some (locus, measure) -> (
                match
                  List.find_index
                    (function
                      | O.Account_row r -> r.locus = locus && r.measure = measure
                      | _ -> false)
                    next_items
                with
                | Some idx -> idx
                | None -> 0)
          in
          ({ t_next with selected = sel; detail_scroll = 0 }, Stay)
      | `Key (`ASCII 'c', []) ->
          (open_config ~book ~measure ~balance_view_text t, Stay)
      | `Key (`ASCII 'p', []) ->
          let form = balance_print_preview ~book ~measure ~roles ~balance_view_text t in
          ({ t with overlay = Print_preview { form; scroll = 0 } }, Stay)
      | `Key (`ASCII 'o', []) -> (
          match selected_account ~book ~measure ~roles ~balance_view_text t with
          | Some (locus, measure, amount) ->
              (t, Observe { locus; measure; amount })
          | None -> (t, Stay))
      | `Key (`Home, []) ->
          if t.pane = `Detail then ({ t with detail_scroll = 0 }, Stay)
          else ({ t with selected = 0 }, Stay)
      | `Key (`End, []) ->
          let all_items = items ~book ~measure ~roles ~balance_view_text t in
          let count = List.length all_items in
          if t.pane = `Detail then
            let _, view = detail_viewport ~dimensions ~width_of ~book ~measure ~roles ~balance_view_text t in
            ({ t with detail_scroll = view.last }, Stay)
          else ({ t with selected = max 0 (count - 1) }, Stay)
      | `Key ((`Arrow `Up | `ASCII 'k'), []) ->
          let all_items = items ~book ~measure ~roles ~balance_view_text t in
          let count = List.length all_items in
          if t.pane = `Detail then
            let _, view = detail_viewport ~dimensions ~width_of ~book ~measure ~roles ~balance_view_text t in
            let next_scroll = Panel.move ~last:view.last ~position:view.start (-1) in
            ({ t with detail_scroll = next_scroll }, Stay)
          else
            let next_sel = max 0 (min (max 0 (count - 1)) (t.selected - 1)) in
            ({ t with selected = next_sel }, Stay)
      | `Key ((`Arrow `Down | `ASCII 'j'), []) ->
          let all_items = items ~book ~measure ~roles ~balance_view_text t in
          let count = List.length all_items in
          if t.pane = `Detail then
            let _, view = detail_viewport ~dimensions ~width_of ~book ~measure ~roles ~balance_view_text t in
            let next_scroll = Panel.move ~last:view.last ~position:view.start 1 in
            ({ t with detail_scroll = next_scroll }, Stay)
          else
            let next_sel = max 0 (min (max 0 (count - 1)) (t.selected + 1)) in
            ({ t with selected = next_sel }, Stay)
      | `Key ((`Page `Up | `ASCII 'u'), _) ->
          let all_items = items ~book ~measure ~roles ~balance_view_text t in
          let count = List.length all_items in
          if t.pane = `Detail then
            let _, view = detail_viewport ~dimensions ~width_of ~book ~measure ~roles ~balance_view_text t in
            let next_scroll = Panel.move ~last:view.last ~position:view.start (-(max 1 view.capacity)) in
            ({ t with detail_scroll = next_scroll }, Stay)
          else
            let step = list_capacity ~dimensions in
            let next_sel = max 0 (min (max 0 (count - 1)) (t.selected - step)) in
            ({ t with selected = next_sel }, Stay)
      | `Key ((`Page `Down | `ASCII 'd'), _) ->
          let all_items = items ~book ~measure ~roles ~balance_view_text t in
          let count = List.length all_items in
          if t.pane = `Detail then
            let _, view = detail_viewport ~dimensions ~width_of ~book ~measure ~roles ~balance_view_text t in
            let next_scroll = Panel.move ~last:view.last ~position:view.start (max 1 view.capacity) in
            ({ t with detail_scroll = next_scroll }, Stay)
          else
            let step = list_capacity ~dimensions in
            let next_sel = max 0 (min (max 0 (count - 1)) (t.selected + step)) in
            ({ t with selected = next_sel }, Stay)
      | _ -> (t, Stay))

let screen ~book ~measure ~roles ~balance_view_text ~dimensions:(width, height) ~width_of t =
  let items_list = items ~book ~measure ~roles ~balance_view_text t in
  let stacked = width >= 72 && width < 120 && height >= 18 in
  let list_width =
    if stacked then width
    else if width >= 80 then
      let left, _ = browser_pane_widths width in
      left
    else width
  in
  let lines = balance_lines ~width_of ~width:(max 0 (list_width - 6)) ~book items_list in
  let detail =
    match List.nth_opt items_list t.selected with
    | None -> [ Ui_text.tr "No supplied Locus / Measure coordinates." ]
    | Some item -> O.balance_item_detail ~book item
  in
  let right_width =
    if stacked then width
    else if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1
    else width
  in
  let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
  let is_detail = t.pane = `Detail in
  let title_text = title t in
  let pad rows = rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (O.Plain, "")) in
  if stacked then
    let list_height = height / 2 in
    Panel.frame ~width_of ~width ~height:list_height ~focused:(not is_detail) ~title:title_text
      ~scroll:0
      ~selected:(if lines = [] then None else Some t.selected)
      ?heading:(if lines = [] then Some "No balances are selected." else None)
      lines
    @ Panel.frame ~width_of ~width ~height:(height - list_height) ~focused:is_detail
        ~title:"Selected Balance" ~scroll:t.detail_scroll ~selected:None wrapped_detail
  else if width >= 80 then
    let left_width, right_width = browser_pane_widths width in
    let left_panel =
      Panel.frame ?heading:(if lines = [] then Some "No balances are selected." else None)
        ~width_of ~width:left_width ~height ~focused:(not is_detail) ~title:title_text ~scroll:0
        ~selected:(if lines = [] then None else Some t.selected)
        lines
    in
    let right_panel =
      Panel.frame ~width_of ~width:right_width ~height ~focused:is_detail ~title:"Selected Balance"
        ~scroll:t.detail_scroll ~selected:None wrapped_detail
    in
    pad
      (List.map2
         (fun (style_l, text_l) (style_r, text_r) ->
           (O.Columns (left_width, style_l, style_r), text_l ^ " " ^ text_r))
         left_panel right_panel)
  else if is_detail then
    Panel.frame ~width_of ~width ~height ~focused:true ~title:"Selected Balance"
      ~scroll:t.detail_scroll ~selected:None wrapped_detail
  else
    Panel.frame ?heading:(if lines = [] then Some "No balances are selected." else None)
      ~width_of ~width ~height ~focused:true ~title:title_text ~scroll:0
      ~selected:(if lines = [] then None else Some t.selected)
      lines

let footer ~dimensions:_ ~width_of:_ t =
  match t.overlay with
  | Config_picker _ ->
      [
        "j/k select  Space toggle  Enter review";
        "Esc/q cancel; unknown stays '?'  no write until confirmed";
      ]
  | Config_review _ ->
      [ "Enter save  Tab choose Edit  Esc edit"; "Full selection must fit before saving" ]
  | Print_preview _ ->
      [
        "PgUp/Dn scroll  Home/End  Enter/Esc close";
        "Preview only; no terminal output or book write";
      ]
  | No_overlay ->
      [
        "j/k move  Tab measure  v view  c config  o observe  p print  Esc home";
        "Selected coordinate balance details remain inspectable";
      ]

(* Screen contract *)

let config_files = [ "balance-view.tsv" ]
let modal = has_overlay
let form = active_form
let detail_focused t = t.pane = `Detail

let context (env : Screen.env) =
  (env.book, env.measure, Lazy.force env.accounting_roles, env.config "balance-view.tsv")

let request_of t next = function
  | Stay when next.notice <> "" && next.notice <> t.notice -> Screen.Message next.notice
  | Stay -> Screen.Stay
  | Back_to_home -> Screen.Home
  | Open_commands -> Screen.Commands
  | Cycle_measure direction -> Screen.Cycle_measure direction
  | Observe { locus; measure; amount } -> Screen.Observe { locus; measure; amount }
  | Save_balance_view { expected; content } ->
      Screen.Save_config
        { file = "balance-view.tsv"; expected; content; admission = Vocabulary_unchanged }
  | Reload -> Screen.Reload

let handle env (geometry : Screen.geometry) t input =
  let book, measure, roles, balance_view_text = context env in
  let next, command =
    handle ~blocked:env.blocked ~book ~measure ~roles ~balance_view_text
      ~dimensions:geometry.screen ~width_of:geometry.width_of t input
  in
  (next, request_of t next command)

let saved _env _geometry result t =
  match result with
  | Ok () -> (notify_saved t, Screen.Message "Visible Balance accounts saved. Unknown values remain '?'.")
  | Error why -> (notify_save_failed t why, Screen.Stay)

let open_config env t =
  let book, measure, _, balance_view_text = context env in
  let next = open_config ~book ~measure ~balance_view_text t in
  (next, if next.notice <> "" then Screen.Message next.notice else Screen.Message "")

let items env t =
  let book, measure, roles, balance_view_text = context env in
  items ~book ~measure ~roles ~balance_view_text t

let detail_viewport env (geometry : Screen.geometry) t =
  let book, measure, roles, balance_view_text = context env in
  detail_viewport ~dimensions:geometry.screen ~width_of:geometry.width_of ~book ~measure ~roles
    ~balance_view_text t

let print_preview_form env t =
  let book, measure, roles, balance_view_text = context env in
  print_preview_form ~book ~measure ~roles ~balance_view_text t

let view env (geometry : Screen.geometry) t =
  let book, measure, roles, balance_view_text = context env in
  let overlay = overlay ~dimensions:geometry.screen ~body_dimensions:geometry.body
      ~width_of:geometry.width_of t in
  {
    Screen.title = Ui_text.tr "Balances";
    subtitle = None;
    rows = lazy (screen ~book ~measure ~roles ~balance_view_text ~dimensions:geometry.content
                   ~width_of:geometry.width_of t);
    footer = footer ~dimensions:geometry.screen ~width_of:geometry.width_of t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
