module O = Ui_render

type window = { capacity : int; start : int; last : int }

let capacity ~height ~heading = max 0 (max 0 height - 2 - if heading && height >= 4 then 1 else 0)

let move ~last ~position delta =
  let last = max 0 last in
  let position = max 0 (min last position) in
  if delta > 0 then position + min delta (last - position)
  else if delta < -position then 0
  else position + delta

let window ~capacity ~count ~scroll ~selected =
  let capacity = max 0 capacity and count = max 0 count in
  let last = max 0 (count - capacity) in
  let start =
    match selected with
    | None -> move ~last ~position:scroll 0
    | Some index ->
        let index = move ~last:(max 0 (count - 1)) ~position:index 0 in
        min last (max 0 (index - max 0 (capacity - 1)))
  in
  { capacity; start; last }

let frame ?heading ~width_of ~width ~height ~focused ~title ~scroll ~selected rows =
  if width < 6 || height < 2 then List.init (max 0 height) (fun _ -> (O.Plain, ""))
  else
    let heading = if height >= 4 then heading else None in
    let count = List.length rows in
    let selected =
      if count = 0 then None
      else Option.map (fun index -> move ~last:(count - 1) ~position:index 0) selected
    in
    let view =
      window ~capacity:(capacity ~height ~heading:(heading <> None)) ~count ~scroll ~selected
    in
    let shown =
      rows |> List.filteri (fun i _ -> i >= view.start && i - view.start < view.capacity)
    in
    let shown =
      List.mapi
        (fun i text ->
          let is_selected = selected = Some (i + view.start) in
          O.panel_line ~width ~width_of
            (if is_selected then if focused then O.Active else O.Chrome else O.Plain)
            ((if is_selected then "> " else "  ") ^ text))
        shown
    in
    let style = if focused then O.Focused_frame else O.Frame in
    [ O.panel_border ~width ~style ~width_of (Ui_text.tr title) ]
    @ Option.to_list (Option.map (O.panel_line ~width ~width_of O.Chrome) heading)
    @ shown
    @ List.init
        (max 0 (view.capacity - List.length shown))
        (fun _ -> O.panel_line ~width ~width_of O.Plain "")
    @ [
        O.panel_bottom ~width ~style ~width_of
          ~title:
            (Printf.sprintf "%d–%d / %d"
               (if count = 0 || view.capacity = 0 then 0 else view.start + 1)
               (if view.capacity = 0 then 0 else view.start + min view.capacity (count - view.start))
               count)
          ();
      ]

let frame_rows ?(inset = 2) ?bottom_label ~width_of ~width ~height ~focused ~title rows =
  if inset = 0 then
    if width < 2 || height < 2 then []
    else
      let style = if focused then O.Focused_frame else O.Frame in
      let capacity = max 0 (height - 2) in
      let shown = List.filteri (fun i _ -> i < capacity) rows in
      let shown =
        shown @ List.init (max 0 (capacity - List.length shown)) (fun _ -> (O.Plain, ""))
      in
      [ O.panel_border ~width ~style ~inset:0 ~width_of title ]
      @ List.map
          (fun (row_style, text) ->
            match row_style with
            | O.Spans spans ->
                (* The border keeps its own cells; the row's spans stay whole. *)
                let spans = O.fit_spans ~width_of (width - 2) spans in
                ( O.Spans (((O.Plain, "│") :: spans) @ [ (O.Plain, "│") ]),
                  "│" ^ O.spans_text spans ^ "│" )
            | _ -> (row_style, "│" ^ O.pad ~width_of (width - 2) text ^ "│"))
          shown
      @ [ O.panel_bottom ~width ~style ~width_of ~title:(Option.value ~default:"" bottom_label) () ]
  else
    let painted =
      frame ~width_of ~width ~height ~focused ~title ~scroll:0 ~selected:None (List.map snd rows)
    in
    let painted =
      match bottom_label with
      | None -> painted
      | Some title ->
          List.mapi
            (fun i row ->
              if i = height - 1 && width >= 6 && height >= 2 then
                O.panel_bottom ~width ~width_of
                  ~style:(if focused then O.Focused_frame else O.Frame)
                  ~title ()
              else row)
            painted
    in
    if width < 6 || height < 2 then painted
    else
      let content = Array.of_list rows in
      List.mapi
        (fun i (style, text) ->
          if i = 0 || i > Array.length content || i >= height - 1 then (style, text)
          else
            let child, _ = content.(i - 1) in
            let style =
              match O.input_cell ~width:(width - 6) child with
              | Some col -> O.Input (col + 4)
              | None -> child
            in
            (style, text))
        painted

let preview ~width_of ~width ~height ~title ~scroll ~notice ~action rows =
  frame ~width_of ~width
    ~height:(max 0 (height - 2))
    ~focused:true ~title ~scroll ~selected:None rows
  @ [
      (O.Status, O.clip_text ~width_of width notice); (O.Active, O.clip_text ~width_of width action);
    ]

let preview_window ?selected ~height ~count ~scroll () =
  window ~capacity:(capacity ~height:(max 0 (height - 2)) ~heading:false) ~count ~scroll ~selected

let review_scroll view input =
  let move delta = move ~last:view.last ~position:view.start delta in
  match input with
  | `Key ((`Arrow `Up | `ASCII 'k'), []) -> move (-1)
  | `Key ((`Arrow `Down | `ASCII 'j'), []) -> move 1
  | `Key (`Page `Up, []) | `Key (`ASCII 'u', [ `Ctrl ]) -> move (-max 1 view.capacity)
  | `Key (`Page `Down, []) | `Key (`ASCII 'd', [ `Ctrl ]) -> move (max 1 view.capacity)
  | `Key (`Home, []) -> 0
  | `Key (`End, []) -> view.last
  | _ -> view.start

let split_widths width =
  if width < 80 then (width, width)
  else
    let left = max 36 (min 58 (width * 52 / 100)) in
    (left, width - left - 1)

let split ?left_heading ~width_of ~width ~height ~left_focused ~left_title ~left_scroll
    ~left_selected ~left_rows ~right_focused ~right_title ~right_scroll ~right_selected ~right_rows
    () =
  let pad rows = rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (O.Plain, "")) in
  if width >= 80 then
    let left_width, right_width = split_widths width in
    let left_panel =
      frame ?heading:left_heading ~width_of ~width:left_width ~height ~focused:left_focused
        ~title:left_title ~scroll:left_scroll ~selected:left_selected left_rows
    in
    let right_panel =
      frame ~width_of ~width:right_width ~height ~focused:right_focused ~title:right_title
        ~scroll:right_scroll ~selected:right_selected right_rows
    in
    pad
      (List.map2
         (fun (style_l, text_l) (style_r, text_r) ->
           (O.Columns (left_width, style_l, style_r), text_l ^ " " ^ text_r))
         left_panel right_panel)
  else if right_focused then
    frame ~width_of ~width ~height ~focused:true ~title:right_title ~scroll:right_scroll
      ~selected:right_selected right_rows
  else
    frame ~width_of ~width ~height ~focused:true ?heading:left_heading ~title:left_title
      ~scroll:left_scroll ~selected:left_selected left_rows
