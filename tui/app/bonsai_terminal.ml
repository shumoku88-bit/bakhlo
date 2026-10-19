(* Existing Bonsai_term state-machine/event loop; same daily actions and file owner. *)
module B = Bonsai_term
module Bonsai = B.Bonsai
module V = B.View
module C = Shell_state
module H = Shell_input
module X = Shell_dispatch
module R = Shell_view
module F = Daily_file
module P = Ui_preferences
module D = Bakhlo_domain

let fit width height view =
  let view = V.crop ~r:(max 0 (V.width view - width)) ~b:(max 0 (V.height view - height)) view in
  V.pad ~r:(max 0 (width - V.width view)) ~b:(max 0 (height - V.height view)) view

let color (c : P.color) = B.Attr.Color.xterm_256 c.index
let fg c = B.Attr.fg (color c)
let bg c = B.Attr.bg (color c)

let attributes theme style =
  match P.palette theme with
  | None -> (
      match style with
      | C.Plain | C.Calendar_dates | C.Bonsai | C.Entrance | C.Columns _ | C.Input _ -> []
      | C.Active -> [ B.Attr.fg B.Attr.Color.Expert.cyan; B.Attr.invert; B.Attr.bold ]
      | C.Focused_frame -> [ B.Attr.fg B.Attr.Color.Expert.cyan; B.Attr.bold ]
      | C.Heading | C.Status | C.Panel_heading -> [ B.Attr.bold ]
      | C.Panel | C.Chrome | C.Frame -> []
      | C.Panel_active -> [ B.Attr.fg B.Attr.Color.Expert.cyan; B.Attr.invert; B.Attr.bold ])
  | Some palette -> (
      match style with
      | C.Plain | C.Calendar_dates | C.Bonsai | C.Entrance | C.Columns _ | C.Input _ -> [ fg palette.foreground; bg palette.background ]
      | C.Active -> [ fg palette.selected_foreground; bg palette.selected_background; B.Attr.bold ]
      | C.Heading -> [ fg palette.foreground; bg palette.background; B.Attr.bold ]
      | C.Chrome | C.Frame -> [ fg palette.heading; bg palette.background ]
      | C.Focused_frame -> [ fg palette.accent; bg palette.panel_background ]
      | C.Status -> [ fg palette.status; bg palette.background; B.Attr.bold ]
      | C.Panel -> [ fg palette.panel_foreground; bg palette.panel_background ]
      | C.Panel_heading -> [ fg palette.panel_foreground; bg palette.panel_background; B.Attr.bold ]
      | C.Panel_active ->
          [ fg palette.selected_foreground; bg palette.selected_background; B.Attr.bold ])

let border_attributes theme intent =
  let color =
    match theme with
    | P.Terminal -> (
        (* ANSI slots belong to the terminal's light/dark palette too. *)
        match intent with
        | `Create -> B.Attr.Color.Expert.cyan
        | `Change -> B.Attr.Color.Expert.yellow
        | `Cancel -> B.Attr.Color.Expert.red)
    | P.Bakhlo_light | P.Bakhlo_dark ->
        let light = theme = P.Bakhlo_light in
        let index =
          match intent with
          | `Create -> if light then 31 else 67
          | `Change -> if light then 136 else 179
          | `Cancel -> if light then 131 else 174
        in
        B.Attr.Color.xterm_256 index
  in
  [ B.Attr.fg color ]

(* Compose styled glyph runs natively. Borders are not part of the input highlight,
   including the interior edges of side-by-side panes. No presentation glyph
   participates in navigation, accounting or publication decisions. *)
let rec lines ?border theme rows =
  rows
  |> List.map (fun (style, text) ->
      match style with
      | C.Columns (left_width, left_style, right_style) ->
          let split = ref 0 and cells = ref 0 in
          Uutf.String.fold_utf_8
            (fun () offset -> function
              | `Uchar c when !cells < left_width ->
                  cells := !cells + V.uchar_tty_width c;
                  split := offset + String.length (Daily_overlays.utf8 c)
              | `Uchar _ | `Malformed _ -> ())
            () text;
          let left = String.sub text 0 !split in
          let right_start = min (String.length text) (!split + 1) in
          let right = String.sub text right_start (String.length text - right_start) in
          V.hcat [ lines ?border theme [left_style, left]; V.text " ";
                   lines ?border theme [right_style, right] ]
      | _ ->
      let glyphs =
        Uutf.String.fold_utf_8
          (fun xs _ -> function `Uchar c -> Daily_overlays.utf8 c :: xs | `Malformed _ -> xs)
          [] text |> List.rev
      in
      let body_style =
        match style with
        | C.Frame | C.Focused_frame -> C.Chrome
        | C.Input _ | C.Bonsai | C.Entrance -> C.Plain
        | style -> style
      in
      let edge_attrs =
        match border with
        | Some intent -> border_attributes theme intent
        | None -> attributes theme (if style = C.Focused_frame then C.Focused_frame else C.Frame)
      in
      let leaf_attrs = [ B.Attr.fg B.Attr.Color.Expert.green ] in
      let entrance_key_attrs = [ B.Attr.fg B.Attr.Color.Expert.cyan; B.Attr.bold ] in
      let framed_row = String.starts_with ~prefix:"│" text && String.ends_with ~suffix:"│" text in
      let ruled_row = String.starts_with ~prefix:"╭" text || String.starts_with ~prefix:"╰" text in
      let total_cells = V.width (V.text text) in
      let rec paint cell = function
        | "[" :: a :: b :: "]" :: rest
          when style = C.Calendar_dates && String.length a = 1 && String.length b = 1
               && a.[0] >= '0' && a.[0] <= '9' && b.[0] >= '0' && b.[0] <= '9' ->
            (attributes theme C.Active, "[" ^ a ^ b ^ "]") :: paint (cell + 4) rest
        | glyph :: rest when style = C.Bonsai && (glyph = ":" || glyph = ";") ->
            (leaf_attrs, glyph) :: paint (cell + 1) rest
        | key :: " " :: rest
          when style = C.Entrance
               && (key = "r" || key = "s" || key = "g" || key = "a" || key = "b" || key = "d")
               && (cell = 0 || String.get text (max 0 (cell - 1)) = ' ') ->
            (entrance_key_attrs, key) :: paint (cell + 1) (" " :: rest)
        | glyph :: rest ->
            let attrs =
              if (framed_row && (cell = 0 || cell = total_cells - 1))
                 || (ruled_row && List.mem glyph [ "─"; "╭"; "╮"; "╰"; "╯" ]) then edge_attrs
              else if (match style with C.Input caret -> cell = caret | _ -> false) then
                attributes theme C.Active
              else attributes theme body_style
            in
            (attrs, glyph) :: paint (cell + V.width (V.text glyph)) rest
        | [] -> []
      in
      let runs =
        List.fold_left
          (fun runs (attrs, text) ->
            match runs with
            | (previous, content) :: rest
              when B.Attr.equal (B.Attr.many previous) (B.Attr.many attrs) ->
                (previous, content ^ text) :: rest
            | _ -> (attrs, text) :: runs)
          [] (paint 0 glyphs)
        |> List.rev
      in
      match runs with
      | [] -> V.text " " (* Empty content is still a physical terminal row. *)
      | _ -> V.hcat (List.map (fun (attrs, text) -> V.text ~attrs text) runs))
  |> V.vcat

let backdrop theme view =
  match P.palette theme with
  | None -> view
  | Some palette ->
      V.with_colors ~fill_backdrop:true view ~fg:(color palette.foreground)
        ~bg:(color palette.background)

let width_of text = V.width (V.text text)
let overlay_screen dimensions state = R.overlay_screen ~dimensions ~width_of state

let editor_border state =
  if state.C.record_visible then Option.map Record_session.border_intent state.C.record else None

let base_view ((width, height) as dimensions) theme state =
  let border = if overlay_screen dimensions state = None then editor_border state else None in
  R.screen ~width_of dimensions state |> lines ?border theme |> fit width height |> backdrop theme

let overlay_view dimensions theme state =
  match R.resolve_overlay ~dimensions ~width_of state with
  | None -> None
  | Some frame ->
      let pane = lines ?border:(editor_border state) theme frame.rows in
      let pane =
        match P.palette theme with
        | None -> pane
        | Some palette ->
            V.with_colors ~fill_backdrop:true pane ~fg:(color palette.panel_foreground)
              ~bg:(color palette.panel_background)
      in
      Some (V.pad ~l:frame.origin_x ~t:frame.origin_y pane)

let render ((width, height) as dimensions) state =
  let base = base_view dimensions state.C.theme state in
  match overlay_view dimensions state.C.theme state with
  | None -> base
  | Some overlay -> V.zcat [ overlay; base ] |> fit width height

let input_of_event : B.Event.t -> C.input = function
  | B.Event.Paste marker -> `Paste marker
  | B.Event.Mouse _ -> `Mouse ()
  | B.Event.Key_press { key; mods } ->
      let key =
        match key with
        | Escape -> `Escape
        | Enter -> `Enter
        | Tab -> `Tab
        | Backspace -> `Backspace
        | Insert -> `Insert
        | Delete -> `Delete
        | Home -> `Home
        | End -> `End
        | Arrow direction -> `Arrow direction
        | Page direction -> `Page direction
        | Function n -> `Function n
        | ASCII c -> `ASCII c
        | Uchar c -> `Uchar c
      in
      let mods =
        List.map (function B.Event.Modifier.Meta -> `Meta | Ctrl -> `Ctrl | Shift -> `Shift) mods
      in
      `Key (key, mods)

type action = Terminal_event of B.Event.t | Request_exit

let app initial ~exit ~dimensions graph =
  let state, inject =
    (* Resize and keys may share a batch: read dimensions at action application, not capture. *)
    Bonsai.state_machine_with_input ~default_model:initial
      ~apply_action:(fun context active_dimensions state -> function
        | Terminal_event event -> (
            match active_dimensions with
            | Bonsai.Computation_status.Inactive -> state
            | Active (dimensions : B.Dimensions.t) -> (
                match H.handle ~dimensions:(dimensions.width, dimensions.height)
                  ~width_of state (input_of_event event) with
                | Some state -> state
                | None ->
                    Bonsai.Apply_action_context.schedule_event context (exit ());
                    state))
        | Request_exit ->
            Bonsai.Apply_action_context.schedule_event context (exit ());
            state)
      dimensions graph
  in
  let set_cursor = B.Cursor.set_cursor_position graph in
  let cursor_pos =
    Bonsai.arr2 graph state dimensions ~f:(fun state (dimensions : B.Dimensions.t) ->
        R.cursor_position ~width_of (dimensions.width, dimensions.height) state)
  in
  let cursor_effect =
    Bonsai.arr2 graph set_cursor cursor_pos ~f:(fun set_cursor cursor_pos ->
        let cursor =
          Option.map
            (fun (x, y) ->
              { B.Cursor.position = { B.Position.x; y }; kind = B.Cursor.Kind.Default })
            cursor_pos
        in
        set_cursor cursor)
  in
  Bonsai.Edge.after_display ~here:Stdlib.Lexing.dummy_pos cursor_effect graph;
  let view =
    Bonsai.arr2 graph state dimensions ~f:(fun state (dimensions : B.Dimensions.t) ->
        render (dimensions.width, dimensions.height) state)
  in
  let handler =
    Bonsai.arr1 graph inject ~f:(fun inject event -> inject (Terminal_event event))
  in
  (~view, ~handler)

type first_run_result = First_run_created of F.t | First_run_cancelled | First_run_failed of string

type first_run_action = First_run_event of B.Event.t

let first_run_app initial ~outcome ~exit ~dimensions graph =
  let state, inject =
    Bonsai.state_machine_with_input ~default_model:initial
      ~apply_action:(fun context active_dimensions state (First_run_event event) ->
        match active_dimensions with
        | Bonsai.Computation_status.Inactive -> state
        | Active (dimensions : B.Dimensions.t) ->
            (match First_run.handle state (input_of_event event) with
             | First_run.Continue next -> next
             | First_run.Cancel ->
                 outcome := Some First_run_cancelled;
                 Bonsai.Apply_action_context.schedule_event context (exit ());
                 state
             | First_run.Create _ when
                 not (First_run.ready_to_create
                   ~dimensions:(dimensions.width, dimensions.height) ~width_of state) ->
                 First_run.refuse_confirmation state
             | First_run.Create details ->
                 (try
                    let session =
                      F.create_empty ~path:details.destination ~measure:details.measure
                        ~scale:details.scale
                    in
                    outcome := Some (First_run_created session)
                  with
                  | F.Refused why -> outcome := Some (First_run_failed why)
                  | Unix.Unix_error (error, _, _) ->
                      outcome := Some (First_run_failed (Unix.error_message error))
                  | Sys_error why -> outcome := Some (First_run_failed why));
                 Bonsai.Apply_action_context.schedule_event context (exit ());
                 state))
      dimensions graph
  in
  let set_cursor = B.Cursor.set_cursor_position graph in
  let cursor_pos =
    Bonsai.arr2 graph state dimensions ~f:(fun state (dimensions : B.Dimensions.t) ->
        snd (First_run.screen ~dimensions:(dimensions.width, dimensions.height) ~width_of state))
  in
  Bonsai.Edge.after_display ~here:Stdlib.Lexing.dummy_pos
    (Bonsai.arr2 graph set_cursor cursor_pos ~f:(fun set_cursor cursor_pos ->
       let cursor =
         Option.map
           (fun (x, y) -> { B.Cursor.position = { B.Position.x; y }; kind = B.Cursor.Kind.Default })
           cursor_pos
       in
       set_cursor cursor))
    graph;
  let view =
    Bonsai.arr2 graph state dimensions ~f:(fun state (dimensions : B.Dimensions.t) ->
        let width, height = dimensions.width, dimensions.height in
        let rows, _ = First_run.screen ~dimensions:(width, height) ~width_of state in
        lines P.Terminal rows |> fit width height)
  in
  let handler = Bonsai.arr1 graph inject ~f:(fun inject event -> inject (First_run_event event)) in
  (~view, ~handler)

let start_first_run path read_error =
  F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
  let initial = First_run.initial ~source_path:path ~read_error in
  let outcome = ref None in
  (match
     Async.Thread_safe.block_on_async_exn (fun () ->
       B.start_with_exit ~dispose:true ~mouse:B.Mouse_reporting.No_mouse_events ~bpaste:true
         (first_run_app initial ~outcome))
   with
   | Ok () -> ()
   | Error _ -> raise (F.Refused "Bonsai-terminal-unavailable"));
  match !outcome with
  | Some (First_run_created session) -> Some session
  | Some First_run_cancelled -> None
  | Some (First_run_failed why) ->
      prerr_endline ("First-run creation refused: " ^ why ^ ". Inspect the destination; no retry was attempted.");
      None
  | None -> None

let run_loaded session =
  match
    Async.Thread_safe.block_on_async_exn (fun () ->
        B.start_with_exit ~dispose:true ~mouse:B.Mouse_reporting.No_mouse_events ~bpaste:true
          (app (C.initial session)))
  with
  | Ok () -> ()
  | Error _ -> raise (F.Refused "Bonsai-terminal-unavailable")

let run path =
  match
    try Ok (F.load path)
    with
    | F.Refused why -> Error why
    | Unix.Unix_error (error, _, _) -> Error (Unix.error_message error)
    | Sys_error why -> Error why
  with
  | Ok session ->
      F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
      run_loaded session
  | Error why ->
      (match start_first_run path why with
       | None -> ()
       | Some session -> run_loaded session)
