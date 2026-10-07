(* Notty drawing and event loop; daily-book actions are shared with Bonsai. *)
open Notty
module C = Daily_interaction
module F = Daily_file
module P = Ui_preferences

let input_of_event = function
  | `Key event -> (`Key event : C.input)
  | `Paste marker -> `Paste marker
  | `End -> `End
  | `Resize _ -> `Resize ()
  | `Mouse _ -> `Mouse ()

let color (c : P.color) =
  if c.index >= 232 then A.gray (c.index - 232)
  else
    let cube = c.index - 16 in
    A.rgb ~r:(cube / 36) ~g:(cube / 6 mod 6) ~b:(cube mod 6)

let fg c = A.fg (color c)
let bg c = A.bg (color c)

let attribute theme style =
  match P.palette theme with
  | None -> (
      match style with
      | C.Plain -> A.empty
      | C.Active -> A.(st reverse ++ st bold)
      | C.Heading | C.Status -> A.st A.bold
      | C.Panel -> A.st A.reverse
      | C.Panel_heading -> A.(st reverse ++ st bold)
      | C.Panel_active -> A.(st reverse ++ st bold ++ st underline))
  | Some palette -> (
      match style with
      | C.Plain -> A.(fg (color palette.foreground) ++ bg (color palette.background))
      | C.Active ->
          A.(
            fg (color palette.selected_foreground)
            ++ bg (color palette.selected_background)
            ++ st bold)
      | C.Heading -> A.(fg (color palette.heading) ++ bg (color palette.background) ++ st bold)
      | C.Status -> A.(fg (color palette.status) ++ bg (color palette.background) ++ st bold)
      | C.Panel -> A.(fg (color palette.panel_foreground) ++ bg (color palette.panel_background))
      | C.Panel_heading ->
          A.(fg (color palette.accent) ++ bg (color palette.panel_background) ++ st bold)
      | C.Panel_active ->
          A.(
            fg (color palette.selected_foreground)
            ++ bg (color palette.selected_background)
            ++ st bold))

let lines theme rows =
  rows |> List.map (fun (style, text) -> I.string (attribute theme style) text) |> I.vcat

let backdrop theme width height image =
  match P.palette theme with
  | None -> image
  | Some palette ->
      I.zcat
        [
          image;
          I.char A.(fg (color palette.foreground) ++ bg (color palette.background)) ' ' width height;
        ]

let width_of text = I.width (I.string A.empty text)
let overlay_screen dimensions state = C.overlay_screen ~dimensions ~width_of state

let render ((width, height) as dimensions) state =
  let base =
    C.screen ~frontend:"Notty" dimensions state
    |> lines state.C.theme |> I.hsnap ~align:`Left width |> I.vsnap ~align:`Top height
    |> backdrop state.C.theme width height
  in
  match overlay_screen dimensions state with
  | None -> base
  | Some rows ->
      let pane = lines state.C.theme rows in
      let left = max 0 ((width - I.width pane) / 2)
      and top = max 0 ((height - I.height pane) / 2) in
      I.zcat [ I.pad ~l:left ~t:top pane; base ]
      |> I.hsnap ~align:`Left width |> I.vsnap ~align:`Top height

let run path =
  let session = F.load path in
  F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
  let terminal = Notty_unix.Term.create ~mouse:false ~bpaste:true () in
  Fun.protect
    ~finally:(fun () -> Notty_unix.Term.release terminal)
    (fun () ->
      let rec loop state =
        Notty_unix.Term.image terminal (render (Notty_unix.Term.size terminal) state);
        match C.handle state (input_of_event (Notty_unix.Term.event terminal)) with
        | None -> ()
        | Some state -> loop state
      in
      loop (C.initial session))

let self_check () =
  let state = C.self_check () in
  List.iter
    (fun (style, expected) ->
      F.require (A.equal (attribute P.Terminal style) expected) "Notty-terminal-default-style")
    [
      (C.Plain, A.empty);
      (C.Active, A.(st reverse ++ st bold));
      (C.Heading, A.st A.bold);
      (C.Status, A.st A.bold);
      (C.Panel, A.st A.reverse);
      (C.Panel_heading, A.(st reverse ++ st bold));
      (C.Panel_active, A.(st reverse ++ st bold ++ st underline));
    ];
  List.iter
    (fun theme ->
      List.iter
        (fun ((width, height) as dimensions) ->
          List.iter
            (fun state ->
              let state = { state with C.theme } in
              let overlay = state.C.overlay in
              let image = render dimensions state in
              F.require (I.width image = width && I.height image = height) "Notty-geometry";
              let ansi = Buffer.create 1024 in
              Render.to_buffer ansi Cap.ansi (0, 0) dimensions image;
              let emits substring = Base.String.is_substring (Buffer.contents ansi) ~substring in
              F.require ((not (emits "38;2;")) && not (emits "48;2;")) "Notty-no-truecolor-SGR";
              (match P.palette theme with
              | None -> F.require ((not (emits "38;")) && not (emits "48;")) "Notty-no-fixed-colors"
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
                  let pane_width = width_of (snd (List.hd rows)) in
                  F.require
                    (List.for_all (fun (_, text) -> width_of text = pane_width) rows)
                    "Notty-panel-uniform-cell-width";
                  if width >= pane_width && height >= List.length rows then (
                    let left = (width - pane_width) / 2 and top = (height - List.length rows) / 2 in
                    let buffer = Buffer.create 512 in
                    let pane =
                      I.crop ~l:left ~t:top
                        ~r:(width - left - pane_width)
                        ~b:(height - top - List.length rows)
                        image
                    in
                    Render.to_buffer buffer Cap.dumb (0, 0) (pane_width, List.length rows) pane;
                    F.require
                      (Buffer.contents buffer = String.concat "\n" (List.map snd rows))
                      "Notty-overlay-front-and-centered")
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
            @ C.posting_render_cases state))
        [ (100, 25); (64, 20); (40, 10); (20, 5) ])
    P.all_themes;
  List.iter
    (fun theme ->
      List.iter
        (fun state ->
          let image =
            render (64, 20) { state with C.theme; blocked = true; message = "household-warning" }
          in
          let buffer = Buffer.create 64 in
          Render.to_buffer buffer Cap.dumb (0, 0) (64, 1) (I.crop ~t:19 image);
          F.require
            (String.trim (Buffer.contents buffer) = "household-warning")
            "Notty-overlay-household-warning-visible")
        (([
            C.Commands 0;
            C.Themes { selected = 0; original = theme };
            C.Loci { target = C.From_locus; query = ""; selected = 0; notice = None };
          ]
         |> List.map (fun overlay -> { state with C.overlay }))
        @ C.posting_render_cases state))
    P.all_themes;
  F.require (I.width (I.string A.empty "財布") = 4) "Notty-unicode-width";
  F.require
    (match C.handle state (input_of_event (`Key (`ASCII 'Q', [ `Ctrl ]))) with
    | None -> true
    | Some _ -> false)
    "Notty-event-adapter";
  List.iter
    (fun key ->
      F.require
        (match C.handle { state with C.focus = C.Amount } (input_of_event (`Key (key, []))) with
        | Some { C.overlay = C.Commands 0; _ } -> true
        | Some _ | None -> false)
        "Notty-space-event-to-shared-overlay")
    [ `ASCII ' '; `Uchar (Uchar.of_int 0x20) ];
  let picker =
    match C.handle { state with C.focus = C.Source } (input_of_event (`Key (`Enter, []))) with
    | Some ({ C.overlay = C.Loci _; _ } as picker) -> picker
    | _ -> raise (F.Refused "Notty-picker-enter-adapter")
  in
  F.require
    (match C.handle picker (input_of_event (`Key (`Uchar (Uchar.of_int 0x20), []))) with
    | Some { C.overlay = C.Loci { query = " "; _ }; _ } -> true
    | _ -> false)
    "Notty-picker-search-adapter";
  F.require
    (match C.handle state (input_of_event (`Key (`ASCII 'T', [ `Ctrl ]))) with
    | Some editor -> C.editor_visible editor
    | None -> false)
    "Notty-posting-editor-adapter";
  let decoder = Unescape.create () in
  Unescape.input decoder (Bytes.of_string " ") 0 1;
  F.require
    (match Unescape.next decoder with
    | `Key event -> (
        match C.handle state (input_of_event (`Key event)) with
        | Some { C.overlay = C.Commands 0; _ } -> true
        | Some _ | None -> false)
    | _ -> false)
    "Notty-terminal-space-decode-to-overlay";
  print_endline
    "PASS: Notty indexed colors/no truecolor, centered/front overlays, ASCII/Unicode Space, locus \
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
    | [ _; "--snapshot"; path ] ->
        Notty_unix.output_image ~cap:Cap.dumb (render (100, 25) (C.initial (F.load path)))
    | _ ->
        prerr_endline
          "Usage: tools/tui [notty] --book FILE | --check FILE | --copy-from SOURCE --book \
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
