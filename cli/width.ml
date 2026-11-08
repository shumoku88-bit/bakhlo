(* How many terminal cells a string takes, so tables line up. East Asian wide and
   fullwidth characters (kanji, kana, hangul, fullwidth forms, most emoji) take two
   cells, combining marks and zero-width characters none, everything else one. *)
let wide =
  [
    (0x1100, 0x115F);
    (0x2329, 0x232A);
    (0x2E80, 0x303E);
    (0x3041, 0x33FF);
    (0x3400, 0x4DBF);
    (0x4E00, 0x9FFF);
    (0xA000, 0xA4CF);
    (0xAC00, 0xD7A3);
    (0xF900, 0xFAFF);
    (0xFE10, 0xFE19);
    (0xFE30, 0xFE6F);
    (0xFF00, 0xFF60);
    (0xFFE0, 0xFFE6);
    (0x1F300, 0x1F64F);
    (0x1F900, 0x1F9FF);
    (0x20000, 0x2FFFD);
    (0x30000, 0x3FFFD);
  ]

let zero = [ (0x0300, 0x036F); (0x200B, 0x200F); (0xFE00, 0xFE0F) ]
let within ranges c = List.exists (fun (a, b) -> c >= a && c <= b) ranges
let cells c = if within zero c then 0 else if within wide c then 2 else 1

let of_string s =
  let rec go i total =
    if i >= String.length s then total
    else
      let d = String.get_utf_8_uchar s i in
      go (i + Uchar.utf_decode_length d) (total + cells (Uchar.to_int (Uchar.utf_decode_uchar d)))
  in
  go 0 0
