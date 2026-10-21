(* Owner-local chart painter checks: exact scaling, bounded widths, collision
   glyphs, annotation rows and connected paths. Synthetic amounts only. *)
module C = Trend_locus_chart

let z = Z.of_int
let require condition why = if not condition then failwith why

let utf8_width text =
  let width = ref 0 in
  String.iter (fun c -> if Char.code c land 0xc0 <> 0x80 then incr width) text;
  !width

let contains text piece =
  let piece_length = String.length piece in
  let limit = String.length text - piece_length in
  let rec loop index =
    index <= limit && (String.sub text index piece_length = piece || loop (index + 1))
  in
  piece_length = 0 || loop 0

let has rendered piece = List.exists (fun row -> contains row piece) rendered.C.rows

let has_digit text =
  let found = ref false in
  String.iter (fun c -> if c >= '0' && c <= '9' then found := true) text;
  !found

let bounded width rendered = List.for_all (fun row -> utf8_width row <= width) rendered.C.rows
let series marker values : C.series = { marker; values = Array.of_list values }

let chart ?(selected = 0) ?(guides = []) ?(annotations = []) ~count series : C.t =
  { series = Array.of_list series; count; selected; guides; annotations }

let render ?(width = 40) ?(height = 8) t : C.rendered =
  C.render ~width ~height ~width_of:utf8_width ~label:Z.to_string t

let () =
  (* A 601-digit amount cannot fit an exact axis and is never cut into another
     printed number. *)
  let huge = Z.add (Z.pow (z 10) 600) (z 7) in
  let huge_chart =
    render ~width:40 ~height:6 (chart ~count:2 [ series C.markers.(0) [ Z.neg huge; huge ] ])
  in
  require (not huge_chart.C.axis_exact) "601-digit labels cannot fit a narrow exact axis";
  require
    (List.for_all (fun row -> not (has_digit row)) huge_chart.rows)
    "an inexact axis never prints a partial numeric label";

  (* Constant, negative and degenerate surfaces stay bounded and sane. *)
  let constant =
    render ~width:12 ~height:5 (chart ~count:2 [ series C.markers.(0) [ z 5; z 5 ] ])
  in
  require (bounded 12 constant) "a constant series stays inside the display width";
  let negative =
    render ~width:12 ~height:5 (chart ~count:2 [ series C.markers.(0) [ z (-7); z (-3) ] ])
  in
  require (bounded 12 negative) "negative values stay inside the display width";
  let empty = render ~width:0 ~height:3 (chart ~count:2 [ series C.markers.(0) [ z 1; z 2 ] ]) in
  require
    (List.length empty.rows = 3 && List.for_all (fun row -> row = "") empty.rows)
    "zero width still returns the requested rows";
  let flat = render ~width:20 ~height:0 (chart ~count:2 [ series C.markers.(0) [ z 1; z 2 ] ]) in
  require (flat.rows = []) "zero height paints nothing";
  let tiny = render ~width:2 ~height:3 (chart ~count:2 [ series C.markers.(0) [ z 1; z 2 ] ]) in
  require (List.length tiny.rows = 3 && bounded 2 tiny) "a tiny surface stays bounded";

  (* Distinct series meeting in one cell collide; one series reusing a cell for
     several x positions does not. *)
  let collide =
    render ~width:30 ~height:6
      (chart ~count:2 [ series C.markers.(0) [ z 10; z 20 ]; series C.markers.(1) [ z 10; z 20 ] ])
  in
  require (has collide C.collision) "two series sharing a cell show the collision glyph";
  let repeated_values = List.init 8 (fun _ -> z 10) in
  let repeated =
    render ~width:8 ~height:4 (chart ~count:8 [ series C.markers.(0) repeated_values ])
  in
  require (has repeated C.markers.(0)) "a plotted series still marks its values";
  require
    (not (has repeated C.collision))
    "one series reusing a cell never claims a cross-series collision";

  (* Annotations paint their own row without guides; intersecting ones collide. *)
  let annotation glyph at : C.annotation = { glyph; at } in
  let plotted = [ series C.markers.(0) [ z 1; z 2; z 3 ] ] in
  let annotated =
    render ~width:30 ~height:6 (chart ~count:3 ~annotations:[ annotation "A" [ 1 ] ] plotted)
  in
  require (has annotated "A") "an annotation row is visible without guides";
  let intersecting =
    render ~width:30 ~height:6
      (chart ~count:3 ~annotations:[ annotation "A" [ 1 ]; annotation "B" [ 1 ] ] plotted)
  in
  require (has intersecting C.collision) "annotations marking one cell collide";

  (* Two exact endpoints are joined along the interior; a lone point is not. *)
  let connected =
    render ~width:20 ~height:8 (chart ~count:2 [ series C.markers.(0) [ z 0; z 100 ] ])
  in
  require (has connected "·") "two exact endpoints are connected along the interior";
  let isolated = render ~width:20 ~height:8 (chart ~count:1 [ series C.markers.(0) [ z 100 ] ]) in
  require
    (has isolated C.markers.(0) && not (has isolated "·"))
    "a lone point paints no connecting path";
  print_endline
    "PASS: Trend/Locus chart exact huge-axis fallback, bounded degenerate surfaces, collision \
     glyphs, annotation rows and connected paths."
