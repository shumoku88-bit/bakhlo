(* LOAM Tui.Chart ported to exact Z values. Integer division is Euclidean
   (floor for the positive divisors used here), as in Lean's Int.
   Unlike LOAM, nice steps are not capped at 10^24: the tick count stays
   bounded by the interval count, so huge amounts still chart. *)
module O = Ui_render

type range = { low : Z.t; high : Z.t }
type scale = { range : range; step : Z.t; ticks : Z.t list }

let nice_step raw =
  let wanted = Z.max Z.one raw in
  let base = Z.pow (Z.of_int 10) (String.length (Z.to_string wanted) - 1) in
  if Z.leq wanted base then base
  else if Z.leq wanted (Z.mul base (Z.of_int 2)) then Z.mul base (Z.of_int 2)
  else if Z.leq wanted (Z.mul base (Z.of_int 5)) then Z.mul base (Z.of_int 5)
  else Z.mul base (Z.of_int 10)

let scale_for ?(intervals = 4) values =
  match values with
  | [] -> { range = { low = Z.zero; high = Z.one }; step = Z.one; ticks = [ Z.zero; Z.one ] }
  | first :: rest ->
      let minimum = List.fold_left Z.min first rest and maximum = List.fold_left Z.max first rest in
      let seed_low, seed_high =
        if Z.equal minimum maximum then
          let pad = Z.max Z.one (Z.div (Z.abs minimum) (Z.of_int 10)) in
          (Z.sub minimum pad, Z.add maximum pad)
        else (minimum, maximum)
      in
      let spread = Z.max Z.one (Z.abs (Z.sub seed_high seed_low)) in
      let intervals = Z.of_int (max 1 intervals) in
      let step = nice_step (Z.max Z.one (Z.cdiv spread intervals)) in
      let low = Z.mul (Z.fdiv seed_low step) step in
      let high = Z.mul (Z.cdiv seed_high step) step in
      let high = if Z.leq high low then Z.add low step else high in
      let count = Z.to_int (Z.div (Z.sub high low) step) + 1 in
      {
        range = { low; high };
        step;
        ticks = List.init count (fun i -> Z.add low (Z.mul (Z.of_int i) step));
      }

let row_for_value height range value =
  if height <= 1 || Z.leq range.high range.low then 0
  else
    let offset =
      Z.ediv (Z.mul (Z.sub value range.low) (Z.of_int (height - 1))) (Z.sub range.high range.low)
    in
    let offset = Z.abs offset in
    height - 1 - if Z.lt offset (Z.of_int (height - 1)) then Z.to_int offset else height - 1

let x_for_index width count index =
  if width <= 1 || count <= 1 then 0 else min (width - 1) (index * (width - 1) / (count - 1))

let interpolate left right numerator denominator =
  if denominator = 0 then left
  else Z.add left (Z.ediv (Z.mul (Z.sub right left) (Z.of_int numerator)) (Z.of_int denominator))

let dot_value dx dy =
  match (dx, dy) with
  | 0, 0 -> 1
  | 0, 1 -> 2
  | 0, 2 -> 4
  | 1, 0 -> 8
  | 1, 1 -> 16
  | 1, 2 -> 32
  | 0, 3 -> 64
  | 1, 3 -> 128
  | _ -> 0

let glyph mask = if mask = 0 then " " else O.utf8 (Uchar.of_int (0x2800 + mask))

(* Each subpixel column spans from the midpoint with its left neighbour to the
   midpoint with its right one; a missing neighbour contributes its own row. *)
let braille_mask sample range width height cell_x cell_y =
  let sub_width = max 1 (width * 2) and sub_height = max 1 (height * 4) in
  let row value = row_for_value sub_height range value in
  let mask = ref 0 in
  for dx = 0 to 1 do
    let sub_x = (cell_x * 2) + dx in
    match sample sub_width sub_x with
    | None -> ()
    | Some value ->
        let current = row value in
        let toward neighbour =
          match neighbour with Some v -> (row v + current) / 2 | None -> current
        in
        let a = if sub_x = 0 then current else toward (sample sub_width (sub_x - 1)) in
        let b = if sub_x + 1 >= sub_width then current else toward (sample sub_width (sub_x + 1)) in
        let low = min current (min a b) and high = max current (max a b) in
        for dy = 0 to 3 do
          let sub_y = (cell_y * 4) + dy in
          if low <= sub_y && sub_y <= high then mask := !mask + dot_value dx dy
        done
  done;
  !mask

let braille_glyph sample range width height cell_x cell_y =
  glyph (braille_mask sample range width height cell_x cell_y)

let qualified_sample values joins width x =
  let count = Array.length values in
  if count = 0 then None
  else if count = 1 || width <= 1 then values.(0)
  else if x + 1 >= width then values.(count - 1)
  else
    let denominator = width - 1 in
    let scaled = x * (count - 1) in
    let index = scaled / denominator and remainder = scaled mod denominator in
    if remainder = 0 then values.(index)
    else if not (index < Array.length joins && joins.(index)) then None
    else
      match (values.(index), values.(index + 1)) with
      | Some left, Some right -> Some (interpolate left right remainder denominator)
      | _ -> None

let qualified_rows ~width ~height ~values ~joins ~selected ~range ~connect ~grid_rows =
  let width = max 1 width and height = max 1 height in
  let values = Array.of_list values and joins = Array.of_list joins in
  let count = Array.length values in
  let sample = qualified_sample values joins in
  let markers =
    List.filter_map Fun.id
      (List.init count (fun i ->
           Option.map
             (fun v -> (x_for_index width count i, row_for_value height range v))
             values.(i)))
  in
  let selected_value = if selected >= 0 && selected < count then values.(selected) else None in
  let selected_x = x_for_index width count selected in
  let selected_y = Option.map (row_for_value height range) selected_value in
  List.init height (fun row ->
      String.concat ""
        (List.init width (fun col ->
             let base = if connect then braille_glyph sample range width height col row else " " in
             if selected_value <> None && col = selected_x && selected_y = Some row then "◆"
             else if col = selected_x then if base = " " then "│" else base
             else if selected_y <> None && selected_y = Some row && abs (col - selected_x) <= 2 then
               if base = " " then "─" else base
             else if List.mem (col, row) markers then "●"
             else if base <> " " then base
             else if List.mem row grid_rows then "┄"
             else " ")))

let series_sample values =
  let values = Array.of_list values in
  fun sub_width x ->
    let count = Array.length values in
    if count = 0 then None
    else if count = 1 || sub_width <= 1 then Some values.(0)
    else if x + 1 >= sub_width then Some values.(count - 1)
    else
      let denominator = sub_width - 1 in
      let scaled = x * (count - 1) in
      let segment = scaled / denominator in
      let left = values.(segment) in
      let right = if segment + 1 < count then values.(segment + 1) else left in
      Some (interpolate left right (scaled mod denominator) denominator)

let line_rows ~width ~height ~values ~selected ~range ~grid_rows =
  let width = max 1 width and height = max 1 height in
  let sample = series_sample values in
  let values = Array.of_list values in
  let count = Array.length values in
  let selected_x = x_for_index width count selected in
  let selected_y =
    if count = 0 then 0
    else
      row_for_value height range
        values.(if selected >= 0 && selected < count then selected else count - 1)
  in
  List.init height (fun row ->
      String.concat ""
        (List.init width (fun col ->
             let base = braille_glyph sample range width height col row in
             if col = selected_x && row = selected_y then "◆"
             else if col = selected_x then if base = " " then "│" else base
             else if row = selected_y && abs (col - selected_x) <= 2 then
               if base = " " then "─" else base
             else if List.mem row grid_rows && base = " " then "┄"
             else base)))

let axis_width ~width_of width scale label =
  min
    (List.fold_left (fun widest tick -> max widest (width_of (label tick))) 3 scale.ticks)
    (max 3 (width / 4))

(* The axis prefix of one row: the tick label at that row, or the note. *)
let axis_prefix ~width_of ~axis ~height ~scale ~label ?(note = fun _ -> "") row =
  match List.find_opt (fun tick -> row_for_value height scale.range tick = row) scale.ticks with
  | Some tick ->
      let value = label tick in
      O.pad_left ~width_of axis (if width_of value <= axis then value else "…") ^ " ┤ "
  | None -> O.pad ~width_of axis (note row) ^ " │ "

let with_value_axis ~width_of ~axis ~height ~scale ~label ?(note = fun _ -> "") rows =
  let rows = Array.of_list rows in
  List.init height (fun row ->
      let prefix = axis_prefix ~width_of ~axis ~height ~scale ~label ~note row in
      prefix ^ if row < Array.length rows then rows.(row) else "")

(* The same axis for rows of spans: the prefix is a plain span of its own. *)
let with_value_axis_spans ~width_of ~axis ~height ~scale ~label ?(note = fun _ -> "") rows =
  let rows = Array.of_list rows in
  List.init height (fun row ->
      let prefix = axis_prefix ~width_of ~axis ~height ~scale ~label ~note row in
      if row < Array.length rows then (O.Plain, prefix) :: rows.(row) else [ (O.Plain, prefix) ])

(* Several series share one braille grid: masks are unioned so a column never
   overwrites another series, and each series' marker sits on its selected
   value when that cell carries no line. *)
type spans = (O.style * string) list
(** A row of styled spans: the text of the row is the concatenation of its
    spans, so one chart row can name the series each of its cells belongs to. *)

type owner = Line of int | Marked | Quiet

let multi_line_spans ~width ~height ~series ~selected ~range ~grid_rows ~markers ?(guides = []) ()
    =
  let width = max 1 width and height = max 1 height in
  let series = List.map Array.of_list series in
  let samples = List.map (fun values -> series_sample (Array.to_list values)) series in
  let count = match series with values :: _ -> Array.length values | [] -> 0 in
  (* The cell's dots and the series that owns the cell: an overlapping cell
     takes the later series' colour, because the braille glyph keeps every
     series' dots and one cell can only carry one colour. The marker glyphs
     still name both series. *)
  let cell_of_series = List.mapi (fun index sample -> (index, sample)) samples in
  let mask_and_owner cell_x cell_y =
    List.fold_left
      (fun (mask, owner) (index, sample) ->
        let bits = braille_mask sample range width height cell_x cell_y in
        if bits = 0 then (mask, owner) else (mask lor bits, Some index))
      (0, None) cell_of_series
  in
  let selected_x = x_for_index width count selected in
  let marker_at =
    List.filter_map
      (fun (index, values) ->
        if selected >= 0 && selected < Array.length values && index < List.length markers then
          Some (row_for_value (height * 4) range values.(selected) / 4, List.nth markers index, index)
        else None)
      (List.mapi (fun index values -> (index, values)) series)
  in
  (* As in LOAM, the selected values' markers win over the line; two markers in
     one cell become one shared mark rather than a false time position. *)
  let cells_of_row row =
    List.init width (fun col ->
        match
          if col = selected_x then List.filter (fun (y, _, _) -> y = row) marker_at else []
        with
        | [ (_, marker, index) ] -> (Line index, marker)
        | _ :: _ :: _ -> (Marked, "◎")
        | [] ->
            let mask, owner = mask_and_owner col row in
            if mask <> 0 then
              ((match owner with Some index -> Line index | None -> Quiet), glyph mask)
            else if col = selected_x then (Quiet, "│")
            else if List.mem col guides then (Quiet, "┊")
            else if List.mem row grid_rows then (Quiet, "┄")
            else (Quiet, " "))
  in
  (* Consecutive cells of one owner become one span; the span's text is built
     in a buffer, so the rows stay linear in their width. *)
  let spans_of_cells cells =
    let flush owner buffer acc = (owner, Buffer.contents buffer) :: acc in
    let rec loop owner buffer acc = function
      | [] -> List.rev (flush owner buffer acc)
      | (cell_owner, glyph) :: rest ->
          if cell_owner = owner then begin
            Buffer.add_string buffer glyph;
            loop owner buffer acc rest
          end else begin
            let acc = flush owner buffer acc in
            Buffer.clear buffer;
            Buffer.add_string buffer glyph;
            loop cell_owner buffer acc rest
          end
    in
    match cells with
    | [] -> []
    | (owner, glyph) :: rest ->
        let buffer = Buffer.create 16 in
        Buffer.add_string buffer glyph;
        loop owner buffer [] rest
  in
  List.init height (fun row ->
      let cells = cells_of_row row in
      spans_of_cells cells
      |> List.map (fun (owner, text) ->
             let style =
               match owner with Line index -> O.Series index | Marked -> O.Active | Quiet -> O.Chrome
             in
             (style, text)))
