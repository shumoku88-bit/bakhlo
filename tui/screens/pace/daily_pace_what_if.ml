(* LOAM DailyPaceWhatIf over Book.daily_pace. Unlike LOAM (JPY only),
   any pool Measure works at its own scale, and a leading [+] prices an
   income into the pool ([-] or no sign is a purchase, as in LOAM). *)
module B = Bakhlo_household.Book
module O = Ui_render
module Panel = Ui_panel

type projection = {
  current_per_day : Z.t;
  projected_per_day : Z.t;
  change_per_day : Z.t;
  available_after : Z.t;
}

let scale book measure = Option.value ~default:0 (List.assoc_opt measure (B.measures book))
let unit_name (p : B.daily_pace) = String.uppercase_ascii p.measure

(* The book's pace Measure, even when today's answer is unavailable. *)
let units ~measure = String.uppercase_ascii measure

(* [+] is an income, [-] or no sign a purchase; the rest is the amount. *)
let split_sign input =
  let rest () = String.sub input 1 (String.length input - 1) in
  if String.starts_with ~prefix:"+" input then (true, rest ())
  else if String.starts_with ~prefix:"-" input then (false, rest ())
  else (false, input)

let income input = fst (split_sign input)

let project ~book (p : B.daily_pace) input =
  let income, digits = split_sign input in
  let valid =
    digits <> ""
    && String.length digits <= 18
    && String.for_all
         (fun c -> (c >= '0' && c <= '9') || (c = '.' && scale book p.measure > 0))
         digits
  in
  if p.remaining_days <= 0 then Error "No remaining days in this cycle."
  else if not valid then
    Error ("Enter a " ^ unit_name p ^ " amount, +amount for income (up to 18 digits).")
  else
    match B.parse_signed_amount book p.measure digits with
    | Error _ -> Error ("Invalid " ^ unit_name p ^ " amount.")
    | Ok quanta ->
        let after = (if income then Z.add else Z.sub) p.available_through_end quanta in
        let projected = Z.ediv after (Z.of_int p.remaining_days) in
        Ok
          {
            current_per_day = p.daily_pace_quanta;
            projected_per_day = projected;
            change_per_day = Z.sub projected p.daily_pace_quanta;
            available_after = after;
          }

type t = { amount : string; notice : string }

let create () = { amount = ""; notice = "" }

type step = Stay of t | Back

let update ~book ~measure ~pace t (input : Ui_input.input) =
  let decimal =
    match pace with Ok (p : B.daily_pace) -> scale book p.measure > 0 | Error _ -> false
  in
  match input with
  | `Key ((`Escape | `ASCII ('q' | 'Q')), []) -> Back
  | `Key (`Backspace, []) ->
      let n = String.length t.amount in
      Stay { amount = (if n = 0 then "" else String.sub t.amount 0 (n - 1)); notice = "" }
  | `Key (`ASCII c, []) ->
      let sign = (c = '+' || c = '-') && t.amount = "" in
      if
        sign
        || ((c >= '0' && c <= '9') || (decimal && c = '.'))
           && String.length (snd (split_sign t.amount)) < 18
      then Stay { amount = t.amount ^ String.make 1 c; notice = "" }
      else
        Stay
          {
            t with
            notice =
              "Only " ^ units ~measure
              ^ " digits (at most 18) after an optional + or -. Esc/q closes.";
          }
  | _ -> Stay t

let rows ~width_of ~width ~book ~measure ~pace t =
  let line text = (O.Plain, text) in
  let info text = List.map line (O.wrap_text ~width_of (max 1 width) text) in
  let kind = if income t.amount then "Income" else "Purchase" in
  let label = " " ^ kind ^ " (" ^ units ~measure ^ "): " in
  let input =
    let shown, caret =
      O.input_text ~width_of
        ~width:(max 1 (width - width_of label))
        ~cursor:None ~caret:"|" t.amount
    in
    ( (match caret with Some col -> O.Input (width_of label + col) | None -> O.Plain),
      label ^ shown )
  in
  [ line " Daily Pace / What if"; input ]
  @ (match pace with
    | Error why ->
        info "Current projection unavailable (not zero)."
        @ info ("Current Daily Pace unavailable: " ^ why)
    | Ok (p : B.daily_pace) -> (
        let fmt q = Book_display.format_money book p.measure q in
        [
          line (" Current: " ^ fmt p.daily_pace_quanta ^ " " ^ p.measure ^ "/day");
          line (" Remaining days: " ^ string_of_int p.remaining_days);
          line (" Already protected Scheduled: " ^ fmt p.automatic_deductions ^ " " ^ p.measure);
        ]
        @
        if t.amount = "" then
          info " Enter amount to compare (+amount for income); nothing is recorded."
        else
          match project ~book p t.amount with
          | Error why -> info why
          | Ok r ->
              [
                line
                  (" After " ^ String.lowercase_ascii kind ^ ": " ^ fmt r.projected_per_day ^ " "
                 ^ p.measure ^ "/day");
                line (" Daily change: " ^ fmt r.change_per_day ^ " " ^ p.measure ^ "/day");
                line (" Available after: " ^ fmt r.available_after ^ " " ^ p.measure);
              ]))
  @ if t.notice = "" then [] else info t.notice

let footer =
  [
    (O.Chrome, " Immediate purchase (or +income) in selected Daily Pace pool only.");
    (O.Chrome, " Not already Scheduled. No writes or reservations. Esc/q closes.");
  ]

(* LOAM fitWithFooter: the body above, the footer pinned to the bottom rows. *)
let fit ~height body =
  let room = max 0 (height - List.length footer) in
  let body = List.filteri (fun i _ -> i < room) body in
  body @ List.init (room - List.length body) (fun _ -> (O.Plain, "")) @ footer

let frame ~width_of ~screen ~body:((body_w, body_h) as region) ~book ~measure ~pace t =
  if body_w >= 62 && body_h >= 20 then
    let pane_w = min 86 (body_w - 4) in
    let width = pane_w - 2 in
    rows ~width_of ~width ~book ~measure ~pace t
    |> fit ~height:16
    |> List.map (fun (style, text) ->
        (* The frame adds one border cell before the caret column. *)
        ( (match style with O.Input col -> O.Input (col + 1) | s -> s),
          O.clip_text ~width_of width text ))
    |> Panel.frame_rows ~inset:0 ~width_of ~width:pane_w ~height:18 ~focused:true
         ~title:"Daily Pace / What if"
    |> Ui_overlay.centered ~width_of ~screen ~body:region ~pane_width:pane_w ~caret:`Bounded
  else
    let width = max 1 body_w in
    rows ~width_of ~width ~book ~measure ~pace t
    |> fit ~height:body_h
    |> List.map (fun (style, text) ->
        (style, O.pad ~width_of width (O.clip_text ~width_of width text)))
    |> Ui_overlay.centered ~width_of ~screen ~body:region ~pane_width:width ~caret:`Bounded
