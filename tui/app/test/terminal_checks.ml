(* Bonsai adapter checks: cell geometry, colours, overlay placement, feedback
   visibility and event translation over the synthetic scenario states. *)
open Bonsai_terminal

let run () =
  let directory = "scratch/terminal-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let state = C.initial ~config_home:directory (F.load path) in
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
                      R.overlay_position ~dimensions ~width_of state ~pane_width
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
            (Interaction_render_fixture.render_cases state))
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
        (Interaction_render_fixture.render_cases state))
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
              let feedback = X.feedback_lines ~dimensions ~width_of state in
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
            (Interaction_render_fixture.render_cases state))
        [ (48, 14); (80, 24); (140, 40) ])
    P.all_themes;
  F.require (V.width (V.text "財布") = 4) "Bonsai-unicode-width";
  F.require
    (match
       H.handle state
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
        (match H.handle state (input_of_event event) with
        | Some opened -> overlay_screen (80, 24) opened <> None
        | None -> false)
        "Bonsai-space-event-to-shared-overlay")
    [ B.Event.Key.ASCII ' '; B.Event.Key.Uchar (Uchar.of_int 0x20) ];
  F.require
    (match
       H.handle state
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
