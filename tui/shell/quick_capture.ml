(* LOAM QuickCapture over the retained Actual entries. Templates are rebuilt
   from the book on every keystroke; amounts are exact quanta at the Measure's
   scale. The record date defaults to Record's own day (LOAM: today). *)
module B = Bakhlo_household.Daily_book
module O = Ui_render
module A = Daily_draft
module D = Bakhlo_domain

type posting = { locus : string; signed : Z.t }
type past = { description : string; date : string; postings : posting list }
type template = { postings : posting list; last_used : string; uses : int; recent : int }
type known = { description : string; last_used : string; uses : int }

(* Current, unreversed, single-Measure entries with both a receiving and a paying side. *)
let history book measure =
  let reversed = List.filter_map (fun (e : B.entry) -> e.reversal_of) (B.entries book) in
  List.filter_map
    (fun (e : B.entry) ->
      let memo = Option.value ~default:"" e.memo in
      if
        e.reversal_of <> None || List.mem e.id reversed || memo = ""
        || not (List.for_all (fun p -> A.mstr (D.Effect.measure p) = measure) e.effects)
      then None
      else
        let postings =
          List.map (fun p -> { locus = A.lstr (D.Effect.locus p); signed = A.quanta p }) e.effects
          |> List.stable_sort (fun a b ->
              match compare a.locus b.locus with 0 -> Z.compare a.signed b.signed | c -> c)
        in
        if
          List.exists (fun p -> Z.sign p.signed > 0) postings
          && List.exists (fun p -> Z.sign p.signed < 0) postings
        then Some ({ description = memo; date = e.day; postings } : past)
        else None)
    (B.entries book)

let template_total (t : template) =
  List.fold_left
    (fun s (p : posting) -> if Z.sign p.signed > 0 then Z.add s p.signed else s)
    Z.zero t.postings

(* Distinct templates for one exact description: most used recently, then latest. *)
let templates_for (past : past list) description =
  let mine =
    List.filter (fun (p : past) -> p.description = description) past
    |> List.stable_sort (fun (a : past) (b : past) -> compare b.date a.date)
  in
  let recent = List.filteri (fun i _ -> i < 10) mine in
  let grouped =
    List.fold_left
      (fun (acc : template list) (p : past) ->
        if List.exists (fun (t : template) -> t.postings = p.postings) acc then
          List.map
            (fun (t : template) ->
              if t.postings = p.postings then { t with uses = t.uses + 1 } else t)
            acc
        else
          acc
          @ [
              {
                postings = p.postings;
                last_used = p.date;
                uses = 1;
                recent =
                  List.length (List.filter (fun (r : past) -> r.postings = p.postings) recent);
              };
            ])
      [] mine
  in
  List.stable_sort
    (fun (a : template) (b : template) ->
      if a.recent <> b.recent then compare b.recent a.recent
      else if a.last_used <> b.last_used then compare b.last_used a.last_used
      else compare b.uses a.uses)
    grouped

let lower = String.lowercase_ascii
let contains needle haystack = Base.String.is_substring haystack ~substring:needle

(* Descriptions matching the typed text: prefixes, then substrings; most used first. *)
let descriptions_for (past : past list) typed =
  let known =
    List.fold_left
      (fun (acc : known list) (p : past) ->
        if List.exists (fun (k : known) -> k.description = p.description) acc then
          List.map
            (fun (k : known) ->
              if k.description = p.description then
                { k with uses = k.uses + 1; last_used = max k.last_used p.date }
              else k)
            acc
        else acc @ [ { description = p.description; last_used = p.date; uses = 1 } ])
      [] past
  in
  let query = lower typed in
  let ranked items =
    List.stable_sort
      (fun (a : known) (b : known) ->
        if a.uses <> b.uses then compare b.uses a.uses else compare b.last_used a.last_used)
      items
  in
  if query = "" then []
  else
    let prefix (k : known) = String.starts_with ~prefix:query (lower k.description) in
    ranked (List.filter prefix known)
    @ ranked (List.filter (fun k -> (not (prefix k)) && contains query (lower k.description)) known)

(* `580`, `1,200`, `580円` and `¥580` are amount words; separators are dropped. *)
let amount_word word =
  let body =
    List.fold_left
      (fun acc s ->
        String.concat ""
          (String.split_on_char ',' (Base.String.substr_replace_all acc ~pattern:s ~with_:"")))
      word [ "円"; "¥"; "￥" ]
  in
  if
    body = ""
    || (not (String.for_all (fun c -> (c >= '0' && c <= '9') || c = '.') body))
    || not (String.exists (fun c -> c >= '0' && c <= '9') body)
  then None
  else Some body

type parsed = {
  description : string;
  total : string option;
  extras : (string * string option) list;
  describing : bool;  (** Still typing the description: no amount and no separator after it yet. *)
}

let words text =
  Base.String.substr_replace_all text ~pattern:"　" ~with_:" "
  |> String.split_on_char ' '
  |> List.filter (( <> ) "")

let rec pairs = function
  | [] -> []
  | [ word ] -> [ (word, None) ]
  | word :: next :: tail -> (
      match amount_word next with
      | Some amount -> (word, Some amount) :: pairs tail
      | None -> (word, None) :: pairs (next :: tail))

let ends_with_separator text =
  String.ends_with ~suffix:" " text || String.ends_with ~suffix:"　" text

let parse text =
  let ws = words text in
  let rec split before = function
    | w :: rest when amount_word w = None -> split (w :: before) rest
    | after -> (List.rev before, after)
  in
  let before, after = split [] ws in
  {
    description = String.concat " " before;
    total = Option.bind (List.nth_opt after 0) amount_word;
    extras = (match after with [] -> [] | _ :: rest -> pairs rest);
    describing = after = [] && not (ends_with_separator text);
  }

(* An admitted Locus named by token or label: exactly, else by a unique prefix. *)
let locus_for catalog word =
  let query = lower word in
  match
    List.find_opt (fun (token, label) -> lower token = query || lower label = query) catalog
  with
  | Some (token, _) -> Some token
  | None -> (
      match
        List.filter
          (fun (token, label) ->
            String.starts_with ~prefix:query (lower token)
            || String.starts_with ~prefix:query (lower label))
          catalog
      with
      | [ (token, _) ] -> Some token
      | _ -> None)

type line = { locus : string; quanta : Z.t option; receiving : bool }
type plan = { description : string; total : Z.t option; lines : line list; unknown : string list }

let receiving_lines plan = List.filter (fun l -> l.receiving) plan.lines
let paying_lines plan = List.filter (fun l -> not l.receiving) plan.lines

let sum lines =
  List.fold_left
    (fun acc l -> match (acc, l.quanta) with Some s, Some q -> Some (Z.add s q) | _ -> None)
    (Some Z.zero) lines

let complete plan =
  plan.description <> "" && plan.unknown = []
  && receiving_lines plan <> []
  && paying_lines plan <> []
  && List.for_all (fun l -> match l.quanta with Some q -> Z.sign q > 0 | None -> false) plan.lines
  && sum (receiving_lines plan) = sum (paying_lines plan)

let pays role = role = Some Locus_roles.Asset || role = Some Locus_roles.Liability

(* Put one named Locus into the plan (LOAM supply): a present Locus only takes the
   amount; otherwise it replaces the line with the same role or the only line on
   its side, else joins that side. Assets and liabilities pay; a Locus without a
   role fills the receiving side first, then the paying side. *)
let supply roles plan token amount =
  if List.exists (fun l -> l.locus = token) plan.lines then
    {
      plan with
      lines =
        List.map
          (fun l ->
            if l.locus = token then
              { l with quanta = (match amount with Some _ -> amount | None -> l.quanta) }
            else l)
          plan.lines;
    }
  else
    let role = List.assoc_opt token roles in
    let shares l = role <> None && List.assoc_opt l.locus roles = role in
    let receiving =
      match List.find_opt shares plan.lines with
      | Some l -> l.receiving
      | None ->
          if role <> None then not (pays role)
          else receiving_lines plan = [] || paying_lines plan <> []
    in
    let side = List.filter (fun l -> l.receiving = receiving) plan.lines in
    let target =
      match List.filter shares side with
      | [ l ] -> Some l
      | _ -> ( match side with [ l ] -> Some l | _ -> None)
    in
    match target with
    | Some old ->
        {
          plan with
          lines =
            List.map
              (fun l ->
                if l = old then
                  {
                    l with
                    locus = token;
                    quanta = (match amount with Some _ -> amount | None -> l.quanta);
                  }
                else l)
              plan.lines;
        }
    | None -> { plan with lines = plan.lines @ [ { locus = token; quanta = amount; receiving } ] }

(* Give the one unamounted line on each side whatever the total leaves. *)
let fill plan =
  match plan.total with
  | None -> plan
  | Some total ->
      let rest lines =
        match List.filter (fun l -> l.quanta = None) lines with
        | [ _ ] ->
            Some
              (Z.sub total
                 (List.fold_left
                    (fun s l -> match l.quanta with Some q -> Z.add s q | None -> s)
                    Z.zero lines))
        | _ -> None
      in
      let r = rest (receiving_lines plan) and p = rest (paying_lines plan) in
      {
        plan with
        lines =
          List.map
            (fun l ->
              if l.quanta <> None then l else { l with quanta = (if l.receiving then r else p) })
            plan.lines;
      }

let quanta book measure text =
  match B.parse_amount book measure text with Ok q -> Some q | Error _ -> None

let make_plan ~book ~measure catalog roles template (parsed : parsed) =
  let total = Option.bind parsed.total (quanta book measure) in
  let bad_total = match (parsed.total, total) with Some t, None -> [ t ] | _ -> [] in
  (* A template is replayed exactly at its own total; any other total keeps only its Loci. *)
  let lines =
    match template with
    | None -> []
    | Some (t : template) ->
        let exact = match total with None -> true | Some x -> Z.equal x (template_total t) in
        let receiving = List.filter (fun (p : posting) -> Z.sign p.signed > 0) t.postings
        and paying = List.filter (fun (p : posting) -> Z.sign p.signed < 0) t.postings in
        let line side (p : posting) =
          {
            locus = p.locus;
            receiving = Z.sign p.signed > 0;
            quanta =
              (if exact then Some (Z.abs p.signed) else if List.length side = 1 then total else None);
          }
        in
        List.map (line receiving) receiving @ List.map (line paying) paying
  in
  let base =
    {
      description = parsed.description;
      total = (match total with Some _ -> total | None -> Option.map template_total template);
      lines;
      unknown = bad_total;
    }
  in
  fill
    (List.fold_left
       (fun plan (word, amount) ->
         let exact = Option.bind amount (quanta book measure) in
         let bad = match (amount, exact) with Some a, None -> [ a ] | _ -> [] in
         match locus_for catalog word with
         | Some token -> { (supply roles plan token exact) with unknown = plan.unknown @ bad }
         | None -> { plan with unknown = plan.unknown @ [ word ] @ bad })
       base parsed.extras)

(* A leading date word (2026-10-18, 10-18 or 10/18) once a separator follows it. *)
type dated = { word : string; lead : string; date : string option; body : string }

let valid_iso iso = Day.normalize iso = Ok iso
let pad2 s = if String.length s = 1 then "0" ^ s else s

let resolve_date ~today word =
  match List.concat_map (String.split_on_char '/') (String.split_on_char '-' word) with
  | [ y; m; d ] ->
      let iso = y ^ "-" ^ pad2 m ^ "-" ^ pad2 d in
      if valid_iso iso then Some iso else None
  | [ m; d ] -> (
      let in_year year =
        let iso = year ^ "-" ^ pad2 m ^ "-" ^ pad2 d in
        if valid_iso iso then Some iso else None
      in
      let year = String.sub today 0 (min 4 (String.length today)) in
      let previous () =
        match int_of_string_opt year with
        | Some y when y > 1000 -> in_year (string_of_int (y - 1))
        | _ -> None
      in
      match in_year year with Some iso when iso <= today -> Some iso | _ -> previous ())
  | _ -> None

let dated ~today text =
  let n = String.length text in
  let rec word_end i =
    if i < n && text.[i] <> ' ' && not (Base.String.is_substring_at text ~pos:i ~substring:"　") then
      word_end (i + 1)
    else i
  in
  let w = word_end 0 in
  let rec seps_end i =
    if i < n && text.[i] = ' ' then seps_end (i + 1)
    else if Base.String.is_substring_at text ~pos:i ~substring:"　" then seps_end (i + 3)
    else i
  in
  let s = seps_end w in
  let word = String.sub text 0 w in
  if
    s = w
    || (not (String.exists (fun c -> c = '-' || c = '/') word))
    || not (String.for_all (fun c -> (c >= '0' && c <= '9') || c = '-' || c = '/') word)
  then None
  else
    Some
      {
        word;
        lead = String.sub text 0 s;
        date = resolve_date ~today word;
        body = String.sub text s (n - s);
      }

type t = {
  today : string;
  measure : string;
  text : string;
  cursor : int;
  past : past list;
  catalog : (string * string) list;
  roles : (string * Locus_roles.role) list;
}

let initial ~book ~day ~measure ~roles =
  {
    today = day;
    measure;
    text = "";
    cursor = 0;
    past = history book measure;
    roles;
    catalog =
      List.map
        (fun token -> (token, B.label book token))
        (Option.value ~default:[] (B.approved_loci book));
  }

let with_roles roles t = { t with roles }
let text t = t.text

let record_date t =
  match dated ~today:t.today t.text with
  | Some { date = Some d; _ } -> d
  | Some { word; _ } -> word
  | None -> t.today

(* Read "パン屋 card" as a known description plus Locus words when the whole text
   is not itself a known description; the longest known prefix wins. *)
let parsed t =
  let raw = parse (match dated ~today:t.today t.text with Some d -> d.body | None -> t.text) in
  let ws = words raw.description in
  let known d = List.exists (fun (p : past) -> p.description = d) t.past in
  if List.length ws <= 1 || known raw.description then raw
  else
    let rec try_count count =
      if count < 1 then raw
      else
        let description = String.concat " " (List.filteri (fun i _ -> i < count) ws) in
        let rest = List.filteri (fun i _ -> i >= count) ws in
        if known description && List.for_all (fun w -> locus_for t.catalog w <> None) rest then
          {
            raw with
            description;
            extras = List.map (fun w -> (w, None)) rest @ raw.extras;
            describing = false;
          }
        else try_count (count - 1)
    in
    try_count (List.length ws - 1)

let suggestions t =
  let p = parsed t in
  if p.describing then descriptions_for t.past p.description else []

(* Templates for the description; with a total, those matching it come first. *)
let templates ~book t =
  let p = parsed t in
  if p.describing then []
  else
    let all = templates_for t.past p.description in
    match Option.bind p.total (quanta book t.measure) with
    | Some total ->
        List.filter (fun x -> Z.equal (template_total x) total) all
        @ List.filter (fun x -> not (Z.equal (template_total x) total)) all
    | None -> all

let selected_template ~book t =
  match templates ~book t with
  | [] -> None
  | options -> List.nth_opt options (t.cursor mod List.length options)

let current ~book t =
  let plan =
    make_plan ~book ~measure:t.measure t.catalog t.roles (selected_template ~book t) (parsed t)
  in
  match dated ~today:t.today t.text with
  | Some { date = None; word; _ } -> { plan with unknown = word :: plan.unknown }
  | _ -> plan

type prefill = { day : string; description : string; rows : (string * string) list; focus : int }

(* Record rows for a plan: receiving lines first, then paying lines, signed. *)
let prefill ~book t plan =
  let row l =
    ( l.locus,
      match l.quanta with
      | Some q -> B.format book t.measure (if l.receiving then q else Z.neg q)
      | None -> "" )
  in
  let side lines = if lines = [] then [ ("", "") ] else List.map row lines in
  let rows = side (receiving_lines plan) @ side (paying_lines plan) in
  let rec missing i = function
    | [] -> None
    | (locus, amount) :: rest ->
        if locus = "" then Some (3 + (2 * i))
        else if amount = "" then Some (4 + (2 * i))
        else missing (i + 1) rest
  in
  let focus =
    if plan.description = "" then 1
    else Option.value ~default:(3 + (2 * List.length rows)) (missing 0 rows)
  in
  { day = record_date t; description = plan.description; rows; focus }

type step = Stay of t | Cancel | Preview of prefill | Edit of prefill

let edited t text = Stay { t with text; cursor = 0 }

let backspace text =
  let rec start i =
    if i <= 0 then 0 else if Char.code text.[i] land 0xC0 = 0x80 then start (i - 1) else i
  in
  if text = "" then "" else String.sub text 0 (start (String.length text - 1))

let append t text = { t with text = t.text ^ text; cursor = 0 }

let update ~book t (input : Ui_input.input) =
  let count () =
    let p = parsed t in
    if p.describing then List.length (suggestions t) else List.length (templates ~book t)
  in
  match input with
  | `Key (`Escape, []) -> Cancel
  | `Key (`Backspace, []) -> edited t (backspace t.text)
  | `Key (`ASCII c, []) when c >= ' ' && c <= '~' -> edited t (t.text ^ String.make 1 c)
  | `Key (`Uchar u, []) -> edited t (t.text ^ O.utf8 u)
  | `Key (`Arrow ((`Up | `Down) as d), []) ->
      let n = count () in
      if n = 0 then Stay t
      else Stay { t with cursor = ((t.cursor mod n) + if d = `Up then n - 1 else 1) mod n }
  | `Key (`Tab, []) -> Edit (prefill ~book t (current ~book t))
  | `Key (`Enter, []) ->
      let p = parsed t in
      if p.describing then
        match suggestions t with
        | [] -> if p.description = "" then Stay t else edited t (t.text ^ " ")
        | options ->
            let (k : known) = List.nth options (t.cursor mod List.length options) in
            let lead = match dated ~today:t.today t.text with Some d -> d.lead | None -> "" in
            edited t (lead ^ k.description ^ " ")
      else
        let plan = current ~book t in
        if complete plan then Preview (prefill ~book t plan) else Edit (prefill ~book t plan)
  | _ -> Stay t

(* The quick capture's own surface over the terminal: a bounded framed modal
   (LOAM ModalSurface.centered?), or the whole area when the terminal is too
   small to frame. *)
type surface = {
  framed : bool;  (** The mode itself, never guessed from the height. *)
  width : int;  (** Physical cells of the rectangle. *)
  height : int;
  top : int;  (** First row of the rectangle. *)
  left : int;  (** First column of the rectangle. *)
}

let surface (width, height) =
  let width = max 0 width and height = max 0 height in
  let usable = max 0 (width - 1) in
  if usable < 56 || height < 16 then { framed = false; width; height; top = 0; left = 0 }
  else
    let modal = min 80 (usable - 4) in
    (* The terminal's final row stays reserved, as in LOAM. *)
    {
      framed = true;
      width = modal;
      height = 14;
      top = (height - 1 - 14) / 2;
      left = (usable - modal) / 2;
    }

(* Painting *)

let name_of t token =
  match List.assoc_opt token t.catalog with Some l when l <> "" -> l | _ -> token

let short_date d = if String.length d > 5 then String.sub d 5 (String.length d - 5) else d
let grouped ~book t q = Book_display.format_money book t.measure q

let describe ~book t plan =
  let part l =
    name_of t l.locus ^ " " ^ match l.quanta with Some q -> grouped ~book t q | None -> "?"
  in
  let side lines = if lines = [] then "?" else String.concat " + " (List.map part lines) in
  side (receiving_lines plan) ^ "  ←  " ^ side (paying_lines plan)

let template_text ~book t (x : template) =
  let part (p : posting) = name_of t p.locus ^ " " ^ grouped ~book t (Z.abs p.signed) in
  String.concat " + "
    (List.map part (List.filter (fun (p : posting) -> Z.sign p.signed > 0) x.postings))
  ^ "  ←  "
  ^ String.concat " + "
      (List.map part (List.filter (fun (p : posting) -> Z.sign p.signed < 0) x.postings))

let window options chosen rows =
  let n = List.length options in
  let rows = max 1 rows in
  let start = max 0 (min (n - rows) (chosen - (rows / 2))) in
  List.filteri (fun i _ -> i >= start && i < start + rows) (List.mapi (fun i x -> (i, x)) options)

let view ~book ~width_of ~width ~height t =
  let clip = O.clip_text ~width_of (max 0 width) in
  let row chosen main detail =
    ( (if chosen then O.Active else O.Plain),
      clip ((if chosen then " › " else "   ") ^ main ^ "  " ^ detail) )
  in
  let muted text = (O.Chrome, clip text) in
  let p = parsed t in
  let date = record_date t in
  let shown =
    if
      String.length date >= 4
      && String.length t.today >= 4
      && String.sub date 0 4 = String.sub t.today 0 4
    then short_date date
    else date
  in
  let head = " " ^ shown ^ "  " in
  let input =
    let room = max 1 (width - width_of head) in
    let text, caret = O.input_text ~width_of ~width:room ~cursor:None ~caret:"|" t.text in
    ((match caret with Some c -> O.Input (width_of head + c) | None -> O.Plain), head ^ text)
  in
  let footer = [ muted "[Enter] next [↑↓] choose [Tab] full form [Esc] cancel"; (O.Plain, "") ] in
  let list_rows = max 1 (height - List.length footer - 3) in
  let body =
    if p.describing then
      let options = suggestions t in
      if p.description = "" then
        [
          muted "   Description, then total and Loci if they differ: パン屋 420 card";
          muted "   Another day: date first, 10-18 パン屋";
        ]
      else if options = [] then
        [ muted "   New description · Enter, then total and Loci: 900 food card" ]
      else
        let chosen = t.cursor mod List.length options in
        List.map
          (fun (i, (k : known)) ->
            row (i = chosen) k.description
              (Printf.sprintf "%d×  last %s" k.uses (short_date k.last_used)))
          (window options chosen list_rows)
    else
      let options = templates ~book t in
      let plan = current ~book t in
      let status =
        if plan.unknown <> [] then
          "Not understood: " ^ String.concat " " plan.unknown ^ " · Enter opens the form"
        else if complete plan then
          "Enter to preview"
          ^ match plan.total with Some x -> " · total " ^ grouped ~book t x | None -> ""
        else if plan.lines = [] then "Total and Loci next, e.g. 900 food card"
        else "Enter opens the form to finish; or name a part: food 300"
      in
      let alternatives =
        if List.length options <= 1 then []
        else
          let chosen = t.cursor mod List.length options in
          List.map
            (fun (i, x) ->
              row (i = chosen) (template_text ~book t x)
                (Printf.sprintf "%d×  last %s" x.uses (short_date x.last_used)))
            (window options chosen (list_rows - 3))
      in
      [ row true (describe ~book t plan) ""; muted ("   " ^ status) ]
      @
      if alternatives = [] then []
      else [ (O.Plain, ""); muted "   Past records (↑↓)" ] @ alternatives
  in
  let content = input :: (O.Plain, "") :: body in
  let room = max 0 (height - List.length footer) in
  let content = List.filteri (fun i _ -> i < room) content in
  content @ List.init (max 0 (room - List.length content)) (fun _ -> (O.Plain, "")) @ footer
