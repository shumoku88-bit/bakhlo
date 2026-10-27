(* Exact amount text: decimal quanta, positive arithmetic expressions and display.
   No household, Measure lookup, clock or I/O; callers supply the retained scale. *)
module R = Q

exception Refused of string

let require p why = if not p then raise (Refused why)
let protect f = try Ok (f ()) with Refused why -> Error why

let integer_syntax s =
  let len = String.length s in
  let start = if len > 0 && (s.[0] = '-' || s.[0] = '+') then 1 else 0 in
  let rec digits n = n = len || (s.[n] >= '0' && s.[n] <= '9' && digits (n + 1)) in
  len > start && digits start

let integer s =
  require (integer_syntax s) "invalid-integer";
  Z.of_string s

let format ~decimals n =
  if decimals = 0 then Z.to_string n
  else
    let factor = Z.pow (Z.of_int 10) decimals in
    let whole, fraction = Z.div_rem (Z.abs n) factor in
    let digits = Z.to_string fraction in
    (if Z.sign n < 0 then "-" else "")
    ^ Z.to_string whole ^ "."
    ^ String.make (decimals - String.length digits) '0'
    ^ digits

let normalize_amount_text text =
  let len = String.length text in
  let b = Buffer.create len in
  let rec loop i =
    if i >= len then Buffer.contents b
    else if i + 2 < len && Char.code text.[i] = 0xEF && Char.code text.[i + 1] = 0xBC then
      let c3 = Char.code text.[i + 2] in
      if c3 >= 0x90 && c3 <= 0x99 then begin
        Buffer.add_char b (Char.chr (Char.code '0' + (c3 - 0x90)));
        loop (i + 3)
      end
      else begin
        (match c3 with
        | 0x8C -> Buffer.add_char b ','
        | 0x8E -> Buffer.add_char b '.'
        | 0x8B -> Buffer.add_char b '+'
        | 0x8D -> Buffer.add_char b '-'
        | 0x8A -> Buffer.add_char b '*'
        | 0x8F -> Buffer.add_char b '/'
        | 0x88 -> Buffer.add_char b '('
        | 0x89 -> Buffer.add_char b ')'
        | _ -> Buffer.add_substring b text i 3);
        loop (i + 3)
      end
    else if i + 1 < len && text.[i] = '\xc3' && (text.[i + 1] = '\x97' || text.[i + 1] = '\xb7')
    then begin
      Buffer.add_char b (if text.[i + 1] = '\x97' then '*' else '/');
      loop (i + 2)
    end
    else if i + 2 < len && text.[i] = '\xe3' && text.[i + 1] = '\x80' && text.[i + 2] = '\x80' then begin
      Buffer.add_char b ' ';
      loop (i + 3)
    end
    else begin
      Buffer.add_char b text.[i];
      loop (i + 1)
    end
  in
  loop 0

let parse_whole whole =
  let is_digit c = c >= '0' && c <= '9' in
  if whole = "" then raise (Refused "invalid-amount");
  if not (String.contains whole ',') then begin
    require (String.for_all is_digit whole) "invalid-amount";
    whole
  end
  else
    let groups = String.split_on_char ',' whole in
    match groups with
    | [] -> raise (Refused "invalid-amount")
    | g0 :: rest ->
        require (rest <> []) "invalid-amount";
        let len0 = String.length g0 in
        require (len0 >= 1 && len0 <= 3 && String.for_all is_digit g0) "invalid-amount";
        List.iter
          (fun g -> require (String.length g = 3 && String.for_all is_digit g) "invalid-amount")
          rest;
        String.concat "" groups

let calculate_amount decimals text =
  (* shortcut: cap expression input to bound recursive nesting, raise it if real receipts need more. *)
  require (String.length text <= 4096) "invalid-amount";
  let length = String.length text and pos = ref 0 in
  let rec spaces () =
    if !pos < length && text.[!pos] = ' ' then (
      incr pos;
      spaces ())
  in
  let decimal () =
    spaces ();
    let start = !pos in
    while !pos < length && match text.[!pos] with '0' .. '9' | ',' | '.' -> true | _ -> false do
      incr pos
    done;
    let raw = String.sub text start (!pos - start) in
    match String.split_on_char '.' raw with
    | [ whole ] -> R.of_bigint (integer (parse_whole whole))
    | [ whole; fraction ] ->
        require
          (fraction <> "" && String.for_all (fun c -> c >= '0' && c <= '9') fraction)
          "invalid-amount";
        let whole = parse_whole whole in
        R.make (integer (whole ^ fraction)) (Z.pow (Z.of_int 10) (String.length fraction))
    | _ -> raise (Refused "invalid-amount")
  in
  let rec atom () =
    spaces ();
    if !pos < length && text.[!pos] = '(' then (
      incr pos;
      let value = expression () in
      spaces ();
      require (!pos < length && text.[!pos] = ')') "invalid-amount";
      incr pos;
      value)
    else decimal ()
  and product () =
    let rec more value =
      spaces ();
      if !pos < length && (text.[!pos] = '*' || text.[!pos] = '/') then (
        let op = text.[!pos] in
        incr pos;
        let right = atom () in
        if op = '/' then require (not (R.equal right R.zero)) "division-by-zero";
        more (if op = '*' then R.mul value right else R.div value right))
      else value
    in
    more (atom ())
  and expression () =
    let rec more value =
      spaces ();
      if !pos < length && (text.[!pos] = '+' || text.[!pos] = '-') then (
        let op = text.[!pos] in
        incr pos;
        let right = product () in
        more (if op = '+' then R.add value right else R.sub value right))
      else value
    in
    more (product ())
  in
  let value = expression () in
  spaces ();
  require (!pos = length) "invalid-amount";
  require (R.sign value > 0) "non-positive-amount";
  let quanta = R.mul value (R.of_bigint (Z.pow (Z.of_int 10) decimals)) in
  require (Z.equal (R.den quanta) Z.one) "indivisible-amount";
  R.num quanta

let decimal_quanta ~decimals text =
  let is_digit c = c >= '0' && c <= '9' in
  match String.split_on_char '.' text with
  | [ whole ] ->
      let clean_whole = parse_whole whole in
      Z.mul (integer clean_whole) (Z.pow (Z.of_int 10) decimals)
  | [ whole; fraction ] ->
      let clean_whole = parse_whole whole in
      require (fraction <> "" && String.for_all is_digit fraction) "invalid-amount";
      require (decimals > 0 && String.length fraction <= decimals) "amount-precision";
      integer (clean_whole ^ fraction ^ String.make (decimals - String.length fraction) '0')
  | [] | _ :: _ -> raise (Refused "invalid-amount")

let parse_positive ~decimals text =
  protect (fun () ->
      let norm = normalize_amount_text text in
      let expression =
        String.exists (function '+' | '-' | '*' | '/' | '(' | ')' -> true | _ -> false) norm
      in
      if expression then calculate_amount decimals norm
      else
        let n = decimal_quanta ~decimals norm in
        require (Z.sign n > 0) "non-positive-amount";
        n)

let parse_signed ~decimals text =
  protect (fun () ->
      let text = String.trim text in
      require (text <> "") "empty-amount";
      let is_neg, clean_text =
        if String.starts_with ~prefix:"-" text then
          (true, String.sub text 1 (String.length text - 1))
        else if String.starts_with ~prefix:"+" text then
          (false, String.sub text 1 (String.length text - 1))
        else (false, text)
      in
      let n = decimal_quanta ~decimals (normalize_amount_text clean_text) in
      if is_neg then Z.neg n else n)
