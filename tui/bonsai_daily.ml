(* Existing Bonsai_term state-machine/event loop; same daily actions and file owner. *)
module B = Bonsai_term
module Bonsai = B.Bonsai
module V = B.View
module C = Daily_interaction
module F = Daily_file
module Annual = Bakhlo_sexp.Annual_scope
module P = Ui_preferences
module D = Bakhlo_domain
module Y = Bakhlo_sexp.Year_read

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
let overlay_screen dimensions state = C.overlay_screen ~dimensions ~width_of state

let editor_border state =
  if state.C.record_visible then Option.map Record_session.border_intent state.C.record else None

let base_view ((width, height) as dimensions) theme state =
  let border = if overlay_screen dimensions state = None then editor_border state else None in
  C.screen ~width_of dimensions state |> lines ?border theme |> fit width height |> backdrop theme

let overlay_view dimensions theme state =
  match C.resolve_overlay ~dimensions ~width_of state with
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
                match C.handle ~dimensions:(dimensions.width, dimensions.height)
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
        C.cursor_position ~width_of (dimensions.width, dimensions.height) state)
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

let first_run_app ?annual_year initial ~outcome ~exit ~dimensions graph =
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
                      match annual_year with
                      | None ->
                          F.create_empty ~path:details.destination ~measure:details.measure
                            ~scale:details.scale
                      | Some year ->
                          F.create_annual_empty ~year ~path:details.destination
                            ~measure:details.measure ~scale:details.scale
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

let start_first_run ?annual_year path read_error =
  F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
  let initial = First_run.initial ~source_path:path ~read_error in
  let outcome = ref None in
  (match
     Async.Thread_safe.block_on_async_exn (fun () ->
       B.start_with_exit ~dispose:true ~mouse:B.Mouse_reporting.No_mouse_events ~bpaste:true
         (first_run_app ?annual_year initial ~outcome))
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

let run ?annual_year path =
  F.check_annual_path annual_year path;
  match
    try Ok (F.load ?annual_year path)
    with
    | F.Refused why -> Error why
    | Unix.Unix_error (error, _, _) -> Error (Unix.error_message error)
    | Sys_error why -> Error why
  with
  | Ok session ->
      F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
      run_loaded session
  | Error why ->
      (match start_first_run ?annual_year path why with
       | None -> ()
       | Some session -> run_loaded session)

let self_check () =
  Recovery_checks.self_check ();
  Stock_flow_checks.self_check ();
  First_run.check ~width_of ();
  let state = Daily_interaction_checks.self_check ~width_of () in
  Record_session_checks.self_check ~width_of ();
  Scheduled_session_checks.self_check ~width_of ();
  Actual_workspace_checks.self_check ();
  Scheduled_bulk_checks.self_check ~width_of ();
  Scheduled_generation_checks.self_check ~width_of ();
  let ansi view =
    let buffer = Buffer.create 128 in
    Notty.Render.to_buffer buffer Notty.Cap.ansi (0, 0) (V.width view, V.height view)
      (V.Private.notty_image view);
    Buffer.contents buffer
  in
  let slice left width view =
    V.crop ~l:left ~r:(max 0 (V.width view - left - width)) view
  in
  let field = lines ~border:`Create P.Terminal [ (C.Input 9, "│ Date: x|y │") ] in
  List.iter
    (fun (intent, terminal_color, light_index, dark_index) ->
      List.iter
        (fun (theme, expected) ->
          let field = lines ~border:intent theme [ (C.Input 9, "│ Date: x|y │") ] in
          F.require
            (ansi (slice 0 1 field) = ansi (V.text ~attrs:[ B.Attr.fg expected ] "│"))
            "Bonsai-editor-theme-owned-semantic-border")
        [ P.Terminal, terminal_color;
          P.Bakhlo_light, B.Attr.Color.xterm_256 light_index;
          P.Bakhlo_dark, B.Attr.Color.xterm_256 dark_index ])
    [ `Create, B.Attr.Color.Expert.cyan, 31, 67;
      `Change, B.Attr.Color.Expert.yellow, 136, 179;
      `Cancel, B.Attr.Color.Expert.red, 131, 174 ];
  F.require
    (ansi (slice 2 7 field) = ansi (V.text "Date: x"))
    "Bonsai-editor-body-remains-neutral";
  F.require
    (ansi (slice 9 1 field) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "|"))
    "Bonsai-editor-caret-is-distinct";
  let literal = lines ~border:`Create P.Terminal [ (C.Input 9, "│ Date: ||│ │") ] in
  F.require (ansi (slice 8 1 literal) = ansi (V.text "|"))
    "Bonsai-literal-bar-is-not-a-caret";
  F.require (ansi (slice 10 1 literal) = ansi (V.text "│"))
    "Bonsai-literal-box-glyph-is-not-a-border";
  let dates = lines P.Terminal [ (C.Calendar_dates, "│ [16] 17 │") ] in
  F.require
    (ansi (slice 2 4 dates) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "[16]"))
    "Bonsai-calendar-selected-cell-only";
  F.require (ansi (slice 7 2 dates) = ansi (V.text "17"))
    "Bonsai-calendar-neighbor-remains-neutral";
  let columns = lines P.Terminal [C.Columns (4, C.Plain, C.Active), "財布 x"] in
  F.require (ansi (slice 0 4 columns) = ansi (V.text "財布"))
    "Bonsai-columns-retain-unfocused-unicode-pane";
  F.require
    (ansi (slice 5 1 columns) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "x"))
    "Bonsai-columns-focus-only-the-selected-pane";
  let panes = lines P.Terminal [ C.Columns (3, C.Input 0, C.Active), "|ab 財布" ] in
  F.require
    (ansi (slice 0 1 panes) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "|")
     && ansi (slice 1 2 panes) = ansi (V.text "ab")
     && ansi (slice 4 4 panes) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "財布"))
    "Bonsai-columns-preserve-input-and-independent-active-pane";
  let panes = lines P.Terminal [ C.Columns (4, C.Plain, C.Input 0), "財布 |ab" ] in
  F.require
    (ansi (slice 0 4 panes) = ansi (V.text "財布")
     && ansi (slice 5 1 panes) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "|")
     && ansi (slice 6 2 panes) = ansi (V.text "ab"))
    "Bonsai-columns-right-caret-does-not-color-left-pane";
  let nested = lines P.Terminal
      [ C.Columns (2, C.Plain, C.Columns (4, C.Plain, C.Input 0)), "ab 財布 |x" ] in
  F.require
    (ansi (slice 0 2 nested) = ansi (V.text "ab")
     && ansi (slice 3 4 nested) = ansi (V.text "財布")
     && ansi (slice 8 1 nested) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "|"))
    "Bonsai-nested-columns-preserve-native-caret-style";
  List.iter
    (fun (style, expected) ->
      F.require
        (B.Attr.equal (B.Attr.many (attributes P.Terminal style)) expected)
        "Bonsai-terminal-default-style")
    [
      (C.Plain, B.Attr.empty);
      (C.Active, B.Attr.many [ B.Attr.fg B.Attr.Color.Expert.cyan; B.Attr.invert; B.Attr.bold ]);
      (C.Heading, B.Attr.bold);
      (C.Status, B.Attr.bold);
      (C.Chrome, B.Attr.empty);
      (C.Frame, B.Attr.empty);
      (C.Focused_frame, B.Attr.many [ B.Attr.fg B.Attr.Color.Expert.cyan; B.Attr.bold ]);
      (C.Panel, B.Attr.empty);
      (C.Panel_heading, B.Attr.bold);
      (C.Panel_active, B.Attr.many [ B.Attr.fg B.Attr.Color.Expert.cyan; B.Attr.invert; B.Attr.bold ]);
    ];
  List.iter
    (fun theme ->
      List.iter
        (fun ((width, height) as dimensions) ->
          List.iter
            (fun state ->
              let state = { state with C.theme } in
              let overlay = state.C.overlay in
              let view = render dimensions state in
              F.require (V.width view = width && V.height view = height) "Bonsai-geometry";
              let ansi = Buffer.create 1024 in
              Notty.Render.to_buffer ansi Notty.Cap.ansi (0, 0) dimensions
                (V.Private.notty_image view);
              let emits substring = Base.String.is_substring (Buffer.contents ansi) ~substring in
              F.require ((not (emits "38;2;")) && not (emits "48;2;")) "Bonsai-no-truecolor-SGR";
              (match P.palette theme with
              | None ->
                  F.require
                    (not (emits "38;5;") && not (emits "48;"))
                    "Bonsai-terminal-owned-colors-including-editor"
              | Some palette ->
                  let foreground, background =
                    if overlay = C.No_overlay && not (C.editor_visible state) then
                      (palette.foreground, palette.background)
                    else (palette.panel_foreground, palette.panel_background)
                  in
                  F.require
                    (emits (Printf.sprintf "38;5;%d" foreground.index)
                    && emits (Printf.sprintf "48;5;%d" background.index))
                    "Bonsai-shared-indexed-palette");
              match overlay_screen dimensions state with
              | Some rows ->
                  F.require (rows <> []) "Bonsai-panel-not-empty";
                  let pane_width = width_of (snd (List.hd rows)) in
                  F.require
                    (List.for_all (fun (_, text) -> width_of text = pane_width) rows)
                    (Printf.sprintf "Bonsai-panel-uniform-cell-width:%dx%d:%s" width height
                       (String.concat "," (List.map (fun (_, text) ->
                            string_of_int (width_of text)) rows)));
                  F.require
                    (pane_width <= width && List.length rows <= height)
                    "Bonsai-panel-bounded-to-terminal";
                  if width >= pane_width && height >= List.length rows then (
                    let left, top =
                      C.overlay_position ~dimensions ~width_of state ~pane_width
                        ~pane_height:(List.length rows)
                    in
                    F.require
                      (left >= 0 && top >= 0 && left + pane_width <= width
                      && top + List.length rows <= height)
                      "Bonsai-panel-position-bounded";
                    let buffer = Buffer.create 512 in
                    let pane =
                      Notty.I.crop ~l:left ~t:top
                        ~r:(width - left - pane_width)
                        ~b:(height - top - List.length rows)
                        (V.Private.notty_image view)
                    in
                    Notty.Render.to_buffer buffer Notty.Cap.dumb (0, 0)
                      (pane_width, List.length rows)
                      pane;
                    F.require
                      (Buffer.contents buffer = String.concat "\n" (List.map snd rows))
                      "Bonsai-overlay-front-and-centered")
              | None -> ())
            (Daily_interaction_checks.render_cases state))
        [ (140, 40); (100, 25); (80, 24); (64, 20); (48, 14); (40, 10); (32, 9); (20, 5) ])
    P.all_themes;
  List.iter
    (fun theme ->
      List.iter
        (fun state ->
          let state = { state with C.theme; blocked = true; message = "household-warning" } in
          let view =
            render (64, 20) state
          in
          let buffer = Buffer.create 64 in
          Notty.Render.to_buffer buffer Notty.Cap.dumb (0, 0) (64, 1)
            (V.Private.notty_image (V.crop ~t:17 ~b:2 view));
          F.require
            (String.trim (Buffer.contents buffer) = "household-warning")
            "Bonsai-overlay-household-warning-visible")
        (Daily_interaction_checks.render_cases state))
    P.all_themes;
  List.iter
    (fun theme ->
      List.iter
        (fun ((width, height) as dimensions) ->
          List.iter
            (fun state ->
              let state =
                { state with C.theme; blocked = true;
                  message = String.concat "" (List.init 12 (fun _ -> "Stop 日本語 warning ")) }
              in
              let feedback = C.feedback_lines ~dimensions ~width_of state in
              let feedback_height = List.length feedback in
              F.require (feedback_height > 1) "Bonsai-long-warning-wrapped";
              F.require
                (List.for_all (fun (_, row) -> width_of row <= width) feedback)
                "Bonsai-feedback-cell-width-bounded";
              let view = render dimensions state in
              let buffer = Buffer.create 512 in
              let top = height - 2 - feedback_height in
              F.require (top >= 0) "Bonsai-feedback-bounded";
              let image =
                Notty.I.crop ~t:top ~b:2 (V.Private.notty_image view)
              in
              Notty.Render.to_buffer buffer Notty.Cap.dumb (0, 0)
                (width, feedback_height) image;
              let expected = Buffer.create 512 in
              let feedback_image =
                lines theme feedback |> fit width feedback_height |> V.Private.notty_image
              in
              Notty.Render.to_buffer expected Notty.Cap.dumb (0, 0)
                (width, feedback_height) feedback_image;
              let physical_rows text =
                String.split_on_char '\n' text
                |> List.map (fun row ->
                    let rec last n =
                      if n > 0 && row.[n - 1] = ' ' then last (n - 1) else n
                    in
                    String.sub row 0 (last (String.length row)))
              in
              F.require
                (physical_rows (Buffer.contents buffer) = physical_rows (Buffer.contents expected))
                "Bonsai-long-warning-visible-above-footer")
            (Daily_interaction_checks.render_cases state))
        [ (48, 14); (80, 24); (140, 40) ])
    P.all_themes;
  F.require (V.width (V.text "財布") = 4) "Bonsai-unicode-width";
  F.require
    (match
       C.handle state
         (input_of_event
            (B.Event.Key_press { key = B.Event.Key.ASCII 'Q'; mods = [ B.Event.Modifier.Ctrl ] }))
     with
    | None -> true
    | Some _ -> false)
    "Bonsai-event-adapter";
  List.iter
    (fun key ->
      let event = B.Event.Key_press { key; mods = [] } in
      F.require
        (match C.handle state (input_of_event event) with
        | Some opened -> overlay_screen (80, 24) opened <> None
        | None -> false)
        "Bonsai-space-event-to-shared-overlay")
    [ B.Event.Key.ASCII ' '; B.Event.Key.Uchar (Uchar.of_int 0x20) ];
  F.require
    (match
       C.handle state
         (input_of_event
            (B.Event.Key_press { key = B.Event.Key.ASCII 'r'; mods = [] }))
     with
    | Some editor -> C.editor_visible editor
    | None -> false)
    "Bonsai-record-workspace-adapter";
  let paste = input_of_event (B.Event.Paste `Start) in
  F.require (paste = `Paste `Start) "Bonsai-paste-adapter";
  print_endline
    "PASS: Bonsai cell-width geometry, cyan/default and indexed colors/no truecolor, front overlays, \
     visible warnings, English Record and event adapters."

let print_recovery path =
  let report = F.inspect_recovery path in
  (match report.selected with
  | Ok _ -> print_endline "selected: admitted (no payload output)"
  | Error why -> Printf.printf "selected: unavailable (%s)\n" why);
  List.iter
    (fun (item : F.recovery_item) ->
      let state =
        match item.comparison with
        | F.Candidate_current -> "candidate-is-current"
        | F.Before_current -> "before-is-current"
        | F.Unresolved -> "unresolved"
        | F.Unreadable why -> "unreadable: " ^ why
      in
      Printf.printf "artifact=%S attempt=%s state=%s\n" item.name
        (Option.value ~default:"unknown" item.attempt_id)
        state)
    report.items;
  if report.items <> [] then
    print_endline
      "REVIEW REQUIRED: no adoption/retry. Equality describes current bytes, not past outcome.";
  match (report.selected, report.items) with
  | Ok _, [] ->
      print_endline "No unfinished artifacts found.";
      0
  | Ok _, _ -> 3
  | Error _, _ -> 1

let print_annual_rollover_preview (p : F.annual_rollover_preview) =
  Printf.printf "Read-only prior-year closing preview (NOT target-year balance)\n";
  Printf.printf "Prior year: %04d (fingerprint %s)\n" p.prior_year p.prior_fingerprint;
  Printf.printf "Current year: %04d (fingerprint %s)\n" p.year p.current_fingerprint;
  List.iter
    (fun (coord, balance) ->
      let locus = D.Identifier.Locus.to_string coord.D.Effect_coordinate.locus in
      let measure = D.Identifier.Measure.to_string coord.D.Effect_coordinate.measure in
      let balance_str =
        match balance with
        | Y.Exact q ->
            Printf.sprintf "Exact %s %S" (Z.to_string (D.Quantity.quanta q)) measure
        | Y.Zero_origin -> "Zero_origin (distinct exact zero premise)"
        | Y.Known_present -> "Known_present (amount unknown)"
        | Y.Unknown -> "Unknown (not zero)"
      in
      Printf.printf "Coordinate (%S, %S): %s\n" locus measure balance_str)
    p.balances;
  if p.open_plans = [] then
    Printf.printf "Surviving open plans from %04d: none (read-only; not imported, not payable)\n" p.prior_year
  else (
    Printf.printf "Surviving open plans from %04d (read-only; not imported, not payable):\n" p.prior_year;
    List.iter
      (fun (plan : Bakhlo_sexp.Daily_book.plan) ->
        let changes_str =
          String.concat ", "
            (List.map (fun (loc, amt) -> Printf.sprintf "%S: %s" loc (Z.to_string amt)) plan.changes)
        in
        Printf.printf "  Plan ID: %S | Day: %S | Measure: %S | Changes: [%s]\n"
          plan.id plan.day plan.measure changes_str)
      p.open_plans)

let () =
  try
    match Array.to_list Sys.argv with
    | [ _; "--self-check" ] -> self_check ()
    | [ _; "--book"; path ] -> run path
    | [ _; "--annual-book"; year; "--book"; path ] ->
        let year = match Annual.of_string year with
          | Ok year -> year | Error why -> raise (F.Refused why) in
        run ~annual_year:year path
    | [ _; "--annual-check"; year; "--book"; path ] ->
        let year = match Annual.of_string year with
          | Ok year -> year | Error why -> raise (F.Refused why) in
        ignore (F.load ~annual_year:year path);
        print_endline "PASS: annual book admitted (no payload output; no carried balance claimed)."
    | [ _; "--annual-list"; directory ] ->
        let books = F.list_annual_books ~directory in
        if books = [] then
          print_endline "No YYYY.sexp books found. No opening balance is inferred."
        else
          List.iter (fun (book : F.annual_book_summary) ->
            Printf.printf "%04d  Actual %d  open Scheduled %d  (file-local; no carry)\n"
              book.year book.entries book.open_plans)
            books
    | [ _; "--annual-rollover-preview"; year; "--directory"; directory; "--coordinate"; locus; measure ] ->
        let year = match Annual.of_string year with
          | Ok year -> year | Error why -> raise (F.Refused why) in
        let locus = match D.Identifier.Locus.of_string locus with
          | Ok locus -> locus | Error _ -> raise (F.Refused "invalid-locus") in
        let measure = match D.Identifier.Measure.of_string measure with
          | Ok measure -> measure | Error _ -> raise (F.Refused "invalid-measure") in
        let coordinate : D.Effect_coordinate.t = { locus; measure } in
        let preview = F.preview_annual_rollover ~directory ~year ~coordinates:[ coordinate ] in
        print_annual_rollover_preview preview
    | [ _; "--check"; path ] ->
        ignore (F.load path);
        print_endline "PASS: daily book admitted (no payload output)."
    | [ _; "--copy-from"; source; "--book"; target ] ->
        F.create_copy ~source ~target;
        print_endline "PASS: fresh trial copy created; original unchanged."
    | [ _; "--inspect-recovery"; "--book"; path ] -> exit (print_recovery path)
    | [ _; "--confirm-current-attempt"; id; "--book"; path ] ->
        ignore (F.confirm_current ~session:(F.load path) ~attempt_id:id);
        print_endline "Current candidate confirmed; backup files untouched. No retry."
    | [ _; "--restore-copy-from"; source; "--book"; target ] ->
        F.restore_copy ~source ~target;
        print_endline
          "Checked byte-exact recovery copy created. Original/artifacts unchanged; adoption is \
           explicit."
    | _ ->
        prerr_endline
          "Usage: tools/tui --book FILE | --annual-book YYYY --book YYYY.sexp | --annual-check YYYY --book YYYY.sexp | --annual-list DIR | --annual-rollover-preview YYYY --directory DIR --coordinate LOCUS MEASURE | --check FILE | --copy-from SOURCE --book FRESH_FILE | \
           --inspect-recovery --book FILE | --confirm-current-attempt ID --book FILE | \
           --restore-copy-from SOURCE --book FRESH_FILE";
        exit 2
  with
  | F.Refused why when Array.to_list Sys.argv = [ Sys.argv.(0); "--self-check" ] ->
      prerr_endline ("self-check failed: " ^ why);
      exit 1
  | F.Refused why
    when Array.length Sys.argv > 1
         && List.mem Sys.argv.(1)
              [ "--inspect-recovery"; "--confirm-current-attempt"; "--restore-copy-from" ] ->
      prerr_endline ("Recovery refused: " ^ why ^ "; no automatic adoption or retry.");
      exit 1
  | F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
      prerr_endline
        "TUI/recovery refused: input/file/terminal unavailable; no empty fallback. Remaining \
         artifacts are not automatically adopted or pruned.";
      exit 1
