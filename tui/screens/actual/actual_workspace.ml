(* ActualWorkspace: LOAM-compatible 3-pane Actuals Workspace (UI-03 / UI-04).
   Implements Loci / Actuals / Details layout, prefix/substring live search,
   date/order filtering, and clean single-source cursor positioning. *)

module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module A = Daily_draft
module O = Daily_overlays
module Panel = Ui_panel

type scope = Focus_day | All_current
type sort_order = Asc | Desc
type pane = Loci | Transactions | Details

type t = {
  focus_date : string;
  scope : scope;
  order : sort_order;
  pane : pane;
  locus_row : int;
  transaction_row : int;
  detail_scroll : int;
  search_query : string;
  search_editing : bool;
  notice : string;
}

type command = Stay | Open_selected of B.entry | Record_new | Back | Redraw

let create ~focus_date =
  {
    focus_date;
    scope = All_current;
    order = Desc;
    pane = Transactions;
    locus_row = 0;
    transaction_row = 0;
    detail_scroll = 0;
    search_query = "";
    search_editing = false;
    notice = "";
  }

let focus_date t = t.focus_date
let scope t = t.scope
let sort_order t = t.order
let pane t = t.pane
let locus_row t = t.locus_row
let transaction_row t = t.transaction_row
let detail_scroll t = t.detail_scroll
let search_query t = t.search_query
let search_editing t = t.search_editing
let notice t = t.notice

(* 1. Data extraction and filtering *)

let records_for_scope ~book t =
  let all = B.entries book in
  match t.scope with
  | Focus_day -> List.filter (fun (e : B.entry) -> e.day = t.focus_date) all
  | All_current -> all

let loci_for_scope ~book t =
  let records = records_for_scope ~book t in
  let rec extract_loci acc = function
    | [] -> List.rev acc
    | (e : B.entry) :: rest ->
        let loci = List.map (fun p -> A.lstr (D.Effect.locus p)) e.effects in
        let new_acc =
          List.fold_left (fun a locus -> if List.mem locus a then a else locus :: a) acc loci
        in
        extract_loci new_acc rest
  in
  extract_loci [] records

let selected_locus ~book t =
  if t.locus_row = 0 then None else List.nth_opt (loci_for_scope ~book t) (t.locus_row - 1)

let contains_insensitive needle haystack =
  if needle = "" then true
  else
    Base.String.is_substring (String.lowercase_ascii haystack)
      ~substring:(String.lowercase_ascii needle)

let matches_search ~book t (record : B.entry) =
  if t.search_query = "" then true
  else
    contains_insensitive t.search_query (Option.value ~default:"" record.memo)
    || contains_insensitive t.search_query record.id
    || contains_insensitive t.search_query record.day
    || List.exists
         (fun p ->
           let token = A.lstr (D.Effect.locus p) in
           let label = B.label book token in
           contains_insensitive t.search_query token || contains_insensitive t.search_query label)
         record.effects

let visible_entries ~book t =
  let by_scope = records_for_scope ~book t in
  let by_locus =
    match selected_locus ~book t with
    | None -> by_scope
    | Some locus ->
        List.filter
          (fun (record : B.entry) ->
            List.exists (fun p -> A.lstr (D.Effect.locus p) = locus) record.effects)
          by_scope
  in
  let filtered = List.filter (matches_search ~book t) by_locus in
  List.sort
    (fun (a : B.entry) (b : B.entry) ->
      if a.day = b.day then
        match t.order with Asc -> String.compare b.id a.id | Desc -> String.compare a.id b.id
      else
        match t.order with Asc -> String.compare a.day b.day | Desc -> String.compare b.day a.day)
    filtered

let selected_entry ~book t =
  let records = visible_entries ~book t in
  List.nth_opt records t.transaction_row

let clamp_state ~book t =
  let loci_count = List.length (loci_for_scope ~book t) in
  let locus_row = min (max 0 t.locus_row) loci_count in
  let t_with_locus = { t with locus_row } in
  let records = visible_entries ~book t_with_locus in
  let tx_count = List.length records in
  let transaction_row =
    if tx_count = 0 then 0 else min (max 0 t_with_locus.transaction_row) (tx_count - 1)
  in
  { t_with_locus with transaction_row }

let returned_from_detail ~before_book ~after_book t =
  let locus = selected_locus ~book:before_book t in
  let loci = loci_for_scope ~book:after_book t in
  let locus_row =
    match locus with
    | None -> 0
    | Some token -> (
        match List.find_index (( = ) token) loci with Some idx -> idx + 1 | None -> 0)
  in
  let base =
    {
      t with
      locus_row;
      notice =
        (if Option.is_some locus && locus_row = 0 then
           "Selected Locus is no longer in scope; showing all loci."
         else "");
    }
  in
  let target = Option.map (fun (e : B.entry) -> e.id) (selected_entry ~book:before_book t) in
  let records = visible_entries ~book:after_book base in
  let row =
    match target with
    | None -> None
    | Some id -> List.find_index (fun (e : B.entry) -> e.id = id) records
  in
  match row with
  | Some transaction_row -> { base with transaction_row }
  | None ->
      let fresh = clamp_state ~book:after_book { base with detail_scroll = 0 } in
      {
        fresh with
        notice = "Selected Event no longer matches this list; selection moved to the nearest row.";
      }

(* 2. Amount and Details formatting (LOAM ActualWorkspace) *)

let effect_amount book p =
  let measure = A.mstr (D.Effect.measure p) in
  O.format_money book measure (A.quanta p) ^ " " ^ measure

(* A simple receiving amount, never a sum across split Effects or Measures. *)
let amount_summary book (entry : B.entry) =
  let measures =
    List.sort_uniq String.compare (List.map (fun p -> A.mstr (D.Effect.measure p)) entry.effects)
  in
  let positive = List.filter (fun p -> Z.sign (A.quanta p) > 0) entry.effects
  and negative = List.filter (fun p -> Z.sign (A.quanta p) < 0) entry.effects in
  if List.length measures > 1 then Printf.sprintf "multi (%d)" (List.length measures)
  else if List.length positive > 1 || List.length negative > 1 then "split"
  else
    match (positive, entry.effects) with
    | p :: _, _ | [], [ p ] -> effect_amount book p
    | [], [] -> "—"
    | [], _ -> "see details"

let display_locus ~book token =
  let label = B.label book token in
  if label = "" || label = token then token else label ^ " [" ^ token ^ "]"

let description (entry : B.entry) =
  match entry.memo with None | Some "" -> "(no description)" | Some text -> O.visible text

(* LOAM detailRawLines: date, Effects with label and exact amount, blank,
   description and ID. Bakhlo then keeps the entry's other retained facts
   (original amount, reversal, Merchant, exchange, completed Scheduled). *)
let detail_raw_lines ~book ~width_of ~width (entry_opt : B.entry option) : (O.style * string) list =
  let wrapped style text =
    List.map (fun line -> (style, " " ^ line)) (O.wrap_text ~width_of (max 1 (width - 1)) text)
  in
  match entry_opt with
  | None -> wrapped O.Chrome "(no Actual selected)"
  | Some entry ->
      let effect_lines p =
        let amount = effect_amount book p in
        let label = display_locus ~book (A.lstr (D.Effect.locus p)) in
        let amount_width = width_of amount in
        if amount_width + 4 <= width then
          [ (O.Plain, " " ^ O.pad ~width_of (width - amount_width - 3) label ^ "  " ^ amount) ]
        else
          (* The complete value remains scrollable, never a silently clipped number. *)
          wrapped O.Plain label @ wrapped O.Chrome "Amount (wrapped):" @ wrapped O.Plain amount
      in
      (* The retained facts O.entry_lines lists after the ID line. *)
      let rec after_id = function
        | [] -> []
        | line :: rest -> if String.starts_with ~prefix:"ID: " line then rest else after_id rest
      in
      let extras = after_id (O.entry_lines book entry) in
      wrapped O.Chrome ("Date: " ^ entry.day)
      @ wrapped O.Chrome (Printf.sprintf "Effects (%d):" (List.length entry.effects))
      @ (if entry.effects = [] then wrapped O.Chrome "(no Effects)"
         else List.concat_map effect_lines entry.effects)
      @ [ (O.Plain, "") ]
      @ wrapped O.Plain (description entry)
      @ wrapped O.Chrome ("ID: " ^ O.visible entry.id)
      @ List.concat_map (wrapped O.Chrome) extras

(* 3. Geometry (LOAM geometryForBounds over the workspace content) *)

(* Content excludes the Shell's feedback row (LOAM's status row), its two
   footer rows and the reserved last terminal row. *)
type geometry = {
  writable : int;
  left_width : int;
  panel_height : int;
  detail_height : int;
  context_rows : int;
  wide : bool;
}

let panel_geometry (width, height) =
  let writable = max 0 width and body_capacity = max 0 height + 1 in
  let context_rows = if body_capacity >= 5 then 2 else if body_capacity >= 4 then 1 else 0 in
  let panel_height = max 0 (height - context_rows) in
  let terminal = height + 4 in
  let detail_capacity = if terminal >= 48 then 12 else if terminal >= 36 then 10 else 8 in
  {
    writable;
    left_width = min 50 (max 34 (writable * 30 / 100));
    panel_height;
    detail_height = (if panel_height >= 16 then detail_capacity + 1 else 0);
    context_rows;
    wide = writable >= 98 && panel_height >= 16;
  }

let terminal_geometry dimensions = panel_geometry dimensions

let detail_bounds g pane =
  ( (if g.wide then g.left_width else g.writable),
    if g.detail_height > 0 then g.detail_height else if pane = Details then g.panel_height else 0 )

let list_height g pane =
  if g.wide && pane = Transactions then g.panel_height else max 0 (g.panel_height - g.detail_height)

let list_capacity pane height = max 0 (height - 2 - if pane = Loci || height < 4 then 0 else 1)

let detail_scroll_limit ~book ~width_of geometry t =
  let width, height = detail_bounds geometry t.pane in
  if width < 3 || height < 3 then 0
  else
    let lines = detail_raw_lines ~book ~width_of ~width:(width - 2) (selected_entry ~book t) in
    max 0 (List.length lines - (height - 2))

let page_size geometry pane =
  max 1
    (match pane with
    | Details -> snd (detail_bounds geometry pane) - 2
    | other -> list_capacity other (list_height geometry other))

(* 4. Navigation *)

let move_previous ~book ~width_of geometry t =
  match t.pane with
  | Loci ->
      if t.locus_row = 0 then { t with notice = "No previous Locus row." }
      else
        clamp_state ~book
          {
            t with
            locus_row = t.locus_row - 1;
            transaction_row = 0;
            detail_scroll = 0;
            notice = "";
          }
  | Transactions ->
      if t.transaction_row = 0 then { t with notice = "No previous Actual row." }
      else { t with transaction_row = t.transaction_row - 1; detail_scroll = 0; notice = "" }
  | Details ->
      if t.detail_scroll = 0 then { t with notice = "Top of Details." }
      else { t with detail_scroll = t.detail_scroll - 1; notice = "" }

let move_next ~book ~width_of geometry t =
  let detail_end = detail_scroll_limit ~book ~width_of geometry t in
  match t.pane with
  | Loci ->
      let count = List.length (loci_for_scope ~book t) in
      if t.locus_row < count then
        clamp_state ~book
          {
            t with
            locus_row = t.locus_row + 1;
            transaction_row = 0;
            detail_scroll = 0;
            notice = "";
          }
      else { t with notice = "No next Locus row." }
  | Transactions ->
      let count = List.length (visible_entries ~book t) in
      if t.transaction_row + 1 < count then
        { t with transaction_row = t.transaction_row + 1; detail_scroll = 0; notice = "" }
      else { t with notice = "No next Actual row." }
  | Details ->
      if t.detail_scroll >= detail_end then { t with notice = "End of Details." }
      else { t with detail_scroll = t.detail_scroll + 1; notice = "" }

let move_page_up ~book ~width_of geometry t =
  let ps = page_size geometry t.pane in
  match t.pane with
  | Loci ->
      if t.locus_row = 0 then { t with notice = "Top of Locus list." }
      else
        clamp_state ~book
          {
            t with
            locus_row = max 0 (t.locus_row - ps);
            transaction_row = 0;
            detail_scroll = 0;
            notice = "";
          }
  | Transactions ->
      if t.transaction_row = 0 then { t with notice = "Top of Actual list." }
      else
        { t with transaction_row = max 0 (t.transaction_row - ps); detail_scroll = 0; notice = "" }
  | Details ->
      if t.detail_scroll = 0 then { t with notice = "Top of Details." }
      else { t with detail_scroll = max 0 (t.detail_scroll - ps); notice = "" }

let move_page_down ~book ~width_of geometry t =
  let ps = page_size geometry t.pane in
  let detail_end = detail_scroll_limit ~book ~width_of geometry t in
  match t.pane with
  | Loci ->
      let count = List.length (loci_for_scope ~book t) in
      if t.locus_row >= count then { t with notice = "End of Locus list." }
      else
        clamp_state ~book
          {
            t with
            locus_row = min count (t.locus_row + ps);
            transaction_row = 0;
            detail_scroll = 0;
            notice = "";
          }
  | Transactions ->
      let count = List.length (visible_entries ~book t) in
      if count = 0 || t.transaction_row + 1 >= count then { t with notice = "End of Actual list." }
      else
        {
          t with
          transaction_row = min (count - 1) (t.transaction_row + ps);
          detail_scroll = 0;
          notice = "";
        }
  | Details ->
      if t.detail_scroll >= detail_end then { t with notice = "End of Details." }
      else { t with detail_scroll = min detail_end (t.detail_scroll + ps); notice = "" }

let move_home ~book t =
  match t.pane with
  | Loci ->
      clamp_state ~book
        { t with locus_row = 0; transaction_row = 0; detail_scroll = 0; notice = "" }
  | Transactions -> { t with transaction_row = 0; detail_scroll = 0; notice = "" }
  | Details -> { t with detail_scroll = 0; notice = "" }

let move_end ~book ~width_of geometry t =
  let detail_end = detail_scroll_limit ~book ~width_of geometry t in
  match t.pane with
  | Loci ->
      let count = List.length (loci_for_scope ~book t) in
      clamp_state ~book
        { t with locus_row = count; transaction_row = 0; detail_scroll = 0; notice = "" }
  | Transactions ->
      let count = List.length (visible_entries ~book t) in
      let row = if count = 0 then 0 else count - 1 in
      { t with transaction_row = row; detail_scroll = 0; notice = "" }
  | Details -> { t with detail_scroll = detail_end; notice = "" }

let cycle_filter ~book t =
  let scope = match t.scope with Focus_day -> All_current | All_current -> Focus_day in
  clamp_state ~book
    { t with scope; locus_row = 0; transaction_row = 0; detail_scroll = 0; notice = "" }

let cycle_order ~book t =
  let order = match t.order with Asc -> Desc | Desc -> Asc in
  clamp_state ~book { t with order; transaction_row = 0; detail_scroll = 0; notice = "" }

let begin_search ~book t =
  clamp_state ~book
    {
      t with
      scope = All_current;
      pane = Transactions;
      locus_row = 0;
      transaction_row = 0;
      detail_scroll = 0;
      search_query = "";
      search_editing = true;
      notice = "";
    }

let backspace_utf8 str =
  if String.length str = 0 then ""
  else
    let rec find_last_char_start idx =
      if idx <= 0 then 0
      else
        let byte = Char.code str.[idx] in
        if byte land 0b1100_0000 <> 0b1000_0000 then idx else find_last_char_start (idx - 1)
    in
    let last_idx = find_last_char_start (String.length str - 1) in
    String.sub str 0 last_idx

let edit_search ~book t edit =
  clamp_state ~book
    {
      t with
      search_query = edit t.search_query;
      transaction_row = 0;
      detail_scroll = 0;
      notice = "";
    }

let normalize_for_bounds ~book ~dimensions ~width_of t =
  let geometry = terminal_geometry dimensions in
  if t.detail_scroll = 0 then t
  else
    let maximum = detail_scroll_limit ~book ~width_of geometry t in
    { t with detail_scroll = min t.detail_scroll maximum }

(* 5. Event handling *)

let handle ~book ~dimensions ~width_of t (input : Ui_input.input) =
  let geometry = terminal_geometry dimensions in
  let t = normalize_for_bounds ~book ~dimensions ~width_of t in
  if t.search_editing then
    match input with
    | `Key (`Enter, _) -> ({ t with search_editing = false; notice = "" }, Stay)
    | `Key (`Escape, _) ->
        let cleared =
          clamp_state ~book
            {
              t with
              search_query = "";
              search_editing = false;
              transaction_row = 0;
              detail_scroll = 0;
              notice = "";
            }
        in
        (cleared, Stay)
    | `Key (`Backspace, _) -> (edit_search ~book t backspace_utf8, Stay)
    | `Key (`ASCII c, _) when c >= ' ' && c <= '~' ->
        (edit_search ~book t (fun curr -> curr ^ String.make 1 c), Stay)
    | `Key (`Uchar u, _) ->
        let b = Buffer.create 4 in
        Uutf.Buffer.add_utf_8 b u;
        (edit_search ~book t (fun curr -> curr ^ Buffer.contents b), Stay)
    | _ -> (t, Stay)
  else
    match input with
    | `Key (`ASCII 'j', []) | `Key (`Arrow `Down, _) -> (move_next ~book ~width_of geometry t, Stay)
    | `Key (`ASCII 'k', []) | `Key (`Arrow `Up, _) ->
        (move_previous ~book ~width_of geometry t, Stay)
    | `Key (`Page `Down, _) -> (move_page_down ~book ~width_of geometry t, Stay)
    | `Key (`Page `Up, _) -> (move_page_up ~book ~width_of geometry t, Stay)
    | `Key (`Home, _) -> (move_home ~book t, Stay)
    | `Key (`End, _) -> (move_end ~book ~width_of geometry t, Stay)
    | `Key (`ASCII 'h', []) | `Key (`Arrow `Left, _) ->
        let prev_pane =
          match t.pane with Loci -> Details | Transactions -> Loci | Details -> Transactions
        in
        ({ t with pane = prev_pane; notice = "" }, Stay)
    | `Key (`ASCII 'l', []) | `Key (`Arrow `Right, _) ->
        let next_pane =
          match t.pane with Loci -> Transactions | Transactions -> Details | Details -> Loci
        in
        ({ t with pane = next_pane; notice = "" }, Stay)
    | `Key (`Tab, mods) ->
        if List.mem `Shift mods then
          let prev_pane =
            match t.pane with Loci -> Details | Transactions -> Loci | Details -> Transactions
          in
          ({ t with pane = prev_pane; notice = "" }, Stay)
        else
          let next_pane =
            match t.pane with Loci -> Transactions | Transactions -> Details | Details -> Loci
          in
          ({ t with pane = next_pane; notice = "" }, Stay)
    | `Key (`ASCII 'i', []) ->
        let next_pane =
          match t.pane with Details -> Transactions | Loci | Transactions -> Details
        in
        ({ t with pane = next_pane; notice = "" }, Stay)
    | `Key (`ASCII 'f', []) -> (cycle_filter ~book t, Stay)
    | `Key (`ASCII 's', []) -> (cycle_order ~book t, Stay)
    | `Key (`ASCII '/', []) -> (begin_search ~book t, Stay)
    | `Key (`Enter, _) -> (
        match t.pane with
        | Transactions | Details -> (
            match selected_entry ~book t with
            | Some entry -> (t, Open_selected entry)
            | None -> ({ t with notice = "No current Actual is selected to open." }, Stay))
        | Loci -> ({ t with notice = "Move to the Actuals pane before opening a record." }, Stay))
    | `Key (`ASCII ('n' | 'N' | 'r' | 'R'), []) -> (t, Record_new)
    | `Key (`ASCII ('q' | 'Q'), _) | `Key (`Escape, _) ->
        if t.pane = Details then ({ t with pane = Transactions; notice = "" }, Stay) else (t, Back)
    | `Key (`ASCII 'l', [ `Ctrl ]) -> (t, Redraw)
    | _ -> (t, Stay)

(* 6. Screen Rendering (LOAM ActualWorkspace.view) *)

let scope_text t =
  match t.scope with
  | Focus_day -> "Focus Day (" ^ t.focus_date ^ ")"
  | All_current -> "All Current"

let current_locus_name ~book t =
  match selected_locus ~book t with None -> "All loci" | Some token -> display_locus ~book token

let frame ~width_of ~width ~height ~focused ~title ~bottom rows =
  Panel.frame_rows ~inset:0 ?bottom_label:bottom ~width_of ~width ~height ~focused ~title rows

(* Date and amount columns stay fixed while Description receives the rest. *)
let table_row ~width_of width amount_width date desc amount =
  O.pad ~width_of 10 date ^ "  "
  ^ O.pad ~width_of (max 0 (width - 10 - amount_width - 4)) desc
  ^ "  "
  ^ O.pad_left ~width_of amount_width
      (if width_of amount <= amount_width then amount else "see details")

let list_panel ~book ~width_of t ~records ~loci pane (width, height) title =
  let selected = if pane = Loci then t.locus_row else t.transaction_row in
  let row_width =
    width - 5
    (* two borders and the three-column selection marker *)
  in
  let tabular = row_width >= 40 in
  let amount_width =
    if pane = Loci then 0
    else
      min
        (max 0 (row_width - 26))
        (min 22
           (max 12 (List.fold_left (fun w e -> max w (width_of (amount_summary book e))) 0 records)))
  in
  let header =
    if pane = Loci || height < 4 then []
    else
      [
        ( O.Chrome,
          "   "
          ^
          if tabular then table_row ~width_of row_width amount_width "Date" "Description" "Amount"
          else "Description" );
      ]
  in
  let rows = list_capacity pane height in
  let start = if selected < rows then 0 else selected + 1 - rows in
  let records = Array.of_list records and loci = Array.of_list loci in
  let label index =
    if pane = Loci then
      if index = 0 then Some "[All loci]"
      else if index - 1 < Array.length loci then
        Some (O.pad ~width_of (max 0 row_width) (display_locus ~book loci.(index - 1)))
      else None
    else if index < Array.length records then
      let e = records.(index) in
      Some
        (if tabular then
           table_row ~width_of row_width amount_width e.day (description e) (amount_summary book e)
         else O.pad ~width_of (max 0 row_width) (description e))
    else None
  in
  let active = pane = t.pane in
  let content =
    List.init rows (fun row ->
        let index = start + row in
        match label index with
        | Some text ->
            let chosen = index = selected in
            ( (if chosen && active then O.Active else O.Plain),
              (if chosen then if active then " > " else " * " else "   ") ^ text )
        | None ->
            (O.Plain, if row = 0 && pane = Transactions then " (no matching Actual records)" else ""))
  in
  let total = if pane = Loci then Array.length loci + 1 else Array.length records in
  let position = if total = 0 then "0/0" else Printf.sprintf "%d/%d" (selected + 1) total in
  let more = if start + rows < total then " ▼" else "" in
  frame ~width_of ~width ~height ~focused:active ~title
    ~bottom:(Some (position ^ more))
    (header @ content)

let detail_panel ~book ~width_of (width, height) t =
  let focused = t.pane = Details in
  let capacity = max 0 (height - 2) in
  let lines =
    detail_raw_lines ~book ~width_of ~width:(max 1 (width - 2)) (selected_entry ~book t)
  in
  let max_scroll = max 0 (List.length lines - capacity) in
  let scroll = min t.detail_scroll max_scroll in
  let visible = List.filteri (fun i _ -> i >= scroll && i < scroll + capacity) lines in
  let has_more = scroll < max_scroll and can_scroll_up = scroll > 0 in
  let bottom =
    if focused then
      let indicator =
        if has_more && can_scroll_up then "▲▼"
        else if has_more then "▼"
        else if can_scroll_up then "▲"
        else ""
      in
      Some
        (if indicator = "" then "[j/k] scroll  [Esc] back"
         else Printf.sprintf "[j/k] scroll %s  [Esc] back" indicator)
    else if has_more then Some "▼ [i] more"
    else None
  in
  frame ~width_of ~width ~height ~focused
    ~title:("Details" ^ if focused then " [active]" else "")
    ~bottom visible

let search_line ~width ~width_of t =
  let width = max 0 width in
  if t.search_editing && width > 0 then
    let caption = O.clip_text ~width_of (width - 1) " Search: /" in
    let query =
      O.tail_text ~width_of (max 0 (width - width_of caption - 1)) (O.visible t.search_query)
    in
    let text = caption ^ query in
    (O.Input (width_of text), text ^ " ")
  else (O.Chrome, O.clip_text ~width_of width (" Search: /" ^ t.search_query))

let screen ~book ~today ~draft_retained ~dimensions ~width_of t =
  let g = panel_geometry dimensions in
  let loci = loci_for_scope ~book t in
  let t = clamp_state ~book t in
  let records = visible_entries ~book t in
  let order_tag, order_text =
    match t.order with Asc -> ("asc", "oldest first") | Desc -> ("desc", "newest first")
  in
  let left_header =
    "Loci" ^ (if t.pane = Loci then " [active]" else "") ^ Printf.sprintf " (%d)" (List.length loci)
  in
  let right_header =
    "Actuals"
    ^ (if t.pane = Transactions then " [active]" else "")
    ^ Printf.sprintf " (%d, %s, %s)" (List.length records) order_tag order_text
  in
  let searching = t.search_query <> "" || t.search_editing in
  let context_line =
    if searching then search_line ~width:g.writable ~width_of t
    else
      ( O.Chrome,
        O.clip_text ~width_of g.writable (" " ^ scope_text t ^ "  |  " ^ current_locus_name ~book t)
      )
  in
  (* Bakhlo keeps its retained-draft warning visible in the workspace title. *)
  let title =
    ( O.Plain,
      O.clip_text ~width_of g.writable
        (" Household Actuals Workspace  |  known through " ^ today
        ^ if draft_retained then "   Draft retained" else "") )
  in
  let context =
    if g.context_rows = 1 && searching then [ context_line ]
    else List.filteri (fun i _ -> i < g.context_rows) [ title; context_line ]
  in
  let list pane width title =
    list_panel ~book ~width_of t ~records ~loci pane (width, list_height g pane) title
  in
  let detail () = detail_panel ~book ~width_of (detail_bounds g t.pane) t in
  let panels =
    if g.wide then
      let left = list Loci g.left_width left_header @ detail () in
      let right = list Transactions (g.writable - g.left_width - 1) right_header in
      List.map2
        (fun (ls, lt) (rs, rt) -> (O.Columns (g.left_width, ls, rs), lt ^ " " ^ rt))
        left right
    else if t.pane = Details && g.detail_height = 0 then detail ()
    else
      let pane = if t.pane = Loci then Loci else Transactions in
      list pane g.writable (if pane = Loci then left_header else right_header)
      @ if g.detail_height > 0 then detail () else []
  in
  context @ panels

let footer ~dimensions ~width_of t =
  let width, _ = dimensions in
  if t.search_editing then
    [
      "Search input: type text   Backspace delete   Enter keep   Esc clear";
      "Matches update live across all current Actual evidence.";
    ]
  else if t.pane = Details then
    [
      "[j/k] scroll details  [h/l] pane  [Esc/i] return to Actuals";
      "[Enter] open selected  [d] date  [m] merchant  [n] new  [q] back";
    ]
  else
    let detailed =
      "[j/k] select  [h/l] pane  [Tab] cycle  [i] details  [f] filter  [s] sort  [/] search"
    in
    if width_of detailed <= width then
      [ detailed; "[Enter] open selected  [d] date  [m] merchant  [n] new  [q] back" ]
    else
      [
        "[j/k] sel [h/l] pane [Tab] cycle [i] info [f] filter [s] sort [/] search";
        "[Enter] open [d] date [m] merchant [n] new [q] back";
      ]

(* The search caret sits on the context row that paints the search line. *)
let cursor_position ~dimensions ~width_of t =
  let g = panel_geometry dimensions in
  match search_line ~width:g.writable ~width_of t with
  | O.Input caret, _ when g.context_rows >= 1 -> Some (caret, if g.context_rows = 1 then 0 else 1)
  | _ -> None

let detail_window ~book ~dimensions ~width_of t =
  let g = terminal_geometry dimensions in
  let last = detail_scroll_limit ~book ~width_of g t in
  {
    Panel.capacity = max 0 (snd (detail_bounds g t.pane) - 2);
    start = min last t.detail_scroll;
    last;
  }
