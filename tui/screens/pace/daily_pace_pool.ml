(* LOAM DailyPacePoolSetup choose/review over Bakhlo's captured-bytes save.
   Two deliberate additions: review refuses to save unless every row is
   visible, and balances dropped from an earlier pool are named in review. *)
module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module A = Daily_draft
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query

type t = {
  measure : string;
  expected : (string option, string) result;  (** Captured bytes, or why they are unusable. *)
  candidates : string list;
  chosen : string list;
  dropped : string list;
  cursor : int;
  reviewing : bool;
  notice : string;
}

let token s = s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s

let rows_from measure text =
  let lines =
    String.split_on_char '\n' text
    |> List.filter (fun line ->
        let s = String.trim line in
        s <> "" && not (String.starts_with ~prefix:"#" s))
  in
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | line :: rest -> (
        match String.split_on_char '\t' line with
        | [ locus; m ] when token locus && m = measure ->
            if List.mem locus acc then Error "Duplicate Daily Pace coordinate."
            else loop (locus :: acc) rest
        | [ _; m ] when token m ->
            Error ("Existing Pool uses another Measure: " ^ m ^ ". Refusing replacement.")
        | _ -> Error "Malformed daily-pace.tsv; no rows were skipped.")
  in
  loop [] lines

(* The support route of an exact current balance: 0 zero-origin, 1 opening,
   2 current observation; [None] when the balance is not exact. *)
let route book ~measure locus =
  match (D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string measure) with
  | Ok locus, Ok measure -> (
      match Q.query (B.image book) { D.Effect_coordinate.locus; measure } with
      | Ok (Q.Exact exact) -> (
          match Q.premise exact with
          | Q.Zero_origin -> Some 0
          | Q.Opening _ -> Some 1
          | Q.Current_assertion _ -> Some 2)
      | Ok (Q.Known_present _) | Error _ -> None)
  | _ -> None

(* LOAM lists exact current balances grouped by support (zero-origin, opening,
   current observation), each group in first-appearance order over the
   retained entries (any Locus, as balances do), then admitted Loci without one. *)
let appearance_order book ~measure =
  let add acc l = if List.mem l acc then acc else l :: acc in
  let seen =
    List.fold_left
      (fun acc (e : B.entry) ->
        List.fold_left
          (fun acc posting ->
            if D.Identifier.Measure.to_string (D.Effect.measure posting) = measure then
              add acc (A.lstr (D.Effect.locus posting))
            else acc)
          acc e.effects)
      [] (B.entries book)
  in
  List.rev (List.fold_left add seen (Option.value ~default:[] (B.approved_loci book)))

let prepare ~book ~measure ~config =
  let routed =
    List.filter_map
      (fun l -> Option.map (fun r -> (r, l)) (route book ~measure l))
      (appearance_order book ~measure)
  in
  let candidates = List.map snd (List.stable_sort (fun (a, _) (b, _) -> compare a b) routed) in
  let previous =
    match config with
    | Error why -> Error ("Pool configuration was unreadable: " ^ why)
    | Ok None -> Ok []
    | Ok (Some text) -> rows_from measure text
  in
  let chosen, dropped, notice =
    match previous with
    | Error why -> ([], [], why ^ " No changes can be saved.")
    | Ok old ->
        let kept, dropped = List.partition (fun l -> List.mem l candidates) old in
        ( kept,
          dropped,
          if dropped = [] then ""
          else "Not exact-current, dropped from the pool: " ^ String.concat ", " dropped )
  in
  {
    measure;
    candidates;
    chosen;
    dropped;
    cursor = 0;
    reviewing = false;
    notice;
    expected =
      Result.map (fun _ -> match config with Ok bytes -> bytes | Error _ -> None) previous;
  }

let measure t = t.measure
let reviewing t = t.reviewing
let chosen t = t.chosen
let with_notice t notice = { t with notice }
let coordinate_text t locus = locus ^ " / " ^ t.measure

(* LOAM view: two heading rows, then the list or the review. *)
let rows ~width_of ~width ~height t =
  let line ?(style = O.Plain) text = (style, O.clip_text ~width_of width text) in
  let muted = line ~style:O.Chrome in
  (* A refusal or dropped-balance notice is wrapped whole, never clipped. *)
  let notice =
    List.map (fun text -> (O.Chrome, text)) (O.wrap_text ~width_of (max 1 width) t.notice)
  in
  let head =
    [
      line ("Daily Pace / Spendable pool (" ^ t.measure ^ ")");
      muted "Only observed exact balances can be selected.";
    ]
  in
  let rows =
    if t.reviewing then
      head
      @ [
          line "Review: these balances fund ordinary spending.";
          line ("Selected: " ^ string_of_int (List.length t.chosen));
          muted "Display settings never change balances or history.";
        ]
      @ List.map (fun l -> line ("  " ^ coordinate_text t l)) t.chosen
      @ (if t.dropped = [] then []
         else [ muted ("Dropped (not exact-current): " ^ String.concat ", " t.dropped) ])
      @ [ line ~style:O.Active "Enter: save pool   Esc/e: edit" ]
      @ notice
    else
      let available = max 1 (height - 6) in
      let offset = if t.cursor < available then 0 else t.cursor + 1 - available in
      head
      @ (if t.candidates = [] then [ muted "No exact balances. Observe amounts first." ] else [])
      @ List.filteri
          (fun i _ -> i < available)
          (List.filteri
             (fun i _ -> i >= offset)
             (List.mapi
                (fun i l ->
                  let cursor = if i = t.cursor then "> " else "  " in
                  let mark = if List.mem l t.chosen then "[x] " else "[ ] " in
                  line
                    ~style:(if i = t.cursor then O.Active else O.Plain)
                    (cursor ^ mark ^ coordinate_text t l))
                t.candidates))
      @ [
          muted ("Chosen: " ^ string_of_int (List.length t.chosen));
          muted "j/k select  Space toggle  Enter review";
          muted "Esc cancel; no write until confirmed.";
        ]
      @ notice
  in
  rows

type step =
  | Stay of t
  | Cancel of t
  | Save of { picker : t; expected : string option; content : string }

let update ~width_of ~width ~height t (input : Ui_input.input) =
  let key = match input with `Key (k, []) -> Some k | _ -> None in
  if not t.reviewing then
    match key with
    | Some (`Escape | `ASCII ('q' | 'Q')) -> Cancel { t with notice = "" }
    | Some (`Arrow `Up | `ASCII 'k') -> Stay { t with cursor = max 0 (t.cursor - 1) }
    | Some (`Arrow `Down | `ASCII 'j') ->
        Stay { t with cursor = max 0 (min (List.length t.candidates - 1) (t.cursor + 1)) }
    | Some (`ASCII ' ') -> (
        match List.nth_opt t.candidates t.cursor with
        | None -> Stay t
        | Some l ->
            let chosen =
              if List.mem l t.chosen then List.filter (( <> ) l) t.chosen else t.chosen @ [ l ]
            in
            Stay { t with chosen; notice = "" })
    | Some `Enter -> (
        match t.expected with
        | Error why -> Stay { t with notice = why ^ " No changes can be saved." }
        | Ok _ when t.chosen = [] ->
            Stay { t with notice = "Select at least one known-current balance." }
        | Ok _ -> Stay { t with reviewing = true; notice = "" })
    | _ -> Stay t
  else
    match (key, t.expected) with
    | Some (`Escape | `ASCII ('e' | 'E')), _ -> Stay { t with reviewing = false; notice = "" }
    | Some `Enter, Ok expected ->
        (* Every review row, the notice line included, must be visible and whole to save. *)
        let review = rows ~width_of ~width:max_int ~height t in
        if
          List.length review > height || List.exists (fun (_, text) -> width_of text > width) review
        then Stay { t with notice = "Not saved: too small." }
        else
          Save
            {
              picker = t;
              expected;
              content = String.concat "" (List.map (fun l -> l ^ "\t" ^ t.measure ^ "\n") t.chosen);
            }
    | _ -> Stay t
