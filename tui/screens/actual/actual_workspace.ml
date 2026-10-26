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

type scope = {
  window : window;
  today : string;
  focus_day : string;
      (** The day the window was opened on: today, or the day of a chosen window. *)
  roles : roles;
  measure : string;
}
(** What the workspace reads besides the book: the resolved period window, the
    day, the accounting roles and the current Measure. *)

type context = {
  book : B.t;
  scope : scope;
  warning : string option;
      (** The window could not be resolved; the list still works and says so. *)
}
(** Everything the workspace reads that the Shell owns. *)

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
  focus_day : string option;  (** The day the workspace was opened on; None is today. *)
  pending_selection : bool;
      (** The next resolve selects the focus day's group (or the latest day before it). *)
  remembered_scope : scope option;
      (** The scope of the last render, kept so a drill return restores the
      selection in the same window and the same order. *)
  list_tops : int * int;
      (** The first shown row of the Loci and the Actuals lists: the view moves only
          when the selection would leave it. *)
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
    list_tops = (0, 0);
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
let set_period period t =
  { t with period; period_offset = 0; pending_selection = true; notice = ""; list_tops = (0, 0) }

let set_period_offset offset t =
  { t with period_offset = offset; pending_selection = true; notice = ""; list_tops = (0, 0) }

let set_focus_day day t =
  {
    t with
    focus_day = Some day;
    period_offset = 0;
    pending_selection = true;
    notice = "";
    list_tops = (0, 0);
  }

let set_window period ~focus_day t =
  {
    t with
    period;
    focus_day = Some focus_day;
    period_offset = 0;
    pending_selection = true;
    notice = "";
    list_tops = (0, 0);
  }

let period_name = function
  | Today -> "Day"
  | Cycle -> "Cycle"
  | Month -> "Month"
  | Year -> "Year"
  | All -> "All"

let set_scope scope t = { t with remembered_scope = Some scope }

(* 1. Data extraction and filtering *)

let in_window ~window (e : B.entry) = e.day >= window.start_day && e.day < window.end_exclusive

(* The entries inside the window, in book order. *)
let scan_window ~book ~window = List.filter (in_window ~window) (B.entries book)

(* First-occurrence Loci order from an already-scoped record list. *)
let loci_of_records records =
  let seen = Hashtbl.create 64 and loci = ref [] in
  List.iter
    (fun (e : B.entry) ->
      List.iter
        (fun p ->
          let locus = A.lstr (D.Effect.locus p) in
          if not (Hashtbl.mem seen locus) then begin
            Hashtbl.add seen locus ();
            loci := locus :: !loci
          end)
        e.effects)
    records;
  List.rev !loci

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
        Z.compare (entry_expense_amount ~roles ~measure b) (entry_expense_amount ~roles ~measure a)
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
   list and that day's EXPENSE total, formatted only when its header is shown. *)
type group = { day : string; entries : B.entry list; first : int; total : string option Lazy.t }

(* The EXPENSE total per Measure in the shared money format. A day with an
   effect without a role is partial: the total is marked, never completed. *)
let totals_text ~book totals partial =
  let parts =
    List.filter_map
      (fun (measure, amount) ->
        if Z.sign amount = 0 then None else Some (O.format_money book measure amount ^ " " ^ measure))
      totals
  in
  match parts with
  | [] -> if partial then Some "+?" else None
  | parts -> Some (String.concat " / " parts ^ if partial then "+?" else "")

(* The EXPENSE total of the given entries: a day's shown entries, so its count and
   total describe the same rows under a Locus filter or a search, or the whole
   window for the title. *)
type expense_roles = { role_book : B.t; table : (string, Roles.role) Hashtbl.t }

let expense_roles ~ctx =
  match ctx.scope.roles with
  | Error _ -> None
  | Ok roles ->
      let table = Hashtbl.create (List.length roles) in
      List.iter
        (fun (locus, role) -> if not (Hashtbl.mem table locus) then Hashtbl.add table locus role)
        roles;
      Some { role_book = ctx.book; table }

(* A ledger has few Measures, so the sums are an association list. *)
let expense_total roles entries =
  let totals = ref [] and partial = ref false in
  let add measure amount =
    let rec go = function
      | [] -> [ (measure, amount) ]
      | (m, sum) :: rest when String.equal m measure -> (m, Z.add sum amount) :: rest
      | pair :: rest -> pair :: go rest
    in
    totals := go !totals
  in
  List.iter
    (fun (e : B.entry) ->
      List.iter
        (fun (posting : D.Effect.t) ->
          match Hashtbl.find_opt roles.table (A.lstr (D.Effect.locus posting)) with
          | Some Roles.Expense -> add (A.mstr (D.Effect.measure posting)) (A.quanta posting)
          | Some (Roles.Income | Roles.Asset | Roles.Liability | Roles.Equity) -> ()
          | None -> partial := true)
        e.effects)
    entries;
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) !totals in
  totals_text ~book:roles.role_book sorted !partial

let shown_total ~ctx entries =
  Option.bind (expense_roles ~ctx) (fun roles -> expense_total roles entries)

(* Day groups follow the list order; under an amount order there is no day to
   group by, so no header is drawn. *)
let groups_of_entries ~ctx ~order records =
  match order with
  | Largest -> []
  | Newest | Oldest ->
      let rec loop acc index = function
        | [] -> List.rev acc
        | (e : B.entry) :: rest ->
            let acc =
              match acc with
              | g :: gs when g.day = e.day -> { g with entries = e :: g.entries } :: gs
              | _ -> { day = e.day; entries = [ e ]; first = index; total = lazy None } :: acc
            in
            loop acc (index + 1) rest
      in
      let roles = expense_roles ~ctx in
      List.map
        (fun (g : group) ->
          let entries = List.rev g.entries in
          {
            g with
            entries;
            total = lazy (Option.bind roles (fun roles -> expense_total roles entries));
          })
        (loop [] 0 records)

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

(* One scan of the window: the Loci list, the active Locus, the filtered and
   sorted rows and the day groups. It depends on the Locus row, the search and
   the order, never on the selection. *)
type listing = {
  loci : string list;
  locus_index : int;
  locus : string option;
  records : B.entry list;
  groups : group list;
  count : int;
}

let listing ~ctx t =
  let entries = scan_window ~book:ctx.book ~window:ctx.scope.window in
  let loci = loci_of_records entries in
  let locus_index = min (max 0 t.locus_row) (List.length loci) in
  let locus = locus_at loci locus_index in
  let records = filtered_entries ~ctx t ~records:entries ~locus in
  let groups = groups_of_entries ~ctx ~order:t.order records in
  { loci; locus_index; locus; records; groups; count = List.length records }

(* Both row indices clamped to a listing, and the pending default selection. *)
let clamp_to ~ctx l t =
  let transaction_row = if l.count = 0 then 0 else min (max 0 t.transaction_row) (l.count - 1) in
  let transaction_row =
    if t.pending_selection then default_row ~today:ctx.scope.focus_day l.groups
    else transaction_row
  in
  { t with locus_row = l.locus_index; transaction_row; pending_selection = false }

(* Within one key a selection move reuses the listing it was given. *)
let listing_once ~ctx =
  let last = ref None in
  fun t ->
    let key = (t.locus_row, t.search_query, t.order) in
    match !last with
    | Some (k, l) when k = key -> l
    | _ ->
        let l = listing ~ctx t in
        last := Some (key, l);
        l

let resolve ~ctx t =
  let l = listing ~ctx t in
  (l.loci, l.locus, l.records, l.groups, clamp_to ~ctx l t)

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

(* After a publication the selection stays on the same Event, in the same
   window and the same order. *)
let returned_from_detail ~before_book ~after_book t =
  match t.remembered_scope with
  | None -> (t, "")
  | Some scope -> (
      let ctx = { book = after_book; scope; warning = None } in
      let before = { book = before_book; scope; warning = None } in
      let locus = selected_locus ~ctx:before t in
      let loci =
        loci_of_records (List.filter (in_window ~window:scope.window) (B.entries before_book))
      in
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
      | Some transaction_row -> ({ base with transaction_row }, base.notice)
      | None ->
          let fresh = clamp_state ~ctx { base with detail_scroll = 0 } in
          let notice =
            "Selected Event no longer matches this list; selection moved to the nearest row."
          in
          ({ fresh with notice }, notice))

(* 2. Amount and Details formatting (LOAM ActualWorkspace) *)

let effect_amount book p =
  let measure = A.mstr (D.Effect.measure p) in
  O.format_money book measure (A.quanta p) ^ " " ^ measure

let amount_summary book entry = Record_lines.amount_summary ~format:(effect_amount book) entry

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

let move_next ~ctx ~lists ~width_of geometry t =
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
      let count = (lists t).count in
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

let move_page_down ~ctx ~lists ~width_of geometry t =
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
      let count = (lists t).count in
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

let move_end ~ctx ~lists ~width_of geometry t =
  match t.pane with
  | Loci ->
      let count = List.length (loci_in_scope ~ctx) in
      clamp_state ~ctx
        { t with locus_row = count; transaction_row = 0; detail_scroll = 0; notice = "" }
  | Transactions ->
      let count = (lists t).count in
      let row = if count = 0 then 0 else count - 1 in
      { t with transaction_row = row; detail_scroll = 0; notice = "" }
  | Details -> { t with detail_scroll = detail_scroll_limit ~ctx ~width_of geometry t; notice = "" }

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

let handle_key ~ctx ~lists ~dimensions ~width_of t (input : Ui_input.input) =
  let geometry = terminal_geometry dimensions in
  (* The default selection is applied once, when the workspace opens or the period
     window moves. *)
  let t = if t.pending_selection then clamp_to ~ctx (lists t) t else t in
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
    | `Key (`ASCII 'j', []) | `Key (`Arrow `Down, _) ->
        (move_next ~ctx ~lists ~width_of geometry t, Stay)
    | `Key (`ASCII 'k', []) | `Key (`Arrow `Up, _) -> (move_previous ~ctx ~width_of geometry t, Stay)
    | `Key (`Page `Down, _) -> (move_page_down ~ctx ~lists ~width_of geometry t, Stay)
    | `Key (`Page `Up, _) -> (move_page_up ~ctx ~width_of geometry t, Stay)
    | `Key (`Home, _) -> (move_home ~ctx t, Stay)
    | `Key (`End, _) -> (move_end ~ctx ~lists ~width_of geometry t, Stay)
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
  let left = group.day ^ match weekday_name group.day with "" -> "" | name -> " " ^ name in
  let count =
    match List.length group.entries with 1 -> "1 entry" | n -> Printf.sprintf "%d entries" n
  in
  let head = left ^ "  " ^ count in
  match Lazy.force group.total with
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
  "  "
  ^ O.pad ~width_of (max 0 (width - amount_width - 4)) desc
  ^ "  "
  ^ O.pad_left ~width_of amount_width
      (if width_of amount <= amount_width then amount else "see details")

(* The list rows: a header per day (under a date order) and one row per entry.
   The selection marks entries only, so a day header is never chosen. *)
type display_row = { style : O.style; text : string Lazy.t; entry : int option }

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
    add_entry O.Plain (lazy "[All loci]");
    List.iter
      (fun token ->
        add_entry O.Plain (lazy (O.pad ~width_of (max 0 row_width) (display_locus ~book token))))
      loci
  end
  else if show_days then
    List.iter
      (fun (group : group) ->
        add_header O.Heading (lazy (day_header ~width_of ~width:row_width group));
        List.iter (fun (e : B.entry) -> add_entry O.Plain (lazy (entry_text e))) group.entries)
      groups
  else List.iter (fun (e : B.entry) -> add_entry O.Plain (lazy (entry_text e))) records;
  (List.rev !rows, Array.of_list (List.rev !entry_rows), Array.of_list (List.rev !header_rows))

(* Where the selection sits among the list's rows (a day header precedes its
   entries under a date order): the selection's row, its day header's row (-1
   without one) and the number of rows. *)
let positions t ~records ~groups ~loci pane =
  match pane with
  | Loci -> (t.locus_row, -1, List.length loci + 1)
  | Transactions | Details ->
      if t.order = Largest then (t.transaction_row, -1, List.length records)
      else
        List.fold_left
          (fun (selected, header, count) (g : group) ->
            let size = List.length g.entries in
            if t.transaction_row >= g.first && t.transaction_row < g.first + size then
              (count + 1 + t.transaction_row - g.first, count, count + 1 + size)
            else (selected, header, count + 1 + size))
          (0, -1, 0) groups

let pane_top t = function Loci -> fst t.list_tops | Transactions | Details -> snd t.list_tops

(* The first shown row: the view keeps its place and moves only as far as the
   selection needs, then brings the selected day's header in when the whole day
   fits. *)
let visible_start ~rows ~top (selected, header, count) =
  let start =
    if selected < top then selected else if selected >= top + rows then selected - rows + 1 else top
  in
  let start = max 0 (min (max 0 (count - rows)) start) in
  if header >= 0 && header < start && selected - header < rows then header else start

let list_panel ~book ~width_of t ~records ~groups ~loci pane (width, height) title =
  let selected = if pane = Loci then t.locus_row else t.transaction_row in
  let row_width =
    width - 5
    (* two borders and the three-column selection marker *)
  in
  let tabular = row_width >= 40 in
  (* The widest amount, between 12 and 22 cells and within the row; the scan
     stops once no wider amount could change the column. *)
  let amount_width =
    let cap = min 22 (max 0 (row_width - 26)) in
    if pane = Loci then 0
    else if cap <= 12 then cap
    else
      let rec widest w = function
        | e :: rest when w < cap -> widest (max w (width_of (amount_summary book e))) rest
        | _ -> w
      in
      min cap (max 12 (widest 0 records))
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
  let header_display = if selected < Array.length header_rows then header_rows.(selected) else -1 in
  let start =
    visible_start ~rows ~top:(pane_top t pane) (selected_display, header_display, display_count)
  in
  let visible = List.filteri (fun i _ -> i >= start && i < start + rows) display in
  let active = pane = t.pane in
  let content =
    List.init rows (fun row ->
        match List.nth_opt visible row with
        | Some display_row ->
            let chosen =
              match display_row.entry with Some index -> index = selected | None -> false
            in
            ( (if chosen && active then O.Active else display_row.style),
              (if chosen then if active then " > " else " * " else "   ")
              ^ Lazy.force display_row.text )
        | None ->
            (O.Plain, if row = 0 && pane = Transactions then " (no matching Actual records)" else ""))
  in
  let total = if pane = Loci then List.length loci + 1 else List.length records in
  let position = if total = 0 then "0/0" else Printf.sprintf "%d/%d" (selected + 1) total in
  let more = if start + rows < display_count then " ▼" else "" in
  frame ~width_of ~width ~height ~focused:active ~title
    ~bottom:(Some (position ^ more))
    (header @ content)

(* A key that changes the lists leaves both where they are shown, so the next
   key moves the view only as far as the selection needs. A key that changes
   nothing (opening a day, say) keeps the state as it was. *)
let handle ~ctx ~dimensions ~width_of t input =
  let lists = listing_once ~ctx in
  let next, command = handle_key ~ctx ~lists ~dimensions ~width_of t input in
  if { next with notice = t.notice } = t then (next, command)
  else
    let g = terminal_geometry dimensions in
    let l = lists next in
    let resolved = clamp_to ~ctx l next in
    let top pane =
      visible_start
        ~rows:(list_capacity pane (list_height g pane))
        ~top:(pane_top next pane)
        (positions resolved ~records:l.records ~groups:l.groups ~loci:l.loci pane)
    in
    ({ next with list_tops = (top Loci, top Transactions) }, command)

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

(* The period bar: every period with the current one bracketed, the window and
   its EXPENSE total. The amount is never cut: a narrower bar drops the other
   periods first, then the window. *)
let period_bar ~width_of ~width ~total t (window : window) =
  let tab period =
    if period = t.period then (O.Heading, "[" ^ period_name period ^ "]")
    else (O.Chrome, period_name period)
  in
  let tabs =
    List.concat
      (List.mapi
         (fun i period -> (if i = 0 then [] else [ (O.Plain, " ") ]) @ [ tab period ])
         [ Today; Cycle; Month; Year; All ])
  in
  let part spans = (O.Plain, "  ") :: spans in
  let window_part label = if t.period = All then [] else part [ (O.Plain, label) ] in
  (* A cycle within one year names its last day without the year. *)
  let short =
    match (t.period, Cal.shift_days window.end_exclusive (-1)) with
    | Cycle, Ok last when String.sub last 0 5 = String.sub window.start_day 0 5 ->
        window.start_day ^ ".." ^ String.sub last 5 5
    | _ -> window.label
  in
  let total_part =
    match total with Some amount -> part [ (O.Plain, "Expense " ^ amount) ] | None -> []
  in
  let head = (O.Plain, " Actual") in
  let fits spans = width_of (Ui_render.spans_text spans) <= width in
  let spans =
    List.find_opt fits
      [
        (head :: part tabs) @ window_part window.label @ total_part;
        (head :: part tabs) @ window_part short @ total_part;
        (head :: part [ tab t.period ]) @ window_part window.label @ total_part;
        (head :: part [ tab t.period ]) @ window_part short @ total_part;
        (head :: part [ tab t.period ]) @ total_part;
        head :: total_part;
      ]
    |> Option.value ~default:(Ui_render.clip_spans ~width_of width [ head ])
  in
  (O.Spans spans, Ui_render.spans_text spans)

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
            (match ctx.scope.roles with
            | Error why -> Some ("No day totals: " ^ why)
            | Ok _ -> None);
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
          ^ (if draft_retained then "   Draft retained" else "")
          ^ "  |  " ^ text) )
  in
  let title = period_bar ~width_of ~width:g.writable ~total t ctx.scope.window in
  let context =
    if g.context_rows = 1 && searching then [ context_line ]
    else List.filteri (fun i _ -> i < g.context_rows) [ title; context_line ]
  in
  let list pane width title =
    list_panel ~book:ctx.book ~width_of t ~records ~groups ~loci pane
      (width, list_height g pane)
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
      "[j/k] select  [h/l] pane  [Tab] cycle  [i] details  [f] period  [s] sort  [/] search  [ ] \
       window"
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
