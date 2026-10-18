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

type command =
  | Stay
  | Open_selected of B.entry
  | Record_new
  | Back
  | Redraw

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
          List.fold_left
            (fun a locus -> if List.mem locus a then a else locus :: a)
            acc loci
        in
        extract_loci new_acc rest
  in
  extract_loci [] records

let selected_locus ~book t =
  if t.locus_row = 0 then None
  else List.nth_opt (loci_for_scope ~book t) (t.locus_row - 1)

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
           contains_insensitive t.search_query token
           || contains_insensitive t.search_query label)
         record.effects

let visible_entries ~book t =
  let by_scope = records_for_scope ~book t in
  let by_locus =
    match selected_locus ~book t with
    | None -> by_scope
    | Some locus ->
        List.filter
          (fun (record : B.entry) ->
            List.exists
              (fun p -> A.lstr (D.Effect.locus p) = locus)
              record.effects)
          by_scope
  in
  let filtered = List.filter (matches_search ~book t) by_locus in
  List.sort
    (fun (a : B.entry) (b : B.entry) ->
      if a.day = b.day then
        match t.order with
        | Asc -> String.compare b.id a.id
        | Desc -> String.compare a.id b.id
      else
        match t.order with
        | Asc -> String.compare a.day b.day
        | Desc -> String.compare b.day a.day)
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
    if tx_count = 0 then 0
    else min (max 0 t_with_locus.transaction_row) (tx_count - 1)
  in
  { t_with_locus with transaction_row }

let returned_from_detail ~before_book ~after_book t =
  let locus = selected_locus ~book:before_book t in
  let loci = loci_for_scope ~book:after_book t in
  let locus_row =
    match locus with
    | None -> 0
    | Some token -> (
        match List.find_index (( = ) token) loci with
        | Some idx -> idx + 1
        | None -> 0)
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
        notice =
          "Selected Event no longer matches this list; selection moved to the nearest row.";
      }

(* 2. Amount and Details formatting *)

let effect_amount book p =
  let measure = A.mstr (D.Effect.measure p) and quanta = A.quanta p in
  let amount = B.format book measure (Z.abs quanta) in
  let parts = String.split_on_char '.' amount in
  let whole = List.hd parts in
  let grouped = Buffer.create (String.length amount + 16) in
  String.iteri
    (fun i c ->
      if i > 0 && (String.length whole - i) mod 3 = 0 then Buffer.add_char grouped ',';
      Buffer.add_char grouped c)
    whole;
  (if Z.sign quanta < 0 then "-" else if Z.sign quanta > 0 then "+" else "")
  ^ Buffer.contents grouped
  ^ (match List.tl parts with [] -> "" | xs -> "." ^ String.concat "." xs)
  ^ " " ^ measure

let amount_summary book (entry : B.entry) =
  let measures =
    List.sort_uniq String.compare
      (List.map (fun p -> A.mstr (D.Effect.measure p)) entry.effects)
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

let detail_raw_lines ~book ~width_of ~width t (entry_opt : B.entry option) :
    (O.style * string) list =
  match entry_opt with
  | None -> [ (O.Chrome, "(no Actual selected)") ]
  | Some entry ->
      let lines = O.entry_lines book entry in
      let wrapped = List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) lines in
      List.map (fun line -> (O.Plain, line)) wrapped

(* 3. Geometry calculations *)

type geometry = {
  writable : int;
  left_width : int;
  right_width : int;
  panel_height : int;
  loci_height : int;
  tx_height : int;
  wide : bool;
}

let panel_geometry (width, height) =
  let writable = max 0 width in
  let panel_height = max 0 height in
  let wide = writable >= 80 && panel_height >= 14 in
  let left_width, right_width =
    if wide then
      let left = max 36 (min 58 (writable * 52 / 100)) in
      (left, max 0 (writable - left - 1))
    else (writable, writable)
  in
  let loci_height = if wide then max 4 (min 7 (panel_height * 30 / 100)) else panel_height in
  let tx_height = if wide then max 0 (panel_height - loci_height) else panel_height in
  {
    writable;
    left_width;
    right_width;
    panel_height;
    loci_height;
    tx_height;
    wide;
  }

let terminal_geometry dimensions = panel_geometry dimensions

let list_capacity pane height =
  max 1 (height - 2 - (if pane = Loci || height < 4 then 0 else 1))

let detail_scroll_limit ~book ~width_of geometry t =
  let width = geometry.writable in
  let height = max 0 geometry.panel_height in
  let _, detail_width =
    if width < 80 then (width, width)
    else
      let left = max 36 (min 58 (width * 52 / 100)) in
      (left, width - left - 1)
  in
  let capacity = Panel.capacity ~height ~heading:false in
  let lines = detail_raw_lines ~book ~width_of ~width:detail_width t (selected_entry ~book t) in
  max 0 (List.length lines - capacity)

let page_size geometry pane =
  match pane with
  | Details ->
      let height = max 0 geometry.panel_height in
      max 1 (Panel.capacity ~height ~heading:false)
  | Loci -> list_capacity Loci geometry.loci_height
  | Transactions -> list_capacity Transactions geometry.tx_height

(* 4. Navigation *)

let move_previous ~book ~width_of geometry t =
  match t.pane with
  | Loci ->
      if t.locus_row = 0 then { t with notice = "No previous Locus row." }
      else
        clamp_state ~book
          { t with locus_row = t.locus_row - 1; transaction_row = 0; detail_scroll = 0; notice = "" }
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
          { t with locus_row = t.locus_row + 1; transaction_row = 0; detail_scroll = 0; notice = "" }
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
          { t with locus_row = max 0 (t.locus_row - ps); transaction_row = 0; detail_scroll = 0; notice = "" }
  | Transactions ->
      if t.transaction_row = 0 then { t with notice = "Top of Actual list." }
      else { t with transaction_row = max 0 (t.transaction_row - ps); detail_scroll = 0; notice = "" }
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
          { t with locus_row = min count (t.locus_row + ps); transaction_row = 0; detail_scroll = 0; notice = "" }
  | Transactions ->
      let count = List.length (visible_entries ~book t) in
      if count = 0 || t.transaction_row + 1 >= count then
        { t with notice = "End of Actual list." }
      else
        { t with transaction_row = min (count - 1) (t.transaction_row + ps); detail_scroll = 0; notice = "" }
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
  clamp_state ~book
    { t with order; transaction_row = 0; detail_scroll = 0; notice = "" }

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
        if byte land 0b1100_0000 <> 0b1000_0000 then idx
        else find_last_char_start (idx - 1)
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
    | `Key (`ASCII 'j', []) | `Key (`Arrow `Down, _) ->
        (move_next ~book ~width_of geometry t, Stay)
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
            | None ->
                ({ t with notice = "No current Actual is selected to open." }, Stay))
        | Loci ->
            ({ t with notice = "Move to the Actuals pane before opening a record." }, Stay))
    | `Key (`ASCII ('n' | 'N' | 'r' | 'R'), []) -> (t, Record_new)
    | `Key (`ASCII ('q' | 'Q'), _) | `Key (`Escape, _) ->
        if t.pane = Details then ({ t with pane = Transactions; notice = "" }, Stay)
        else (t, Back)
    | `Key (`ASCII 'l', [ `Ctrl ]) -> (t, Redraw)
    | _ -> (t, Stay)

(* 6. Screen Rendering *)

let scope_text t =
  match t.scope with
  | Focus_day -> "Focus Day (" ^ t.focus_date ^ ")"
  | All_current -> "All Current"

let current_locus_name ~book t =
  match selected_locus ~book t with
  | None -> "All loci"
  | Some token -> display_locus ~book token

let render_panel ~width ~height ~title ~focused ~bottom_label ~width_of lines =
  if width < 6 || height < 2 then
    List.init (max 0 height) (fun _ -> (O.Plain, String.make (max 0 width) ' '))
  else
    let style = if focused then O.Focused_frame else O.Frame in
    let top = O.panel_border ~width ~style ~width_of (Ui_text.tr title) in
    let bottom =
      O.panel_bottom ~width ~style ~width_of
        ~title:(Option.value ~default:"" bottom_label) ()
    in
    let capacity = max 0 (height - 2) in
    let rec take acc count = function
      | [] -> List.rev acc
      | x :: xs ->
          if count >= capacity then List.rev acc
          else take (x :: acc) (count + 1) xs
    in
    let visible = take [] 0 lines in
    let body =
      List.map
        (fun (s, line) -> O.panel_line ~width ~width_of s line)
        visible
    in
    let pad_count = max 0 (capacity - List.length visible) in
    let padding = List.init pad_count (fun _ -> O.panel_line ~width ~width_of O.Plain "") in
    top :: body @ padding @ [ bottom ]

let render_detail_panel ~book ~width_of (width, height) ~focused t =
  let capacity = max 0 (height - 2) in
  let raw_lines =
    detail_raw_lines ~book ~width_of ~width t (selected_entry ~book t)
  in
  let count = List.length raw_lines in
  let max_scroll = max 0 (count - capacity) in
  let scroll = min t.detail_scroll max_scroll in
  let visible =
    raw_lines |> List.filteri (fun i _ -> i >= scroll && i < scroll + capacity)
  in
  let has_more = scroll < max_scroll in
  let can_scroll_up = scroll > 0 in
  let bottom_label =
    if focused then
      let indicator =
        if has_more && can_scroll_up then "▲▼"
        else if has_more then "▼"
        else if can_scroll_up then "▲"
        else ""
      in
      if indicator = "" then "[j/k] scroll  [Esc] back"
      else Printf.sprintf "[j/k] scroll %s  [Esc] back" indicator
    else if has_more then "▼ [i] more"
    else ""
  in
  let title = "Actual Detail" ^ if focused then " [active]" else "" in
  render_panel ~width ~height ~title ~focused
    ~bottom_label:(if bottom_label = "" then None else Some bottom_label)
    ~width_of visible

let screen ~book ~dimensions ~width_of t =
  let geometry = panel_geometry dimensions in
  let loci = loci_for_scope ~book t in
  let loci_count = List.length loci in
  let t_clamped = clamp_state ~book t in
  let records = visible_entries ~book t_clamped in
  let tx_count = List.length records in

  (* Loci panel lines *)
  let loci_header =
    Printf.sprintf "Loci (%d)" loci_count ^ if t.pane = Loci then " [active]" else ""
  in
  let loci_rows =
    "[All loci]" :: List.map (display_locus ~book) loci
  in
  let loci_panel (w, h) =
    Panel.frame ~width_of ~width:w ~height:h ~focused:(t.pane = Loci)
      ~title:loci_header ~scroll:0 ~selected:(Some t.locus_row) loci_rows
  in

  (* Actuals panel lines *)
  let order_tag = match t.order with Asc -> "asc" | Desc -> "desc" in
  let order_text = match t.order with Asc -> "oldest first" | Desc -> "newest first" in
  let tx_header =
    Printf.sprintf "Actuals (%d, %s, %s)" tx_count order_tag order_text
    ^ (if t.pane = Transactions then " [active]" else "")
  in
  let amount_w =
    min 22
      (max 12
         (List.fold_left
            (fun n (e : B.entry) -> max n (width_of (amount_summary book e)))
            0 records))
  in
  let tx_panel (w, h) =
    (* Reserve the panel_line border and Panel.frame's two-cell selection prefix. *)
    let row_width = max 0 (w - 6) in
    let tabular = row_width >= 40 in
    let header_line =
      if tabular then
        let desc_w = max 0 (row_width - 10 - amount_w - 4) in
        O.pad ~width_of 10 "Date" ^ "  "
        ^ O.pad ~width_of desc_w "Description"
        ^ "  "
        ^ String.make (max 0 (amount_w - width_of "Amount")) ' '
        ^ "Amount"
      else "Description"
    in
    let rows_text =
      List.map
        (fun (e : B.entry) ->
          let desc = Option.value ~default:"(no description)" e.memo in
          let amt = amount_summary book e in
          if tabular then
            let desc_w = max 0 (row_width - 10 - amount_w - 4) in
            let amt_str = if width_of amt <= amount_w then amt else "see details" in
            O.pad ~width_of 10 e.day ^ "  "
            ^ O.pad ~width_of desc_w desc ^ "  "
            ^ String.make (max 0 (amount_w - width_of amt_str)) ' '
            ^ amt_str
          else O.clip_text ~width_of row_width desc)
        records
    in
    if tx_count = 0 then
      render_panel ~width:w ~height:h ~title:tx_header ~focused:(t.pane = Transactions)
        ~bottom_label:(Some "0–0 / 0") ~width_of
        ((if h >= 4 then [ O.Chrome, header_line ] else [])
         @ [ O.Plain, "  (no matching Actual records)" ])
    else
      Panel.frame ?heading:(if h >= 4 then Some header_line else None)
        ~width_of ~width:w ~height:h ~focused:(t.pane = Transactions)
        ~title:tx_header ~scroll:0 ~selected:(Some t.transaction_row) rows_text
  in

  (* Details panel *)
  let details_panel (w, h) =
    render_detail_panel ~book ~width_of (w, h) ~focused:(t.pane = Details) t
  in

  (* Layout synthesis *)
  if geometry.wide then
    let left_w = geometry.left_width in
    let right_w = geometry.right_width in
    let loci_h = geometry.loci_height in
    let tx_h = geometry.tx_height in
    let detail_h = geometry.panel_height in
    let left_top = loci_panel (left_w, loci_h) in
    let left_bottom = tx_panel (left_w, tx_h) in
    let left = left_top @ left_bottom in
    let right = details_panel (right_w, detail_h) in
    List.map2
      (fun (style_l, text_l) (style_r, text_r) ->
        (O.Columns (left_w, style_l, style_r), text_l ^ " " ^ text_r))
      left right
  else if t.pane = Details then
    details_panel (geometry.writable, geometry.panel_height)
  else if t.pane = Loci then
    loci_panel (geometry.writable, geometry.panel_height)
  else
    tx_panel (geometry.writable, geometry.panel_height)

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

let search_line ~width ~width_of t =
  let width = max 0 (width - 1) in
  if t.search_editing && width > 0 then
    let caption = O.clip_text ~width_of (width - 1) " Search: /" in
    let query = O.tail_text ~width_of (max 0 (width - width_of caption - 1))
        (O.visible t.search_query) in
    let text = caption ^ query in
    (O.Input (width_of text), text ^ " ")
  else
    (O.Chrome, O.clip_text ~width_of width (" Search: /" ^ t.search_query))

let cursor_position ~dimensions:(width, height) ~width_of t =
  match search_line ~width ~width_of t with
  | O.Input caret, _ when height > 1 -> Some (caret, 1)
  | _ -> None
