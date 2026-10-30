(* Shared UI primitives: line input and panels. *)
open Interaction_check_fixture

let input_checks ~width_of () =
  let module O = Ui_render in
  let input ?(cursor = None) ?(caret = "|") width value =
    O.input_text ~width_of ~width ~cursor ~caret value
  in
  List.iter
    (fun (width, value, cursor, expected) ->
      require (input ~cursor width value = expected) "input-visible-window")
    [
      (4, "", None, ("|", Some 0));
      (4, "abc", None, ("abc|", Some 3));
      (4, "abcd", None, ("…cd|", Some 3));
      (4, "abcdef", Some 0, ("|ab…", Some 0));
      (5, "abcdef", Some 2, ("ab|c…", Some 2));
      (5, "a|│b", Some 2, ("a||│b", Some 2));
      (7, "日本語", Some 3, ("日|本語", Some 2));
    ];
  require (input ~caret:" " 4 "abcd" = ("…cd ", Some 3)) "input-blank-insertion-cell";
  List.iter
    (fun width -> require (input width "日本語" = ("", None)) "input-no-width-no-caret")
    [ min_int; -1; 0 ];
  require
    (input 1 "日本語" = ("|", Some 0) && input ~caret:"" 4 "abc" = ("abc", None))
    "input-reserved-or-absent-insertion-cell";
  let value = String.make 80 'a' ^ "日本語" in
  List.iter
    (fun cursor ->
      List.iter
        (fun width ->
          let painted, cell = input ~cursor width value in
          require (width_of painted <= width) "input-window-cell-bounded";
          let column = Option.get cell in
          let offset = String.index painted '|' in
          require
            (width_of (String.sub painted 0 offset) = column)
            "input-caret-matches-painted-insertion-cell";
          require
            (O.cursor_in_rows ~width_of ~width [ (O.Input column, painted) ] = Some (column, 0))
            "input-window-and-metadata-agree")
        [ 1; 2; 8; 16; 80; 120 ])
    [ Some 0; Some 40; Some 83; None ];
  List.iter
    (fun (width, style, expected) ->
      require (O.input_cell ~width style = expected) "input-recursive-pane-bounds")
    [
      (8, O.Columns (4, O.Input 3, O.Active), Some 3);
      (8, O.Columns (4, O.Plain, O.Input 2), Some 7);
      (8, O.Columns (4, O.Input 4, O.Plain), None);
      (7, O.Columns (4, O.Plain, O.Input 2), None);
      (5, O.Columns (4, O.Plain, O.Input 0), None);
      (8, O.Columns (4, O.Plain, O.Input (-1)), None);
      (8, O.Columns (4, O.Columns (1, O.Plain, O.Input 1), O.Active), Some 3);
      (10, O.Columns (4, O.Plain, O.Columns (2, O.Active, O.Input 1)), Some 9);
      (0, O.Input 0, None);
      (max_int, O.Columns (max_int, O.Plain, O.Input 0), None);
    ];
  let rows = [ (O.Plain, "literal | │"); (O.Columns (4, O.Plain, O.Input 1), "財布  |") ] in
  require
    (O.cursor_in_rows ~width_of ~width:8 rows = Some (6, 1))
    "input-cjk-pane-origin-not-byte-offset";
  require
    (O.cursor_in_rows ~width_of ~width:6 rows = None
    && O.cursor_in_rows ~width_of ~width:8 [ (O.Input 3, "ab") ] = None
    && O.cursor_in_rows ~width_of ~width:8 [ (O.Plain, "|") ] = None)
    "input-hidden-clipped-and-literal-caret";
  print_endline
    "PASS: shared input windows, retained UTF-8 bytes, insertion cells and recursive Columns caret \
     bounds."

let panel_checks ~width_of () =
  let module Panel = Ui_panel in
  require
    (Panel.capacity ~height:8 ~heading:false = 6
    && Panel.capacity ~height:8 ~heading:true = 5
    && Panel.capacity ~height:3 ~heading:true = 1
    && Panel.capacity ~height:min_int ~heading:true = 0)
    "panel-data-capacity";
  List.iter
    (fun last ->
      List.iter
        (fun position ->
          List.iter
            (fun delta ->
              let moved = Panel.move ~last ~position delta in
              require (moved >= 0 && moved <= max 0 last) "panel-motion-bounded")
            [ min_int; -1; 0; 1; max_int ])
        [ min_int; 0; 1; max_int ])
    [ min_int; 0; 1; max_int ];
  require
    (Panel.move ~last:max_int ~position:max_int max_int = max_int
    && Panel.move ~last:max_int ~position:max_int min_int = 0
    && Panel.move ~last:10 ~position:max_int (-1) = 9)
    "panel-motion-clamps-before-stepping";
  let view = Panel.window ~capacity:3 ~count:10 ~scroll:0 ~selected:(Some 8) in
  require (view.capacity = 3 && view.start = 6 && view.last = 7) "panel-selection-follows-window";
  let start scroll selected =
    (Panel.window ~capacity:3 ~count:10 ~scroll ~selected:(Some selected)).start
  in
  require
    (start max_int 8 = 7 && start 7 6 = 6 && start 4 5 = 4 && start min_int 2 = 0)
    "panel-selection-keeps-scroll-while-in-view";
  let ended = Panel.window ~capacity:3 ~count:10 ~scroll:max_int ~selected:None in
  require
    (ended.start = 7 && Panel.move ~last:ended.last ~position:ended.start (-1) = 6)
    "panel-scroll-bottom-and-immediate-up";
  let empty = Panel.window ~capacity:0 ~count:0 ~scroll:max_int ~selected:(Some max_int) in
  require (empty.start = 0 && empty.last = 0) "panel-empty-zero-capacity";
  let huge =
    Panel.window ~capacity:max_int ~count:max_int ~scroll:max_int ~selected:(Some max_int)
  in
  require (huge.start = 0 && huge.last = 0) "panel-window-machine-boundary";
  let content = List.init 10 (fun n -> Printf.sprintf "row-%02d 日本語" n) in
  let contains rows needle =
    List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) rows
  in
  let render focused =
    Panel.frame ~heading:"Columns" ~width_of ~width:32 ~height:6 ~focused ~title:"Panel" ~scroll:0
      ~selected:(Some 9) content
  in
  let active = render true and inactive = render false in
  require
    (contains active "row-07" && contains active "row-09"
    && (not (contains active "row-06"))
    && contains active "8–10 / 10")
    "panel-paint-uses-same-window";
  require
    (List.exists
       (fun (style, line) ->
         style = Ui_render.Active && Base.String.is_substring line ~substring:"row-09")
       active
    && (not (List.exists (fun (style, _) -> style = Ui_render.Active) inactive))
    && List.map snd active = List.map snd inactive)
    "panel-focus-not-selection";
  List.iter
    (fun (width, height) ->
      List.iter
        (fun selected ->
          let rows =
            Panel.frame ~heading:"Columns" ~width_of ~width ~height ~focused:true ~title:"Panel"
              ~scroll:max_int ~selected content
          in
          require
            (List.length rows = max 0 height
            && List.for_all (fun (_, line) -> width_of line <= width) rows)
            "panel-bounded-render")
        [ None; Some 0; Some 9; Some max_int ])
    [ (0, 0); (1, 1); (6, 2); (8, 3); (18, 4); (32, 9); (48, 14); (80, 24) ];
  require
    (not
       (contains
          (Panel.frame ~heading:"Columns" ~width_of ~width:32 ~height:3 ~focused:true ~title:"Panel"
             ~scroll:0 ~selected:(Some 0) content)
          "Columns"))
    "panel-low-height-keeps-data-not-heading";
  print_endline
    "PASS: independent shared panel capacity/window, integer-safe motion, focus/selection and \
     bounded Unicode painting."
