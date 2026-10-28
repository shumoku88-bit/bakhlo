(* LOAM DailyPaceWhy over Book.daily_pace: the answer already carries
   its pool balances and per-occurrence deductions; this only labels them. *)
module B = Bakhlo_household.Book
module O = Ui_render
module A = Daily_draft
module D = Bakhlo_domain
module Panel = Ui_panel

let support_text book (coordinate : D.Effect_coordinate.t) =
  match B.quantity book ~locus:(A.lstr coordinate.locus) ~measure:(A.mstr coordinate.measure) with
  | Some { support = Zero_origin; _ } -> "recorded history"
  | Some { support = Opening _; _ } -> "opening balance"
  | Some { support = Counted _; _ } -> "observed"
  | None -> "unsupported"

let short_date date =
  if String.length date > 5 then String.sub date 5 (String.length date - 5) else date

let lines ~width_of ~width ~book (p : B.daily_pace) =
  let fmt q = Book_display.format_money book p.measure q in
  let locus (c : D.Effect_coordinate.t) = A.lstr c.locus in
  let pool = List.stable_sort (fun (_, a) (_, b) -> Z.compare b a) p.pool_balances in
  let pool_loci = List.map (fun (c, _) -> locus c) p.pool_balances in
  let plans = B.plans book in
  let deductions =
    List.map
      (fun (id, quanta) -> (id, quanta, List.find_opt (fun (plan : B.plan) -> plan.id = id) plans))
      p.plan_deductions
    |> List.stable_sort (fun (_, _, a) (_, _, b) ->
        let day = function Some (plan : B.plan) -> plan.day | None -> "" in
        compare (day a) (day b))
  in
  (* What a protected occurrence pays into: its receiving Loci outside the pool. *)
  let payee id = function
    | None -> id
    | Some (plan : B.plan) -> (
        match
          List.filter (fun (l, q) -> Z.sign q > 0 && not (List.mem l pool_loci)) plan.changes
        with
        | [] -> id
        | receiving -> String.concat " + " (List.map (fun (l, _) -> B.label book l) receiving))
  in
  let pool_rows =
    List.map (fun (c, q) -> (B.label book (locus c), fmt q, support_text book c)) pool
  in
  (* Still open after its date: protected until completed or retired. *)
  let deduction_rows =
    List.map
      (fun (id, q, plan) ->
        let day = match plan with Some (plan : B.plan) -> plan.day | None -> "" in
        ( short_date day ^ "  " ^ payee id plan,
          fmt q,
          if day <> "" && day < p.observed_at then "overdue, still open" else "" ))
      deductions
  in
  let free = p.available_through_end in
  (* Widths include each row's indent: one space for totals, three for terms. *)
  let names =
    [ " Pool"; " Protected Scheduled"; " Free through cycle end" ]
    @ List.map (fun (name, _, _) -> "   " ^ name) (pool_rows @ deduction_rows)
  in
  let amounts =
    [ fmt p.eligible_pool; "-" ^ fmt p.automatic_deductions; fmt free ]
    @ List.map (fun (_, amount, _) -> amount) (pool_rows @ deduction_rows)
  in
  let name_width = min (width / 2) (List.fold_left (fun w n -> max w (width_of n)) 0 names) in
  let amount_width = List.fold_left (fun w a -> max w (width_of a)) 0 amounts in
  (* [name … amount   note], the amount right-aligned in a shared column. *)
  let row indent name amount note =
    ( O.Plain,
      O.clip_text ~width_of width
        (O.pad ~width_of name_width (indent ^ name)
        ^ "  "
        ^ O.pad_left ~width_of amount_width amount
        ^ if note = "" then "" else "   " ^ note) )
  in
  let blank = (O.Plain, "") in
  [
    ( O.Plain,
      O.clip_text ~width_of width
        (" Today " ^ p.observed_at ^ ": " ^ fmt p.daily_pace_quanta ^ " " ^ p.measure ^ "/day") );
  ]
  @ List.map
      (fun text -> (O.Chrome, text))
      (O.wrap_text ~width_of (max 1 width)
         (" = " ^ fmt free ^ " free ÷ " ^ string_of_int p.remaining_days ^ " days left (cycle ends "
        ^ p.end_exclusive ^ ", exclusive)"))
  @ [ blank; row " " "Pool" (fmt p.eligible_pool) (string_of_int (List.length pool) ^ " balances") ]
  @ List.map (fun (name, amount, note) -> row "   " name amount note) pool_rows
  @ [
      blank;
      row " " "Protected Scheduled"
        ("-" ^ fmt p.automatic_deductions)
        (string_of_int (List.length deductions) ^ " before cycle end");
    ]
  @ (if deduction_rows = [] then [ (O.Chrome, "   (none)") ]
     else List.map (fun (name, amount, note) -> row "   " name amount note) deduction_rows)
  @ [ blank; row " " "Free through cycle end" (fmt free) "" ]

(* Today's terms, or why they are unavailable; never a zero in their place. *)
let explanation_rows ~width_of ~width ~book = function
  | Ok p -> lines ~width_of ~width ~book p
  | Error why ->
      List.map
        (fun text -> (O.Chrome, text))
        (O.wrap_text ~width_of (max 1 width) (" Explanation unavailable (not zero): " ^ why))

type t = { scroll : int }

let create () = { scroll = 0 }

type step = Stay of t | Back

let floating (body_w, body_h) = body_w >= 62 && body_h >= 20

(* Content width and visible rows: inside the frame when floating, below the
   title line otherwise. *)
let geometry ((body_w, body_h) as body) =
  if floating body then (max 1 (min 90 (body_w - 4) - 2), max 0 (body_h - 4))
  else (max 1 body_w, max 0 (body_h - 1))

let update ~width_of ~body ~book ~pace t (input : Ui_input.input) =
  let width, visible = geometry body in
  let total = List.length (explanation_rows ~width_of ~width ~book pace) in
  let last = max 0 (total - visible) in
  let scroll n = Stay { scroll = max 0 (min last n) } in
  match input with
  | `Key ((`Escape | `ASCII ('q' | 'Q' | '?')), []) -> Back
  | `Key ((`Arrow `Down | `ASCII 'j'), []) -> scroll (t.scroll + 1)
  | `Key ((`Arrow `Up | `ASCII 'k'), []) -> scroll (t.scroll - 1)
  | `Key (`Page `Down, []) | `Key (`ASCII 'd', [ `Ctrl ]) -> scroll (t.scroll + max 1 visible)
  | `Key (`Page `Up, []) | `Key (`ASCII 'u', [ `Ctrl ]) -> scroll (t.scroll - max 1 visible)
  | `Key (`Home, []) -> scroll 0
  | `Key (`End, []) -> scroll last
  | _ -> Stay t

let frame ~width_of ~screen ~body:((body_w, body_h) as region) ~book ~pace t =
  let width, visible = geometry region in
  let all = explanation_rows ~width_of ~width ~book pace in
  let start = max 0 (min t.scroll (List.length all - visible)) in
  let shown = List.filteri (fun i _ -> i >= start && i < start + visible) all in
  let shown = shown @ List.init (max 0 (visible - List.length shown)) (fun _ -> (O.Plain, "")) in
  if floating region then
    let pane_w = min 90 (body_w - 4) in
    Panel.frame_rows ~inset:0 ~width_of ~width:pane_w ~height:(body_h - 2) ~focused:true
      ~title:"Daily Pace / Why" shown
    |> Ui_overlay.centered ~width_of ~screen ~body:region ~pane_width:pane_w ~caret:`None
  else
    (O.Plain, " Daily Pace / Why") :: shown
    |> List.map (fun (style, text) -> (style, O.pad ~width_of width text))
    |> Ui_overlay.centered ~width_of ~screen ~body:region ~pane_width:width ~caret:`None
