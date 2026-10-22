(* ActualWorkspace: the Actuals workspace (UI-03 / UI-04). The list is grouped
   by day inside a period window (Today / Cycle / Month / Year / All); every day header
   carries that day's EXPENSE-role total per Measure and is marked partial when
   an effect has no role. Loci / Actuals / Details stay a three-pane layout with
   prefix/substring live search and a single-source cursor. *)

module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module A = Daily_draft
module O = Daily_overlays
module Panel = Ui_panel
module Roles = Locus_roles
module Cal = Daily_calendar

type period = Today | Cycle | Month | Year | All
type sort_order = Newest | Oldest | Largest
type pane = Loci | Transactions | Details

type window = { start_day : string; end_exclusive : string; label : string }

type roles = ((string * Roles.role) list, string) result

(** What the workspace reads besides the book: the resolved period window, the
    day, the accounting roles and the current Measure. *)
type scope = {
  window : window;
  today : string;
  focus_day : string;
  (** The day the window was opened on: today, or the Calendar's selected day. *)
  roles : roles;
  measure : string;
}

(** Everything the workspace reads that the Shell owns. *)
type context = {
  book : B.t;
  scope : scope;
  warning : string option;
  (** The window could not be resolved; the list still works and says so. *)
}

type t = {
  period : period;
  period_offset : int;
  order : sort_order;
  pane : pane;
  locus_row : int;
  transaction_row : int;
  detail_scroll : int;
  search_query : string;
  search_editing : bool;
  notice : string;
  focus_day : string option;
  (** The day the workspace was opened on; None is today. *)
  pending_selection : bool;
  (** The next resolve selects the focus day's group (or the latest day before it). *)
  remembered_scope : scope option;
  (** The scope of the last render, kept so a drill return restores the
      selection in the same window and the same order. *)
}

type command = Stay | Open_selected of B.entry | Record_new | Back | Redraw

let create ?focus_day () =
  {
    focus_day;
    period = Cycle;
    period_offset = 0;
    order = Newest;
    pane = Transactions;
    locus_row = 0;
    transaction_row = 0;
    detail_scroll = 0;
    search_query = "";
    search_editing = false;
    notice = "";
    pending_selection = true;
    remembered_scope = None;
  }

let period t = t.period
let period_offset t = t.period_offset
let focus_day t = t.focus_day
let sort_order t = t.order
let pane t = t.pane
let locus_row t = t.locus_row
let transaction_row t = t.transaction_row
let detail_scroll t = t.detail_scroll
let search_query t = t.search_query
let search_editing t = t.search_editing
let notice t = t.notice

(* The period filter and its window are the Screen's choice; the workspace keeps
   the scope so a drill return restores the selection in the same window. *)
let set_period period t = { t with period; period_offset = 0; pending_selection = true; notice = "" }

let set_period_offset offset t =
  { t with period_offset = offset; pending_selection = true; notice = "" }

let set_focus_day day t =
  { t with focus_day = Some day; period_offset = 0; pending_selection = true; notice = "" }

let set_scope scope t = { t with remembered_scope = Some scope }

(* 1. Data extraction and filtering *)

let in_window ~window (e : B.entry) = e.day >= window.start_day && e.day < window.end_exclusive

(* The entries inside the window, in book order. *)
let scan_window ~book ~window = List.filter (in_window ~window) (B.entries book)

(* First-occurrence Loci order from an already-scoped record list. *)
let loci_of_records records =
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

let locus_at loci row = if row = 0 then None else List.nth_opt loci (row - 1)

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

(* The entry's EXPENSE total in one Measure: the amount order of the list. *)
let entry_expense_amount ~roles ~measure (entry : B.entry) =
  match roles with
  | Error _ -> Z.zero
  | Ok roles ->
      List.fold_left
        (fun acc (posting : D.Effect.t) ->
          let locus = A.lstr (D.Effect.locus posting) in
          if
            A.mstr (D.Effect.measure posting) = measure
            && List.assoc_opt locus roles = Some Roles.Expense
          then Z.add acc (A.quanta posting)
          else acc)
        Z.zero entry.effects

(* The day order follows the list order; within one day the entries keep the
   order the workspace has always shown. *)
let compare_entries ~sort ~roles ~measure (a : B.entry) (b : B.entry) =
  match sort with
  | Newest ->
      let by_day = String.compare b.day a.day in
      if by_day <> 0 then by_day else String.compare a.id b.id
  | Oldest ->
      let by_day = String.compare a.day b.day in
      if by_day <> 0 then by_day else String.compare b.id a.id
  | Largest ->
      let by_amount =
        Z.compare
          (entry_expense_amount ~roles ~measure b)
          (entry_expense_amount ~roles ~measure a)
      in
      if by_amount <> 0 then by_amount else String.compare a.id b.id

let filtered_entries ~ctx t ~records ~locus =
  let book = ctx.book in
  let by_locus =
    match locus with
    | None -> records
    | Some locus ->
        List.filter
          (fun (record : B.entry) ->
            List.exists (fun p -> A.lstr (D.Effect.locus p) = locus) record.effects)
          records
  in
  let filtered = List.filter (matches_search ~book t) by_locus in
  List.sort
    (compare_entries ~sort:t.order ~roles:ctx.scope.roles ~measure:ctx.scope.measure)
    filtered

(* A day of the list: its entries, where its first entry sits in the sorted
   list and that day's EXPENSE total. *)
type group = {
  day : string;
  entries : B.entry list;
  first : int;
  total : string option;
}

(* The EXPENSE total per Measure in the shared money format. A day with an
   effect without a role is partial: the total is marked, never completed. *)
let totals_text ~book totals partial =
  let parts =
    List.filter_map
      (fun (measure, amount) ->
        if Z.sign amount = 0 then None
        else Some (O.format_money book measure amount ^ " " ^ measure))
      totals
  in
  match parts with
  | [] -> if partial then Some "+?" else None
  | parts -> Some (String.concat " / " parts ^ (if partial then "+?" else ""))

(* The EXPENSE total of the given entries: a day's shown entries, so its count and
   total describe the same rows under a Locus filter or a search, or the whole
   window for the title. *)
let shown_total ~ctx entries =
  match ctx.scope.roles with
  | Error _ -> None
  | Ok roles ->
      let totals = Hashtbl.create 4 and partial = ref false in
      List.iter
        (fun (e : B.entry) ->
          List.iter
            (fun (posting : D.Effect.t) ->
              match List.assoc_opt (A.lstr (D.Effect.locus posting)) roles with
              | Some Roles.Expense ->
                  let measure = A.mstr (D.Effect.measure posting) in
                  let sum = Option.value ~default:Z.zero (Hashtbl.find_opt totals measure) in
                  Hashtbl.replace totals measure (Z.add sum (A.quanta posting))
              | Some (Roles.Income | Roles.Asset | Roles.Liability | Roles.Equity) -> ()
              | None -> partial := true)
            e.effects)
        entries;
      let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) (List.of_seq (Hashtbl.to_seq totals)) in
      totals_text ~book:ctx.book sorted !partial

(* Day groups follow the list order; under an amount order there is no day to
   group by, so no header is drawn. *)
let groups_of_entries ~ctx ~order records =
  match order with
  | Largest -> []
  | Newest | Oldest -> (
      let rec loop acc index = function
        | [] -> List.rev acc
        | (e : B.entry) :: rest ->
            let acc =
              match acc with
              | g :: gs when g.day = e.day -> { g with entries = e :: g.entries } :: gs
              | _ -> { day = e.day; entries = [ e ]; first = index; total = None } :: acc
            in
            loop acc (index + 1) rest
      in
      List.map
        (fun (g : group) ->
          let entries = List.rev g.entries in
          { g with entries; total = shown_total ~ctx entries })
        (loop [] 0 records))

(* The selection the workspace opens on: today's group, or the latest day before
   it inside the window. *)
let default_row ~today groups =
  let latest_before =
    List.fold_left
      (fun acc (g : group) ->
        match acc with
        | None -> if g.day < today then Some g else None
        | Some a -> if g.day < today && g.day > a.day then Some g else acc)
      None groups
  in
  match List.find_opt (fun (g : group) -> g.day = today) groups with
  | Some g -> g.first
  | None -> ( match latest_before with Some g -> g.first | None -> 0)

(* Resolve one scan into the Loci list, the active Locus, the filtered and sorted
   rows, the day groups and both row indices clamped. *)
let resolve ~ctx t =
  let entries = scan_window ~book:ctx.book ~window:ctx.scope.window in
  let loci = loci_of_records entries in
  let locus_row = min (max 0 t.locus_row) (List.length loci) in
  let locus = locus_at loci locus_row in
  let records = filtered_entries ~ctx t ~records:entries ~locus in
  let groups = groups_of_entries ~ctx ~order:t.order records in
  let tx_count = List.length records in
  let transaction_row =
    if tx_count = 0 then 0 else min (max 0 t.transaction_row) (tx_count - 1)
  in
  let transaction_row =
    if t.pending_selection then default_row ~today:ctx.scope.focus_day groups else transaction_row
  in
  (loci, locus, records, groups, { t with locus_row; transaction_row; pending_selection = false })

let visible_entries ~ctx t =
  let _, _, records, _, _ = resolve ~ctx t in
  records

let selected_entry ~ctx t =
  let _, _, records, _, _ = resolve ~ctx t in
  List.nth_opt records t.transaction_row

let selected_locus ~ctx t =
  let entries = scan_window ~book:ctx.book ~window:ctx.scope.window in
  if t.locus_row = 0 then None else locus_at (loci_of_records entries) t.locus_row

let clamp_state ~ctx t =
  let _, _, _, _, clamped = resolve ~ctx t in
  clamped

(* The default selection is applied once, when the workspace opens or the period
   window moves. *)
let apply_pending ~ctx t =
  if t.pending_selection then
    let _, _, _, _, t = resolve ~ctx t in
    t
  else t

(* After a publication the selection stays on the same Event, in the same
   window and the same order. *)
let returned_from_detail ~before_book ~after_book t =
  match t.remembered_scope with
  | None -> (t, "")
  | Some scope ->
      let ctx = { book = after_book; scope; warning = None } in
      let before = { book = before_book; scope; warning = None } in
      let locus = selected_locus ~ctx:before t in
      let loci = loci_of_records (List.filter (in_window ~window:scope.window) (B.entries before_book)) in
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
          pending_selection = false;
          notice =
            (if Option.is_some locus && locus_row = 0 then
               "Selected Locus is no longer in scope; showing all loci."
             else "");
        }
      in
      let target = Option.map (fun (e : B.entry) -> e.id) (selected_entry ~ctx:before t) in
      let records = visible_entries ~ctx base in
      let row =
        match target with
        | None -> None
        | Some id -> List.find_index (fun (e : B.entry) -> e.id = id) records
      in
      match row with
      | Some transaction_row -> { base with transaction_row }, base.notice
      | None ->
          let fresh = clamp_state ~ctx { base with detail_scroll = 0 } in
          let notice =
            "Selected Event no longer matches this list; selection moved to the nearest row."
          in
          ({ fresh with notice }, notice)

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

let weekday_name day =
  match Cal.weekday day with
  | Ok index -> [| "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat"; "Sun" |].(index mod 7)
  | Error _ -> ""

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
  (* Below 30 terminal rows the list keeps the height and Details opens on [i]. *)
  let tall = panel_height >= 16 && terminal >= 30 in
  {
    writable;
    left_width = min 50 (max 34 (writable * 30 / 100));
    panel_height;
    detail_height = (if tall then detail_capacity + 1 else 0);
    context_rows;
    wide = writable >= 98 && tall;
  }

let terminal_geometry dimensions = panel_geometry dimensions

let detail_bounds g pane =
  ( (if g.wide then g.left_width else g.writable),
    if g.detail_height > 0 then g.detail_height else if pane = Details then g.panel_height else 0 )

let list_height g pane =
  if g.wide && pane = Transactions then g.panel_height else max 0 (g.panel_height - g.detail_height)

let list_capacity pane height = max 0 (height - 2 - if pane = Loci || height < 4 then 0 else 1)

let detail_scroll_limit ~ctx ~width_of geometry t =
  let width, height = detail_bounds geometry t.pane in
  if width < 3 || height < 3 then 0
  else
    let lines =
      detail_raw_lines ~book:ctx.book ~width_of ~width:(width - 2) (selected_entry ~ctx t)
    in
    max 0 (List.length lines - (height - 2))

let page_size geometry pane =
  max 1
    (match pane with
    | Details -> snd (detail_bounds geometry pane) - 2
    | other -> list_capacity other (list_height geometry other))

(* 4. Navigation *)

let loci_in_scope ~ctx =
  let entries = scan_window ~book:ctx.book ~window:ctx.scope.window in
  loci_of_records entries

let move_previous ~ctx ~width_of:_ _geometry t =
  match t.pane with
  | Loci ->
      if t.locus_row = 0 then { t with notice = "No previous Locus row." }
      else
        clamp_state ~ctx
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

let move_next ~ctx ~width_of geometry t =
  match t.pane with
  | Loci ->
      let count = List.length (loci_in_scope ~ctx) in
      if t.locus_row < count then
        clamp_state ~ctx
          {
            t with
            locus_row = t.locus_row + 1;
            transaction_row = 0;
            detail_scroll = 0;
            notice = "";
          }
      else { t with notice = "No next Locus row." }
  | Transactions ->
      let count = List.length (visible_entries ~ctx t) in
      if t.transaction_row + 1 < count then
        { t with transaction_row = t.transaction_row + 1; detail_scroll = 0; notice = "" }
      else { t with notice = "No next Actual row." }
  | Details ->
      let detail_end = detail_scroll_limit ~ctx ~width_of geometry t in
      if t.detail_scroll >= detail_end then { t with notice = "End of Details." }
      else { t with detail_scroll = t.detail_scroll + 1; notice = "" }

let move_page_up ~ctx ~width_of:_ geometry t =
  let ps = page_size geometry t.pane in
  match t.pane with
  | Loci ->
      if t.locus_row = 0 then { t with notice = "Top of Locus list." }
      else
        clamp_state ~ctx
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

let move_page_down ~ctx ~width_of geometry t =
  let ps = page_size geometry t.pane in
  match t.pane with
  | Loci ->
      let count = List.length (loci_in_scope ~ctx) in
      if t.locus_row >= count then { t with notice = "End of Locus list." }
      else
        clamp_state ~ctx
          {
            t with
            locus_row = min count (t.locus_row + ps);
            transaction_row = 0;
            detail_scroll = 0;
            notice = "";
          }
  | Transactions ->
      let count = List.length (visible_entries ~ctx t) in
      if count = 0 || t.transaction_row + 1 >= count then { t with notice = "End of Actual list." }
      else
        {
          t with
          transaction_row = min (count - 1) (t.transaction_row + ps);
          detail_scroll = 0;
          notice = "";
        }
  | Details ->
      let detail_end = detail_scroll_limit ~ctx ~width_of geometry t in
      if t.detail_scroll >= detail_end then { t with notice = "End of Details." }
      else { t with detail_scroll = min detail_end (t.detail_scroll + ps); notice = "" }

let move_home ~ctx t =
  match t.pane with
  | Loci ->
      clamp_state ~ctx { t with locus_row = 0; transaction_row = 0; detail_scroll = 0; notice = "" }
  | Transactions -> { t with transaction_row = 0; detail_scroll = 0; notice = "" }
  | Details -> { t with detail_scroll = 0; notice = "" }

let move_end ~ctx ~width_of geometry t =
  match t.pane with
  | Loci ->
      let count = List.length (loci_in_scope ~ctx) in
      clamp_state ~ctx
        { t with locus_row = count; transaction_row = 0; detail_scroll = 0; notice = "" }
  | Transactions ->
      let count = List.length (visible_entries ~ctx t) in
      let row = if count = 0 then 0 else count - 1 in
      { t with transaction_row = row; detail_scroll = 0; notice = "" }
  | Details ->
      { t with detail_scroll = detail_scroll_limit ~ctx ~width_of geometry t; notice = "" }

(* The order cycles by date first; the amount order needs the accounting roles,
   so it is refused (not guessed) when the roles file is unreadable. *)
let cycle_order ~ctx t =
  let reset order =
    clamp_state ~ctx { t with order; transaction_row = 0; detail_scroll = 0; notice = "" }
  in
  match t.order with
  | Newest -> reset Oldest
  | Oldest -> (
      match ctx.scope.roles with
      | Error _ ->
          { t with notice = "Amount order needs accounting-roles.tsv; the order was not changed." }
      | Ok _ -> reset Largest)
  | Largest -> reset Newest

let begin_search ~ctx t =
  clamp_state ~ctx
    {
      t with
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

let edit_search ~ctx t edit =
  clamp_state ~ctx
    {
      t with
      search_query = edit t.search_query;
      transaction_row = 0;
      detail_scroll = 0;
      notice = "";
    }

let normalize_for_bounds ~ctx ~dimensions ~width_of t =
  let geometry = terminal_geometry dimensions in
  if t.detail_scroll = 0 then t
  else
    let maximum = detail_scroll_limit ~ctx ~width_of geometry t in
    { t with detail_scroll = min t.detail_scroll maximum }

(* 5. Event handling *)

(* Panes in screen order, wrapping: Loci, Actuals, Details. *)
let next_pane = function Loci -> Transactions | Transactions -> Details | Details -> Loci
let previous_pane = function Loci -> Details | Transactions -> Loci | Details -> Transactions

let handle ~ctx ~dimensions ~width_of t (input : Ui_input.input) =
  let geometry = terminal_geometry dimensions in
  let t = apply_pending ~ctx t in
  let t = normalize_for_bounds ~ctx ~dimensions ~width_of t in
  if t.search_editing then
    match input with
    | `Key (`Enter, _) -> ({ t with search_editing = false; notice = "" }, Stay)
    | `Key (`Escape, _) ->
        let cleared =
          clamp_state ~ctx
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
    | `Key (`Backspace, _) -> (edit_search ~ctx t backspace_utf8, Stay)
    | `Key (`ASCII c, _) when c >= ' ' && c <= '~' ->
        (edit_search ~ctx t (fun curr -> curr ^ String.make 1 c), Stay)
    | `Key (`Uchar u, _) -> (edit_search ~ctx t (fun curr -> curr ^ O.utf8 u), Stay)
    | _ -> (t, Stay)
  else
    let focus pane = ({ t with pane; notice = "" }, Stay) in
    match input with
    | `Key (`ASCII 'j', []) | `Key (`Arrow `Down, _) -> (move_next ~ctx ~width_of geometry t, Stay)
    | `Key (`ASCII 'k', []) | `Key (`Arrow `Up, _) -> (move_previous ~ctx ~width_of geometry t, Stay)
    | `Key (`Page `Down, _) -> (move_page_down ~ctx ~width_of geometry t, Stay)
    | `Key (`Page `Up, _) -> (move_page_up ~ctx ~width_of geometry t, Stay)
    | `Key (`Home, _) -> (move_home ~ctx t, Stay)
    | `Key (`End, _) -> (move_end ~ctx ~width_of geometry t, Stay)
    | `Key (`ASCII 'h', []) | `Key (`Arrow `Left, _) -> focus (previous_pane t.pane)
    | `Key (`ASCII 'l', []) | `Key (`Arrow `Right, _) -> focus (next_pane t.pane)
    | `Key (`Tab, mods) ->
        focus (if List.mem `Shift mods then previous_pane t.pane else next_pane t.pane)
    | `Key (`ASCII 'i', []) ->
        focus (match t.pane with Details -> Transactions | Loci | Transactions -> Details)
    | `Key (`ASCII 's', []) -> (cycle_order ~ctx t, Stay)
    | `Key (`ASCII '/', []) -> (begin_search ~ctx t, Stay)
    | `Key (`Enter, _) -> (
        match t.pane with
        | Transactions | Details -> (
            match selected_entry ~ctx t with
            | Some entry -> (t, Open_selected entry)
            | None -> ({ t with notice = "No current Actual is selected to open." }, Stay))
        | Loci -> ({ t with notice = "Move to the Actuals pane before opening a record." }, Stay))
    | `Key (`ASCII ('n' | 'N' | 'r' | 'R'), []) -> (t, Record_new)
    | `Key (`ASCII ('q' | 'Q'), _) | `Key (`Escape, _) ->
        if t.pane = Details then ({ t with pane = Transactions; notice = "" }, Stay) else (t, Back)
    | `Key (`ASCII 'l', [ `Ctrl ]) -> (t, Redraw)
    | _ -> (t, Stay)

(* 6. Screen Rendering (LOAM ActualWorkspace.view) *)

let current_locus_name ~book = function
  | None -> "All loci"
  | Some token -> display_locus ~book token

let frame ~width_of ~width ~height ~focused ~title ~bottom rows =
  Panel.frame_rows ~inset:0 ?bottom_label:bottom ~width_of ~width ~height ~focused ~title rows

(* The day's header: the date with its weekday, the number of entries and that
   day's EXPENSE total. The amount is never cut: a narrower list drops the count
   first and the total last. *)
let day_header ~width_of ~width (group : group) =
  let left = group.day ^ (match weekday_name group.day with "" -> "" | name -> " " ^ name) in
  let count =
    match List.length group.entries with 1 -> "1 entry" | n -> Printf.sprintf "%d entries" n
  in
  let head = left ^ "  " ^ count in
  match group.total with
  | None -> if width_of head <= width then head else left
  | Some total ->
      if width_of head + 2 + width_of total <= width then
        O.pad ~width_of (width - width_of total) head ^ total
      else if width_of left + 2 + width_of total <= width then
        O.pad ~width_of (width - width_of total) left ^ total
      else if width_of head <= width then head
      else left

(* Date and amount columns stay fixed while Description receives the rest. *)
let table_row ~width_of width amount_width date desc amount =
  O.pad ~width_of 10 date ^ "  "
  ^ O.pad ~width_of (max 0 (width - 10 - amount_width - 4)) desc
  ^ "  "
  ^ O.pad_left ~width_of amount_width
      (if width_of amount <= amount_width then amount else "see details")

(* Under a day group the date is in the header, so only the description and the
   amount are listed, indented under it. *)
let grouped_row ~width_of width amount_width desc amount =
  "  " ^ O.pad ~width_of (max 0 (width - amount_width - 4)) desc
  ^ "  "
  ^ O.pad_left ~width_of amount_width
      (if width_of amount <= amount_width then amount else "see details")

(* The list rows: a header per day (under a date order) and one row per entry.
   The selection marks entries only, so a day header is never chosen. *)
type display_row = { style : O.style; text : string; entry : int option }

let display_rows ~book ~width_of ~row_width ~amount_width ~show_days ~groups ~records ~loci ~pane =
  let rows = ref [] in
  let entry_rows = ref [] in
  let header_rows = ref [] in
  let row_count = ref 0 in
  let entry_count = ref 0 in
  let current_header = ref (-1) in
  let add_header style text =
    rows := { style; text; entry = None } :: !rows;
    incr row_count;
    current_header := !row_count - 1
  in
  let add_entry style text =
    rows := { style; text; entry = Some !entry_count } :: !rows;
    entry_rows := !row_count :: !entry_rows;
    header_rows := !current_header :: !header_rows;
    incr entry_count;
    incr row_count
  in
  let entry_text (e : B.entry) =
    let amount = amount_summary book e in
    let desc = description e in
    let amount_text = if width_of amount <= amount_width then amount else "see details" in
    if show_days then grouped_row ~width_of row_width amount_width desc amount_text
    else table_row ~width_of row_width amount_width e.day desc amount_text
  in
  if pane = Loci then begin
    add_entry O.Plain "[All loci]";
    List.iter
      (fun token ->
        add_entry O.Plain (O.pad ~width_of (max 0 row_width) (display_locus ~book token)))
      loci
  end
  else if show_days then
    List.iter
      (fun (group : group) ->
        add_header O.Heading (day_header ~width_of ~width:row_width group);
        List.iter (fun (e : B.entry) -> add_entry O.Plain (entry_text e)) group.entries)
      groups
  else List.iter (fun (e : B.entry) -> add_entry O.Plain (entry_text e)) records;
  (List.rev !rows, Array.of_list (List.rev !entry_rows), Array.of_list (List.rev !header_rows))

let list_panel ~book ~width_of t ~records ~groups ~loci pane (width, height) title =
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
  (* An amount order is not a day order, so no day header is drawn. *)
  let show_days = pane = Transactions && t.order <> Largest in
  let header =
    if pane = Loci || height < 4 then []
    else
      [
        ( O.Chrome,
          "   "
          ^
          if not tabular then "Description"
          else if show_days then grouped_row ~width_of row_width amount_width "Description" "Amount"
          else table_row ~width_of row_width amount_width "Date" "Description" "Amount" );
      ]
  in
  let rows = list_capacity pane height in
  let display, entry_rows, header_rows =
    display_rows ~book ~width_of ~row_width ~amount_width ~show_days ~groups ~records ~loci ~pane
  in
  let display_count = List.length display in
  let selected_display = if selected < Array.length entry_rows then entry_rows.(selected) else 0 in
  let max_start = max 0 (display_count - rows) in
  let start = max 0 (min max_start (selected_display + 1 - rows)) in
  (* The selected day's header stays in view when the whole day fits. *)
  let header_display = if selected < Array.length header_rows then header_rows.(selected) else -1 in
  let start =
    if header_display >= 0 && header_display < start && selected_display - header_display < rows then
      header_display
    else start
  in
  let visible = List.filteri (fun i _ -> i >= start && i < start + rows) display in
  let active = pane = t.pane in
  let content =
    List.init rows (fun row ->
        match List.nth_opt visible row with
        | Some display_row ->
            let chosen = match display_row.entry with Some index -> index = selected | None -> false in
            ( (if chosen && active then O.Active else display_row.style),
              (if chosen then if active then " > " else " * " else "   ") ^ display_row.text )
        | None ->
            (O.Plain, if row = 0 && pane = Transactions then " (no matching Actual records)" else ""))
  in
  let total = if pane = Loci then List.length loci + 1 else List.length records in
  let position = if total = 0 then "0/0" else Printf.sprintf "%d/%d" (selected + 1) total in
  let more = if start + rows < display_count then " ▼" else "" in
  frame ~width_of ~width ~height ~focused:active ~title
    ~bottom:(Some (position ^ more))
    (header @ content)

let detail_panel ~book ~width_of (width, height) t ~entry =
  let focused = t.pane = Details in
  let capacity = max 0 (height - 2) in
  let lines = detail_raw_lines ~book ~width_of ~width:(max 1 (width - 2)) entry in
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

(* The window's EXPENSE total per Measure, for the screen's title line. *)
let window_total ~ctx = shown_total ~ctx (scan_window ~book:ctx.book ~window:ctx.scope.window)

let screen ~ctx ~total ~draft_retained ~dimensions ~width_of t =
  let g = panel_geometry dimensions in
  let loci, locus, records, groups, t = resolve ~ctx t in
  let order_tag, order_text =
    match t.order with
    | Newest -> ("desc", "newest first")
    | Oldest -> ("asc", "oldest first")
    | Largest -> ("amount", "largest first")
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
      let warnings =
        List.filter_map
          (fun warning -> warning)
          [
            (match ctx.warning with Some why -> Some why | None -> None);
            ( match ctx.scope.roles with
            | Error why ->
                Some ("No day totals: " ^ why)
            | Ok _ -> None );
          ]
      in
      let text =
        match warnings with
        | [] -> current_locus_name ~book:ctx.book locus
        | warnings -> String.concat " " warnings
      in
      ( O.Chrome,
        O.clip_text ~width_of g.writable
          (" known through " ^ ctx.scope.today
          ^ if draft_retained then "   Draft retained" else ""
          ^ "  |  " ^ text) )
  in
  (* The workspace title names the window and its EXPENSE total. The amount is
     never cut: a narrower list drops the window first. *)
  let title =
    let parts =
      List.filter_map
        (fun part -> part)
        [
          Some " Actual";
          Some (ctx.scope.window.label);
          (match total with Some amount -> Some ("Expense " ^ amount) | None -> None);
        ]
    in
    let full = String.concat "  |  " parts in
    let text =
      if width_of full <= g.writable then full
      else
        let short = String.concat "  |  " (List.filter_map (fun p -> p) [ Some " Actual"; (match total with Some amount -> Some ("Expense " ^ amount) | None -> None) ]) in
        if width_of short <= g.writable then short else " Actual"
    in
    (O.Plain, O.clip_text ~width_of g.writable text)
  in
  let context =
    if g.context_rows = 1 && searching then [ context_line ]
    else List.filteri (fun i _ -> i < g.context_rows) [ title; context_line ]
  in
  let list pane width title =
    list_panel ~book:ctx.book ~width_of t ~records ~groups ~loci pane (width, list_height g pane)
      title
  in
  let detail () =
    detail_panel ~book:ctx.book ~width_of (detail_bounds g t.pane) t
      ~entry:(List.nth_opt records t.transaction_row)
  in
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
      "Matches update live in the current window and all Loci.";
    ]
  else if t.pane = Details then
    [
      "[j/k] scroll details  [h/l] pane  [Esc/i] return to Actuals";
      "[Enter] open selected  [d] date  [m] merchant  [n] new  [q] back";
    ]
  else
    let detailed =
      "[j/k] select  [h/l] pane  [Tab] cycle  [i] details  [f] period  [s] sort  [/] search  [ ] window"
    in
    if width_of detailed <= width then
      [ detailed; "[Enter] open selected  [d] date  [m] merchant  [n] new  [q] back  [{ }] year" ]
    else
      [
        "[j/k] sel [h/l] pane [i] info [f] period [s] sort [/] search [ ] window";
        "[Enter] open [d] date [m] merchant [n] new [q] back [{ }] year";
      ]

(* The search caret sits on the context row that paints the search line. *)
let cursor_position ~dimensions ~width_of t =
  let g = panel_geometry dimensions in
  match search_line ~width:g.writable ~width_of t with
  | O.Input caret, _ when g.context_rows >= 1 -> Some (caret, if g.context_rows = 1 then 0 else 1)
  | _ -> None

let detail_window ~ctx ~dimensions ~width_of t =
  let g = terminal_geometry dimensions in
  let last = detail_scroll_limit ~ctx ~width_of g t in
  {
    Panel.capacity = max 0 (snd (detail_bounds g t.pane) - 2);
    start = min last t.detail_scroll;
    last;
  }
