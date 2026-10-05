open Base

type section = { name : string; body : string }
type t = section list

type error =
  | Invalid_utf8 of { byte_offset : int }
  | Framing of { byte_offset : int; problem : string }

let ( let* ) result f = Result.bind result ~f
let fail byte_offset problem = Error (Framing { byte_offset; problem })
let next text pos = pos + Stdlib.Uchar.utf_decode_length (Stdlib.String.get_utf_8_uchar text pos)

let validate_utf8 text =
  let rec loop pos =
    if pos = String.length text then Ok ()
    else if not (Stdlib.Uchar.utf_decode_is_valid (Stdlib.String.get_utf_8_uchar text pos)) then
      Error (Invalid_utf8 { byte_offset = pos })
    else loop (next text pos)
  in
  loop 0

let valid_name name =
  (not (String.is_empty name))
  && not (String.exists name ~f:(function '\t' | '\r' | '\n' -> true | _ -> false))

let of_string text =
  let* () = validate_utf8 text in
  let size = String.length text in
  let line pos =
    match String.index_from text pos '\n' with
    | None -> fail pos "missing framing newline"
    | Some stop -> Ok (String.sub text ~pos ~len:(stop - pos), stop + 1)
  in
  let* header, start = line 0 in
  if not (String.equal header "LOAM-HOUSEHOLD-IMAGE\t2") then
    fail 0 "unsupported HouseholdImage header"
  else
    let count pos spelling limit =
      if String.is_empty spelling then fail pos "empty section length"
      else
        let rec digits i n =
          if i = String.length spelling then Ok n
          else
            match spelling.[i] with
            | '0' .. '9' as c ->
                let d = Char.to_int c - Char.to_int '0' in
                (* Bound by remaining BYTES before conversion; scalar extent is then
                 checked independently. No overflow/truncation of a valid extent. *)
                if n > limit / 10 || (n = limit / 10 && d > limit % 10) then
                  fail pos "section length exceeds remaining input"
                else digits (i + 1) ((n * 10) + d)
            | _ -> fail pos "section length must be unsigned decimal"
        in
        digits 0 0
    in
    let rec take pos remaining =
      if remaining = 0 then Ok pos
      else if pos = size then fail pos "truncated section body"
      else take (next text pos) (remaining - 1)
    in
    let rec sections pos seen reversed =
      if pos = size then Ok (List.rev reversed)
      else
        let* row, body_start = line pos in
        match String.split row ~on:'\t' with
        | [ "SECTION"; name; spelling ] when valid_name name ->
            if Set.mem seen name then fail pos "repeated section name"
            else
              let* length = count pos spelling (size - body_start) in
              let* stop = take body_start length in
              let body = String.sub text ~pos:body_start ~len:(stop - body_start) in
              sections stop (Set.add seen name) ({ name; body } :: reversed)
        | _ -> fail pos "expected SECTION, safe name and character length"
    in
    sections start (Set.empty (module String)) []

let sections t = t
