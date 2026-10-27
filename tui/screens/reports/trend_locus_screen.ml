(* Trend / Locus comparison: a read-only full-chart owner of recorded EFFECT
   flow over one explicit Measure, painted like LOAM's full-screen Trend
   (Loam.Tui.LocusTrendComparePane).

   The owner never writes a file, never reads the clock and never keeps a stale
   chart: a projection is reused only while its book is the same value and its
   configuration text, roles, Measure and query are equal, so a changed book or
   file is projected again and a failure clears the chart instead of painting an
   old one. The selection is an immutable period; the effective point index is
   derived from the current projection. *)
module B = Bakhlo_household.Daily_book
module R = Trend_locus_report
module O = Daily_overlays

let markers = [| "●"; "◆"; "▲"; "■"; "□" |]

module UChart = Ui_chart
module Cal = Daily_calendar
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

type projection = {
  book : B.t;  (** Compared physically: every book change is a new value. *)
  boundary : (string option, string) result;
  roles : ((string * Locus_roles.role) list, string) result;
  measure : string;
  query : string option * R.grain * R.scope * R.coordinate list;
  plotted : R.coordinate list;  (** The effective series. *)
  outcome : (R.snapshot, string) result;
}
(** One projection and everything it was computed from. *)

type t = {
  focus_day : string option;  (** The observation day captured from the Shell. *)
  grain : R.grain;
  scope : R.scope;
  coordinates : R.coordinate list;  (** The user's choice; empty means the default. *)
  selected_period : (string * string) option;
      (** The selected period, kept across a grain or query change. *)
  viewport_start : int;
      (** First point of the sliding Day window; it moves only when the selection
          leaves it, as in LOAM. *)
  projection : projection option;
  picker : picker option;
  editor : editor option;
  overlays : overlay list;  (** Session-only annotations; never persisted. *)
  guides : bool;
  help : Ui_form.t option;  (** The [?] help overlay. *)
  notice : string;
}

let create () =
  {
    focus_day = None;
    grain = R.Cycle;
    scope = R.All_history;
    coordinates = [];
    selected_period = None;
    viewport_start = 0;
    projection = None;
    picker = None;
    editor = None;
    overlays = [];
    guides = false;
    help = None;
    notice = "";
  }

let enter ~focus_day t =
  { t with focus_day = Some focus_day; picker = None; editor = None; help = None }

let modal t = Option.is_some t.editor || Option.is_some t.help
let saved _env _geometry _result t = (t, Screen.Stay)

(* Queries *)

let same_coordinate (left : R.coordinate) (right : R.coordinate) =
  left.R.locus = right.R.locus && left.R.measure = right.R.measure

(* Other grains always project the whole recorded history; the chooser keeps
   the user's Day scope so returning to Day restores it. *)
let effective_scope t = if t.grain = R.Day then t.scope else R.All_history

(* The default series is derived from the shown history every time: the Expense
   role is the only authority, never a guessed name or sign. *)
let default_coordinates (env : Screen.env) t ~boundary ~roles =
  match t.focus_day with
  | None -> []
  | Some observed_at -> (
      match
        Result.bind boundary (fun text -> R.history_start ~observed_at ~boundary_presets_text:text)
      with
      | Error _ -> []
      | Ok start_day -> (
          match Cal.shift_days observed_at 1 with
          | Error _ -> []
          | Ok end_exclusive ->
              R.initial_series ~book:env.book ~measure:env.measure
                ~roles:(Result.value ~default:[] roles) ~start_day ~end_exclusive))

let compute (env : Screen.env) t =
  let boundary = env.config boundary_file in
  let roles = Lazy.force env.accounting_roles in
  let query = (t.focus_day, t.grain, effective_scope t, t.coordinates) in
  match t.projection with
  | Some p
    when p.book == env.book && p.boundary = boundary && p.roles = roles && p.measure = env.measure
         && p.query = query ->
      p
  | _ ->
      let plotted =
        match t.coordinates with
        | _ :: _ as coordinates -> coordinates
        | [] -> default_coordinates env t ~boundary ~roles
      in
      let outcome =
        match t.focus_day with
        | None -> Error "No observation day: the Shell has not focused a day for this chart."
        | Some observed_at -> (
            (* The default series needs the roles; an unreadable file is a refusal
               that names it, never a silent empty chart. *)
            match (t.coordinates, roles) with
            | [], Error why -> Error ("Accounting roles unavailable (accounting-roles.tsv): " ^ why)
            | _ ->
                Result.bind boundary (fun boundary_presets_text ->
                    R.project ~book:env.book ~observed_at ~boundary_presets_text ~grain:t.grain
                      ~scope:(effective_scope t) ~coordinates:plotted))
      in
      { book = env.book; boundary; roles; measure = env.measure; query; plotted; outcome }

let with_projection env t = { t with projection = Some (compute env t) }
let project env t = (compute env t).outcome
let effective_coordinates env t = (compute env t).plotted

(* The plotted Measure: an explicit choice keeps its own Measure, so the
   catalog and the formatted amounts never mix Measures. *)
let current_measure (env : Screen.env) t =
  match effective_coordinates env t with
  | coordinate :: _ -> coordinate.R.measure
  | [] -> env.measure

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
  let t = with_projection env t in
  match project env t with
  | Error _ -> t
  | Ok snap -> { t with selected_period = period_at snap (effective_index t snap) }

(* Only Day over all history slides a window over its points (LOAM
   [usesSlidingDayViewport]); the window moves just enough to keep the
   selection, so moving inside it never shifts the chart. *)
let sliding t = t.grain = R.Day && t.scope = R.All_history

let viewport_start_for t ~count ~selected =
  if (not (sliding t)) || count = 0 then 0
  else
    let size = min viewport count in
    let last_start = count - size in
    let start = max 0 (min t.viewport_start last_start) in
    if selected < start then selected
    else if start + size <= selected then min last_start (selected + 1 - size)
    else start

let window_of t count selected =
  let start = viewport_start_for t ~count ~selected in
  (start, if sliding t then min count (start + viewport) else count)

(* After every key the owner keeps the projection it painted and the window
   that contains the selection. *)
let settle env t =
  let t = with_projection env t in
  match project env t with
  | Ok snap ->
      let count = Array.length (points_of snap) in
      { t with viewport_start = viewport_start_for t ~count ~selected:(effective_index t snap) }
  | Error _ -> t

(* Accessors for checks *)

let selected (env : Screen.env) t =
  match project env t with Ok snap -> effective_index t snap | Error _ -> 0

let visible_window (env : Screen.env) t =
  match project env t with
  | Ok snap -> window_of t (Array.length (points_of snap)) (effective_index t snap)
  | Error _ -> (0, 0)

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
  else
    match int_of_string_opt (String.sub date offset length) with
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
  | 2 -> Some (if (year mod 4 = 0 && year mod 100 <> 0) || year mod 400 = 0 then 29 else 28)
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
    | Some coordinate ->
        let rec find index = function
          | [] -> 0
          | candidate :: rest ->
              if same_coordinate candidate coordinate then index else find (index + 1) rest
        in
        find 0 candidates
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
  | Some candidate -> (
      let used = List.find_index (fun c -> same_coordinate c candidate) coordinates in
      match used with
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
    ( { t with picker = Some { picker with notice = "Keep at least one plotted series." } },
      Screen.Stay )
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
  | Ok snap -> (
      let points = points_of snap in
      if Array.length points = 0 then None
      else
        let date = points.(effective_index t snap).R.start_day in
        match (year_of date, month_of date) with
        | Some year, Some month -> (
            match month_length year month with
            | Some length -> Some { length; key = Option.value ~default:"" (month_key date) }
            | None -> None)
        | _ -> None)

let parse_days text length =
  let tokens = split_day_tokens text in
  let rec loop seen acc = function
    | [] -> Ok (List.rev acc)
    | token :: rest -> (
        if not (String.for_all (fun c -> c >= '0' && c <= '9') token) then
          Error "Days accept numbers separated by space, comma or dot."
        else
          match int_of_string_opt token with
          | None -> Error "That day number is not a day of the month."
          | Some day ->
              if day < 1 || day > length then
                Error (Printf.sprintf "Day %d does not exist in that month." day)
              else if List.mem day seen then loop seen acc rest
              else loop (day :: seen) (day :: acc) rest)
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
    ( { t with editor = Some { editor with notice = "A name holds at most 32 characters." } },
      Screen.Stay )
  else
    match parse_days editor.day_text editor.month.length with
    | Error why -> ({ t with editor = Some { editor with notice = why } }, Screen.Stay)
    | Ok [] ->
        ({ t with editor = Some { editor with notice = "Mark at least one day." } }, Screen.Stay)
    | Ok days ->
        ( {
            t with
            overlays = t.overlays @ [ { month = editor.month.key; name; days } ];
            editor = None;
          },
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

let help_form () =
  let lines =
    [
      "Reading the chart";
      "  Values are exact recorded Effect flows of one Measure; nothing is";
      "  inferred from a Locus name, a sign or a balance.";
      "  Non-Day grains show the floor average per day of each window.";
      "  full/partial describes the calendar window only, not household";
      "  coverage, and zero is an exact empty recorded sum, not a balance.";
      "";
      "History and series";
      "  History starts at the first boundary of the explicit preset that";
      "  contains the focused day; missing or ambiguous config is unavailable.";
      "  The default series are the three Expense-role Loci with the most";
      "  recorded entries here (ties: larger movement, then token).";
      "  `a` edits the series for this session; nothing is written.";
      "";
      "Keys";
      "  arrows/hjkl select  Home/End  [ ] grain  s/S scope  a series  o annotate";
      "  v guides  O clear  Enter refresh  ? help  q/Esc Home";
    ]
  in
  Ui_form.create ~id:"trend_help" ~title:(tr "Trend / Locus Help") ~summary:lines
    ~fields:
      [
        Ui_form.buttons_field ~id:"action"
          ~buttons:[ { Ui_form.label = "Close"; is_cancel = true } ]
          ();
      ]
    ()

(* A grain change keeps the Day window only while it still slides (LOAM
   [changeGranularity]). *)
let regrain t grain =
  let next = { t with grain } in
  { next with viewport_start = (if sliding next then t.viewport_start else 0) }

let handle_chart (env : Screen.env) t input =
  let outcome = project env t in
  let stay t = (t, Screen.Stay) in
  match input with
  | `Key (`ASCII ('q' | 'Q'), []) | `Key (`Escape, []) -> (t, Screen.Home)
  | `Key (`ASCII '[', []) -> stay (relocate env (regrain (remember_period env t) (coarser t.grain)))
  | `Key (`ASCII ']', []) -> stay (relocate env (regrain (remember_period env t) (finer t.grain)))
  | `Key (`ASCII 's', []) ->
      if t.grain = R.Day then
        stay
          (relocate env
             { (remember_period env t) with scope = next_scope t.scope; viewport_start = 0 })
      else stay t
  | `Key (`ASCII 'S', []) ->
      if t.grain = R.Day then
        stay
          (relocate env
             { (remember_period env t) with scope = previous_scope t.scope; viewport_start = 0 })
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
  | `Key (`Enter, []) -> stay { t with projection = None }
  | `Key (`ASCII ('a' | 'A'), []) -> stay (open_picker env t)
  | `Key (`ASCII 'o', []) -> stay (open_editor env t)
  | `Key (`ASCII 'O', []) ->
      stay
        { t with overlays = []; guides = false; notice = "Session annotations and guides cleared." }
  | `Key (`ASCII '?', []) -> stay { t with help = Some (help_form ()) }
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
            picker = Some { picker with notice = "Choose an occupied slot or the next empty slot." };
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
              {
                t with
                editor = Some { editor with notice = "A name holds at most 32 characters." };
              }
          else stay { t with editor = Some { editor with field = `Days; notice = "" } }
      | `Days -> apply_editor t editor)
  | `Key (`ASCII c, []) when c >= ' ' && c <> '\127' ->
      stay { t with editor = Some (insert_text editor (String.make 1 c)) }
  | `Key (`Uchar c, []) when O.printable_uchar c ->
      stay { t with editor = Some (insert_text editor (O.utf8 c)) }
  | _ -> (t, Screen.Ignored)

let handle_owner (env : Screen.env) t input =
  match t.editor with
  | Some editor -> handle_editor t editor input
  | None -> (
      match t.help with
      | Some form -> (
          match input with
          | `Key (`ASCII '?', []) -> ({ t with help = None }, Screen.Stay)
          | _ -> (
              match Ui_form.handle_input form input with
              | Ui_form.Cancel -> ({ t with help = None }, Screen.Stay)
              | Ui_form.Updated form | Ui_form.Submit form ->
                  ({ t with help = Some form }, Screen.Stay)))
      | None -> (
          match t.picker with
          | Some picker -> handle_picker env t picker input
          | None -> handle_chart env t input))

let handle (env : Screen.env) (_geometry : Screen.geometry) t input =
  let t, request = handle_owner env t input in
  (settle env t, request)

(* Painting: LOAM's full-screen Trend layout (Loam.Tui.LocusTrendComparePane):
   heading, series rack, source and Selected lines, one row per series, the
   chart with its value axis, the period axis and the session overlays. *)

let marker_of index = markers.(index mod Array.length markers)
let separator = "   ·   "

let month_name = function
  | "01" -> "Jan"
  | "02" -> "Feb"
  | "03" -> "Mar"
  | "04" -> "Apr"
  | "05" -> "May"
  | "06" -> "Jun"
  | "07" -> "Jul"
  | "08" -> "Aug"
  | "09" -> "Sep"
  | "10" -> "Oct"
  | "11" -> "Nov"
  | "12" -> "Dec"
  | other -> other

let short_date date =
  match String.split_on_char '-' date with
  | [ _; month; day ] -> (
      month_name month ^ " "
      ^ match int_of_string_opt day with Some day -> string_of_int day | None -> day)
  | _ -> date

let long_date date =
  match String.split_on_char '-' date with
  | [ year; _; _ ] -> short_date date ^ ", " ^ year
  | _ -> date

let month_label key =
  match String.split_on_char '-' key with
  | [ year; month ] -> month_name month ^ " " ^ year
  | _ -> key

(* The point still running on the observation day. *)
let current_partial (snap : R.snapshot) (point : R.point) =
  (not point.R.complete) && snap.R.observed_at < point.R.end_exclusive

let period_status snap point =
  if point.R.complete then "complete"
  else if current_partial snap point then "current partial"
  else "partial coverage"

let heading = function
  | R.Cycle -> "Trend   cycle average / day"
  | R.Month -> "Trend   month average / day"
  | R.Day -> "Trend   daily amount"

let selected_point (snap : R.snapshot) index =
  let points = points_of snap in
  if index >= 0 && index < Array.length points then Some points.(index) else None

let selected_line (snap : R.snapshot) (point : R.point) =
  match snap.R.grain with
  | R.Day ->
      "Selected   " ^ long_date point.R.start_day
      ^ if current_partial snap point then separator ^ "current day" else ""
  | R.Cycle | R.Month ->
      let last = if current_partial snap point then snap.R.observed_at else point.R.end_exclusive in
      "Selected   " ^ short_date point.R.start_day ^ " → " ^ short_date last ^ separator
      ^ period_status snap point

let source_line t (snap : R.snapshot) visible =
  match snap.R.grain with
  | R.Day ->
      let last =
        Result.value ~default:snap.R.scope_end_exclusive
          (Cal.shift_days snap.R.scope_end_exclusive (-1))
      in
      snap.R.source ^ separator ^ "Range " ^ R.scope_label snap.R.scope ^ "   "
      ^ short_date snap.R.scope_start ^ " → " ^ short_date last ^ separator ^ "Grain Day"
      ^ separator ^ snap.R.measure ^ separator ^ "braille"
      ^ if sliding t then separator ^ string_of_int visible ^ "-day viewport" else ""
  | grain ->
      snap.R.source ^ separator ^ "Grain " ^ R.grain_label grain ^ separator ^ snap.R.measure
      ^ separator ^ "braille"

(* Two rack rows of five slots; a series slot carries its series' colour. *)
let rack_rows ~width_of (snap : R.snapshot) =
  let slot index =
    if index < Array.length snap.R.series then
      ( O.Series index,
        Printf.sprintf "[%d %s %s] " (index + 1) (marker_of index)
          (O.clip_text ~width_of 14 snap.R.series.(index).R.label) )
    else (O.Chrome, Printf.sprintf "[%d + Add] " (index + 1))
  in
  [
    (O.Chrome, "Series  ") :: List.init 3 slot;
    (O.Chrome, "        ") :: List.init 2 (fun i -> slot (i + 3));
  ]

(* One series value at the selected period, in the shared money format; a
   missing point is unavailable, never zero. *)
let amount_text (env : Screen.env) (snap : R.snapshot) (series : R.series) index =
  if index < 0 || index >= Array.length series.R.points then "(unavailable)"
  else
    O.format_money env.book snap.R.measure series.R.points.(index).R.value
    ^ " " ^ snap.R.measure
    ^ if snap.R.grain = R.Day then "" else "/day"

(* A series row never clips its amount into partial digits: the name gives way
   first, then the amount is deferred to a wider terminal. *)
let value_rows ~width_of ~width (env : Screen.env) (snap : R.snapshot) index =
  Array.to_list snap.R.series
  |> List.mapi (fun i (series : R.series) ->
      let head = marker_of i ^ " " and amount = amount_text env snap series index in
      let reserved = width_of (head ^ "  " ^ amount) in
      if reserved > width then [ (O.Series i, head ^ "exact value: enlarge terminal") ]
      else
        [
          (O.Series i, head ^ O.clip_text ~width_of (width - reserved) series.R.label ^ "  ");
          (O.Plain, amount);
        ])

let compact_value_row ~width_of ~width (env : Screen.env) (snap : R.snapshot) index i more =
  let series = snap.R.series.(i) in
  let head = Printf.sprintf "%d %s " (i + 1) (marker_of i) in
  let amount = amount_text env snap series index in
  let more = if more = 0 then "" else Printf.sprintf " (+%d)" more in
  let reserved = width_of (head ^ amount ^ more ^ " ") in
  let text =
    if reserved > width then head ^ "exact value: enlarge terminal" ^ more
    else
      head ^ O.clip_text ~width_of (min 14 (width - reserved)) series.R.label ^ " " ^ amount ^ more
  in
  [ (O.Series i, text) ]

(* Tokens fill a row and wrap at the width, as LOAM's [flowTokens]. *)
let flow_tokens ~width_of width tokens =
  let rec loop line acc = function
    | [] -> List.rev (if line = "" then acc else line :: acc)
    | token :: rest ->
        if line = "" then loop token acc rest
        else if width_of (line ^ "   " ^ token) <= width then loop (line ^ "   " ^ token) acc rest
        else loop token (line :: acc) rest
  in
  loop "" [] tokens

let overlay_marker index = match index with 0 -> "A" | 1 -> "B" | _ -> "C"

let overlay_contains (overlay : overlay) date =
  match (month_key date, day_of date) with
  | Some key, Some day -> key = overlay.month && List.mem day overlay.days
  | _ -> false

(* Session overlays mark exact calendar dates of the shown Day points: one
   marker row under the axis (A/B/C, [*] where they meet) and a legend. *)
let overlay_rows ~width_of ~width ~plot_left ~plot_width t (snap : R.snapshot) start visible =
  if t.grain <> R.Day || t.overlays = [] then []
  else
    let points = points_of snap in
    let cells = Array.make plot_width " " in
    for k = 0 to visible - 1 do
      let date = points.(start + k).R.start_day in
      let matching =
        List.concat
          (List.mapi
             (fun index overlay -> if overlay_contains overlay date then [ index ] else [])
             t.overlays)
      in
      let glyph =
        match matching with [] -> None | [ index ] -> Some (overlay_marker index) | _ -> Some "*"
      in
      Option.iter
        (fun glyph ->
          let x = UChart.x_for_index plot_width visible k in
          cells.(x) <- (if cells.(x) = " " then glyph else "*"))
        glyph
    done;
    let legend =
      ("Overlay session-only · guides " ^ (if t.guides then "on" else "off") ^ " · not saved")
      :: List.mapi
           (fun index (overlay : overlay) ->
             overlay_marker index ^ " " ^ overlay.name ^ " (" ^ month_label overlay.month ^ ": "
             ^ String.concat " " (List.map string_of_int overlay.days)
             ^ ")")
           t.overlays
    in
    (O.Plain, String.make plot_left ' ' ^ String.concat "" (Array.to_list cells))
    :: List.map (fun text -> (O.Chrome, text)) (flow_tokens ~width_of width legend)

let guide_columns ~plot_width t (snap : R.snapshot) start visible =
  if t.grain <> R.Day || not t.guides then []
  else
    let points = points_of snap in
    List.init visible Fun.id
    |> List.filter_map (fun k ->
        if
          List.exists
            (fun overlay -> overlay_contains overlay points.(start + k).R.start_day)
            t.overlays
        then Some (UChart.x_for_index plot_width visible k)
        else None)

let bounded_rows (geometry : Screen.geometry) rows =
  let width, height = geometry.content in
  let width = max 0 width and height = max 0 height in
  let rows = List.filteri (fun i _ -> i < height) rows in
  let rows =
    List.map
      (fun (style, text) ->
        match style with
        | O.Spans spans ->
            let spans = O.clip_spans ~width_of:geometry.width_of width spans in
            (O.Spans spans, O.spans_text spans)
        | _ -> (style, O.clip_text ~width_of:geometry.width_of width text))
      rows
  in
  rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (O.Plain, ""))

let series_values (snap : R.snapshot) start visible =
  Array.to_list snap.R.series
  |> List.map (fun series -> List.init visible (fun k -> series.R.points.(start + k).R.value))

(* A label of [text] centred on [center] and kept inside the plot. *)
let placed ~width center text =
  let text = if String.length text > width then String.sub text 0 width else text in
  let half = String.length text / 2 in
  (max 0 (min (center - min center half) (width - String.length text)), text)

(* The labels in priority order. Unlike LOAM, which overwrites part of a later
   label ("Sep 29t 1"), a label that would touch an earlier one is left out. *)
let overlaid ~width labels =
  let cells = Bytes.make width ' ' and taken = Array.make width false in
  let clear start stop =
    let rec loop i = i >= min width (stop + 1) || ((not taken.(i)) && loop (i + 1)) in
    loop (max 0 (start - 1))
  in
  List.iter
    (fun (start, text) ->
      let stop = start + String.length text in
      if clear start stop then (
        Bytes.blit_string text 0 cells start (String.length text);
        Array.fill taken start (String.length text) true))
    labels;
  Bytes.to_string cells

let centered width text =
  let text = if String.length text > width then String.sub text 0 width else text in
  let left = (width - String.length text) / 2 in
  String.make left ' ' ^ text ^ String.make (width - String.length text - left) ' '

(* The period axis under the plot: Day names its first day, the selected day
   and the observation day ("As of"); Cycle and Month name every window, or only
   the ends when a window is narrower than eight cells. Dates are ASCII. *)
let axis_row ~plot_left ~plot_width (snap : R.snapshot) start visible selected =
  let points = points_of snap in
  if visible = 0 then ""
  else
    let first = points.(start) and last = points.(start + visible - 1) in
    let x k = UChart.x_for_index plot_width visible k in
    let text =
      if snap.R.grain = R.Day then
        let as_of = "As of " ^ short_date snap.R.observed_at in
        let right =
          match
            List.find_opt
              (fun k -> points.(start + k).R.start_day = snap.R.observed_at)
              (List.init visible Fun.id)
          with
          | Some k -> placed ~width:plot_width (x k) as_of
          | None -> placed ~width:plot_width (plot_width - 1) (short_date last.R.start_day)
        in
        let local = selected - start in
        let chosen =
          if local < 0 || local >= visible then []
          else
            let day = points.(selected).R.start_day in
            [
              placed ~width:plot_width (x local)
                (if day = snap.R.observed_at then as_of else short_date day);
            ]
        in
        overlaid ~width:plot_width
          (chosen @ [ right; placed ~width:plot_width 0 (short_date first.R.start_day) ])
      else if plot_width / visible < 8 then
        centered plot_width (short_date first.R.start_day ^ "   …   " ^ short_date last.R.start_day)
      else
        let chunk = max 1 (plot_width / visible) in
        String.concat ""
          (List.init visible (fun k ->
               let point = points.(start + k) in
               let last =
                 if current_partial snap point then snap.R.observed_at else point.R.end_exclusive
               in
               centered chunk (short_date point.R.start_day ^ " → " ^ short_date last)))
    in
    String.make plot_left ' ' ^ text

let chart_body (env : Screen.env) ~width_of ~width ~height t (snap : R.snapshot) start visible
    selected =
  let fmt value = O.format_money env.book snap.R.measure value in
  let values = series_values snap start visible in
  let scale = UChart.scale_for (Z.zero :: List.concat values) in
  (* LOAM keeps an eight-cell value axis; a wider tick label widens it rather
     than turning into an ellipsis. *)
  let axis = max (min 8 (width / 4)) (UChart.axis_width ~width_of width scale fmt) in
  let plot_left = axis + 3 in
  let plot_width = max 1 (width - plot_left) in
  let grid_rows = List.map (UChart.row_for_value height scale.range) scale.ticks in
  let rows =
    UChart.multi_line_spans ~width:plot_width ~height ~series:values ~selected:(selected - start)
      ~range:scale.range ~grid_rows ~markers:(Array.to_list markers)
      ~guides:(guide_columns ~plot_width t snap start visible)
      ()
    |> UChart.with_value_axis_spans ~width_of ~axis ~height ~scale ~label:fmt
  in
  (List.map (fun spans -> (O.Spans spans, O.spans_text spans)) rows, plot_left, plot_width)

let chart_rows (env : Screen.env) (geometry : Screen.geometry) t (snap : R.snapshot) =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let screen_height = snd geometry.screen in
  let compact = screen_height <= compact_height in
  let tiny = screen_height <= 9 in
  let points = points_of snap in
  let count = Array.length points in
  let selected = effective_index t snap in
  let start, stop = window_of t count selected in
  let visible = max 0 (stop - start) in
  let spans rows = List.map (fun spans -> (O.Spans spans, O.spans_text spans)) rows in
  let header =
    match selected_point snap selected with
    | None -> [ (O.Heading, "Trend   " ^ R.grain_label t.grain); (O.Chrome, "No selected period.") ]
    | Some point when compact ->
        let title =
          "Trend " ^ R.grain_label snap.R.grain
          ^ (if snap.R.grain = R.Day then "/" ^ R.scope_label snap.R.scope else "")
          ^ " · " ^ snap.R.measure
        in
        let series_count = Array.length snap.R.series in
        let values =
          if series_count = 0 then [ [ (O.Chrome, "No series.") ] ]
          else if tiny then
            [ compact_value_row ~width_of ~width env snap selected 0 (series_count - 1) ]
          else
            List.init series_count (fun i ->
                compact_value_row ~width_of ~width env snap selected i 0)
        in
        [ (O.Heading, title) ]
        @ (if tiny then []
           else
             [
               (O.Chrome, if t.notice = "" then "Source " ^ snap.R.source else "Notice " ^ t.notice);
             ])
        @ [ (O.Active, if tiny then "Selected " ^ point.R.start_day else selected_line snap point) ]
        @ spans values
    | Some point ->
        [ (O.Heading, heading snap.R.grain) ]
        @ spans (rack_rows ~width_of snap)
        @ [ (O.Chrome, source_line t snap visible); (O.Active, selected_line snap point) ]
        @ spans (value_rows ~width_of ~width env snap selected)
  in
  let notice = if compact || t.notice = "" then [] else [ (O.Status, t.notice) ] in
  (* The plot takes what the header, axis, overlays and notice leave. *)
  let fixed = List.length header + 1 + List.length notice in
  let overlay_reserve =
    if t.grain = R.Day && t.overlays <> [] then if compact then 1 else 2 else 0
  in
  let plot_height = max 1 (height - fixed - overlay_reserve) in
  if visible = 0 then header @ notice
  else
    let body, plot_left, plot_width =
      chart_body env ~width_of ~width ~height:plot_height t snap start visible selected
    in
    let overlays = overlay_rows ~width_of ~width ~plot_left ~plot_width t snap start visible in
    let overlays = if compact then List.filteri (fun i _ -> i < 1) overlays else overlays in
    header @ body
    @ [ (O.Chrome, axis_row ~plot_left ~plot_width snap start visible selected) ]
    @ overlays @ notice

let unavailable_rows (geometry : Screen.geometry) why =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let hint =
    if Base.String.is_substring why ~substring:"accounting-roles.tsv" then
      "Fix accounting-roles.tsv; no Locus role is guessed."
    else "Supply an explicit boundary-presets.tsv preset that contains the focused day."
  in
  let lines = [ tr "Trend / Locus unavailable:"; why; hint ] in
  let wrapped =
    List.concat_map (O.wrap_text ~width_of (max 1 (width - 4))) lines
    |> List.map (fun text -> (O.Plain, text))
  in
  Panel.frame_rows ~inset:0 ~width_of ~width ~height ~focused:true
    ~title:"Trend / Locus [unavailable]" wrapped

let rack_line (env : Screen.env) coordinates =
  coordinates
  |> List.mapi (fun slot coordinate ->
      Printf.sprintf "%d %s %s" (slot + 1) (marker_of slot) (B.label env.book coordinate.R.locus))
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
    else if capacity - List.length notice > 1 then [ (O.Plain, rack_line env coordinates) ]
    else []
  in
  let rows = max 1 (capacity - List.length notice - List.length rack) in
  let window = Panel.window ~capacity:rows ~count ~scroll:0 ~selected:(Some picker.cursor) in
  let stop = min count (window.start + window.capacity) in
  let painted =
    List.init
      (max 0 (stop - window.start))
      (fun i ->
        let index = window.start + i in
        let candidate = List.nth candidates index in
        let used = List.find_index (fun c -> same_coordinate c candidate) coordinates in
        let text =
          Printf.sprintf "%s %s (%s)%s"
            (if index = picker.cursor then ">" else " ")
            (B.label env.book candidate.R.locus)
            candidate.R.locus
            (match used with Some slot -> Printf.sprintf " [slot %d]" (slot + 1) | None -> "")
        in
        ((if index = picker.cursor then O.Active else O.Plain), text))
  in
  let target =
    if picker.target < List.length coordinates then "slot " ^ string_of_int (picker.target + 1)
    else "new slot"
  in
  let title = Printf.sprintf "Series %s • Measure %s" target (current_measure env t) in
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
    Ui_form.create ~id:"trend_locus_annotation" ~title ~summary ~fields ~notice:editor.notice ()
  in
  Ui_form.set_focused form (if editor.field = `Name then 0 else 1)

(* LOAM's Trend tokens, minus the pointer it reads and Bakhlo does not. *)
let footer ~width_of ~(geometry : Screen.geometry) t =
  let width = fst geometry.content in
  let line text = O.clip_text ~width_of width text in
  let two lines = List.map line (List.filteri (fun i _ -> i < 2) lines) in
  match t.editor with
  | Some _ -> [ line "Enter next/apply  Esc cancel"; line "Tab field  session only" ]
  | None when Option.is_some t.help -> [ line "? / Esc close help"; "" ]
  | None -> (
      match t.picker with
      | Some _ -> [ line "↑/↓ choose Locus   1-5 slot   Enter apply"; line "x remove   Esc cancel" ]
      | None when snd geometry.screen <= compact_height ->
          if t.grain = R.Day then
            two
              ([ "←/→ day [/] grain s/S range"; "a series o overlay q/Esc Home" ]
              @ if t.overlays = [] then [] else [ "v guides O clear · session only" ])
          else [ line "←/→ period [/] grain"; line "a series q/Esc Home" ]
      | None ->
          let day = t.grain = R.Day in
          let overlay =
            if not day then []
            else if t.overlays = [] then [ "o overlay" ]
            else
              [ "o overlay"; ("v guides " ^ if t.guides then "off" else "on"); "O clear overlays" ]
          in
          two
            (flow_tokens ~width_of width
               ([ "←/→ select period"; "Home/End"; "[ / ] grain"; "a series" ]
               @ (if day then [ "s/S range" ] else [])
               @ overlay
               @ [ "? help"; "Space Commands"; "q/Esc Home" ])))

let view (env : Screen.env) (geometry : Screen.geometry) t : Screen.view =
  let overlay =
    match t.editor with
    | Some editor ->
        Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
          (editor_form editor)
    | None -> (
        match t.help with
        | Some form ->
            Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
              form
        | None -> None)
  in
  {
    Screen.title = tr "Trend / Locus comparison";
    subtitle = Hidden;
    rows =
      lazy
        (bounded_rows geometry
           (match t.picker with
           | Some picker -> picker_rows env geometry t picker
           | None -> (
               match project env t with
               | Ok snap -> chart_rows env geometry t snap
               | Error why -> unavailable_rows geometry why)));
    footer = footer ~width_of:geometry.width_of ~geometry t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
