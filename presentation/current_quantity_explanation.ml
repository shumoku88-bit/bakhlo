open Base
module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query
module P = A.Current_quantity_projection
module F = A.Correction_frontier
module C = A.Reflected_root_cut
module Text = Current_quantity_text

let id value = D.Identifier.Event.to_string value

let matches (coordinate : D.Effect_coordinate.t) change =
  D.Identifier.Locus.equal coordinate.locus (D.Effect.locus change)
  && D.Identifier.Measure.equal coordinate.measure (D.Effect.measure change)

let roots declarations =
  "  Reflected roots (supplied): ["
  ^ String.concat ~sep:"; " (List.map declarations ~f:(fun root -> Printf.sprintf "%S" (id root)))
  ^ "].\n"

(* Display retained occurrences, never sum them or construct another answer. Root order
   is only an enumeration order; Effect positions refer to the full terminal Event. *)
let occurrences ~frontier ~reflected_roots ~included coordinate =
  let reflected = Set.of_list (module D.Identifier.Event) reflected_roots in
  let rows =
    List.filter_map (F.lineages frontier) ~f:(fun lineage ->
        let terminal = F.terminal_event lineage in
        let effects =
          List.filter_mapi (D.Event.effects terminal) ~f:(fun position change ->
              if not (matches coordinate change) then None
              else
                let key =
                  match D.Effect.key change with
                  | None -> "anonymous"
                  | Some key -> Printf.sprintf "key %S" (D.Identifier.Effect_key.to_string key)
                in
                Some
                  (Printf.sprintf "      Effect %d: %s; quanta=%s\n" (position + 1) key
                     (Z.to_string (D.Quantity.quanta (D.Effect.quantity change)))))
        in
        if List.is_empty effects then None
        else
          let selection =
            if Set.mem reflected (F.root_id lineage) then "reflected (excluded)" else included
          in
          let path =
            match F.correction_path lineage with
            | [] -> "      Correction path: none.\n"
            | edges ->
                String.concat
                  (List.map edges ~f:(fun (edge : D.Event_correction.t) ->
                       Printf.sprintf "      Correction %S -> %S\n" (id edge.target)
                         (id edge.replacement)))
          in
          Some
            (Printf.sprintf "    Root %S; terminal %S; %s.\n"
               (id (F.root_id lineage))
               (id (D.Event.id terminal))
               selection
            ^ path ^ String.concat effects))
  in
  "  Matching terminal Effect occurrences (root order; Event-local positions):\n"
  ^ if List.is_empty rows then "    none.\n" else String.concat rows

let cut_view ~included coordinate cut =
  roots (C.reflected_roots cut)
  ^ occurrences ~frontier:(C.source_frontier cut) ~reflected_roots:(C.reflected_roots cut) ~included
      coordinate

let explain image coordinate =
  let outcome = Q.query image coordinate in
  let frontier = A.Actual_source.frontier (Q.source image) in
  let view =
    match outcome with
    | Ok (Q.Exact answer) ->
        let evidence =
          match Q.premise answer with
          | Current_assertion assertion ->
              "  Supplied assertion + unreflected delta; independent answer-bound cut.\n"
              ^ cut_view ~included:"unreflected (contributes to delta)" coordinate
                  (P.answer_cut assertion)
          | Zero_origin | Opening _ ->
              "  Selection: all qualified terminal Events (no reflected cut).\n"
              ^ occurrences ~frontier ~reflected_roots:[]
                  ~included:"included (contributes to quantity)" coordinate
        in
        Text.exact_row answer ^ evidence
    | Ok (Known_present answer) ->
        Text.present answer
        ^ "  Independent presence premise; no unreflected matching Effect; no scalar.\n"
        ^ cut_view ~included:"unreflected activity" coordinate (Q.present_cut answer)
    | Error (Support_unknown _ as unavailable) ->
        let evidence =
          match Q.presence image with
          | Some { reflected_roots; coordinates }
            when List.exists coordinates ~f:(fun c -> D.Effect_coordinate.compare c coordinate = 0)
            ->
              "  Supplied presence is stale: ANY unreflected matching Effect invalidates it, even \
               net zero.\n" ^ roots reflected_roots
              ^ occurrences ~frontier ~reflected_roots
                  ~included:"unreflected (invalidates presence)" coordinate
          | None | Some { reflected_roots = _; coordinates = _ } ->
              "  Activity or net zero does not establish quantity support.\n"
              ^ occurrences ~frontier ~reflected_roots:[] ~included:"activity only (not support)"
                  coordinate
        in
        Text.unavailable unavailable ^ evidence
  in
  (outcome, "Conditional evidence explanation; not household authority or spending rights.\n" ^ view)
