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

let color (c : P.rgb) = A.rgb_888 ~r:c.r ~g:c.g ~b:c.b
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
      | C.Heading ->
          A.(fg (color palette.heading) ++ bg (color palette.background) ++ st bold)
      | C.Status ->
          A.(fg (color palette.status) ++ bg (color palette.background) ++ st bold)
      | C.Panel ->
          A.(fg (color palette.panel_foreground) ++ bg (color palette.panel_background))
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
      image
      </> I.char
            A.(fg (color palette.foreground) ++ bg (color palette.background))
            ' ' width height

let render ((width, height) as dimensions) state =
  let base =
    C.screen ~frontend:"Notty" dimensions state
    |> lines state.C.theme
    |> I.hsnap ~align:`Left width
    |> I.vsnap ~align:`Top height
    |> backdrop state.theme width height
  in
  match C.overlay_screen state with
  | None -> base
  | Some rows ->
      let pane = lines state.theme rows in
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
        (fun dimensions ->
          let view = render dimensions { state with theme } in
          F.require
            (I.width view = fst dimensions && I.height view = snd dimensions)
            "Notty-geometry")
        [ (100, 25); (64, 20); (40, 10) ])
    P.all_themes;
  F.require (I.width (I.string A.empty "財布") = 4) "Notty-unicode-width";
  F.require
    (match C.handle state (input_of_event (`Key (`ASCII 'Q', [ `Ctrl ]))) with
    | None -> true
    | Some _ -> false)
    "Notty-event-adapter";
  print_endline "PASS: Notty terminal/default custom themes, palette overlay and event adapter."

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
  with F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
    prerr_endline
      "TUI refused: input/file/terminal unavailable; no empty fallback. Any attempted output \
       artifacts retained.";
    exit 1
