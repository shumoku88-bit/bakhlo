(* Balances: current visible accounts and accounting-role view, the visible-
   account picker and print preview. The picker saves balance-view.tsv only
   through the Shell, with the bytes captured when it opened. *)

module B = Bakhlo_household.Daily_book
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

let create () =
  {
    mode = `Current;
    selected = 0;
    pane = `List;
    detail_scroll = 0;
    overlay = No_overlay;
    notice = "";
  }

let mode t = t.mode
let selected t = t.selected

let set_selected selected t =
  let selected = max 0 selected in
  { t with selected; detail_scroll = (if selected = t.selected then t.detail_scroll else 0) }

let title t =
  match t.mode with `Accounting -> "Balances / Accounting" | `Current -> "Balances / Current"

(* One owned geometry: the Shell supplies content = screen minus header,
   feedback and footer, so paging and scrolling use the painted sizes. *)
type layout = {
  wide : bool;
  list_width : int;
  list_height : int;
  detail_width : int;
  detail_height : int;
  detail_only : bool;
}

let layout ~content:(width, height) ~screen_height ~detail =
  let wide = width >= 119 && height >= 10 in
  let detail_width = if wide then min 60 (max 48 (width * 34 / 100)) else width in
  let base_detail_height =
    if wide then height
    else if height >= 12 then
      (if screen_height >= 48 then 10 else if screen_height >= 36 then 8 else 6) + 2
    else 0
  in
  let detail_only = detail && base_detail_height = 0 in
  let detail_height = if detail_only then height else base_detail_height in
  let list_height =
    if detail_only then 0
    else if wide then height
    else height - detail_height - if detail_height > 0 then 1 else 0
  in
  {
    wide;
    list_width = (if wide then width - 1 - detail_width else width);
    list_height;
    detail_width;
    detail_height;
    detail_only;
  }

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
        List.concat_map (fun (p : B.plan) -> List.map fst p.changes) (B.plans book)
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
  | `Accounting -> (
      match roles with
      | Ok roles -> Balance_items.role_balance_items ~book ~roles
      | Error why -> [ Balance_items.Header_row ("Accounting roles unavailable: " ^ why) ])
  | `Current -> (
      match balance_view_coords balance_view_text with
      | Ok coords -> Balance_items.current_balance_items ~book ~coords
      | Error why -> [ Balance_items.Header_row ("Balance view unavailable: " ^ why) ])

let selected_coordinate ~book ~measure ~roles ~balance_view_text t =
  let all_items = items ~book ~measure ~roles ~balance_view_text t in
  match List.nth_opt all_items t.selected with
  | Some (Balance_items.Account_row { locus; measure; _ }) -> Some (locus, measure)
  | _ -> None

let selected_account ~book ~measure ~roles ~balance_view_text t =
  let all_items = items ~book ~measure ~roles ~balance_view_text t in
  match List.nth_opt all_items t.selected with
  | Some (Balance_items.Account_row { locus; measure; value; _ }) ->
      let amount = match value with O.Exact n -> Some n | _ -> None in
      Some (locus, measure, amount)
  | _ -> None

let balance_lines ?(width_of = String.length) ?(width = max_int) ~book items_list =
  List.map (Balance_items.balance_item_line ~width_of ~width ~book) items_list

(* Current presents the selected Locus × Measure evidence: the exact ID and the
   Measure-scaled Amount, never a label or a signed adjustment. *)
let current_amount ~book ~measure = function
  | O.Exact n -> O.format_money book measure n
  | O.Unsupported -> "?"

let current_state = function O.Exact _ -> "exact" | O.Unsupported -> "unsupported"

(* A table cell never clips a quantity into a different number. *)
let quantity_cell ~width_of ~width quantity =
  if width_of quantity <= width then quantity else if width >= 11 then "see details" else "…"

let current_table ~width_of ~width ~book items_list =
  let room = max 0 (width - 5) in
  let measure_width =
    List.fold_left
      (fun size -> function
        | Balance_items.Account_row { measure; _ } -> max size (width_of measure) | _ -> size)
      7 items_list
  in
  (* Preserve the Measure before the Locus; if neither fits, show no digits. *)
  if room < 54 || measure_width > 12 then
    let quantity_width = min 14 (room / 2) in
    let name_width = max 0 (room - quantity_width - 2) in
    let name locus measure =
      let suffix = " / " ^ measure in
      if width_of suffix <= name_width then
        (O.clip_text ~width_of (name_width - width_of suffix) locus ^ suffix, true)
      else if width_of measure <= name_width then (measure, true)
      else (locus, false)
    in
    let lines =
      List.map
        (function
          | Balance_items.Account_row { locus; measure; value; _ } ->
              let name, identified = name locus measure in
              let quantity =
                if not identified then "see details"
                else
                  match value with
                  | O.Exact _ -> current_amount ~book ~measure value
                  | O.Unsupported -> current_state value
              in
              O.pad ~width_of name_width name ^ "  "
              ^ O.pad_left ~width_of quantity_width
                  (quantity_cell ~width_of ~width:quantity_width quantity)
          | item -> Balance_items.balance_item_line ~width_of ~width:room ~book item)
        items_list
    in
    ("Locus / Measure  Value / state", lines)
  else
    let measure_width = min 12 measure_width in
    let state_width = if room >= 74 then 23 else 11 in
    let desired =
      List.fold_left
        (fun size -> function
          | Balance_items.Account_row { measure; value; _ } ->
              max size (width_of (current_amount ~book ~measure value))
          | _ -> size)
        12 items_list
      |> min 22
    in
    let quantity_width = min desired (room - measure_width - state_width - 13) in
    let locus_width = max 1 (room - quantity_width - measure_width - state_width - 5) in
    let row locus quantity measure state =
      O.pad ~width_of locus_width locus ^ "  "
      ^ O.pad_left ~width_of quantity_width (quantity_cell ~width_of ~width:quantity_width quantity)
      ^ " "
      ^ O.pad ~width_of measure_width measure
      ^ "  " ^ O.pad ~width_of state_width state
    in
    let lines =
      List.map
        (function
          | Balance_items.Account_row { locus; measure; value; _ } ->
              row locus (current_amount ~book ~measure value) measure (current_state value)
          | item -> Balance_items.balance_item_line ~width_of ~width:room ~book item)
        items_list
    in
    (row "Locus" "Amount" "Measure" "State", lines)

let current_detail ~book item =
  match item with
  | Balance_items.Account_row { locus; measure; value; _ } ->
      let explanation =
        match value with
        | O.Exact _ -> []
        | O.Unsupported ->
            [
              Ui_text.tr
                "No current quantity support is justified for this coordinate. Do not infer zero.";
            ]
      in
      [
        "Locus: " ^ locus;
        "Measure: " ^ measure;
        "Amount: " ^ current_amount ~book ~measure value ^ " " ^ measure;
        "State: " ^ current_state value;
      ]
      @ explanation
      @ [ Ui_text.tr "Locus × Measure; not an Account taxonomy." ]
  | item -> Balance_items.balance_item_detail ~book item

let detail_lines ~book t items_list =
  match List.nth_opt items_list t.selected with
  | None -> [ Ui_text.tr "No balances are selected in the current balance view." ]
  | Some item -> (
      match t.mode with
      | `Accounting -> Balance_items.balance_item_detail ~book item
      | `Current -> current_detail ~book item)

let detail_rows ~width_of ~width ~book t items_list =
  detail_lines ~book t items_list
  |> List.mapi (fun index line ->
      match t.mode with
      | `Accounting ->
          O.wrap_text ~width_of (max 1 (width - 6)) line |> List.map (fun text -> (O.Plain, text))
      | `Current ->
          let style = if index = 0 || index = 2 then O.Plain else O.Chrome in
          O.wrap_text ~width_of (max 1 (width - 3)) line
          |> List.map (fun text -> (style, " " ^ text)))
  |> List.concat

(* Print keeps every exact digit; Current prints the same scaled Amount as the list. *)
let current_print_lines ~book items_list =
  List.map
    (function
      | Balance_items.Account_row { locus; measure; value; _ } ->
          "  " ^ locus ^ "  "
          ^ current_amount ~book ~measure value
          ^ " " ^ measure ^ "  " ^ current_state value
      | item -> Balance_items.balance_item_line ~book item)
    items_list

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
      ~fields:[ Form.action_buttons ~confirm:(Ui_text.tr "OK") ~cancel:(Ui_text.tr "Close") () ]
      ()
  in
  let view_error =
    match t.mode with
    | `Accounting -> None
    | `Current -> (
        match balance_view_coords balance_view_text with Error why -> Some why | Ok _ -> None)
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
      let summary =
        header
        @
        match t.mode with
        | `Current -> current_print_lines ~book items_list
        | `Accounting -> balance_lines ~book items_list
      in
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
          ~fields:
            [ Form.action_buttons ~confirm:(Ui_text.tr "Done") ~cancel:(Ui_text.tr "Close") () ]
          ()

let balance_display_review measure chosen =
  Form.create ~id:"review_balance_view" ~title:"Review visible accounts"
    ~summary:
      ([
         "Measure: " ^ measure;
         "Only the selected Measure's display rows will change.";
         "Unknown balances remain '?'.";
       ]
      @
      if chosen = [] then [ "  (no accounts chosen)" ]
      else List.map (fun (c : BalView.coordinate) -> "  " ^ c.locus) chosen)
    ~fields:[ Form.action_buttons ~confirm:"Save" ~cancel:"Edit" () ]
    ()

let print_fits = balance_print_fits

let print_preview_summary t =
  match t.overlay with Print_preview { form; _ } -> Some form.Form.summary | _ -> None

let print_preview_form = balance_print_preview

let detail_viewport ~layout ~width_of ~book ~measure ~roles ~balance_view_text t =
  let items_list = items ~book ~measure ~roles ~balance_view_text t in
  let wrapped =
    detail_rows ~width_of ~width:layout.detail_width ~book t items_list |> List.map snd
  in
  let view =
    Panel.window
      ~capacity:(Panel.capacity ~height:layout.detail_height ~heading:false)
      ~count:(List.length wrapped) ~scroll:t.detail_scroll ~selected:None
  in
  (wrapped, view)

let open_config ~book ~measure ~balance_view_text t =
  match balance_view_text with
  | Error why -> { t with overlay = No_overlay; notice = "Balance setup unavailable: " ^ why }
  | Ok raw -> (
      let previous = match raw with None -> Ok [] | Some text -> BalView.of_string text in
      match previous with
      | Error why -> { t with overlay = No_overlay; notice = "Balance setup unavailable: " ^ why }
      | Ok prev ->
          let old =
            List.filter_map
              (fun (c : BalView.coordinate) -> if c.measure = measure then Some c.locus else None)
              prev
          in
          let approved = admitted_loci book in
          let candidates = old @ List.filter (fun l -> not (List.mem l old)) approved in
          let picker =
            { candidates; chosen = old; cursor = 0; raw_before = raw; previous = prev }
          in
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

let has_overlay t = match t.overlay with No_overlay -> false | _ -> true

(* Every Balances overlay is a centred pane at most 64 cells wide. *)
let overlay_width width = min 64 (max 8 (width - 4))

let overlay ~dimensions:((width, _) as _dimensions) ~body_dimensions:((body_w, body_h) as _body_dim)
    ~width_of t : overlay_frame option =
  match t.overlay with
  | No_overlay -> None
  | Config_picker picker ->
      let pane_w = overlay_width body_w in
      let pane_h = min body_h (max 5 (List.length picker.candidates + 3)) in
      let rows =
        List.map
          (fun locus -> (if List.mem locus picker.chosen then "[x] " else "[ ] ") ^ locus)
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
      let pane_w = overlay_width body_w in
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
      Some { origin_x; origin_y; pane_width = pane_w; pane_height = List.length rows; rows; cursor }
  | Print_preview { form; scroll } ->
      let pane_width = overlay_width body_w in
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

let list_capacity ~heading ~layout = Panel.capacity ~height:layout.list_height ~heading

let handle ~blocked ~book ~measure ~roles ~balance_view_text ~dimensions ~content ~width_of t
    (input : Ui_input.input) =
  let layout = layout ~content ~screen_height:(snd dimensions) ~detail:(t.pane = `Detail) in
  match t.overlay with
  | Print_preview { form; scroll } -> (
      let pane_width = overlay_width (fst dimensions) in
      let content =
        List.concat_map (O.wrap_text ~width_of (max 1 (pane_width - 6))) form.Form.summary
      in
      let pane_height = min (snd dimensions) (max 3 (List.length content + 2)) in
      let view =
        Panel.window
          ~capacity:(Panel.capacity ~height:pane_height ~heading:false)
          ~count:(List.length content) ~scroll ~selected:None
      in
      let scroll_to scroll = ({ t with overlay = Print_preview { form; scroll } }, Stay) in
      let scroll_print delta = scroll_to (Panel.move ~last:view.last ~position:view.start delta) in
      match input with
      | `Key (`Home, _) -> scroll_to 0
      | `Key (`End, _) -> scroll_to view.last
      | `Key ((`Page `Up | `ASCII 'u'), _) -> scroll_print (-max 1 view.capacity)
      | `Key ((`Page `Down | `ASCII 'd'), _) -> scroll_print (max 1 view.capacity)
      | `Key ((`ASCII 'k' | `Arrow `Up), _) -> scroll_print (-1)
      | `Key ((`ASCII 'j' | `Arrow `Down), _) -> scroll_print 1
      | `Key ((`Escape | `Enter | `ASCII ('q' | 'Q')), _) -> ({ t with overlay = No_overlay }, Stay)
      | _ -> (t, Stay))
  | Config_picker picker -> (
      let move delta =
        let next_cursor =
          Panel.move ~last:(List.length picker.candidates - 1) ~position:picker.cursor delta
        in
        ({ t with overlay = Config_picker { picker with cursor = next_cursor } }, Stay)
      in
      match input with
      | `Key ((`Escape | `ASCII ('q' | 'Q')), []) -> ({ t with overlay = No_overlay }, Stay)
      | `Key ((`Arrow `Up | `ASCII 'k'), []) -> move (-1)
      | `Key ((`Arrow `Down | `ASCII 'j'), []) -> move 1
      | `Key (`ASCII ' ', []) ->
          let locus = List.nth picker.candidates picker.cursor in
          let chosen =
            if List.mem locus picker.chosen then List.filter (fun x -> x <> locus) picker.chosen
            else picker.chosen @ [ locus ]
          in
          ({ t with overlay = Config_picker { picker with chosen } }, Stay)
      | `Key (`Enter, []) ->
          let chosen_coords = List.map (fun locus -> { BalView.locus; measure }) picker.chosen in
          let form = balance_display_review measure chosen_coords in
          ({ t with overlay = Config_review { picker; form } }, Stay)
      | _ -> (t, Stay))
  | Config_review { picker; form } -> (
      match input with
      | `Key (`ASCII ('e' | 'E'), []) -> ({ t with overlay = Config_picker picker }, Stay)
      | `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] -> (
          let direction = if mods = [] then `Right else `Left in
          match Form.handle_input form (`Key (`Arrow direction, [])) with
          | Form.Updated next_form ->
              ({ t with overlay = Config_review { picker; form = next_form } }, Stay)
          | _ -> (t, Stay))
      | _ -> (
          match Form.handle_input form input with
          | Form.Cancel -> ({ t with overlay = Config_picker picker }, Stay)
          | Form.Updated next_form ->
              ({ t with overlay = Config_review { picker; form = next_form } }, Stay)
          | Form.Submit submitted ->
              if blocked then
                let updated =
                  Form.set_notice submitted "Writes stopped. Cancel and reload to inspect."
                in
                ({ t with overlay = Config_review { picker; form = updated } }, Stay)
              else
                let pane_w = overlay_width (fst dimensions) in
                let body_h = max 0 (snd dimensions - 3) in
                let rows =
                  Form.render_rows ~width:(max 0 (pane_w - 6)) ~height:max_int ~width_of submitted
                in
                let fits =
                  pane_w >= 48 && List.length rows <= Panel.capacity ~height:body_h ~heading:false
                in
                if not fits then
                  let updated =
                    Form.set_notice submitted
                      "Enlarge the terminal to review every selected account before saving."
                  in
                  ({ t with overlay = Config_review { picker; form = updated } }, Stay)
                else
                  let chosen_coords =
                    List.map (fun locus -> { BalView.locus; measure }) picker.chosen
                  in
                  let other =
                    List.filter
                      (fun (c : BalView.coordinate) -> c.measure <> measure)
                      picker.previous
                  in
                  let content = BalView.to_string (other @ chosen_coords) in
                  (t, Save_balance_view { expected = picker.raw_before; content })))
  | No_overlay -> (
      let toggle_pane = ({ t with pane = (if t.pane = `List then `Detail else `List) }, Stay) in
      let count () = List.length (items ~book ~measure ~roles ~balance_view_text t) in
      (* One motion key: [detail] scrolls the detail by the painted window, [list] moves
         the selection, clamped to the items. *)
      let move ~detail ~list =
        if t.pane = `Detail then
          let _, view =
            detail_viewport ~layout ~width_of ~book ~measure ~roles ~balance_view_text t
          in
          ( { t with detail_scroll = Panel.move ~last:view.last ~position:view.start (detail view) },
            Stay )
        else (set_selected (max 0 (min (max 0 (count () - 1)) (t.selected + list))) t, Stay)
      in
      let page = list_capacity ~heading:(t.mode = `Current) ~layout in
      match input with
      | `Key ((`Escape | `ASCII ('q' | 'Q')), []) ->
          if t.pane = `Detail then ({ t with pane = `List }, Stay) else (t, Back_to_home)
      | `Key ((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)), []) -> toggle_pane
      | `Key ((`Enter | `ASCII ('i' | 'I')), []) -> toggle_pane
      | `Key (`ASCII ' ', []) -> (t, Open_commands)
      | `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] -> toggle_pane
      | `Key (`ASCII 'w', []) -> (t, Cycle_measure `Prev)
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
                      | Balance_items.Account_row r -> r.locus = locus && r.measure = measure
                      | _ -> false)
                    next_items
                with
                | Some idx -> idx
                | None -> 0)
          in
          ({ t_next with selected = sel; detail_scroll = 0 }, Stay)
      | `Key (`ASCII 'c', []) -> (open_config ~book ~measure ~balance_view_text t, Stay)
      | `Key (`ASCII 'p', []) ->
          let form = balance_print_preview ~book ~measure ~roles ~balance_view_text t in
          ({ t with overlay = Print_preview { form; scroll = 0 } }, Stay)
      | `Key (`ASCII 'o', []) -> (
          match selected_account ~book ~measure ~roles ~balance_view_text t with
          | Some (locus, measure, amount) -> (t, Observe { locus; measure; amount })
          | None -> (t, Stay))
      | `Key (`Home, []) ->
          if t.pane = `Detail then ({ t with detail_scroll = 0 }, Stay) else (set_selected 0 t, Stay)
      | `Key (`End, []) ->
          if t.pane = `Detail then
            let _, view =
              detail_viewport ~layout ~width_of ~book ~measure ~roles ~balance_view_text t
            in
            ({ t with detail_scroll = view.last }, Stay)
          else (set_selected (count () - 1) t, Stay)
      | `Key ((`Arrow `Up | `ASCII ('k' | 'K')), []) -> move ~detail:(fun _ -> -1) ~list:(-1)
      | `Key ((`Arrow `Down | `ASCII ('j' | 'J')), []) -> move ~detail:(fun _ -> 1) ~list:1
      | `Key ((`Page `Up | `ASCII 'u'), _) ->
          move ~detail:(fun view -> -max 1 view.capacity) ~list:(-page)
      | `Key ((`Page `Down | `ASCII 'd'), _) ->
          move ~detail:(fun view -> max 1 view.capacity) ~list:page
      | _ -> (t, Stay))

let screen ~book ~measure ~roles ~balance_view_text ~dimensions:(width, height) ~screen_height
    ~width_of t =
  let items_list = items ~book ~measure ~roles ~balance_view_text t in
  let layout = layout ~content:(width, height) ~screen_height ~detail:(t.pane = `Detail) in
  let heading, lines =
    match t.mode with
    | `Current ->
        let heading, lines = current_table ~width_of ~width:layout.list_width ~book items_list in
        (Some heading, lines)
    | `Accounting ->
        (None, balance_lines ~width_of ~width:(max 0 (layout.list_width - 6)) ~book items_list)
  in
  let wrapped_detail = detail_rows ~width_of ~width:layout.detail_width ~book t items_list in
  let is_detail = t.pane = `Detail in
  let list_title =
    match t.mode with
    | `Accounting -> title t
    | `Current -> if is_detail then "Balances" else "Balances [active]"
  in
  let detail_title =
    match t.mode with
    | `Accounting -> "Selected Balance"
    | `Current -> if is_detail then "Selected balance [active]" else "Selected balance"
  in
  let list_panel ~height =
    match t.mode with
    | `Accounting ->
        Panel.frame ?heading ~width_of ~width:layout.list_width ~height ~focused:(not is_detail)
          ~title:list_title ~scroll:0
          ~selected:(if lines = [] then None else Some t.selected)
          lines
    | `Current ->
        let count = List.length lines in
        let window =
          Panel.window
            ~capacity:(Panel.capacity ~height ~heading:true)
            ~count ~scroll:0 ~selected:(Some t.selected)
        in
        let rows =
          if count = 0 then
            O.wrap_text ~width_of
              (max 1 (layout.list_width - 3))
              "No balances are selected in the current balance view."
            |> List.map (fun text -> (O.Chrome, " " ^ text))
          else
            List.filteri (fun i _ -> i >= window.start && i - window.start < window.capacity) lines
            |> List.mapi (fun offset text ->
                let chosen = t.selected = window.start + offset in
                ( (if chosen && not is_detail then O.Active else O.Plain),
                  (if chosen then if is_detail then " * " else " > " else "   ") ^ text ))
        in
        let rows =
          (if height >= 4 then
             List.map (fun text -> (O.Chrome, "   " ^ text)) (Option.to_list heading)
           else [])
          @ rows
        in
        let bottom_label =
          Printf.sprintf "%d/%d%s%s"
            (if count = 0 then 0 else min count (t.selected + 1))
            count
            (if window.start > 0 then " ↑" else "")
            (if window.start + window.capacity < count then " ↓" else "")
        in
        Panel.frame_rows ~inset:0 ~bottom_label ~width_of ~width:layout.list_width ~height
          ~focused:(not is_detail) ~title:list_title rows
  in
  let detail_panel ~height =
    match t.mode with
    | `Accounting ->
        Panel.frame ~width_of ~width:layout.detail_width ~height ~focused:is_detail
          ~title:detail_title ~scroll:t.detail_scroll ~selected:None (List.map snd wrapped_detail)
    | `Current ->
        let count = List.length wrapped_detail in
        let window =
          Panel.window
            ~capacity:(Panel.capacity ~height ~heading:false)
            ~count ~scroll:t.detail_scroll ~selected:None
        in
        let rows =
          List.filteri
            (fun i _ -> i >= window.start && i - window.start < window.capacity)
            wrapped_detail
        in
        let bottom_label =
          Printf.sprintf "%d-%d/%d%s%s"
            (if window.capacity = 0 then 0 else window.start + 1)
            (min count (window.start + window.capacity))
            count
            (if window.start > 0 then " ↑" else "")
            (if window.start + window.capacity < count then " ↓" else "")
        in
        Panel.frame_rows ~inset:0 ~bottom_label ~width_of ~width:layout.detail_width ~height
          ~focused:is_detail ~title:detail_title rows
  in
  if layout.wide then
    List.map2
      (fun (style_l, text_l) (style_r, text_r) ->
        (O.Columns (layout.list_width, style_l, style_r), text_l ^ " " ^ text_r))
      (list_panel ~height:layout.list_height)
      (detail_panel ~height:layout.list_height)
  else if layout.detail_only then detail_panel ~height:layout.detail_height
  else
    list_panel ~height:layout.list_height
    @
    if layout.detail_height = 0 then []
    else [ (O.Plain, "") ] @ detail_panel ~height:layout.detail_height

let footer ~dimensions:(width, _) ~width_of t =
  let fit choices =
    match List.find_opt (fun text -> width_of text <= max 0 width) choices with
    | Some text -> text
    | None -> O.clip_text ~width_of (max 0 width) (List.hd (List.rev choices))
  in
  match t.overlay with
  | Config_picker _ ->
      [
        fit
          [
            "j/k select  Space toggle  Enter review";
            "j/k sel Space toggle Enter review";
            "j/k Space Enter review";
          ];
        fit
          [
            "Esc/q cancel; unknown stays '?'  no write until confirmed";
            "Esc/q cancel; '?' stays unknown";
            "Esc/q cancel; no write";
          ];
      ]
  | Config_review _ ->
      [
        fit [ "Enter save  Tab choose Edit  Esc edit"; "Enter save Tab/Esc edit" ];
        fit [ "Full selection must fit before saving"; "Full review required to save" ];
      ]
  | Print_preview _ ->
      [
        fit
          [
            "PgUp/Dn scroll  Home/End  Enter/Esc close";
            "PgUp/Dn Home/End Enter/Esc close";
            "j/k scroll Enter/Esc close";
          ];
        fit
          [
            "Preview only; no terminal output or book write";
            "Preview only; no output or write";
            "Preview only; no write";
          ];
      ]
  | No_overlay ->
      [
        (if t.pane = `Detail then
           fit [ "[j/k] scroll [Esc/i/q] list [Space] commands"; "[j/k] scroll [Esc/i/q] list" ]
         else
           fit
             [
               "[j/k] select [i/Enter] details [q] back [Space] commands";
               "[j/k] sel [i/Enter] info [q] back";
               "[j/k] sel [i] info [q] back";
             ]);
        fit
          [
            "[C-u/d] page [Home/End] ends [p] print view [w] measure [v] view [c] config [o] \
             observe";
            "[C-u/d] page [Home/End] ends [p] print view [w] unit [v] view [c] cfg [o] obs";
            "[C-u/d] page [Home/End] ends [p] print view";
            "[C-u/d] page [p] print";
          ];
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

let handle env (geometry : Screen.geometry) t input =
  let book, measure, roles, balance_view_text = context env in
  let next, command =
    handle ~blocked:env.blocked ~book ~measure ~roles ~balance_view_text ~dimensions:geometry.screen
      ~content:geometry.content ~width_of:geometry.width_of t input
  in
  (next, request_of t next command)

let saved _env _geometry result t =
  match result with
  | Ok () ->
      (notify_saved t, Screen.Message "Visible Balance accounts saved. Unknown values remain '?'.")
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
  let layout =
    layout ~content:geometry.content ~screen_height:(snd geometry.screen) ~detail:(t.pane = `Detail)
  in
  detail_viewport ~layout ~width_of:geometry.width_of ~book ~measure ~roles ~balance_view_text t

let print_preview_form env t =
  let book, measure, roles, balance_view_text = context env in
  print_preview_form ~book ~measure ~roles ~balance_view_text t

let view env (geometry : Screen.geometry) t =
  let book, measure, roles, balance_view_text = context env in
  let overlay =
    overlay ~dimensions:geometry.screen ~body_dimensions:geometry.body ~width_of:geometry.width_of t
  in
  {
    Screen.title = Ui_text.tr "Balances";
    subtitle =
      Text
        (match t.mode with
        | `Current -> "Selected Locus × Measure; balance-view order only."
        | `Accounting -> "Current role-based quantities; different Measures are not combined.");
    rows =
      lazy
        (screen ~book ~measure ~roles ~balance_view_text ~dimensions:geometry.content
           ~screen_height:(snd geometry.screen) ~width_of:geometry.width_of t);
    footer = footer ~dimensions:geometry.screen ~width_of:geometry.width_of t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
