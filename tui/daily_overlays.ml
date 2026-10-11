(* Shared physical terminal geometry and read-only evidence formatting.
   Controllers and editors own navigation; these primitives never publish. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module A = Daily_actions
let tr = Ui_text.tr

type style = Plain | Active | Heading | Status | Chrome | Frame | Focused_frame
  | Panel | Panel_heading | Panel_active

let panel_width = 34

let utf8 c =
  let b = Buffer.create 4 in
  Uutf.Buffer.add_utf_8 b c;
  Buffer.contents b

let printable_uchar c =
  let n = Uchar.to_int c in
  n >= 32 && (n < 127 || n > 159)

let visible text =
  let b = Buffer.create (String.length text) in
  Uutf.String.fold_utf_8
    (fun () _ -> function
      | `Uchar c ->
          let n = Uchar.to_int c in
          if n < 32 || (n >= 127 && n <= 159) then
            Buffer.add_string b (Printf.sprintf "\\\\u%04x" n)
          else Uutf.Buffer.add_utf_8 b c
      | `Malformed bytes ->
          String.iter (fun c -> Buffer.add_string b (Printf.sprintf "\\\\x%02x" (Char.code c))) bytes)
    () text;
  Buffer.contents b

let clip_text ~width_of room value =
  let text = visible value in
  if room <= 0 then ""
  else if width_of text <= room then text
  else
    let _, prefix =
      Uutf.String.fold_utf_8
        (fun (stopped, prefix) _ -> function
          | `Uchar c when not stopped ->
              let next = prefix ^ utf8 c in
              if width_of next <= room - width_of "…" then (false, next)
              else (true, prefix)
          | `Uchar _ | `Malformed _ -> (stopped, prefix))
        (false, "") text
    in
    if width_of "…" <= room then prefix ^ "…" else String.make room '.'

let pad ~width_of width value =
  let text = clip_text ~width_of width value in
  text ^ String.make (max 0 (width - width_of text)) ' '

let panel_line ?(width = panel_width) ~width_of style text =
  let left = "│ " and right = " │" in
  let room = max 0 (width - width_of left - width_of right) in
  (style, left ^ pad ~width_of room text ^ right)

let rule ~width_of room =
  let cells = max 1 (width_of "─") in
  String.concat "" (List.init (max 0 room / cells) (fun _ -> "─"))
  ^ String.make (max 0 room mod cells) ' '

let panel_border ?(width = panel_width) ?(style = Focused_frame) ~width_of title =
  let left = "╭─" and right = "─╮" in
  let room = max 0 (width - width_of left - width_of right) in
  let title = clip_text ~width_of room (" " ^ title ^ " ") in
  (style, left ^ title ^ rule ~width_of (room - width_of title) ^ right)

let panel_bottom ?(width = panel_width) ?(style = Focused_frame) ?(title = "") ~width_of () =
  let room = max 0 (width - width_of "╰╯") in
  let title = if title = "" then "" else clip_text ~width_of room (" " ^ title ^ " ") in
  (style, "╰" ^ title ^ rule ~width_of (room - width_of title) ^ "╯")

let wrap_text ~width_of room text =
  if room <= 0 then []
  else
    let lines, last =
      Uutf.String.fold_utf_8
        (fun (lines, current) _ -> function
          | `Malformed _ -> (lines, current)
          | `Uchar c ->
              let glyph = utf8 c in
              let glyph = if width_of glyph <= room then glyph else clip_text ~width_of room glyph in
              let next = current ^ glyph in
              if current = "" || width_of next <= room then (lines, next)
              else (current :: lines, glyph))
        ([], "") (visible text)
    in
    List.rev (last :: lines)

let review_page ~dimensions:(width, height) ~width_of lines scroll =
  let width = max 4 (min 76 (width - 4)) in
  let capacity = max 1 (height - 7) in
  let lines = List.concat_map (wrap_text ~width_of (max 1 (width - 4))) lines in
  let last = max 0 (List.length lines - capacity) in
  (width, capacity, lines, min last (max 0 scroll), last)

type quantity_value = Unsupported | Known_present | Exact of Z.t

let quantity_value ~book ~measure locus =
  match D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string measure with
  | Ok locus, Ok measure ->
      let coordinate : D.Effect_coordinate.t = { locus; measure } in
      (match Q.query (B.image book) coordinate with
      | Error (Q.Support_unknown _) -> Unsupported
      | Ok (Q.Known_present _) -> Known_present
      | Ok (Q.Exact e) -> Exact (D.Quantity.quanta (Q.quantity e)))
  | Error _, _ | _, Error _ -> Unsupported

let quantity ~book ~measure locus =
  match quantity_value ~book ~measure locus with
  | Unsupported -> tr "Unknown"
  | Known_present -> tr "Present; amount unknown"
  | Exact n -> B.format book measure n

let locus_candidates book query =
  let query = String.lowercase_ascii query in
  let contains text =
    Base.String.is_substring (String.lowercase_ascii text) ~substring:query
  in
  let choices = Option.value ~default:[] (B.approved_loci book) in
  let matches = List.filter (fun id -> contains id || contains (B.label book id)) choices in
  if query = "" then matches
  else let exact, rest = List.partition (fun id -> id = query) matches in exact @ rest

let signed book measure amount =
  (if Z.sign amount > 0 then "+" else "") ^ B.format book measure amount ^ " " ^ measure

let entry_lines book (entry : B.entry) =
  [tr "Effects (exact quantities):"]
  @ List.concat (List.mapi
      (fun n p ->
        let locus = A.lstr (D.Effect.locus p) and measure = A.mstr (D.Effect.measure p) in
        [ A.format_message "Posting %d: %s [%s]" (n + 1) (visible (B.label book locus)) (visible locus);
          "  " ^ signed book measure (A.quanta p) ^
          (match D.Effect.key p with None -> "" | Some key ->
            " / " ^ tr "Key:" ^ " " ^ visible (D.Identifier.Effect_key.to_string key)) ])
      entry.effects)
  @ [ ""; tr "Description:" ^ " " ^ (match entry.memo with None -> tr "(no description)" | Some text -> visible text);
      tr "Date:" ^ " " ^ entry.day; "ID: " ^ visible entry.id ]
  @ (match entry.reversal_of with None -> [] | Some id -> [tr "Reversal of:" ^ " " ^ visible id])
  @ (match entry.exchange with None -> [] | Some (a,b) -> [tr "Exchange keys:" ^ " " ^ visible a ^ " → " ^ visible b])
  @ (B.plans book |> List.filter_map (fun (p : B.plan) ->
      if p.paid_by = Some entry.id then Some (tr "Completed Scheduled:" ^ " " ^ visible p.id ^ " / " ^ p.day)
      else None))

let plan_lines book (plan : B.plan) =
  [tr "Expected Effects (exact quantities):"]
  @ List.mapi (fun n (locus, amount) ->
      A.format_message "Posting %d: %s [%s]  %s" (n+1)
        (visible (B.label book locus)) (visible locus) (signed book plan.measure amount)) plan.changes
  @ ["Due: " ^ plan.day; "ID: " ^ visible plan.id; "Measure: " ^ visible plan.measure]
  @ (match plan.cancelled_on, plan.paid_by with
      | Some day, _ -> [tr "Cancelled on:" ^ " " ^ day]
      | None, Some id -> [tr "Completed by Actual:" ^ " " ^ visible id]
      | None, None -> [tr "Open Scheduled occurrence"])

let preview_lines book (transaction : A.transaction) =
  (match transaction.plan with
  | Some id ->
      [tr "Complete Scheduled:" ^ " " ^ visible id; tr "Actual and completion link publish together."]
      @ (match List.find_opt (fun (p:B.plan) -> p.id=id) (B.plans book) with
        | None -> [] | Some p -> [tr "Original due date (kept):" ^ " " ^ p.day])
  | None -> [if transaction.replace then tr "Correct Actual (same ID)" else tr "Record new Movement"])
  @ entry_lines book transaction.entry
  @ (match transaction.entry.effects with
      | [] -> []
      | first :: _ ->
          let measure=A.mstr (D.Effect.measure first) in
          let total=List.fold_left (fun n posting ->
            let value=A.quanta posting in if Z.sign value>0 then Z.add n value else n)
            Z.zero transaction.entry.effects in
          [tr "Balanced total:" ^ " " ^ B.format book measure total ^ " " ^ measure])
