(* Read-only awareness after completion; similar plans never assert recurrence. *)
module B = Bakhlo_household.Daily_book
module O = Ui_render
module Panel = Ui_panel

type t = {
  book : B.t;
  source : B.plan;
  base_revision : string;
  candidate : B.plan option;
  additional : int;
  choice : int;
  reviewing : bool;
  scroll : int;
  notice : string;
}

type outcome = Updated of t | Closed of B.plan option | Add of B.plan | Defer of B.plan

let positive_loci (plan : B.plan) =
  plan.changes
  |> List.filter_map (fun (locus, amount) -> if Z.sign amount > 0 then Some locus else None)
  |> List.sort_uniq String.compare

let create ~book ~base_revision (source : B.plan) =
  let loci = positive_loci source in
  let candidates =
    B.open_plans book
    |> List.filter (fun (p : B.plan) -> source.day < p.day && loci <> [] && positive_loci p = loci)
    |> List.sort (fun (a : B.plan) b ->
        let date = String.compare a.day b.day in
        if date = 0 then String.compare a.id b.id else date)
  in
  {
    book;
    source;
    base_revision;
    candidate = List.nth_opt candidates 0;
    additional = max 0 (List.length candidates - 1);
    choice = 0;
    reviewing = false;
    scroll = 0;
    notice = "";
  }

let base_revision t = t.base_revision
let with_notice t notice = { t with notice; choice = 0; reviewing = false; scroll = 0 }

let dimensions (width, height) =
  if width >= 76 && height >= 16 then (min 72 (width - 4), min 22 (height - 2))
  else (max 0 width, max 0 height)

let viewport ~dimensions:(width, height) ~width_of t =
  let rows =
    (match t.candidate with
      | None -> []
      | Some p ->
          Book_display.plan_lines t.book p
          @ [
              "Match: same positive Locus set and a later explicit date.";
              "Not a same-series, same-contract or equal-amount claim.";
            ])
    |> List.concat_map (O.wrap_text ~width_of (max 1 (width - 6)))
  in
  let view =
    Panel.window
      ~capacity:(Panel.capacity ~height:(max 0 (height - 1)) ~heading:false)
      ~count:(List.length rows) ~scroll:t.scroll ~selected:None
  in
  (rows, view)

let handle ~dimensions:((width, height) as dimensions) ~width_of t input =
  if t.reviewing then
    let _, view = viewport ~dimensions ~width_of t in
    let t = { t with scroll = view.start } in
    match input with
    | `Key ((`Escape | `ASCII 'q'), []) -> Updated { t with reviewing = false; scroll = 0 }
    | `Key ((`Arrow (`Up | `Down) | `ASCII ('j' | 'k') | `Page _ | `Home | `End), []) ->
        Updated { t with scroll = Panel.review_scroll view input }
    | _ -> Updated t
  else
    match input with
    | `Key ((`Escape | `ASCII 'q'), []) -> Closed t.candidate
    | `Key ((`Tab | `Arrow `Right | `Arrow `Down | `ASCII 'j'), []) ->
        Updated { t with choice = (t.choice + 1) mod 3; notice = "" }
    | `Key (`Tab, [ `Shift ]) | `Key ((`Arrow `Left | `Arrow `Up | `ASCII 'k'), []) ->
        Updated { t with choice = (t.choice + 2) mod 3; notice = "" }
    | `Key (`Enter, []) -> (
        match (t.candidate, t.choice) with
        | _, 0 -> Closed t.candidate
        | Some _, 1 | None, 2 -> Add t.source
        | Some _, _ -> Updated { t with reviewing = true; scroll = 0; notice = "" }
        | None, _ ->
            if width < 20 || height < 3 then
              Updated (with_notice t "Enlarge terminal to choose Defer.")
            else Defer t.source)
    | _ -> Updated t

let footer t =
  if t.reviewing then [ "j/k PgUp/Dn Home/End review"; "Esc/q back to choices" ]
  else [ "Tab/Arrows choose  Enter confirm"; "Esc/q done  Completion is already published" ]

let screen ~dimensions:((width, height) as dimensions) ~width_of t =
  let width = max 0 width and height = max 0 height in
  if width = 0 || height = 0 then []
  else
    let rows =
      if t.reviewing then
        let rows, view = viewport ~dimensions ~width_of t in
        Panel.frame ~width_of ~width
          ~height:(max 0 (height - 1))
          ~focused:true ~title:"Scheduled / Completion / Existing Plan / Review" ~scroll:view.start
          ~selected:None rows
        @ [ (O.Status, O.clip_text ~width_of width t.notice) ]
      else
        let context, labels =
          match t.candidate with
          | Some p ->
              ( [
                  "Scheduled / Completion / Existing Plan";
                  "Completed: " ^ O.visible t.source.id;
                  "Later: " ^ O.visible p.id;
                  "Due: " ^ p.day;
                  Printf.sprintf "Also found %d similar later plan(s)." t.additional;
                  "Match: same positive Locus set; not a series claim.";
                ],
                [ "Keep as is"; "Add another"; "Review" ] )
          | None ->
              ( [
                  "Scheduled / Completion / Next Plan";
                  "Completed: " ^ O.visible t.source.id;
                  "No similar later current-open plan found.";
                  "Nothing will be inferred or created automatically.";
                  "Defer keeps an unfinished intent in Attention.";
                ],
                [ "Done"; "Defer to Attention"; "Add next" ] )
        in
        let context =
          List.filteri (fun i _ -> i < max 0 (height - 4)) context
          |> List.map (fun text -> (O.Chrome, O.clip_text ~width_of width text))
        in
        let view =
          Panel.window ~capacity:(min 3 (height - 1)) ~count:3 ~scroll:0 ~selected:(Some t.choice)
        in
        let choices =
          labels
          |> List.mapi (fun i label ->
              ( (if i = t.choice then O.Active else O.Plain),
                O.clip_text ~width_of width ((if i = t.choice then "> " else "  ") ^ label) ))
          |> List.filteri (fun i _ -> i >= view.start && i < view.start + view.capacity)
        in
        let rows = context @ choices in
        rows
        @ List.init (max 0 (height - 1 - List.length rows)) (fun _ -> (O.Plain, ""))
        @ [ (O.Status, O.clip_text ~width_of width t.notice) ]
    in
    List.map (fun (style, text) -> (style, O.pad ~width_of width text)) rows
