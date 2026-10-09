(* Experimental, read-only Bonsai-native workspace.
   Deliberately does not reuse Daily_interaction's single global UI model.
   One admitted immutable book is passed to independently stateful panels.
   No household publication, recovery, guessed date or mutable authority. *)
module T = Bonsai_term
module Bonsai = T.Bonsai
module V = T.View
module F = Daily_file
module Book = Bakhlo_sexp.Daily_book

let rec drop n = function xs when n <= 0 -> xs | [] -> [] | _ :: xs -> drop (n - 1) xs
let rec take n = function _ when n <= 0 -> [] | [] -> [] | x :: xs -> x :: take (n - 1) xs

let keep_in_view ~height ~selected rows =
  let visible = max 1 (min 6 (height - 12)) in
  let start = max 0 (selected - visible + 1) in
  take visible (drop start rows)

let fit width height view =
  let width = max 1 width and height = max 1 height in
  let view = V.crop ~r:(max 0 (V.width view - width)) ~b:(max 0 (V.height view - height)) view in
  V.pad ~r:(max 0 (width - V.width view)) ~b:(max 0 (height - V.height view)) view

let text ?(attrs = []) value = V.text ~attrs value
let heading s = text ~attrs:[ T.Attr.bold ] s

let selected ~active s =
  if active then text ~attrs:[ T.Attr.invert; T.Attr.bold ] ("> " ^ s) else text ("  " ^ s)

let clip_lines width height views = fit width height (V.vcat views)

let plan_status (p : Book.plan) =
  if p.paid_by <> None then "PAID" else if p.cancelled_on <> None then "CANCELLED" else "OPEN"

let plan_panel book selected_index width height =
  let plans = Book.plans book in
  let rows =
    List.mapi
      (fun i (p : Book.plan) ->
        selected
          ~active:(i = selected_index)
          (p.day ^ " " ^ p.id ^ " [" ^ plan_status p ^ "]"))
      plans
  in
  let detail =
    match List.nth_opt plans selected_index with
    | None -> [ text "No recorded plans in this book." ]
    | Some p ->
        heading ("Plan " ^ p.id ^ " / " ^ p.measure)
        :: List.map
             (fun (locus, amount) ->
               text ("  " ^ Book.label book locus ^ ": " ^ Book.format book p.measure amount))
             p.changes
  in
  clip_lines width height
    ([ heading "PLANS"; text "Recorded occurrences (not a completeness claim)" ]
    @ keep_in_view ~height ~selected:selected_index rows
    @ [ text ""; heading "SELECTED PLAN" ]
    @ detail)

let render ~observed_at ~plan_view (dims : T.Dimensions.t) =
  let width = max 1 dims.width and height = max 1 dims.height in
  fit width height
    (V.vcat
      [
        heading ("BAKHLO / Bonsai plans lab (read-only) / " ^ observed_at);
        fit width (max 1 (height - 2)) plan_view;
        text "Up / Down: select    q / Ctrl-Q: quit";
      ])

let app book observed_at ~exit ~dimensions graph =
  let plans = Book.plans book in
  let cursor, set_cursor =
    Bonsai.state_machine ~default_model:0
      ~apply_action:(fun _ index delta -> max 0 (min (List.length plans - 1) (index + delta)))
      graph
  in
  let plan_view =
    Bonsai.arr2 graph cursor dimensions
      ~f:(fun index (dims : T.Dimensions.t) ->
        plan_panel book index (max 1 dims.width) (max 1 (dims.height - 2)))
  in
  let view =
    Bonsai.arr2 graph plan_view dimensions
      ~f:(fun plan_view dims -> render ~observed_at ~plan_view dims)
  in
  let handler =
    Bonsai.arr2 graph set_cursor dimensions
      ~f:(fun set_cursor _dims event ->
        match event with
        | T.Event.Key_press { key = T.Event.Key.Arrow `Up; mods = [] } ->
            set_cursor (-1)
        | T.Event.Key_press { key = T.Event.Key.Arrow `Down; mods = [] } ->
            set_cursor 1
        | T.Event.Key_press { key = T.Event.Key.ASCII ('q' | 'Q'); mods = [] }
        | T.Event.Key_press
            { key = T.Event.Key.ASCII ('q' | 'Q'); mods = [ T.Event.Modifier.Ctrl ] } ->
            exit ()
        | _ -> set_cursor 0)
  in
  (~view, ~handler)

let run path observed_at =
  let session = F.load path in
  F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
  (* No inferred observation date, including in this experimental reader. *)
  F.require (String.length observed_at = 10) "explicit-YYYY-MM-DD-required";
  match
    Async.Thread_safe.block_on_async_exn (fun () ->
        T.start_with_exit ~dispose:true ~mouse:T.Mouse_reporting.No_mouse_events ~bpaste:true
          (app session.book observed_at))
  with
  | Ok () -> ()
  | Error _ -> raise (F.Refused "Bonsai-terminal-unavailable")

let () =
  try
    match Array.to_list Sys.argv with
    | [ _; "--book"; path; "--at"; observed_at ] -> run path observed_at
    | _ ->
        prerr_endline "Usage: tools/bonsai-lab --book SYNTHETIC_FILE --at YYYY-MM-DD";
        exit 2
  with
  | F.Refused why ->
      prerr_endline ("Bonsai lab refused: " ^ why ^ "; no data written.");
      exit 1
  | Unix.Unix_error _ | Sys_error _ ->
      prerr_endline "Bonsai lab refused unavailable input; no data written.";
      exit 1
