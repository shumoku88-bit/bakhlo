(* Experimental, read-only Bonsai-native workspace.
   Deliberately does not reuse Daily_interaction's single global UI model.
   One admitted immutable book is passed to independently stateful panels.
   No household publication, recovery, guessed date or mutable authority. *)
module T = Bonsai_term
module Bonsai = T.Bonsai
module V = T.View
module F = Daily_file
module Book = Bakhlo_sexp.Daily_book

type focus = Plans | Budgets
type focus_action = Toggle | Keep

let focused focus pane = focus = pane

let label focus = function
  | Plans -> if focused focus Plans then "[PLANS *]" else "[PLANS]"
  | Budgets -> if focused focus Budgets then "[BUDGETS *]" else "[BUDGETS]"

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

let plan_panel book focus selected_index width height =
  let plans = Book.plans book in
  let rows =
    List.mapi
      (fun i (p : Book.plan) ->
        selected
          ~active:(i = selected_index && focused focus Plans)
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
    ([ heading (label focus Plans); text "Recorded occurrences (not a completeness claim)" ]
    @ keep_in_view ~height ~selected:selected_index rows
    @ [ text ""; heading "SELECTED PLAN" ]
    @ detail)

let budget_panel book observed_at focus selected_index width height =
  let header = [ heading (label focus Budgets); text ("Review at " ^ observed_at) ] in
  let items = Book.budgets book in
  let rows =
    match items with
    | None -> [ text "Budget information not supplied (UNKNOWN)." ]
    | Some [] -> [ text "Budget section supplied: zero definitions." ]
    | Some budgets ->
        let index_rows =
          List.mapi
            (fun i (b : Book.budget) ->
              selected
                ~active:(i = selected_index && focused focus Budgets)
                (b.id ^ "  " ^ b.start_day ^ ".." ^ b.end_exclusive))
            budgets
        in
        let detail =
          match List.nth_opt budgets selected_index with
          | None -> [ text "No selected budget." ]
          | Some b -> (
              let title = heading ("Budget " ^ b.id ^ " / " ^ b.measure) in
              match Book.budget_review book ~id:b.id ~observed_at with
              | Error why ->
                  [ title; text ("Review unavailable: " ^ why); text "No zero fallback." ]
              | Ok review ->
                  let budget_rows =
                    List.map
                      (fun (r : Book.budget_row) ->
                        text
                          (r.purpose ^ ": remaining "
                          ^ Book.format book b.measure r.remaining
                          ^ "; after known plans "
                          ^ Book.format book b.measure r.after_known))
                      review.rows
                  in
                  let unrouted =
                    List.length review.unrouted_actual + List.length review.unrouted_plans
                  and unmanaged =
                    List.length review.unmanaged_actual + List.length review.unmanaged_plans
                  in
                  [
                    title;
                    text ("Unrouted items: " ^ string_of_int unrouted);
                    text ("Explicitly unmanaged items: " ^ string_of_int unmanaged);
                  ]
                  @ budget_rows)
        in
        keep_in_view ~height ~selected:selected_index index_rows
        @ [ text ""; heading "SELECTED BUDGET" ]
        @ detail
  in
  clip_lines width height (header @ rows)

let render ~focus ~plan_view ~budget_view (dimensions : T.Dimensions.t) =
  let width = max 1 dimensions.width and height = max 1 dimensions.height in
  let header = heading "BAKHLO / Bonsai workspace LAB (read-only)" in
  let footer = text "Tab / Left / Right: focus    Up / Down: select    q / Ctrl-Q: quit" in
  let body_height = max 1 (height - 2) in
  let body =
    if width >= 80 then
      let left = width / 2 and right = width - (width / 2) in
      V.hcat [ fit left body_height plan_view; fit right body_height budget_view ]
    else if focus = Plans then fit width body_height plan_view
    else fit width body_height budget_view
  in
  fit width height (V.vcat [ header; body; footer ])

let app book observed_at ~exit ~dimensions graph =
  let plans = Book.plans book in
  let budget_count =
    match Book.budgets book with None -> 0 | Some budgets -> List.length budgets
  in
  (* Each component owns its own cursor. Switching panes preserves both. *)
  let focus, set_focus =
    Bonsai.state_machine ~default_model:Plans
      ~apply_action:(fun _ focus -> function
        | Toggle -> if focus = Plans then Budgets else Plans | Keep -> focus)
      graph
  in
  let plan_cursor, set_plan_cursor =
    Bonsai.state_machine ~default_model:0
      ~apply_action:(fun _ index delta -> max 0 (min (List.length plans - 1) (index + delta)))
      graph
  in
  let budget_cursor, set_budget_cursor =
    Bonsai.state_machine ~default_model:0
      ~apply_action:(fun _ index delta -> max 0 (min (budget_count - 1) (index + delta)))
      graph
  in
  (* Independent incremental panel projections; no UI-owned accounting math. *)
  let plan_view =
    Bonsai.arr2 graph (Bonsai.both focus plan_cursor) dimensions
      ~f:(fun (focus, index) (dims : T.Dimensions.t) ->
        plan_panel book focus index
          (if dims.width >= 80 then dims.width / 2 else dims.width)
          (max 1 (dims.height - 2)))
  in
  let budget_view =
    Bonsai.arr2 graph (Bonsai.both focus budget_cursor) dimensions
      ~f:(fun (focus, index) (dims : T.Dimensions.t) ->
        budget_panel book observed_at focus index
          (if dims.width >= 80 then dims.width - (dims.width / 2) else dims.width)
          (max 1 (dims.height - 2)))
  in
  let view =
    Bonsai.arr2 graph (Bonsai.both focus dimensions) (Bonsai.both plan_view budget_view)
      ~f:(fun (focus, dims) (plan_view, budget_view) -> render ~focus ~plan_view ~budget_view dims)
  in
  let handler =
    Bonsai.arr2 graph (Bonsai.both focus set_focus) (Bonsai.both set_plan_cursor set_budget_cursor)
      ~f:(fun (focus, set_focus) (set_plan_cursor, set_budget_cursor) event ->
        match event with
        | T.Event.Key_press { key = T.Event.Key.Tab; mods = [] }
        | T.Event.Key_press { key = T.Event.Key.Arrow (`Left | `Right); mods = [] } ->
            set_focus Toggle
        | T.Event.Key_press { key = T.Event.Key.Arrow `Up; mods = [] } ->
            if focus = Plans then set_plan_cursor (-1) else set_budget_cursor (-1)
        | T.Event.Key_press { key = T.Event.Key.Arrow `Down; mods = [] } ->
            if focus = Plans then set_plan_cursor 1 else set_budget_cursor 1
        | T.Event.Key_press { key = T.Event.Key.ASCII ('q' | 'Q'); mods = [] }
        | T.Event.Key_press
            { key = T.Event.Key.ASCII ('q' | 'Q'); mods = [ T.Event.Modifier.Ctrl ] } ->
            exit ()
        | _ -> set_focus Keep)
  in
  (~view, ~handler)

let run path observed_at =
  let session = F.load path in
  F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
  (* A book may have no budgets, but an invalid observation must never be guessed. *)
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
