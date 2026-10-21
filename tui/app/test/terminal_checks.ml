(* Bonsai adapter checks: cell geometry, colours, overlay placement, feedback
   visibility and event translation over the synthetic scenario states. *)
open Bonsai_terminal
module O = Daily_overlays

let run () =
  let directory = "scratch/terminal-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let state = C.initial ~config_home:directory (F.load path) in
  let ansi view =
    let buffer = Buffer.create 128 in
    Notty.Render.to_buffer buffer Notty.Cap.ansi (0, 0)
      (V.width view, V.height view)
      (V.Private.notty_image view);
    Buffer.contents buffer
  in
  let slice left width view = V.crop ~l:left ~r:(max 0 (V.width view - left - width)) view in
  let field = lines ~border:`Create P.Terminal [ (C.Input 9, "│ Date: x|y │") ] in
  List.iter
    (fun (intent, terminal_color, light_index, dark_index) ->
      List.iter
        (fun (theme, expected) ->
          let field = lines ~border:intent theme [ (C.Input 9, "│ Date: x|y │") ] in
          F.require
            (ansi (slice 0 1 field) = ansi (V.text ~attrs:[ B.Attr.fg expected ] "│"))
            "Bonsai-editor-theme-owned-semantic-border")
        [
          (P.Terminal, terminal_color);
          (P.Bakhlo_light, B.Attr.Color.xterm_256 light_index);
          (P.Bakhlo_dark, B.Attr.Color.xterm_256 dark_index);
        ])
    [
      (`Create, B.Attr.Color.Expert.cyan, 31, 67);
      (`Change, B.Attr.Color.Expert.yellow, 136, 179);
      (`Cancel, B.Attr.Color.Expert.red, 131, 174);
    ];
  F.require (ansi (slice 2 7 field) = ansi (V.text "Date: x")) "Bonsai-editor-body-remains-neutral";
  F.require
    (ansi (slice 9 1 field) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "|"))
    "Bonsai-editor-caret-is-distinct";
  let literal = lines ~border:`Create P.Terminal [ (C.Input 9, "│ Date: ||│ │") ] in
  F.require (ansi (slice 8 1 literal) = ansi (V.text "|")) "Bonsai-literal-bar-is-not-a-caret";
  F.require
    (ansi (slice 10 1 literal) = ansi (V.text "│"))
    "Bonsai-literal-box-glyph-is-not-a-border";
  let dates = lines P.Terminal [ (C.Calendar_dates, "│ [16] 17 │") ] in
  F.require
    (ansi (slice 2 4 dates) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "[16]"))
    "Bonsai-calendar-selected-cell-only";
  F.require (ansi (slice 7 2 dates) = ansi (V.text "17")) "Bonsai-calendar-neighbor-remains-neutral";
  let columns = lines P.Terminal [ (C.Columns (4, C.Plain, C.Active), "財布 x") ] in
  F.require
    (ansi (slice 0 4 columns) = ansi (V.text "財布"))
    "Bonsai-columns-retain-unfocused-unicode-pane";
  F.require
    (ansi (slice 5 1 columns) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "x"))
    "Bonsai-columns-focus-only-the-selected-pane";
  let panes = lines P.Terminal [ (C.Columns (3, C.Input 0, C.Active), "|ab 財布") ] in
  F.require
    (ansi (slice 0 1 panes) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "|")
    && ansi (slice 1 2 panes) = ansi (V.text "ab")
    && ansi (slice 4 4 panes) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "財布"))
    "Bonsai-columns-preserve-input-and-independent-active-pane";
  let panes = lines P.Terminal [ (C.Columns (4, C.Plain, C.Input 0), "財布 |ab") ] in
  F.require
    (ansi (slice 0 4 panes) = ansi (V.text "財布")
    && ansi (slice 5 1 panes) = ansi (V.text ~attrs:(attributes P.Terminal C.Active) "|")
    && ansi (slice 6 2 panes) = ansi (V.text "ab"))
    "Bonsai-columns-right-caret-does-not-color-left-pane";
  let nested =
    lines P.Terminal [ (C.Columns (2, C.Plain, C.Columns (4, C.Plain, C.Input 0)), "ab 財布 |x") ]
  in
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
      ( C.Panel_active,
        B.Attr.many [ B.Attr.fg B.Attr.Color.Expert.cyan; B.Attr.invert; B.Attr.bold ] );
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
                    ((not (emits "38;5;")) && not (emits "48;"))
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
                       (String.concat ","
                          (List.map (fun (_, text) -> string_of_int (width_of text)) rows)));
                  F.require
                    (pane_width <= width && List.length rows <= height)
                    "Bonsai-panel-bounded-to-terminal";
                  if width >= pane_width && height >= List.length rows then (
                    let left, top =
                      R.overlay_position ~dimensions ~width_of state ~pane_width
                        ~pane_height:(List.length rows)
                    in
                    F.require
                      (left >= 0 && top >= 0
                      && left + pane_width <= width
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
          let view = render (64, 20) state in
          (* Feedback sits on row 17, or row 16 when a LOAM workspace reserves
             the terminal's last row below the two navigation rows. *)
          let buffer = Buffer.create 128 in
          Notty.Render.to_buffer buffer Notty.Cap.dumb (0, 0) (64, 2)
            (V.Private.notty_image (V.crop ~t:16 ~b:2 view));
          F.require
            (List.exists
               (fun line -> String.trim line = "household-warning")
               (String.split_on_char '\n' (Buffer.contents buffer)))
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
                {
                  state with
                  C.theme;
                  blocked = true;
                  message = String.concat "" (List.init 12 (fun _ -> "Stop 日本語 warning "));
                }
              in
              (* A LOAM workspace wraps feedback in its canvas, one column narrower
                 and one row above the reserved last terminal row. *)
              let canvas = X.canvas_dimensions (X.route_layout state) dimensions in
              let reserved = snd dimensions - snd canvas in
              let feedback = X.feedback_lines ~dimensions:canvas ~width_of state in
              let feedback_height = List.length feedback in
              F.require (feedback_height > 1) "Bonsai-long-warning-wrapped";
              F.require
                (List.for_all (fun (_, row) -> width_of row <= width) feedback)
                "Bonsai-feedback-cell-width-bounded";
              let view = render dimensions state in
              let buffer = Buffer.create 512 in
              let top = height - reserved - 2 - feedback_height in
              F.require (top >= 0) "Bonsai-feedback-bounded";
              let image = Notty.I.crop ~t:top ~b:(2 + reserved) (V.Private.notty_image view) in
              Notty.Render.to_buffer buffer Notty.Cap.dumb (0, 0) (width, feedback_height) image;
              let expected = Buffer.create 512 in
              let feedback_image =
                lines theme feedback |> fit width feedback_height |> V.Private.notty_image
              in
              Notty.Render.to_buffer expected Notty.Cap.dumb (0, 0) (width, feedback_height)
                feedback_image;
              let physical_rows text =
                String.split_on_char '\n' text
                |> List.map (fun row ->
                    let rec last n = if n > 0 && row.[n - 1] = ' ' then last (n - 1) else n in
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
         (input_of_event (B.Event.Key_press { key = B.Event.Key.ASCII 'r'; mods = [] }))
     with
    | Some editor -> C.editor_visible editor
    | None -> false)
    "Bonsai-record-workspace-adapter";
  let paste = input_of_event (B.Event.Paste `Start) in
  F.require (paste = `Paste `Start) "Bonsai-paste-adapter";
  (* Shell boundary: a new Record's quick capture is one bounded framed modal
     over the parent screen. Its footer stays inside the frame, nothing
     detaches at the terminal bottom, and the caret is the local input cell
     placed inside that frame. *)
  let quick_footer = "[Tab] full form" in
  let opened = C.open_record state in
  let typed =
    List.fold_left
      (fun acc c ->
        match H.handle ~dimensions:(80, 24) ~width_of acc (`Key (`ASCII c, [])) with
        | Some next -> next
        | None -> acc)
      opened
      (List.init (String.length "Coffee") (String.get "Coffee"))
  in
  F.require
    (match typed.C.record with
    | Some record -> Record_session.in_quick_capture record
    | None -> false)
    "Shell-new-record-opens-the-quick-capture";
  F.require (C.editor_visible typed) "Shell-quick-capture-is-open";
  let framed = overlay_screen (80, 24) typed in
  F.require
    (match framed with Some rows -> List.length rows = 14 | None -> false)
    "Shell-quick-capture-is-one-fourteen-row-overlay";
  let rows = match framed with Some rows -> rows | None -> [] in
  F.require
    (String.starts_with (snd (List.nth rows 0)) ~prefix:"╭ Record"
    && String.starts_with (snd (List.nth rows 13)) ~prefix:"╰")
    "Shell-quick-capture-overlay-is-a-closed-frame";
  F.require
    (List.for_all
       (fun (i, (_, text)) -> i = 0 || i = 13 || String.starts_with text ~prefix:"│")
       (List.mapi (fun i row -> (i, row)) rows))
    "Shell-quick-capture-overlay-keeps-its-sides-closed";
  F.require
    (List.for_all (fun (_, text) -> width_of text = 75) rows)
    "Shell-quick-capture-overlay-rows-share-the-frame-width";
  let footer_rows =
    List.mapi (fun i (_, text) -> (i, text)) rows
    |> List.filter_map (fun (i, text) ->
        if Base.String.is_substring text ~substring:quick_footer then Some i else None)
  in
  F.require
    (footer_rows <> []
    && List.length footer_rows = 1
    && List.for_all (fun i -> i > 0 && i < 13) footer_rows)
    "Shell-quick-capture-footer-stays-inside-the-frame";
  let base = R.screen ~width_of (80, 24) typed in
  F.require
    (not
       (List.exists (fun (_, text) -> Base.String.is_substring text ~substring:quick_footer) base))
    "Shell-quick-capture-footer-is-not-detached-on-the-base-screen";
  let carets =
    List.mapi (fun i (style, _) -> match style with O.Input c -> Some (c, i) | _ -> None) rows
    |> List.filter_map (fun x -> x)
  in
  F.require (List.length carets = 1) "Shell-quick-capture-has-one-caret";
  let cell, row = match carets with [ (c, r) ] -> (c, r) | _ -> (0, 0) in
  let origin_x, origin_y =
    R.overlay_position ~dimensions:(80, 24) ~width_of typed ~pane_width:75 ~pane_height:14
  in
  F.require
    (R.cursor_position ~width_of (80, 24) typed = Some (origin_x + cell, origin_y + row))
    "Shell-quick-capture-caret-is-the-local-input-cell-inside-the-frame";
  F.require
    (cell > 0 && row > 0 && origin_x + cell < 80 && origin_y + row < 24)
    "Shell-quick-capture-caret-stays-inside-the-terminal";
  (* A small terminal keeps the capture whole and unframed: no overlay, bounded
     rows and the retained input. *)
  List.iter
    (fun (width, height) ->
      F.require
        (overlay_screen (width, height) typed = None)
        (Printf.sprintf "Shell-quick-capture-has-no-overlay-at-%dx%d" width height);
      let compact = R.screen ~width_of (width, height) typed in
      F.require
        (List.length compact <= height)
        (Printf.sprintf "Shell-quick-capture-rows-are-bounded-at-%dx%d" width height);
      F.require
        (List.for_all (fun (_, text) -> width_of text <= width) compact)
        (Printf.sprintf "Shell-quick-capture-width-is-bounded-at-%dx%d" width height);
      F.require
        (List.exists (fun (_, text) -> Base.String.is_substring text ~substring:"Coffee") compact)
        (Printf.sprintf "Shell-quick-capture-keeps-the-retained-input-at-%dx%d" width height);
      F.require
        (match R.cursor_position ~width_of (width, height) typed with
        | Some (col, row) -> col < width && row < height
        | None -> false)
        (Printf.sprintf "Shell-quick-capture-caret-is-bounded-at-%dx%d" width height))
    [ (48, 14); (32, 9) ];
  (* A warning that leaves no room for the frame drops the frame, not the
     notice. *)
  let warned = { typed with C.message = "household-warning" } in
  F.require
    (overlay_screen (57, 16) warned = None)
    "Shell-quick-capture-frame-is-dropped-when-a-warning-leaves-no-room";
  F.require
    (List.exists
       (fun (_, text) -> Base.String.is_substring text ~substring:"household-warning")
       (R.screen ~width_of (57, 16) warned))
    "Shell-quick-capture-keeps-the-household-warning-visible";
  (* Back at the full terminal the same input sits in the framed modal again. *)
  F.require
    (match overlay_screen (80, 24) typed with
    | Some rows ->
        List.length rows = 14
        && List.exists (fun (_, text) -> Base.String.is_substring text ~substring:quick_footer) rows
        && List.exists (fun (_, text) -> Base.String.is_substring text ~substring:"Coffee") rows
    | None -> false)
    "Shell-quick-capture-returns-to-the-framed-modal";
  print_endline
    "PASS: Bonsai cell-width geometry, cyan/default and indexed colors/no truecolor, front \
     overlays, visible warnings, English Record and event adapters."
