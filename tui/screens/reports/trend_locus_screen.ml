(* Trend / Locus comparison: a read-only full-chart owner of recorded EFFECT
   flow over one explicit Measure.

   The owner never writes a file, never reads the clock and never keeps a stale
   chart: every projection uses the current book and the current configuration,
   and a failure clears the chart instead of painting an old one. The selection
   is an immutable period; the effective point index is derived from the
   current projection, never cached in mutable state. *)
module B = Bakhlo_sexp.Daily_book
module R = Trend_locus_report
module O = Daily_overlays
module Chart = Trend_locus_chart
module Panel = Ui_panel

let tr = Ui_text.tr
let boundary_file = "boundary-presets.tsv"
let config_files = [ boundary_file ]

let max_series = 5
let max_overlays = 3
let max_name_chars = 32
let max_days_chars = 96
let viewport = 31
let compact_height = 14

type overlay = { month : string; name : string; days : int list }
(** A session-only annotation: the month it marks, its name and its days. *)

type month = { length : int; key : string }
(** The calendar month of the selected point. *)

type editor = {
  month : month;
  name : string;
  day_text : string;
  field : [ `Name | `Days ];
  notice : string;
}
(** The inline annotation editor; nothing it holds is ever saved. *)

type picker = { target : int; cursor : int; notice : string }
(** The inline series picker: the chosen slot and the candidate cursor. *)

type t = {
  focus_day : string option;  (** The observation day captured from the Shell. *)
  grain : R.grain;
  scope : R.scope;
  coordinates : R.coordinate list;  (** The user's choice; empty means the default. *)
  selected_period : (string * string) option;
      (** The selected period, kept across a grain or query change. *)
  picker : picker option;
  editor : editor option;
  overlays : overlay list;  (** Session-only annotations; never persisted. *)
  guides : bool;
  notice : string;
}

let create () =
  {
    focus_day = None;
    grain = R.Cycle;
    scope = R.All_history;
    coordinates = [];
    selected_period = None;
    picker = None;
    editor = None;
    overlays = [];
    guides = false;
    notice = "";
  }

let enter ~focus_day t = { t with focus_day = Some focus_day; picker = None; editor = None }
let modal t = Option.is_some t.editor
let saved _env _geometry _result t = (t, Screen.Stay)

(* Queries *)

let same_coordinate (left : R.coordinate) (right : R.coordinate) =
  left.R.locus = right.R.locus && left.R.measure = right.R.measure

let effective_coordinates (env : Screen.env) t =
  match t.coordinates with
  | [] -> R.initial_series ~book:env.book ~measure:env.measure
  | coordinates -> coordinates

(* The plotted Measure: an explicit choice keeps its own Measure, so the
   catalog and the formatted amounts never mix Measures. *)
let current_measure (env : Screen.env) t =
  match effective_coordinates env t with
  | coordinate :: _ -> coordinate.R.measure
  | [] -> env.measure

(* Other grains always project the whole recorded history; the chooser keeps
   the user's Day scope so returning to Day restores it. *)
let effective_scope t = if t.grain = R.Day then t.scope else R.All_history

let project (env : Screen.env) t =
  match t.focus_day with
  | None -> Error "No observation day: the Shell has not focused a day for this chart."
  | Some observed_at ->
      Result.bind (env.config boundary_file) (fun boundary_presets_text ->
          R.project ~book:env.book ~observed_at ~boundary_presets_text ~grain:t.grain
            ~scope:(effective_scope t) ~coordinates:(effective_coordinates env t))

let points_of (snap : R.snapshot) =
  if Array.length snap.R.series = 0 then [||] else snap.R.series.(0).R.points

(* The point whose window covers a day. *)
let find_covering points day =
  let rec loop index =
    if index >= Array.length points then None
    else
      let point = points.(index) in
      if point.R.start_day <= day && day < point.R.end_exclusive then Some index
      else loop (index + 1)
  in
  loop 0

(* A point that contains the whole selected period. *)
let find_containing points start_day end_exclusive =
  let rec loop index =
    if index >= Array.length points then None
    else
      let point = points.(index) in
      if point.R.start_day <= start_day && end_exclusive <= point.R.end_exclusive then Some index
      else loop (index + 1)
  in
  loop 0

let effective_index t (snap : R.snapshot) =
  let points = points_of snap in
  let count = Array.length points in
  if count = 0 then 0
  else
    match t.selected_period with
    | None -> count - 1
    | Some (start_day, end_exclusive) -> (
        (* The selected start names the point; a finer or coarser grain keeps
           the start when it can. *)
        match find_covering points start_day with
        | Some index -> index
        | None -> (
            match find_containing points start_day end_exclusive with
            | Some index -> index
            | None -> count - 1))

let period_at (snap : R.snapshot) index =
  let points = points_of snap in
  if index < 0 || index >= Array.length points then None
  else Some (points.(index).R.start_day, points.(index).R.end_exclusive)

let result (env : Screen.env) t = project env t

(* A grain or scope key names the period the user was looking at before the
   change, even when they had not scrubbed yet. *)
let remember_period (env : Screen.env) t =
  match t.selected_period with
  | Some _ -> t
  | None -> (
      match project env t with
      | Ok snap -> { t with selected_period = period_at snap (effective_index t snap) }
      | Error _ -> t)

(* The changed projection selects the point covering the remembered start; the
   remembered period becomes that point's own window, so the next change anchors
   on it. A failure leaves the owner unchanged. *)
let relocate (env : Screen.env) t =
  match project env t with
  | Error _ -> t
  | Ok snap -> { t with selected_period = period_at snap (effective_index t snap) }

(* Accessors for checks *)

let selected (env : Screen.env) t =
  match project env t with Ok snap -> effective_index t snap | Error _ -> 0
let grain t = t.grain
let scope t = effective_scope t
let coordinates (env : Screen.env) t = effective_coordinates env t
let selected_period t = t.selected_period
let overlay_count t = List.length t.overlays
let overlays t =
  List.map (fun (overlay : overlay) -> (overlay.month, overlay.name, overlay.days)) t.overlays
let guides t = t.guides
let notice t = t.notice
let picker_open t = Option.is_some t.picker
let picker_target t = match t.picker with Some picker -> Some picker.target | None -> None
let picker_cursor t = match t.picker with Some picker -> Some picker.cursor | None -> None
let editor_open t = Option.is_some t.editor
let editor_name t = match t.editor with Some editor -> editor.name | None -> ""
let editor_days t = match t.editor with Some editor -> editor.day_text | None -> ""
let editor_field t = match t.editor with Some editor -> editor.field | None -> `Name

(* Dates *)

let int_of_part date offset length =
  if String.length date < offset + length then None
  else match int_of_string_opt (String.sub date offset length) with
    | Some value -> Some value
    | None -> None

let year_of date = int_of_part date 0 4
let month_of date = int_of_part date 5 2
let day_of date = int_of_part date 8 2
let month_key date = if String.length date >= 7 then Some (String.sub date 0 7) else None

let month_length year month =
  match month with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 -> Some 31
  | 4 | 6 | 9 | 11 -> Some 30
  | 2 ->
      Some
        (if (year mod 4 = 0 && year mod 100 <> 0) || year mod 400 = 0 then 29 else 28)
  | _ -> None

let utf8_length text =
  let count = ref 0 in
  String.iter (fun c -> if Char.code c land 0xc0 <> 0x80 then incr count) text;
  !count

let drop_last text =
  if text = "" then text
  else
    let rec start n = if n > 0 && Char.code text.[n] land 0xc0 = 0x80 then start (n - 1) else n in
    String.sub text 0 (start (String.length text - 1))

(* Grain and scope *)

let coarser = function R.Day -> R.Month | R.Month -> R.Cycle | R.Cycle -> R.Cycle
let finer = function R.Cycle -> R.Month | R.Month -> R.Day | R.Day -> R.Day

let next_scope = function
  | R.All_history -> R.Current_cycle
  | R.Current_cycle -> R.Current_month
  | R.Current_month -> R.Last_30_days
  | R.Last_30_days -> R.All_history

let previous_scope = function
  | R.All_history -> R.Last_30_days
  | R.Last_30_days -> R.Current_month
  | R.Current_month -> R.Current_cycle
  | R.Current_cycle -> R.All_history

(* Series picker *)

let catalog (env : Screen.env) t = R.catalog ~book:env.book ~measure:(current_measure env t)

let replace_at coordinates index candidate =
  let rec loop i acc = function
    | [] -> List.rev (candidate :: acc)
    | head :: rest ->
        if i = index then List.rev_append acc (candidate :: rest)
        else loop (i + 1) (head :: acc) rest
  in
  loop 0 [] coordinates

let open_picker (env : Screen.env) t =
  let coordinates = effective_coordinates env t in
  let candidates = catalog env t in
  let target = if List.length coordinates >= max_series then 0 else List.length coordinates in
  let cursor =
    match List.nth_opt coordinates target with
    | Some coordinate -> (
        let rec find index = function
          | [] -> 0
          | candidate :: rest ->
              if same_coordinate candidate coordinate then index else find (index + 1) rest
        in
        find 0 candidates)
    | None -> 0
  in
  { t with picker = Some { target; cursor; notice = "" } }

let move_cursor (candidates : R.coordinate list) (picker : picker) delta =
  let count = List.length candidates in
  if count = 0 then picker
  else
    let cursor =
      let next = picker.cursor + delta in
      if next < 0 then count - 1 else if next >= count then 0 else next
    in
    { picker with cursor }

let apply_pick (env : Screen.env) t (picker : picker) =
  let candidates = catalog env t in
  let coordinates = effective_coordinates env t in
  match List.nth_opt candidates picker.cursor with
  | None -> (t, Screen.Stay)
  | Some candidate ->
      let used = List.find_index (fun c -> same_coordinate c candidate) coordinates in
      (match used with
      | Some index when index <> picker.target ->
          (* A coordinate is plotted once; a duplicate never replaces a slot. *)
          ( { t with picker = Some { picker with notice = "That coordinate is already plotted." } },
            Screen.Stay )
      | _ ->
          let next = replace_at coordinates picker.target candidate in
          ({ t with coordinates = next; picker = None }, Screen.Stay))

let remove_pick (env : Screen.env) t (picker : picker) =
  let coordinates = effective_coordinates env t in
  if List.length coordinates <= 1 then
    ({ t with picker = Some { picker with notice = "Keep at least one plotted series." } },
     Screen.Stay)
  else
    (* Removing the next empty slot removes the last occupied one. *)
    let index =
      if picker.target < List.length coordinates then picker.target else List.length coordinates - 1
    in
    let next = List.filteri (fun i _ -> i <> index) coordinates in
    ({ t with coordinates = next; picker = None }, Screen.Stay)

(* Day annotations *)

let split_day_tokens text =
  let buffer = Buffer.create 16 in
  let tokens = ref [] in
  String.iter
    (fun c ->
      if c = ' ' || c = ',' || c = '.' then (
        if Buffer.length buffer > 0 then (
          tokens := Buffer.contents buffer :: !tokens;
          Buffer.clear buffer))
      else Buffer.add_char buffer c)
    text;
  if Buffer.length buffer > 0 then tokens := Buffer.contents buffer :: !tokens;
  List.rev !tokens

let selected_month (env : Screen.env) t =
  match project env t with
  | Error _ -> None
  | Ok snap ->
      let points = points_of snap in
      if Array.length points = 0 then None
      else
        let date = points.(effective_index t snap).R.start_day in
        (match year_of date, month_of date with
        | Some year, Some month -> (
            match month_length year month with
            | Some length ->
                Some { length; key = Option.value ~default:"" (month_key date) }
            | None -> None)
        | _ -> None)

let parse_days text length =
  let tokens = split_day_tokens text in
  let rec loop seen acc = function
    | [] -> Ok (List.rev acc)
    | token :: rest ->
        if not (String.for_all (fun c -> c >= '0' && c <= '9') token) then
          Error "Days accept numbers separated by space, comma or dot."
        else
          match int_of_string_opt token with
          | None -> Error "That day number is not a day of the month."
          | Some day ->
              if day < 1 || day > length then
                Error (Printf.sprintf "Day %d does not exist in that month." day)
              else if List.mem day seen then loop seen acc rest
              else loop (day :: seen) (day :: acc) rest
  in
  loop [] [] tokens

let insert_text editor text =
  match editor.field with
  | `Name ->
      let candidate = editor.name ^ text in
      if utf8_length candidate > max_name_chars then editor else { editor with name = candidate }
  | `Days ->
      let candidate = editor.day_text ^ text in
      if String.length candidate > max_days_chars then editor
      else { editor with day_text = candidate }

let backspace_text editor =
  match editor.field with
  | `Name -> { editor with name = drop_last editor.name }
  | `Days -> { editor with day_text = drop_last editor.day_text }

let open_editor (env : Screen.env) t =
  if t.grain <> R.Day then
    { t with notice = "Day annotations are available in the Day grain only." }
  else if List.length t.overlays >= max_overlays then
    { t with notice = "Three session annotations are already drawn." }
  else
    match selected_month env t with
    | None -> { t with notice = "No selected day: the chart is unavailable." }
    | Some month ->
        { t with editor = Some { month; name = ""; day_text = ""; field = `Name; notice = "" } }

let apply_editor t (editor : editor) =
  let name = String.trim editor.name in
  if name = "" then
    ({ t with editor = Some { editor with notice = "Name the annotation." } }, Screen.Stay)
  else if utf8_length name > max_name_chars then
    ({ t with editor = Some { editor with notice = "A name holds at most 32 characters." } },
     Screen.Stay)
  else
    match parse_days editor.day_text editor.month.length with
    | Error why -> ({ t with editor = Some { editor with notice = why } }, Screen.Stay)
    | Ok [] ->
        ({ t with editor = Some { editor with notice = "Mark at least one day." } }, Screen.Stay)
    | Ok days ->
        ( { t with overlays = t.overlays @ [ { month = editor.month.key; name; days } ]; editor = None },
          Screen.Stay )

(* Input *)

let scrub t (snap : R.snapshot) delta =
  let points = points_of snap in
  let count = Array.length points in
  if count = 0 then t
  else
    let index = max 0 (min (count - 1) (effective_index t snap + delta)) in
    { t with selected_period = period_at snap index }

let jump t (snap : R.snapshot) last =
  let points = points_of snap in
  let count = Array.length points in
  if count = 0 then t
  else
    let index = if last then count - 1 else 0 in
    { t with selected_period = period_at snap index }

let handle_chart (env : Screen.env) t input =
  let outcome = project env t in
  let stay t = (t, Screen.Stay) in
  match input with
  | `Key (`ASCII ('q' | 'Q'), []) | `Key (`Escape, []) -> (t, Screen.Home)
  | `Key (`ASCII '[', []) ->
      stay (relocate env { (remember_period env t) with grain = coarser t.grain })
  | `Key (`ASCII ']', []) ->
      stay (relocate env { (remember_period env t) with grain = finer t.grain })
  | `Key (`ASCII 's', []) ->
      if t.grain = R.Day then
        stay (relocate env { (remember_period env t) with scope = next_scope t.scope })
      else stay t
  | `Key (`ASCII 'S', []) ->
      if t.grain = R.Day then
        stay (relocate env { (remember_period env t) with scope = previous_scope t.scope })
      else stay t
  | `Key ((`ASCII 'h' | `Arrow `Left), []) -> (
      match outcome with Ok snap -> stay (scrub t snap (-1)) | Error _ -> stay t)
  | `Key ((`ASCII 'l' | `Arrow `Right), []) -> (
      match outcome with Ok snap -> stay (scrub t snap 1) | Error _ -> stay t)
  | `Key ((`ASCII 'k' | `Arrow `Up), []) -> (
      match outcome with Ok snap -> stay (scrub t snap (-1)) | Error _ -> stay t)
  | `Key ((`ASCII 'j' | `Arrow `Down), []) -> (
      match outcome with Ok snap -> stay (scrub t snap 1) | Error _ -> stay t)
  | `Key (`Home, []) -> (
      match outcome with Ok snap -> stay (jump t snap false) | Error _ -> stay t)
  | `Key (`End, []) -> (
      match outcome with Ok snap -> stay (jump t snap true) | Error _ -> stay t)
  | `Key (`Enter, []) -> stay t
  | `Key (`ASCII ('a' | 'A'), []) -> stay (open_picker env t)
  | `Key (`ASCII 'o', []) -> stay (open_editor env t)
  | `Key (`ASCII 'O', []) ->
      stay
        {
          t with
          overlays = [];
          guides = false;
          notice = "Session annotations and guides cleared.";
        }
  | `Key (`ASCII ('v' | 'V'), []) ->
      if t.overlays = [] then stay t else stay { t with guides = not t.guides }
  | _ -> (t, Screen.Ignored)

let handle_picker (env : Screen.env) t (picker : picker) input =
  let stay t = (t, Screen.Stay) in
  let candidates = catalog env t in
  let coordinates = effective_coordinates env t in
  match input with
  | `Key (`ASCII ('q' | 'Q'), []) | `Key (`Escape, []) -> stay { t with picker = None }
  | `Key (`ASCII ('1' .. '5' as c), []) ->
      let slot = Char.code c - Char.code '1' in
      let occupied = slot < List.length coordinates in
      let next_empty = List.length coordinates in
      if occupied || slot = next_empty then
        stay { t with picker = Some { picker with target = slot; notice = "" } }
      else
        stay
          {
            t with
            picker =
              Some { picker with notice = "Choose an occupied slot or the next empty slot." };
          }
  | `Key ((`ASCII 'h' | `Arrow `Left), []) ->
      stay { t with picker = Some (move_cursor candidates picker (-1)) }
  | `Key ((`ASCII 'l' | `Arrow `Right), []) ->
      stay { t with picker = Some (move_cursor candidates picker 1) }
  | `Key ((`ASCII 'k' | `Arrow `Up), []) ->
      stay { t with picker = Some (move_cursor candidates picker (-1)) }
  | `Key ((`ASCII 'j' | `Arrow `Down), []) ->
      stay { t with picker = Some (move_cursor candidates picker 1) }
  | `Key (`Enter, []) -> apply_pick env t picker
  | `Key (`ASCII ('x' | 'X'), []) -> remove_pick env t picker
  | _ -> (t, Screen.Ignored)

let handle_editor t (editor : editor) input =
  let stay t = (t, Screen.Stay) in
  match input with
  | `Key (`Escape, []) -> stay { t with editor = None }
  | `Key (`Tab, []) | `Key (`Tab, [ `Shift ]) ->
      let field = if editor.field = `Name then `Days else `Name in
      stay { t with editor = Some { editor with field } }
  | `Key (`Backspace, []) -> stay { t with editor = Some (backspace_text editor) }
  | `Key (`Enter, []) -> (
      match editor.field with
      | `Name ->
          let name = String.trim editor.name in
          if name = "" then
            stay { t with editor = Some { editor with notice = "Name the annotation." } }
          else if utf8_length name > max_name_chars then
            stay
              { t with editor = Some { editor with notice = "A name holds at most 32 characters." } }
          else stay { t with editor = Some { editor with field = `Days; notice = "" } }
      | `Days -> apply_editor t editor)
  | `Key (`ASCII c, []) when c >= ' ' && c <> '\127' ->
      stay { t with editor = Some (insert_text editor (String.make 1 c)) }
  | `Key (`Uchar c, []) when O.printable_uchar c ->
      stay { t with editor = Some (insert_text editor (O.utf8 c)) }
  | _ -> (t, Screen.Ignored)

let handle (env : Screen.env) (_geometry : Screen.geometry) t input =
  match t.editor with
  | Some editor -> handle_editor t editor input
  | None -> (
      match t.picker with
      | Some picker -> handle_picker env t picker input
      | None -> handle_chart env t input)

(* Painting *)

let marker_of index = Chart.markers.(index mod Array.length Chart.markers)

let rack_text (env : Screen.env) (snap : R.snapshot) =
  Array.to_list snap.R.series
  |> List.mapi (fun index series ->
         marker_of index ^ " " ^ series.R.label ^ " (" ^ series.R.coordinate.R.locus ^ ")")
  |> String.concat "  "

let period_line ~width_of ~width t (snap : R.snapshot) index =
  let points = points_of snap in
  if Array.length points = 0 || index < 0 || index >= Array.length points then
    "No selected period."
  else
    let point = points.(index) in
    let range = point.R.start_day ^ ".." ^ point.R.end_exclusive in
    let window = if point.R.complete then "full window" else "partial window" in
    let full =
      range ^ " • " ^ window
      ^ (if width >= 64 then Printf.sprintf " • %d calendar days" point.R.observed_days else "")
    in
    let short = range ^ " • " ^ (if point.R.complete then "full" else "partial") in
    if t.grain = R.Day then point.R.start_day ^ " • day"
    else if width_of full <= width then full
    else if width_of short <= width then short
    else
      let cue = "(widen for full dates)" in
      if width_of cue <= width then cue else O.clip_text ~width_of width cue

let value_items (env : Screen.env) (snap : R.snapshot) index =
  Array.to_list snap.R.series
  |> List.mapi (fun i series ->
         let prefix = marker_of i ^ " " ^ series.R.label in
         let points = series.R.points in
         if index < 0 || index >= Array.length points then (prefix, "(unavailable)")
         else (prefix, B.format env.book snap.R.measure points.(index).R.value))

let compact_value_items (env : Screen.env) (snap : R.snapshot) index =
  Array.to_list snap.R.series
  |> List.mapi (fun i series ->
         let prefix = marker_of i in
         let points = series.R.points in
         if index < 0 || index >= Array.length points then (prefix, "(unavailable)")
         else (prefix, B.format env.book snap.R.measure points.(index).R.value))

let fit_item ~width_of width (prefix, amount) =
  let full = prefix ^ " " ^ amount in
  if width_of full <= width then full
  else if width_of (prefix ^ " (widen)") <= width then prefix ^ " (widen)"
  else if width_of "(widen)" <= width then "(widen)"
  else ""

let pack_items ~width_of width items =
  let rec pack current acc = function
    | [] -> List.rev (if current = "" then acc else current :: acc)
    | (prefix, amount) :: rest ->
        let item = fit_item ~width_of width (prefix, amount) in
        let candidate = if current = "" then item else current ^ "  " ^ item in
        if width_of candidate <= width then pack candidate acc rest
        else if current = "" then pack "" (item :: acc) rest
        else pack "" (current :: acc) ((prefix, amount) :: rest)
  in
  pack "" [] items

let overlay_legend t =
  match t.overlays with
  | [] -> ""
  | overlays ->
      "session-only (not saved, not causal): "
      ^ (overlays
        |> List.map (fun (overlay : overlay) ->
               overlay.month ^ " " ^ overlay.name ^ " "
               ^ String.concat "," (List.map string_of_int overlay.days))
        |> String.concat "  ")

let window_of t count index =
  if t.grain = R.Day && t.scope = R.All_history && count > viewport then
    let start = max 0 (min (count - viewport) (index - viewport / 2)) in
    (start, start + viewport)
  else (0, count)

let chart_series (snap : R.snapshot) start visible =
  Array.to_list snap.R.series
  |> List.mapi (fun index series ->
         let points = series.R.points in
         let values =
           Array.init visible (fun k -> points.(start + k).R.value)
         in
         { Chart.marker = marker_of index; values })
  |> Array.of_list

(* Session annotations mark exact calendar dates: the captured full YYYY-MM
   and the day, never every October or the month of the current selection. *)
let annotation_indices t (snap : R.snapshot) start visible =
  if t.grain <> R.Day then []
  else
    let points = points_of snap in
    if Array.length points = 0 then []
    else
      List.mapi
        (fun slot (overlay : overlay) ->
          let at =
            List.filter_map
              (fun k ->
                let index = start + k in
                if index < 0 || index >= Array.length points then None
                else
                  let date = points.(index).R.start_day in
                  match month_key date, day_of date with
                  | Some key, Some day ->
                      if key = overlay.month && List.mem day overlay.days then Some k else None
                  | _ -> None)
              (List.init visible (fun i -> i))
          in
          { Chart.glyph = string_of_int (slot + 1); at })
        t.overlays

let bounded_rows (geometry : Screen.geometry) rows =
  let width, height = geometry.content in
  let width = max 0 width and height = max 0 height in
  let rows = List.filteri (fun i _ -> i < height) rows in
  let rows =
    List.map
      (fun (style, text) -> (style, O.clip_text ~width_of:geometry.width_of width text))
      rows
  in
  rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (O.Plain, ""))

let chart_panel (env : Screen.env) (geometry : Screen.geometry) t (snap : R.snapshot) header =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let points = points_of snap in
  let count = Array.length points in
  let index = effective_index t snap in
  let start, stop = window_of t count index in
  let visible = max 0 (stop - start) in
  let annotations = annotation_indices t snap start visible in
  let marked = List.concat_map (fun annotation -> annotation.Chart.at) annotations in
  let chart =
    {
      Chart.series = chart_series snap start visible;
      count = visible;
      selected = index - start;
      guides = if t.guides then marked else [];
      annotations;
    }
  in
  if height < 3 then bounded_rows geometry header
  else
    let header = List.filteri (fun i _ -> i < height - 3) header in
    let chart_height = max 3 (height - List.length header) in
    let painted =
      Chart.render ~width:(max 0 (width - 2)) ~height:(max 1 (chart_height - 2)) ~width_of
        ~label:(fun z -> B.format env.book snap.R.measure z) chart
    in
    let header =
      if painted.Chart.axis_exact then header
      else
        (O.Plain, "widen for exact axis values")
        :: List.filteri (fun i _ -> i < height - 4) header
    in
    let chart_height = max 3 (height - List.length header) in
    let bottom =
      if visible = 0 then "no points"
      else
        let first = points.(start).R.start_day and last = points.(stop - 1).R.start_day in
        Printf.sprintf "%s → %s (%d/%d)" first last visible count
    in
    let panel =
      Panel.frame_rows ~inset:0 ~bottom_label:bottom ~width_of ~width ~height:chart_height
        ~focused:true ~title:"Trend / Locus comparison"
        (List.map (fun text -> (O.Plain, text)) painted.Chart.rows)
    in
    header @ panel

let chart_rows (env : Screen.env) (geometry : Screen.geometry) t (snap : R.snapshot) =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let compact = height <= compact_height in
  let index = effective_index t snap in
  let grain = R.grain_label t.grain in
  let scope = R.scope_label (effective_scope t) in
  let unit =
    if t.grain = R.Day then "Day recorded flow, exact /day"
    else grain ^ " floor average of recorded flow, /day"
  in
  let context =
    if compact then
      Printf.sprintf "Measure %s • flow %s • /day • %s" snap.R.measure grain scope
    else
      Printf.sprintf "recorded flow • Measure %s • %s • %s • source: %s • observed %s"
        snap.R.measure grain scope snap.R.source snap.R.observed_at
  in
  let header = ref [] in
  if t.notice <> "" then header := !header @ [ (O.Plain, O.clip_text ~width_of width t.notice) ];
  header := !header @ [ (O.Chrome, O.clip_text ~width_of width context) ];
  if not compact then (
    header := !header @ [ (O.Plain, O.clip_text ~width_of width unit) ];
    header :=
      !header
      @ [
          ( O.Plain,
            O.clip_text ~width_of width
              "full/partial = calendar window only, not household coverage or a balance." );
        ];
    header := !header @ [ (O.Plain, O.clip_text ~width_of width (rack_text env snap)) ]);
  header :=
    !header
    @ [ (O.Plain, O.clip_text ~width_of width (period_line ~width_of ~width t snap index)) ];
  let legend = overlay_legend t in
  if legend <> "" then
    header := !header @ [ (O.Plain, O.clip_text ~width_of width legend) ];
  let items = if compact then compact_value_items env snap index else value_items env snap index in
  header := !header @ List.map (fun text -> (O.Plain, text)) (pack_items ~width_of width items);
  chart_panel env geometry t snap !header

let unavailable_rows (geometry : Screen.geometry) why =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let lines =
    [
      tr "Trend / Locus unavailable:";
      why;
      "Supply an explicit boundary-presets.tsv preset that contains the focused day.";
    ]
  in
  let wrapped =
    List.concat_map (O.wrap_text ~width_of (max 1 (width - 4))) lines
    |> List.map (fun text -> (O.Plain, text))
  in
  Panel.frame_rows ~inset:0 ~width_of ~width ~height ~focused:true
    ~title:"Trend / Locus [unavailable]" wrapped

let rack_line (env : Screen.env) coordinates =
  coordinates
  |> List.mapi (fun slot coordinate ->
         Printf.sprintf "%d %s %s" (slot + 1) (marker_of slot)
           (B.label env.book coordinate.R.locus))
  |> String.concat "  "

let picker_rows (env : Screen.env) (geometry : Screen.geometry) t (picker : picker) =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let inner = max 1 (width - 2) in
  let coordinates = effective_coordinates env t in
  let candidates = catalog env t in
  let count = List.length candidates in
  let capacity = max 0 (height - 2) in
  let notice =
    if picker.notice = "" then []
    else
      O.wrap_text ~width_of inner picker.notice
      |> List.filteri (fun i _ -> i < 2)
      |> List.map (fun text -> (O.Status, text))
  in
  let rack =
    if height > compact_height then
      List.init max_series (fun slot ->
          let text =
            match List.nth_opt coordinates slot with
            | Some coordinate ->
                Printf.sprintf "%d %s %s (%s)" (slot + 1) (marker_of slot)
                  (B.label env.book coordinate.R.locus)
                  coordinate.R.locus
            | None -> Printf.sprintf "%d (empty)" (slot + 1)
          in
          let marker = if slot = picker.target then "→ " else "  " in
          (O.Plain, marker ^ text))
    else if capacity - List.length notice > 1 then
      [ (O.Plain, rack_line env coordinates) ]
    else []
  in
  let rows = max 1 (capacity - List.length notice - List.length rack) in
  let window =
    Panel.window ~capacity:rows ~count ~scroll:0 ~selected:(Some picker.cursor)
  in
  let stop = min count (window.start + window.capacity) in
  let painted =
    List.init (max 0 (stop - window.start)) (fun i ->
        let index = window.start + i in
        let candidate = List.nth candidates index in
        let used = List.find_index (fun c -> same_coordinate c candidate) coordinates in
        let text =
          Printf.sprintf "%s %s (%s)%s" (if index = picker.cursor then ">" else " ")
            (B.label env.book candidate.R.locus)
            candidate.R.locus
            (match used with
            | Some slot -> Printf.sprintf " [slot %d]" (slot + 1)
            | None -> "")
        in
        ((if index = picker.cursor then O.Active else O.Plain), text))
  in
  let target =
    if picker.target < List.length coordinates then "slot " ^ string_of_int (picker.target + 1)
    else "new slot"
  in
  let title =
    Printf.sprintf "Series %s • Measure %s" target (current_measure env t)
  in
  let rows = notice @ rack @ painted in
  Panel.frame_rows ~inset:0 ~width_of ~width ~height ~focused:true ~title rows

let editor_form (editor : editor) =
  let month = editor.month.key in
  let title = if month = "" then "Annotation" else "Annotation " ^ month in
  let summary =
    (if month = "" then [] else [ "Month " ^ month ^ " (full YYYY-MM)" ])
    @ [ "Session only — not saved, not causal."; "Days: recorded dates in that month only." ]
  in
  let fields =
    [
      Ui_form.text_field ~id:"name" ~label:"Name" ~value:editor.name ();
      Ui_form.text_field ~id:"days" ~label:"Days" ~value:editor.day_text ();
    ]
  in
  let form =
    Ui_form.create ~id:"trend_locus_annotation" ~title ~summary ~fields
      ~notice:editor.notice ()
  in
  Ui_form.set_focused form (if editor.field = `Name then 0 else 1)

let footer ~width_of ~width t =
  let line text = O.clip_text ~width_of width text in
  match t.editor with
  | Some _ -> [ line "Enter next/apply  Esc cancel"; line "Tab field  session only" ]
  | None -> (
      match t.picker with
      | Some _ -> [ line "q/Esc close  Enter apply"; line "arrows move  x remove" ]
      | None ->
          if width >= 72 then
            [
              line "arrows/hjkl select  Home/End  [ ] grain  s/S scope  a series  o annotate";
              line "v guides  O clear  Enter refresh  q/Esc Home  Space Commands";
            ]
          else if width >= 48 then
            [
              line "arrows/hjkl select  [ ] grain  s/S scope";
              line "a series  o annotate  v guides  q/Esc Home";
            ]
          else [ line "q/Esc Home  hjkl select"; line "[ ] grain  s/S scope  a series" ])

let view (env : Screen.env) (geometry : Screen.geometry) t : Screen.view =
  let outcome = project env t in
  let overlay =
    Option.bind t.editor (fun editor ->
        Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
          (editor_form editor))
  in
  {
    Screen.title = tr "Trend / Locus comparison";
    subtitle = Default;
    rows =
      lazy
        (bounded_rows geometry
           (match t.picker with
           | Some picker -> picker_rows env geometry t picker
           | None -> (
               match outcome with
               | Ok snap -> chart_rows env geometry t snap
               | Error why -> unavailable_rows geometry why)));
    footer = footer ~width_of:geometry.width_of ~width:(fst geometry.content) t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
