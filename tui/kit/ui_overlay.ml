type frame = {
  origin_x : int;
  origin_y : int;
  pane_width : int;
  pane_height : int;
  rows : (Ui_render.style * string) list;
  cursor : (int * int) option;
}

let modal_width ~body:(body_w, _) = min 64 (max 8 (body_w - 4))

let form ~width_of ~screen:(width, _) ~body:((body_w, body_h) as body) ?pane_width form =
  if body_w < 8 || body_h < 3 then None
  else
    let pane_w = Option.value pane_width ~default:(modal_width ~body) in
    let form_rows = Ui_form.render_rows ~width:(max 0 (pane_w - 6))
        ~height:(Ui_panel.capacity ~height:body_h ~heading:false) ~width_of form in
    let pane_h = min body_h (max 5 (List.length form_rows + 2)) in
    let rows = Ui_panel.frame_rows ~width_of ~width:pane_w ~height:pane_h
        ~focused:true ~title:(Ui_form.title form) form_rows in
    let origin_x = max 0 ((width - pane_w) / 2) in
    let origin_y = max 0 ((body_h - pane_h) / 2) in
    let cursor = Ui_render.cursor_in_rows ~width_of ~width:pane_w rows
      |> Option.map (fun (col, row) -> (origin_x + col, origin_y + row)) in
    Some { origin_x; origin_y; pane_width = pane_w; pane_height = List.length rows; rows; cursor }

let form_fits ~width_of ~body:((_, body_h) as body) form =
  let pane_w = modal_width ~body in
  let rows = Ui_form.render_rows ~width:(max 0 (pane_w - 6)) ~height:max_int ~width_of form in
  pane_w >= 48 && List.length rows <= Ui_panel.capacity ~height:body_h ~heading:false
