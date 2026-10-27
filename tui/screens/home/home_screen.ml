open Ui_render

let tr = Ui_text.tr

let bonsai_silhouette =
  [
    "               .:;;;:.";
    "          .:;;;;;::;;;;:.";
    "       .:;;;:. '\\|/ '::;'";
    "   .:;;;;;;:..  |";
    "    '::;;::'\\   /";
    "            \\_/";
    "            / \\";
    "      .----/---\\----.";
    "       \\___________/";
  ]

let center_line ~width ~width_of text =
  let w = width_of text in
  let pad = max 0 ((width - w) / 2) in
  clip_text ~width_of (max 0 width) (String.make pad ' ' ^ text)

let bonsai_home_lines ~width ~height ~width_of ~today =
  let tree_width = 32 in
  let capacity = max 0 height in
  let show_art = width >= tree_width && capacity >= 20 in
  let roomy = capacity >= 13 in
  let tree_rows =
    if not show_art then [ (Heading, center_line ~width ~width_of "bakhlo") ]
    else
      let rows =
        List.mapi
          (fun i line ->
            let style = if i >= 7 then Chrome else Bonsai in
            (style, center_line ~width ~width_of line))
          bonsai_silhouette
      in
      rows @ [ (Plain, ""); (Heading, center_line ~width ~width_of "bakhlo") ]
  in
  let date_rows =
    if roomy then [ (Plain, ""); (Status, center_line ~width ~width_of today); (Plain, "") ]
    else [ (Status, center_line ~width ~width_of today) ]
  in
  let entrances =
    [
      ("r", tr "Record");
      ("s", tr "Scheduled");
      ("a", tr "Actual");
      ("b", tr "Balances");
      ("d", tr "Daily Pace");
    ]
  in
  let menu_rows =
    if capacity >= 8 then
      List.map
        (fun (key, label) ->
          let text = Printf.sprintf "  %s   %-14s" key label in
          (Entrance, center_line ~width ~width_of text))
        entrances
    else
      let compact = [ "r Record     s Scheduled"; "a Actual     b Balances"; "d Daily Pace" ] in
      List.map (fun line -> (Entrance, center_line ~width ~width_of line)) compact
  in
  let body = tree_rows @ date_rows @ menu_rows in
  let top_pad = max 0 ((capacity - List.length body) / 3) in
  let padded = List.init top_pad (fun _ -> (Plain, "")) @ body in
  let visible_body = List.filteri (fun i _ -> i < capacity) padded in
  let bottom_pad = max 0 (capacity - List.length visible_body) in
  let full_body = visible_body @ List.init bottom_pad (fun _ -> (Plain, "")) in
  List.map (fun (style, text) -> (style, clip_text ~width_of (max 0 width) text)) full_body

type t = unit

let create () = ()

let handle (_ : Screen.env) (_ : Screen.geometry) t input =
  ( t,
    match Ui_input.key_ignoring_case input with
    | Some ((`Escape | `ASCII 'q'), []) -> Screen.Quit
    | Some ((`Enter | `ASCII 'a'), []) -> Screen.Open_route Screen.Actual
    | Some (`ASCII 's', []) -> Screen.Open_route Screen.Scheduled
    | Some (`ASCII 'b', []) -> Screen.Open_route Screen.Balances
    | Some (`ASCII 'd', []) -> Screen.Open_route Screen.Daily_pace
    | Some (`ASCII 'i', []) -> Screen.Open_route Screen.Attention
    | Some (`ASCII 'o', []) -> Screen.Open_observe
    | Some (`ASCII ('r' | 'n'), []) -> Screen.New_record
    | _ -> Screen.Ignored )

let view (env : Screen.env) (geometry : Screen.geometry) () =
  let width, height = geometry.body in
  let badge =
    match env.attention with
    | Ok a -> Attention_data.badge (Attention_data.summarize ~today:env.today a)
    | Error _ -> ""
  in
  {
    Screen.title = tr "Home";
    subtitle = Screen.Default;
    rows = lazy (bonsai_home_lines ~width ~height ~width_of:geometry.width_of ~today:env.today);
    footer = [ " [Enter] actual   [i] attention" ^ badge; " [Space] commands   [q] quit" ];
    overlay = None;
    cursor = None;
  }
