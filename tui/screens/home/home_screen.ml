let tr = Ui_text.tr

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
    rows =
      lazy
        (Daily_overlays.bonsai_home_lines ~width ~height ~width_of:geometry.width_of
           ~today:env.today);
    footer = [ " [Enter] actual   [i] attention" ^ badge; " [Space] commands   [q] quit" ];
    overlay = None;
    cursor = None;
  }
