(* Liquidity: the two unconditional statements stay UNKNOWN, and a conditional
   path exists only after an explicit Run over a typed assumption. That
   assumption is ephemeral: nothing is saved, published or treated as evidence. *)
module A = Daily_draft
module Cal = Daily_calendar
module O = Daily_overlays
module P = Report_period
module Frame = Report_frame
module Report = Liquidity_report

type focus = Field | Run

type t = {
  draft : string option; (* None: not yet initialized; Some "": explicitly emptied *)
  focus : focus;
  scroll : int;
  requested : bool; (* an explicit Run happened for this draft *)
  notice : string; (* last refusal, retained with the draft *)
}

let balance_view_file = "balance-view.tsv"
let config_files = [ balance_view_file ]
let run_prompt = "Run the conditional projection; no path is queried before you run."
let create () = { draft = None; focus = Field; scroll = 0; requested = false; notice = "" }

let month_end day =
  match Cal.parts day with
  | Ok (year, month, _) -> Printf.sprintf "%04d-%02d-%02d" year month (A.days_in_month ~year ~month)
  | Error _ -> ""

let enter ~focus_day t =
  match t.draft with
  | Some _ -> { t with scroll = 0 }
  | None -> { t with draft = Some (month_end focus_day); focus = Run; scroll = 0 }

let assumption t = Option.value ~default:"" t.draft
let run_focused t = t.focus = Run
let modal _ = false

let selection (env : Screen.env) =
  Result.bind (env.config balance_view_file) (function
    | None -> Error "Liquidity requires an explicit balance-view.tsv selection."
    | Some text ->
        Result.map
          (List.map (fun (c : Balance_view_data.coordinate) -> (c.locus, c.measure)))
          (Balance_view_data.of_string text))

let result (env : Screen.env) t =
  if not t.requested then Error (if t.notice = "" then run_prompt else t.notice)
  else
    match t.draft with
    | None | Some "" -> Error "Enter an explicit assumed complete-through date, then Run."
    | Some horizon ->
        Result.bind (selection env) (fun coords ->
            Report.compute ~book:env.book ~today:env.today ~coords ~assumed_complete_through:horizon)

let invalidate t draft = { t with draft; requested = false; notice = ""; scroll = 0 }
let saved _env _geometry _result t = (t, Screen.Stay)
let reloaded _env t = ({ t with requested = false; notice = "" }, Screen.Stay)
let book_changed ~before:_ ~after:_ t = ({ t with requested = false; notice = "" }, "")

let field_label width =
  if width >= 50 then "Assume Scheduled complete through: " else "Assume Scheduled: "

let field_row (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  let label = field_label width in
  let room = max 0 (width - width_of label) in
  match t.focus with
  | Field ->
      let text, caret = O.input_text ~width_of ~width:room ~cursor:None ~caret:"|" (assumption t) in
      ( (match caret with Some column -> O.Input (width_of label + column) | None -> O.Active),
        label ^ text )
  | Run -> (O.Plain, label ^ O.clip_text ~width_of room (assumption t))

let run_row t = ((if t.focus = Run then O.Active else O.Plain), "[Run conditional]")

let wrapped ~width_of width style text =
  List.map (fun line -> (style, line)) (O.wrap_text ~width_of (max 1 width) text)

(* Everything below the two unconditional rows is scrollable. *)
let remainder (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  let disclaimer =
    List.concat_map
      (fun (style, text) -> wrapped ~width_of width style text)
      [
        (O.Chrome, "No retained complete-future evidence is available for this report.");
        (O.Chrome, "Known Scheduled items are not all future flows.");
        (O.Chrome, "Running this does not write or upgrade the assumption into evidence.");
      ]
  in
  let status =
    match result env t with
    | Ok snapshot ->
        List.concat_map
          (fun (style, text) -> wrapped ~width_of width style text)
          (Report.render_lines ~book:env.book snapshot)
    | Error why when (not t.requested) && t.notice = "" -> wrapped ~width_of width O.Chrome why
    | Error why ->
        wrapped ~width_of width O.Status ("Liquidity conditional projection unavailable: " ^ why)
  in
  [ field_row geometry t; run_row t ] @ disclaimer @ status

let capacity (geometry : Screen.geometry) = max 0 (snd geometry.content - 2)

let handle (env : Screen.env) geometry t input =
  let clear t = (t, Screen.Message "") in
  let move delta =
    let last = max 0 (List.length (remainder env geometry t) - capacity geometry) in
    ({ t with scroll = Ui_panel.move ~last ~position:t.scroll delta }, Screen.Stay)
  in
  match P.lowercase input with
  | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Home)
  | Some (`ASCII ' ', []) -> (t, Screen.Commands)
  | Some (`Tab, []) | Some (`Tab, [ `Shift ]) ->
      clear { t with focus = (if t.focus = Field then Run else Field); scroll = 0; notice = "" }
  | Some (`Enter, []) when t.focus = Field -> clear { t with focus = Run; notice = "" }
  | Some (`Enter, []) -> (
      let next = { t with requested = true; notice = ""; scroll = 0 } in
      match result env next with
      | Ok _ -> clear next
      | Error why -> ({ next with requested = false; notice = why }, Screen.Message why))
  | Some (`ASCII 'm', []) ->
      let draft = month_end env.calendar.selected_day in
      let next = invalidate { t with focus = Run } (Some draft) in
      if draft <> "" then clear next
      else
        let why = "Conditional horizon reset unavailable; enter an explicit date." in
        ({ next with notice = why }, Screen.Message why)
  | Some ((`ASCII 'k' | `Arrow `Up), []) -> move (-1)
  | Some ((`ASCII 'j' | `Arrow `Down), []) -> move 1
  | key when Option.is_some (Frame.page_delta key) ->
      move (Option.get (Frame.page_delta key) * max 1 (capacity geometry))
  | Some (`Home, []) -> ({ t with scroll = 0 }, Screen.Stay)
  | Some (`End, []) -> move max_int
  | _ when t.focus = Field -> (
      let value = assumption t in
      match input with
      | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 ->
          clear (invalidate t (Some (value ^ String.make 1 c)))
      | `Key (`Uchar c, []) when O.printable_uchar c ->
          clear (invalidate t (Some (value ^ O.utf8 c)))
      | `Key (`Backspace, []) -> clear (invalidate t (Some (Daily_form.backspace value)))
      | _ -> (t, Screen.Ignored))
  | _ -> (t, Screen.Ignored)

let view (env : Screen.env) (geometry : Screen.geometry) t =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let top = [ (O.Plain, "Forecast path: UNKNOWN"); (O.Plain, "Known low-water mark: UNKNOWN") ] in
  let body = remainder env geometry t in
  let window =
    Ui_panel.window ~capacity:(capacity geometry) ~count:(List.length body) ~scroll:t.scroll
      ~selected:(if t.focus = Field then Some 0 else None)
  in
  let visible =
    List.filteri (fun i _ -> i >= window.start && i < window.start + window.capacity) body
  in
  let rows =
    List.filteri (fun i _ -> i < max 0 height) (top @ visible)
    |> List.map (fun (style, text) -> (style, O.clip_text ~width_of (max 0 width) text))
  in
  let cursor =
    if t.focus <> Field then None
    else
      match O.cursor_in_rows ~width_of ~width visible with
      | Some (column, row) ->
          let header = max 0 (snd geometry.body - snd geometry.content) in
          Some (column, header + List.length top + row)
      | None -> None
  in
  {
    Screen.title = "Reports / Liquidity";
    subtitle = Text "Read-only conditional query; Scheduled coverage is assumed, not proved.";
    rows = lazy rows;
    footer =
      (if width >= 70 then
         [
           "m month end  Tab/Shift-Tab focus  Enter next/run  Backspace delete";
           "j/k scroll  PgUp/Dn page  Home/End ends  Space Commands  q/Esc Home";
         ]
       else if width >= 48 then
         [ "m monthend Tab focus Enter next/run Bksp"; "j/k PgUp/Dn Space Commands q/Esc Home" ]
       else [ "Tab focus Enter next/run Bksp"; "m monthend j/k SPC menu q/Esc" ])
      |> List.map (O.clip_text ~width_of (max 0 width));
    overlay = None;
    cursor;
  }
