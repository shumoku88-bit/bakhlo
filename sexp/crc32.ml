type t = int32

let poly = 0xedb88320l

let table =
  let t = Array.make 256 0l in
  for i = 0 to 255 do
    let c = ref (Int32.of_int i) in
    for _ = 0 to 7 do
      if Int32.logand !c 1l <> 0l then
        c := Int32.logxor (Int32.shift_right_logical !c 1) poly
      else
        c := Int32.shift_right_logical !c 1
    done;
    t.(i) <- !c
  done;
  t

let of_substring s pos len =
  let crc = ref 0xffffffffl in
  let limit = pos + len in
  for i = pos to limit - 1 do
    let byte = Char.code s.[i] in
    let idx = Int32.to_int (Int32.logand (Int32.logxor !crc (Int32.of_int byte)) 0xffl) in
    crc := Int32.logxor (Int32.shift_right_logical !crc 8) table.(idx)
  done;
  Int32.logxor !crc 0xffffffffl

let of_string s = of_substring s 0 (String.length s)

let to_hex crc = Printf.sprintf "%08lx" crc

let of_hex s =
  if String.length s <> 8 then None
  else
    let valid =
      String.for_all
        (fun c ->
          (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))
        s
    in
    if not valid then None
    else
      try Some (Int32.of_string ("0x" ^ s))
      with _ -> None
