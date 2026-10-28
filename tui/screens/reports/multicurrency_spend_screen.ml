(* Multicurrency Spend: an explicit Actual-only window. Calendar Month, named
   boundary presets and explicit Custom dates stay independent sources; a named
   source never silently falls back. Nothing is queried before Run. *)
module A = Draft
module O = Ui_render
module P = Report_period
module Frame = Report_frame
module Report = Multicurrency_spend_report

type kind = Calendar_month | Named of string | Custom
type focus = Start | End_field | Run

type t = {
  kind : kind;
  start_day : string;
  end_day : string;
  focus : focus;
  scroll : int;
  answer : (Report.snapshot, string) result option;
  notice : string;
  presets : (string * string list) list;
  presets_error : string; (* "" when presets are available (including none) *)
  initialized : bool;
  pending : string option; (* focus day awaiting environment resolution *)
}

let preset_file = "boundary-presets.tsv"
let config_files = [ preset_file ]
let run_prompt = "Run the window query; nothing is scanned or sorted before you run."

let create () =
  {
    kind = Calendar_month;
    start_day = "";
    end_day = "";
    focus = Run;
    scroll = 0;
    answer = None;
    notice = "";
    presets = [];
    presets_error = "";
    initialized = false;
    pending = None;
  }

let canonical_day day =
  match Day.normalize day with Ok normalized -> normalized = day | Error _ -> false

let parse_presets text =
  Result.map_error
    (fun () -> "Malformed boundary-presets.tsv; named presets are unavailable.")
    (Boundary_presets.parse text)

let load_presets (env : Screen.env) =
  match env.config preset_file with
  | Error why -> ([], "Named presets unavailable: " ^ why)
  | Ok None -> ([], "")
  | Ok (Some text) -> (
      match parse_presets text with Ok presets -> (presets, "") | Error why -> ([], why))

let windows dates =
  let rec pairs = function a :: (b :: _ as rest) -> (a, b) :: pairs rest | _ -> [] in
  pairs dates

let index_of name names =
  let rec find index = function
    | [] -> None
    | candidate :: rest -> if candidate = name then Some index else find (index + 1) rest
  in
  find 0 names

let named_window presets name day =
  match List.assoc_opt name presets with
  | None -> None
  | Some dates -> List.find_opt (fun (a, b) -> a <= day && day < b) (windows dates)

let member_window presets name start_day end_day =
  match List.assoc_opt name presets with
  | None -> false
  | Some dates -> List.mem (start_day, end_day) (windows dates)

let month_window day =
  if not (canonical_day day) then None
  else
    match Day.parts day with
    | Error _ -> None
    | Ok (year, month, _) -> (
        let start_day = Printf.sprintf "%04d-%02d-01" year month in
        match Day.shift_months start_day 1 with
        | Ok end_day -> Some (start_day, end_day)
        | Error _ -> None)

let source_label t =
  match t.kind with Calendar_month -> "Calendar Month" | Named name -> name | Custom -> "Custom"

let refresh (env : Screen.env) t =
  let presets, presets_error = load_presets env in
  { t with presets; presets_error }

let revalidate t =
  match t.kind with
  | Named name
    when t.presets_error <> "" || not (member_window t.presets name t.start_day t.end_day) ->
      {
        t with
        kind = Custom;
        notice =
          Printf.sprintf
            "Preset %s no longer provides this window; the dates are retained as Custom." name;
      }
  | Calendar_month | Named _ | Custom -> t

let invalidate t = { t with answer = None; notice = ""; scroll = 0 }

let enter env ~focus_day t =
  let t = refresh env t in
  if t.initialized then
    let t = revalidate t in
    { t with answer = None; pending = None; scroll = 0 }
  else
    let t = { t with initialized = true; pending = None; answer = None; scroll = 0 } in
    match month_window focus_day with
    | Some (start_day, end_day) ->
        { t with kind = Calendar_month; start_day; end_day; focus = Run; notice = "" }
    | None ->
        {
          t with
          focus = Run;
          notice = "The focused day is not a canonical real date; enter Start and End explicitly.";
        }

let resolve (env : Screen.env) t =
  match t.pending with
  | None -> t
  | Some focus_day -> enter env ~focus_day { t with pending = None }

let resume ~focus_day t =
  {
    t with
    pending = Some focus_day;
    answer = None;
    scroll = 0;
    focus = (if t.initialized then t.focus else Run);
  }

let window t = (t.start_day, t.end_day)

let result t =
  match t.answer with
  | Some answer -> answer
  | None -> Error (if t.notice = "" then run_prompt else t.notice)

let modal _ = false
let saved _env _geometry _result t = (t, Screen.Stay)

let reloaded env t =
  let t = refresh env t in
  let t = revalidate t in
  ({ t with answer = None; pending = None; scroll = 0 }, Screen.Stay)

let book_changed ~before:_ ~after:_ t = ({ t with answer = None; notice = ""; scroll = 0 }, "")

let query (env : Screen.env) t =
  let refuse why = ({ t with answer = None; notice = why; scroll = 0 }, Some why) in
  match t.kind with
  | Named _ when t.presets_error <> "" -> refuse t.presets_error
  | Named name when not (member_window t.presets name t.start_day t.end_day) ->
      refuse
        (Printf.sprintf
           "Preset %s has no window with these dates; edit the dates, press m, or switch source."
           name)
  | Calendar_month | Named _ | Custom -> (
      if not (canonical_day t.start_day && canonical_day t.end_day && t.start_day < t.end_day) then
        refuse "Enter canonical real Start and End dates, with Start earlier than End (exclusive)."
      else
        match
          Result.bind
            (Result.map_error
               (fun why -> "Accounting roles unavailable: " ^ why)
               (Lazy.force env.accounting_roles))
            (fun roles ->
              Report.compute ~book:env.book ~roles ~start_day:t.start_day ~end_exclusive:t.end_day)
        with
        | Ok snapshot -> ({ t with answer = Some (Ok snapshot); notice = ""; scroll = 0 }, None)
        | Error why -> ({ t with answer = Some (Error why); notice = why; scroll = 0 }, Some why))

let apply_source (env : Screen.env) kind t =
  match kind with
  | Calendar_month -> (
      match month_window env.today with
      | Some (start_day, end_day) ->
          { t with kind; start_day; end_day; answer = None; notice = ""; scroll = 0 }
      | None ->
          {
            t with
            kind;
            answer = None;
            scroll = 0;
            notice = "Selected day is not a canonical real date; enter dates explicitly.";
          })
  | Named name -> (
      match named_window t.presets name env.today with
      | Some (start_day, end_day) ->
          { t with kind; start_day; end_day; answer = None; notice = ""; scroll = 0 }
      | None ->
          {
            t with
            kind;
            answer = None;
            scroll = 0;
            notice =
              Printf.sprintf
                "Preset %s has no adjacent window containing %s; Run is blocked until the dates \
                 are edited, m is pressed, or the source changes."
                name env.today;
          })
  | Custom -> { t with kind = Custom }

let cycle_source (env : Screen.env) delta t =
  if t.presets_error <> "" then
    ({ t with answer = None; notice = t.presets_error }, Screen.Message t.presets_error)
  else
    let names = List.map fst t.presets in
    let count = 1 + List.length names in
    let current =
      match t.kind with
      | Calendar_month -> Some 0
      | Named name -> Option.map (fun index -> index + 1) (index_of name names)
      | Custom -> None
    in
    let index =
      match current with
      | Some index -> (index + delta + count) mod count
      | None -> if delta > 0 then 0 else count - 1
    in
    let kind = if index = 0 then Calendar_month else Named (List.nth names (index - 1)) in
    (apply_source env kind t, Screen.Stay)

let edit t value =
  {
    t with
    kind = Custom;
    start_day = (if t.focus = Start then value else t.start_day);
    end_day = (if t.focus = End_field then value else t.end_day);
    answer = None;
    notice = "";
    scroll = 0;
  }

let shift_month (env : Screen.env) delta t =
  let base =
    if canonical_day t.start_day then t.start_day
    else match month_window env.today with Some (start_day, _) -> start_day | None -> ""
  in
  match Day.shift_months base delta with
  | Error why -> ({ t with answer = None; notice = why }, Screen.Message why)
  | Ok start_day -> (
      match Day.shift_months start_day 1 with
      | Error why -> ({ t with answer = None; notice = why }, Screen.Message why)
      | Ok end_day -> (invalidate { t with kind = Calendar_month; start_day; end_day }, Screen.Stay)
      )

let wrapped ~width_of width style text =
  List.map (fun line -> (style, line)) (O.wrap_text ~width_of (max 1 width) text)

let capacity (geometry : Screen.geometry) =
  max 0 (snd geometry.content - if snd geometry.content < 6 then 3 else 4)

let body (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  let disclaimer =
    List.concat_map
      (fun (style, text) -> wrapped ~width_of width style text)
      ([
         (O.Chrome, "No exchange rate, conversion or home-currency total is inferred.");
         (O.Chrome, "Retained Actual entries only; not a Trip report and not Scheduled spending.");
       ]
      @ if t.presets_error = "" then [] else [ (O.Status, t.presets_error) ])
  in
  let status =
    match result t with
    | Ok snapshot ->
        List.concat_map
          (fun (style, text) -> wrapped ~width_of width style text)
          (Report.render_lines ~book:env.book snapshot)
    | Error why when t.answer = None && t.notice = "" -> wrapped ~width_of width O.Chrome why
    | Error why -> wrapped ~width_of width O.Status ("Multicurrency Spend unavailable: " ^ why)
  in
  let rows = disclaimer @ status in
  let total = List.length rows + 1 in
  let cap = capacity geometry in
  let first = min total (t.scroll + 1) in
  let last = min total (t.scroll + cap) in
  let scroll_note =
    wrapped ~width_of width O.Chrome
      (Printf.sprintf "Scroll %d..%d of %d (j/k, PgUp/PgDn)" first last total)
  in
  scroll_note @ rows

let handle env geometry t input =
  let t = resolve env t in
  let clear_feedback t = (t, Screen.Message "") in
  let move delta =
    let last = max 0 (List.length (body env geometry t) - capacity geometry) in
    ({ t with scroll = Ui_panel.move ~last ~position:t.scroll delta }, Screen.Stay)
  in
  match P.lowercase input with
  | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Home)
  | Some (`ASCII ' ', []) -> (t, Screen.Commands)
  | Some (`Tab, []) | Some (`Tab, [ `Shift ]) ->
      let forward = input = `Key (`Tab, []) in
      let focus =
        match (t.focus, forward) with
        | Start, true -> End_field
        | Start, false -> Run
        | End_field, true -> Run
        | End_field, false -> Start
        | Run, true -> Start
        | Run, false -> End_field
      in
      clear_feedback { t with focus; scroll = 0 }
  | Some (`Enter, []) -> (
      match t.focus with
      | Start -> clear_feedback { t with focus = End_field; scroll = 0 }
      | End_field -> clear_feedback { t with focus = Run; scroll = 0 }
      | Run -> (
          let next, why = query env t in
          match why with None -> clear_feedback next | Some why -> (next, Screen.Message why)))
  | Some (`ASCII '[', []) -> cycle_source env (-1) t
  | Some (`ASCII ']', []) -> cycle_source env 1 t
  | Some (`ASCII 'm', []) -> (
      match month_window env.today with
      | Some (start_day, end_day) ->
          clear_feedback
            {
              t with
              kind = Calendar_month;
              start_day;
              end_day;
              focus = Run;
              answer = None;
              notice = "";
              scroll = 0;
            }
      | None ->
          let why = "Selected day is not a canonical real date; enter dates explicitly." in
          ({ t with answer = None; notice = why }, Screen.Message why))
  | Some (`Arrow `Left, []) when t.kind = Calendar_month -> shift_month env (-1) t
  | Some (`Arrow `Right, []) when t.kind = Calendar_month -> shift_month env 1 t
  | Some ((`ASCII 'k' | `Arrow `Up), []) -> move (-1)
  | Some ((`ASCII 'j' | `Arrow `Down), []) -> move 1
  | key when Option.is_some (Frame.page_delta key) ->
      move (Option.get (Frame.page_delta key) * max 1 (capacity geometry))
  | Some (`Home, []) -> ({ t with scroll = 0 }, Screen.Stay)
  | Some (`End, []) -> move max_int
  | _ when t.focus = Start || t.focus = End_field -> (
      let value = if t.focus = Start then t.start_day else t.end_day in
      match input with
      | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 ->
          clear_feedback (edit t (value ^ String.make 1 c))
      | `Key (`Uchar c, []) when O.printable_uchar c -> clear_feedback (edit t (value ^ O.utf8 c))
      | `Key (`Backspace, []) -> clear_feedback (edit t (Line_edit.backspace value))
      | _ -> (t, Screen.Ignored))
  | _ -> (t, Screen.Ignored)

let view env (geometry : Screen.geometry) t =
  let t = resolve env t in
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let compact = height < 6 in
  let date_row label focused value =
    let room = max 0 (width - width_of label) in
    if focused then
      let text, caret = O.input_text ~width_of ~width:room ~cursor:None ~caret:"|" value in
      let style =
        match caret with Some column -> O.Input (width_of label + column) | None -> O.Active
      in
      ((style, label ^ text), Option.map (fun column -> width_of label + column) caret)
    else ((O.Plain, label ^ O.clip_text ~width_of room value), None)
  in
  let start_row, start_column = date_row "Start (inclusive): " (t.focus = Start) t.start_day in
  let end_row, end_column = date_row "End (exclusive): " (t.focus = End_field) t.end_day in
  let run_row = ((if t.focus = Run then O.Active else O.Plain), "[Run]") in
  let fixed =
    (if compact then [] else [ (O.Chrome, "Window source: " ^ source_label t) ])
    @ [ start_row; end_row; run_row ]
  in
  let fixed =
    List.map (fun (style, text) -> (style, O.clip_text ~width_of (max 0 width) text)) fixed
  in
  let all = body env geometry t in
  let count = List.length all in
  let pane = Ui_panel.window ~capacity:(capacity geometry) ~count ~scroll:t.scroll ~selected:None in
  let visible =
    List.filteri (fun index _ -> index >= pane.start && index < pane.start + pane.capacity) all
  in
  let rows = List.filteri (fun index _ -> index < height) (fixed @ visible) in
  let cursor =
    let header = max 0 (snd geometry.body - snd geometry.content) in
    let index =
      if compact then match t.focus with Start -> Some 0 | End_field -> Some 1 | Run -> None
      else match t.focus with Start -> Some 1 | End_field -> Some 2 | Run -> None
    in
    match index with
    | Some index ->
        let column = if t.focus = Start then start_column else end_column in
        Option.map (fun column -> (column, header + index)) column
    | None -> None
  in
  {
    Screen.title = "Reports / Multicurrency Spend";
    subtitle =
      Text
        (if compact then "Source: " ^ source_label t
         else "Read-only Actual lens; distinct Measures are never converted.");
    rows = lazy rows;
    footer =
      (if width >= 70 then
         [
           "Start/End date  Tab/Shift-Tab focus  Enter next/run  Backspace delete  [ ] source";
           "m selected month  j/k scroll  PgUp/Dn page  Home/End  Space Commands  q/Esc Home";
         ]
       else if width >= 48 then
         [
           "[ ] source  m month  Tab focus  Enter next/run  Bksp";
           "j/k PgUp/Dn Space Commands q/Esc Home";
         ]
       else [ "Tab Enter [ ] m  j/k"; "SPC menu  q/Esc" ])
      |> List.map (O.clip_text ~width_of (max 0 width));
    overlay = None;
    cursor;
  }
