open Base

type token = Word of string | Quoted of string
let space = function ' ' | '\t' -> true | _ -> false
let hex c = match c with
  | '0' .. '9' -> Some (Char.to_int c - Char.to_int '0')
  | 'a' .. 'f' -> Some (10 + Char.to_int c - Char.to_int 'a')
  | 'A' .. 'F' -> Some (10 + Char.to_int c - Char.to_int 'A')
  | _ -> None

let decode line =
  let length = String.length line in
  (* Buffer owns only this one decoded field. Local mutation avoids quadratic
     concatenation; it never escapes or modifies supplied/source evidence. *)
  let rec quoted buffer i =
    if i >= length then Error "unterminated quoted field"
    else match line.[i] with
      | '"' -> Ok (Buffer.contents buffer, i + 1)
      | '\\' ->
        if i + 1 >= length then Error "unfinished escape"
        else (match line.[i + 1] with
          | '"' | '\\' as c -> Buffer.add_char buffer c; quoted buffer (i + 2)
          | 'n' -> Buffer.add_char buffer '\n'; quoted buffer (i + 2)
          | 'r' -> Buffer.add_char buffer '\r'; quoted buffer (i + 2)
          | 't' -> Buffer.add_char buffer '\t'; quoted buffer (i + 2)
          | 'x' when i + 3 < length ->
            (match hex line.[i + 2], hex line.[i + 3] with
             | Some hi, Some lo ->
               Buffer.add_char buffer (Char.of_int_exn (hi * 16 + lo)); quoted buffer (i + 4)
             | _ -> Error "expected two hexadecimal digits after \\x")
          | 'x' -> Error "short hexadecimal escape"
          | _ -> Error "unsupported escape")
      | c when Char.to_int c < 32 || Char.to_int c = 127 -> Error "control byte requires an escape"
      | c -> Buffer.add_char buffer c; quoted buffer (i + 1)
  in
  let rec word_end i =
    if i >= length || space line.[i] then i else word_end (i + 1)
  in
  let rec tokens reversed i =
    if i >= length then Ok (List.rev reversed)
    else if space line.[i] then tokens reversed (i + 1)
    else if Char.equal line.[i] '"' then
      match quoted (Buffer.create 32) (i + 1) with
      | Error problem -> Error problem
      | Ok (text, next) ->
        if next < length && not (space line.[next]) then Error "quoted fields require whitespace separation"
        else tokens (Quoted text :: reversed) next
    else
      let next = word_end i in
      let word = String.sub line ~pos:i ~len:(next - i) in
      if String.exists word ~f:(fun c -> Char.equal c '"' || Char.to_int c < 32 || Char.to_int c = 127)
      then Error "invalid unquoted token"
      else tokens (Word word :: reversed) next
  in
  tokens [] 0
