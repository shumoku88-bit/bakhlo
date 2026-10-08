(* Existing Bonsai_term state-machine/event loop; same daily actions and file owner. *)
module B = Bonsai_term
module Bonsai = B.Bonsai
module V = B.View
module C = Daily_interaction
module F = Daily_file
module P = Ui_preferences

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
      | C.Plain -> []
      | C.Active -> [ B.Attr.invert; B.Attr.bold ]
      | C.Heading | C.Status -> [ B.Attr.bold ]
      | C.Panel -> [ B.Attr.invert ]
      | C.Panel_heading -> [ B.Attr.invert; B.Attr.bold ]
      | C.Panel_active -> [ B.Attr.invert; B.Attr.bold; B.Attr.underline ])
  | Some palette -> (
      match style with
      | C.Plain -> [ fg palette.foreground; bg palette.background ]
      | C.Active -> [ fg palette.selected_foreground; bg palette.selected_background; B.Attr.bold ]
      | C.Heading -> [ fg palette.heading; bg palette.background; B.Attr.bold ]
      | C.Status -> [ fg palette.status; bg palette.background; B.Attr.bold ]
      | C.Panel -> [ fg palette.panel_foreground; bg palette.panel_background ]
      | C.Panel_heading -> [ fg palette.accent; bg palette.panel_background; B.Attr.bold ]
      | C.Panel_active ->
          [ fg palette.selected_foreground; bg palette.selected_background; B.Attr.bold ])

let lines theme rows =
  rows |> List.map (fun (style, text) -> V.text ~attrs:(attributes theme style) text) |> V.vcat

let backdrop theme view =
  match P.palette theme with
  | None -> view
  | Some palette ->
      V.with_colors ~fill_backdrop:true view ~fg:(color palette.foreground)
        ~bg:(color palette.background)

let width_of text = V.width (V.text text)
let overlay_screen dimensions state = C.overlay_screen ~dimensions ~width_of state

let render ((width, height) as dimensions) state =
  let base =
    C.screen ~width_of ~frontend:"Bonsai_term" dimensions state
    |> lines state.C.theme |> fit width height |> backdrop state.C.theme
  in
  match overlay_screen dimensions state with
  | None -> base
  | Some rows ->
      let pane = lines state.C.theme rows in
      let pane =
        match P.palette state.C.theme with
        | None -> pane
        | Some palette ->
            V.with_colors ~fill_backdrop:true pane ~fg:(color palette.panel_foreground)
              ~bg:(color palette.panel_background)
      in
      let left = max 0 ((width - V.width pane) / 2)
      and top = max 0 ((height - V.height pane) / 2) in
      V.zcat [ V.pad ~l:left ~t:top pane; base ] |> fit width height

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

let app initial ~exit ~dimensions graph =
  let state, inject =
    Bonsai.state_machine ~default_model:initial
      ~apply_action:(fun context state (dimensions, event) ->
        match C.handle ~dimensions ~width_of state (input_of_event event) with
        | Some state -> state
        | None ->
            Bonsai.Apply_action_context.schedule_event context (exit ());
            state)
      graph
  in
  let view =
    Bonsai.arr2 graph state dimensions ~f:(fun state (dimensions : B.Dimensions.t) ->
        render (dimensions.width, dimensions.height) state)
  in
  let handler =
    Bonsai.arr2 graph inject dimensions ~f:(fun inject (dimensions : B.Dimensions.t) event ->
        inject ((dimensions.width, dimensions.height), event))
  in
  (~view, ~handler)

let run path =
  let session = F.load path in
  F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
  match
    Async.Thread_safe.block_on_async_exn (fun () ->
        B.start_with_exit ~dispose:true ~mouse:B.Mouse_reporting.No_mouse_events ~bpaste:true
          (app (C.initial session)))
  with
  | Ok () -> ()
  | Error _ -> raise (F.Refused "Bonsai-terminal-unavailable")

let self_check () =
  let state = Daily_interaction_checks.self_check () in
  Recording_checks.self_check ~width_of ();
  List.iter
    (fun (style, expected) ->
      F.require
        (B.Attr.equal (B.Attr.many (attributes P.Terminal style)) expected)
        "Bonsai-terminal-default-style")
    [
      (C.Plain, B.Attr.empty);
      (C.Active, B.Attr.many [ B.Attr.invert; B.Attr.bold ]);
      (C.Heading, B.Attr.bold);
      (C.Status, B.Attr.bold);
      (C.Panel, B.Attr.invert);
      (C.Panel_heading, B.Attr.many [ B.Attr.invert; B.Attr.bold ]);
      (C.Panel_active, B.Attr.many [ B.Attr.invert; B.Attr.bold; B.Attr.underline ]);
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
                  F.require ((not (emits "38;")) && not (emits "48;")) "Bonsai-no-fixed-colors"
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
                  let pane_width = width_of (snd (List.hd rows)) in
                  F.require
                    (List.for_all (fun (_, text) -> width_of text = pane_width) rows)
                    "Bonsai-panel-uniform-cell-width";
                  if width >= pane_width && height >= List.length rows then (
                    let left = (width - pane_width) / 2 and top = (height - List.length rows) / 2 in
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
            (([
                C.No_overlay;
                C.Commands 0;
                C.Themes { selected = C.theme_index theme; original = theme };
                C.Loci
                  {
                    target = C.From_locus;
                    query = "";
                    selected = List.length (C.loci state.session.book) - 1;
                    notice = None;
                  };
                C.Loci { target = C.From_locus; query = ""; selected = 1; notice = None };
                C.Loci { target = C.To_locus; query = "no-match"; selected = 0; notice = None };
                C.Loci
                  {
                    target = C.To_locus;
                    query = String.concat "" (List.init 40 (fun _ -> "長い検索"));
                    selected = 0;
                    notice = None;
                  };
              ]
             |> List.map (fun overlay -> { state with C.overlay }))
            @ Daily_interaction_checks.posting_render_cases state
            @ Recording_checks.render_cases state))
        [ (100, 25); (64, 20); (40, 10); (20, 5) ])
    P.all_themes;
  List.iter
    (fun theme ->
      List.iter
        (fun state ->
          let view =
            render (64, 20) { state with C.theme; blocked = true; message = "household-warning" }
          in
          let buffer = Buffer.create 64 in
          Notty.Render.to_buffer buffer Notty.Cap.dumb (0, 0) (64, 1)
            (V.Private.notty_image (V.crop ~t:19 view));
          F.require
            (String.trim (Buffer.contents buffer) = "household-warning")
            "Bonsai-overlay-household-warning-visible")
        (([
            C.Commands 0;
            C.Themes { selected = 0; original = theme };
            C.Loci { target = C.From_locus; query = ""; selected = 0; notice = None };
          ]
         |> List.map (fun overlay -> { state with C.overlay }))
        @ Daily_interaction_checks.posting_render_cases state
        @ Recording_checks.render_cases state))
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
        (match C.handle { state with C.focus = C.Amount } (input_of_event event) with
        | Some { C.overlay = C.Commands 0; _ } -> true
        | Some _ | None -> false)
        "Bonsai-space-event-to-shared-overlay")
    [ B.Event.Key.ASCII ' '; B.Event.Key.Uchar (Uchar.of_int 0x20) ];
  let picker =
    match
      C.handle { state with C.focus = C.Source }
        (input_of_event (B.Event.Key_press { key = B.Event.Key.Enter; mods = [] }))
    with
    | Some ({ C.overlay = C.Loci _; _ } as picker) -> picker
    | _ -> raise (F.Refused "Bonsai-picker-enter-adapter")
  in
  F.require
    (match
       C.handle picker
         (input_of_event
            (B.Event.Key_press { key = B.Event.Key.Uchar (Uchar.of_int 0x20); mods = [] }))
     with
    | Some { C.overlay = C.Loci { query = " "; _ }; _ } -> true
    | _ -> false)
    "Bonsai-picker-search-adapter";
  F.require
    (match
       C.handle state
         (input_of_event
            (B.Event.Key_press { key = B.Event.Key.ASCII 'T'; mods = [ B.Event.Modifier.Ctrl ] }))
     with
    | Some editor -> C.editor_visible editor
    | None -> false)
    "Bonsai-posting-editor-adapter";
  let paste = input_of_event (B.Event.Paste `Start) in
  F.require (paste = `Paste `Start) "Bonsai-paste-adapter";
  print_endline
    "PASS: Bonsai indexed colors/no truecolor, centered/front overlays, ASCII/Unicode Space, locus \
     picker and event adapter."

let () =
  try
    match Array.to_list Sys.argv with
    | [ _; "--self-check" ] -> self_check ()
    | [ _; "--book"; path ] -> run path
    | [ _; "--check"; path ] ->
        ignore (F.load path);
        print_endline "PASS: daily book admitted (no payload output)."
    | [ _; "--copy-from"; source; "--book"; target ] ->
        F.create_copy ~source ~target;
        print_endline "PASS: fresh trial copy created; original unchanged."
    | _ ->
        prerr_endline
          "Usage: tools/tui --book FILE | --check FILE | --copy-from SOURCE --book \
           FRESH_FILE";
        exit 2
  with
  | F.Refused why when Array.to_list Sys.argv = [ Sys.argv.(0); "--self-check" ] ->
      prerr_endline ("self-check failed: " ^ why);
      exit 1
  | F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
      prerr_endline
        "TUI refused: input/file/terminal unavailable; no empty fallback. Any attempted output \
         artifacts retained.";
      exit 1
