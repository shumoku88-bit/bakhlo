(* Notty adapter checks: cell geometry, colours, overlay placement, feedback visibility
   and event translation over the synthetic scenario states (ported from Bonsai). *)
open Notty_render
module F = Daily_file
module X = Shell_dispatch
module H = Shell_input
module O = Daily_overlays

let run () =
  let directory = "scratch/terminal-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.txt" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let state = C.initial ~config_home:directory (F.load path) in
  let ansi image =
    let buffer = Buffer.create 128 in
    Notty.Render.to_buffer buffer Notty.Cap.ansi (0, 0) (I.width image, I.height image) image;
    Buffer.contents buffer
  in
  let slice left width image = I.crop ~l:left ~r:(max 0 (I.width image - left - width)) image in
  let field = lines ~border:`Create P.Terminal [ (C.Input 9, "│ Date: x|y │") ] in
  List.iter
    (fun (intent, terminal_color, light_index, dark_index) ->
      List.iter
        (fun (theme, expected) ->
          let field = lines ~border:intent theme [ (C.Input 9, "│ Date: x|y │") ] in
          F.require
            (ansi (slice 0 1 field) = ansi (text ~attr:(A.fg expected) "│"))
            "Notty-editor-theme-owned-semantic-border")
        [
          (P.Terminal, terminal_color);
          (P.Bakhlo_light, xterm light_index);
          (P.Bakhlo_dark, xterm dark_index);
        ])
    [ (`Create, A.cyan, 31, 67); (`Change, A.yellow, 136, 179); (`Cancel, A.red, 131, 174) ];
  F.require (ansi (slice 2 7 field) = ansi (text "Date: x")) "Notty-editor-body-remains-neutral";
  F.require
    (ansi (slice 9 1 field) = ansi (text ~attr:(attributes P.Terminal C.Active) "|"))
    "Notty-editor-caret-is-distinct";
  let literal = lines ~border:`Create P.Terminal [ (C.Input 9, "│ Date: ||│ │") ] in
  F.require (ansi (slice 8 1 literal) = ansi (text "|")) "Notty-literal-bar-is-not-a-caret";
  F.require (ansi (slice 10 1 literal) = ansi (text "│")) "Notty-literal-box-glyph-is-not-a-border";
  let columns = lines P.Terminal [ (C.Columns (4, C.Plain, C.Active), "財布 x") ] in
  F.require
    (ansi (slice 0 4 columns) = ansi (text "財布"))
    "Notty-columns-retain-unfocused-unicode-pane";
  F.require
    (ansi (slice 5 1 columns) = ansi (text ~attr:(attributes P.Terminal C.Active) "x"))
    "Notty-columns-focus-only-the-selected-pane";
  let panes = lines P.Terminal [ (C.Columns (3, C.Input 0, C.Active), "|ab 財布") ] in
  F.require
    (ansi (slice 0 1 panes) = ansi (text ~attr:(attributes P.Terminal C.Active) "|")
    && ansi (slice 1 2 panes) = ansi (text "ab")
    && ansi (slice 4 4 panes) = ansi (text ~attr:(attributes P.Terminal C.Active) "財布"))
    "Notty-columns-preserve-input-and-independent-active-pane";
  let panes = lines P.Terminal [ (C.Columns (4, C.Plain, C.Input 0), "財布 |ab") ] in
  F.require
    (ansi (slice 0 4 panes) = ansi (text "財布")
    && ansi (slice 5 1 panes) = ansi (text ~attr:(attributes P.Terminal C.Active) "|")
    && ansi (slice 6 2 panes) = ansi (text "ab"))
    "Notty-columns-right-caret-does-not-color-left-pane";
  let nested =
    lines P.Terminal [ (C.Columns (2, C.Plain, C.Columns (4, C.Plain, C.Input 0)), "ab 財布 |x") ]
  in
  F.require
    (ansi (slice 0 2 nested) = ansi (text "ab")
    && ansi (slice 3 4 nested) = ansi (text "財布")
    && ansi (slice 8 1 nested) = ansi (text ~attr:(attributes P.Terminal C.Active) "|"))
    "Notty-nested-columns-preserve-native-caret-style";
  (* The chart series colours: the terminal's own ANSI slots in the Terminal
     theme, the theme's indexed palette otherwise, and never a truecolor. The
     Terminal slots are the user's choice: blue, magenta, yellow, then cyan;
     no red and no green. *)
  List.iter
    (fun (theme, expected) ->
      let series = lines theme [ (C.Series 0, "●") ] in
      F.require
        (ansi (slice 0 1 series) = ansi (text ~attr:(A.fg expected) "●"))
        "Notty-series-colour-matches-the-theme")
    [ (P.Terminal, A.blue); (P.Bakhlo_light, xterm 25); (P.Bakhlo_dark, xterm 75) ];
  List.iter
    (fun index ->
      let series = lines P.Terminal [ (C.Series index, "●") ] in
      F.require
        (ansi (slice 0 1 series) <> ansi (text "●"))
        "Notty-every-terminal-series-slot-has-a-colour")
    [ 0; 1; 2; 3 ];
  F.require
    (not
       (List.exists
          (fun index ->
            let attr = attributes P.Terminal (C.Series index) in
            A.equal attr (A.fg A.red) || A.equal attr (A.fg A.green))
          [ 0; 1; 2; 3 ]))
    "Notty-terminal-series-avoid-red-and-green";
  F.require
    (A.equal (attributes P.Terminal (C.Series 2)) (A.fg A.yellow)
    && not
         (List.exists
            (fun index -> A.equal (attributes P.Terminal (C.Series index)) (A.fg A.cyan))
            [ 0; 1; 2 ]))
    "Notty-three-terminal-series-keep-blue-apart-from-cyan";
  let spanned = lines P.Terminal [ (C.Spans [ (C.Plain, "a"); (C.Series 1, "b") ], "ab") ] in
  F.require
    (ansi (slice 0 1 spanned) = ansi (text "a")
    && ansi (slice 1 1 spanned) = ansi (text ~attr:(A.fg A.magenta) "b"))
    "Notty-span-cells-keep-their-own-style";
  let neutral = lines P.Terminal [ (C.Series 9, "●") ] in
  F.require (ansi (slice 0 1 neutral) = ansi (text "●")) "Notty-a-further-series-stays-neutral";
  List.iter
    (fun (style, expected) ->
      F.require (A.equal (attributes P.Terminal style) expected) "Notty-terminal-default-style")
    [
      (C.Plain, A.empty);
      (C.Active, active);
      (C.Heading, bold);
      (C.Status, bold);
      (C.Chrome, A.empty);
      (C.Frame, A.empty);
      (C.Focused_frame, A.(fg cyan ++ st bold));
      (C.Panel, A.empty);
      (C.Panel_heading, bold);
      (C.Panel_active, active);
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
              F.require (I.width view = width && I.height view = height) "Notty-geometry";
              let ansi = Buffer.create 1024 in
              Notty.Render.to_buffer ansi Notty.Cap.ansi (0, 0) dimensions view;
              let emits substring = Base.String.is_substring (Buffer.contents ansi) ~substring in
              F.require ((not (emits "38;2;")) && not (emits "48;2;")) "Notty-no-truecolor-SGR";
              (match P.palette theme with
              | None ->
                  F.require
                    ((not (emits "38;5;")) && not (emits "48;"))
                    "Notty-terminal-owned-colors-including-editor"
              | Some palette ->
                  let foreground, background =
                    if overlay = C.No_overlay && not (C.editor_visible state) then
                      (palette.foreground, palette.background)
                    else (palette.panel_foreground, palette.panel_background)
                  in
                  F.require
                    (emits (Printf.sprintf "38;5;%d" foreground.index)
                    && emits (Printf.sprintf "48;5;%d" background.index))
                    "Notty-shared-indexed-palette");
              match overlay_screen dimensions state with
              | Some rows ->
                  F.require (rows <> []) "Notty-panel-not-empty";
                  let pane_width = width_of (snd (List.hd rows)) in
                  F.require
                    (List.for_all (fun (_, text) -> width_of text = pane_width) rows)
                    (Printf.sprintf "Notty-panel-uniform-cell-width:%dx%d:%s" width height
                       (String.concat ","
                          (List.map (fun (_, text) -> string_of_int (width_of text)) rows)));
                  F.require
                    (pane_width <= width && List.length rows <= height)
                    "Notty-panel-bounded-to-terminal";
                  if width >= pane_width && height >= List.length rows then (
                    let left, top =
                      R.overlay_position ~dimensions ~width_of state ~pane_width
                        ~pane_height:(List.length rows)
                    in
                    F.require
                      (left >= 0 && top >= 0
                      && left + pane_width <= width
                      && top + List.length rows <= height)
                      "Notty-panel-position-bounded";
                    let buffer = Buffer.create 512 in
                    let pane =
                      Notty.I.crop ~l:left ~t:top
                        ~r:(width - left - pane_width)
                        ~b:(height - top - List.length rows)
                        view
                    in
                    Notty.Render.to_buffer buffer Notty.Cap.dumb (0, 0)
                      (pane_width, List.length rows)
                      pane;
                    F.require
                      (Buffer.contents buffer = String.concat "\n" (List.map snd rows))
                      "Notty-overlay-front-and-centered")
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
          Notty.Render.to_buffer buffer Notty.Cap.dumb (0, 0) (64, 2) (I.crop ~t:16 ~b:2 view);
          F.require
            (List.exists
               (fun line -> String.trim line = "household-warning")
               (String.split_on_char '\n' (Buffer.contents buffer)))
            "Notty-overlay-household-warning-visible")
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
              F.require (feedback_height > 1) "Notty-long-warning-wrapped";
              F.require
                (List.for_all (fun (_, row) -> width_of row <= width) feedback)
                "Notty-feedback-cell-width-bounded";
              let view = render dimensions state in
              let buffer = Buffer.create 512 in
              let top = height - reserved - 2 - feedback_height in
              F.require (top >= 0) "Notty-feedback-bounded";
              let image = Notty.I.crop ~t:top ~b:(2 + reserved) view in
              Notty.Render.to_buffer buffer Notty.Cap.dumb (0, 0) (width, feedback_height) image;
              let expected = Buffer.create 512 in
              let feedback_image = lines theme feedback |> fit width feedback_height in
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
                "Notty-long-warning-visible-above-footer")
            (Interaction_render_fixture.render_cases state))
        [ (48, 14); (80, 24); (140, 40) ])
    P.all_themes;
  F.require (width_of "財布" = 4) "Notty-unicode-width";
  F.require
    (match H.handle state (input_of_event (`Key (`ASCII (Char.chr 81), [ `Ctrl ]))) with
    | None -> true
    | Some _ -> false)
    "Notty-event-adapter";
  List.iter
    (fun key ->
      let event = `Key (key, []) in
      F.require
        (match H.handle state (input_of_event event) with
        | Some opened -> overlay_screen (80, 24) opened <> None
        | None -> false)
        "Notty-space-event-to-shared-overlay")
    [ `ASCII (Char.chr 32); `Uchar (Uchar.of_int 0x20) ];
  F.require
    (match H.handle state (input_of_event (`Key (`ASCII (Char.chr 114), []))) with
    | Some editor -> C.editor_visible editor
    | None -> false)
    "Notty-record-workspace-adapter";
  let paste = input_of_event (`Paste `Start) in
  F.require (paste = `Paste `Start) "Notty-paste-adapter";
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
    "PASS: Notty cell-width geometry, cyan/default and indexed colors/no truecolor, front \
     overlays, visible warnings, English Record and event adapters."
