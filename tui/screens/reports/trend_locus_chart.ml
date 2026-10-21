(* Owner-local multi-series chart for the Trend / Locus comparison.

   Exact Z amounts are scaled to bounded pixel rows and columns with integer
   arithmetic only: no floating point, no machine-sized conversion and no
   truncated amount is ever presented as another quantity. Series differ by
   their marker glyph, never by a new style. Values are the exact recorded
   flows of the projection's shared, nonempty windows. *)
module O = Daily_overlays

(** The five distinct series markers, in slot order. *)
let markers = [| "●"; "◆"; "▲"; "■"; "□" |]

(** Drawn where two series share one cell. *)
let collision = "◎"

type series = { marker : string; values : Z.t array }
(** One exact recorded value per shared x position. *)

type annotation = { glyph : string; at : int list }
(** A session annotation: its distinct glyph and marked x positions. *)

type t = {
  series : series array;
  count : int;  (** Number of x positions. *)
  selected : int;  (** The selected x position. *)
  guides : int list;  (** x positions carrying a vertical guide. *)
  annotations : annotation list;  (** Marked x positions, one glyph per annotation. *)
}

type rendered = {
  rows : string list;  (** Painted plot rows, value axis column included. *)
  axis_exact : bool;  (** Every axis label fitted; false asks for a wider terminal. *)
}

let nice_step raw =
  let wanted = Z.max Z.one raw in
  let digits = String.length (Z.to_string wanted) in
  let base = Z.pow (Z.of_int 10) (digits - 1) in
  if Z.leq wanted base then base
  else if Z.leq wanted (Z.mul base (Z.of_int 2)) then Z.mul base (Z.of_int 2)
  else if Z.leq wanted (Z.mul base (Z.of_int 5)) then Z.mul base (Z.of_int 5)
  else Z.mul base (Z.of_int 10)

let scale series =
  match Array.find_opt (fun s -> Array.length s.values > 0) series with
  | None -> None
  | Some first ->
      let low = ref first.values.(0) and high = ref first.values.(0) in
      Array.iter
        (fun s ->
          Array.iter
            (fun value ->
              low := Z.min !low value;
              high := Z.max !high value)
            s.values)
        series;
      let low = !low and high = !high in
      let low, high =
        if Z.equal low high then
          (* A constant series still needs a visible band. *)
          let pad = Z.max Z.one (Z.div (Z.abs low) (Z.of_int 10)) in
          (Z.sub low pad, Z.add high pad)
        else (low, high)
      in
      let step = nice_step (Z.max Z.one (Z.cdiv (Z.sub high low) (Z.of_int 4))) in
      let low = Z.mul (Z.ediv low step) step in
      let high = Z.mul (Z.cdiv high step) step in
      let high = if Z.leq high low then Z.add low step else high in
      Some (low, high, step)

let row_for_value height low high value =
  if height <= 1 || Z.leq high low then 0
  else
    let offset = Z.ediv (Z.mul (Z.sub value low) (Z.of_int (height - 1))) (Z.sub high low) in
    let offset = if Z.lt offset (Z.of_int (height - 1)) then Z.to_int offset else height - 1 in
    height - 1 - offset

let x_for_index width count index =
  if width <= 1 || count <= 1 then 0 else min (width - 1) (index * (width - 1) / (count - 1))

let render ~width ~height ~width_of ~label t =
  let width = max 0 width and height = max 0 height in
  if width = 0 || height = 0 then { rows = List.init height (fun _ -> ""); axis_exact = true }
  else if width < 3 then
    { rows = List.init height (fun _ -> String.make width ' '); axis_exact = true }
  else
    match scale t.series with
    | None -> { rows = List.init height (fun _ -> String.make width ' '); axis_exact = true }
    | Some (low, high, step) ->
        let count = Z.div (Z.sub high low) step in
        let count = if Z.gt count (Z.of_int 64) then 64 else Z.to_int count in
        let ticks = List.init (count + 1) (fun i -> Z.add low (Z.mul (Z.of_int i) step)) in
        let labels = List.map label ticks in
        let natural = List.fold_left (fun widest text -> max widest (width_of text)) 0 labels in
        let budget = max 3 (width / 3) in
        let exact = natural <= budget in
        let axis_width = if exact then min (max 1 natural) (width - 2) else 1 in
        let plot_width = max 1 (width - axis_width - 1) in
        let marked = List.filter (fun annotation -> annotation.at <> []) t.annotations in
        let marker_rows = if marked = [] || height < 2 then 0 else 1 in
        let plot_height = max 1 (height - marker_rows) in
        let cells = Array.init plot_height (fun _ -> Array.make plot_width " ") in
        let get x y =
          if x >= 0 && x < plot_width && y >= 0 && y < plot_height then cells.(y).(x) else " "
        in
        let set x y glyph =
          if x >= 0 && x < plot_width && y >= 0 && y < plot_height then cells.(y).(x) <- glyph
        in
        let line x0 y0 x1 y1 =
          let dx = abs (x1 - x0) and dy = abs (y1 - y0) in
          let sx = if x0 < x1 then 1 else -1 and sy = if y0 < y1 then 1 else -1 in
          let rec walk x y error =
            if get x y = " " then set x y "·";
            if x <> x1 || y <> y1 then
              let twice = 2 * error in
              let move_x = twice > -dy and move_y = twice < dx in
              walk
                (if move_x then x + sx else x)
                (if move_y then y + sy else y)
                (error - (if move_x then dy else 0) + if move_y then dx else 0)
          in
          walk x0 y0 (dx - dy)
        in
        Array.iter
          (fun s ->
            let rec connect i previous_x previous_y =
              if i < Array.length s.values then (
                let x = x_for_index plot_width t.count i in
                let y = row_for_value plot_height low high s.values.(i) in
                line previous_x previous_y x y;
                connect (i + 1) x y)
            in
            if Array.length s.values > 0 then
              connect 1 0 (row_for_value plot_height low high s.values.(0)))
          t.series;
        Array.iter
          (fun s ->
            Array.iteri
              (fun i value ->
                let x = x_for_index plot_width t.count i in
                let y = row_for_value plot_height low high value in
                let previous = get x y in
                set x y
                  (if previous = " " || previous = "·" || previous = s.marker then s.marker
                   else collision))
              s.values)
          t.series;
        (if Z.leq low Z.zero && Z.leq Z.zero high then
           let y = row_for_value plot_height low high Z.zero in
           for x = 0 to plot_width - 1 do
             if get x y = " " then set x y "┄"
           done);
        List.iter
          (fun guide ->
            let x = x_for_index plot_width t.count guide in
            for y = 0 to plot_height - 1 do
              if get x y = " " then set x y "┊"
            done)
          t.guides;
        let selected_x = x_for_index plot_width t.count t.selected in
        for y = 0 to plot_height - 1 do
          if get selected_x y = " " then set selected_x y "│"
        done;
        let row_label row =
          List.fold_left
            (fun found (value, text) ->
              match found with
              | Some _ -> found
              | None -> if row_for_value plot_height low high value = row then Some text else None)
            None (List.combine ticks labels)
        in
        let rows =
          List.init plot_height (fun row ->
              let prefix =
                match row_label row with
                | Some text when exact -> O.pad_left ~width_of axis_width text ^ "│"
                | Some _ -> O.pad_left ~width_of axis_width "…" ^ "│"
                | None -> String.make (axis_width + 1) ' '
              in
              prefix ^ String.concat "" (Array.to_list cells.(row)))
        in
        let marker_row =
          if marker_rows = 0 then []
          else
            let row = Array.make plot_width " " in
            List.iter
              (fun annotation ->
                List.iter
                  (fun index ->
                    let x = x_for_index plot_width t.count index in
                    if x >= 0 && x < plot_width then
                      row.(x) <-
                        (if row.(x) = " " || row.(x) = annotation.glyph then annotation.glyph
                         else collision))
                  annotation.at)
              marked;
            [ String.make (axis_width + 1) ' ' ^ String.concat "" (Array.to_list row) ]
        in
        { rows = rows @ marker_row; axis_exact = exact }
