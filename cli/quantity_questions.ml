open Base
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module Text = Bakhlo_presentation.Current_quantity_text
module Explanation = Bakhlo_presentation.Current_quantity_explanation

type t = { first : D.Effect_coordinate.t; rest : D.Effect_coordinate.t list }
type error = Missing_pair | Empty_identity

let plan arguments =
  let rec pairs reversed = function
    | [] -> (
        match List.rev reversed with
        | [] -> Error Missing_pair
        | first :: rest -> Ok { first; rest })
    | [ _ ] -> Error Missing_pair
    | locus :: measure :: rest -> (
        match (D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string measure) with
        | Ok locus, Ok measure ->
            (pairs [@tailcall]) ({ D.Effect_coordinate.locus; measure } :: reversed) rest
        | Error D.Identifier.Empty, _ | _, Error D.Identifier.Empty -> Error Empty_identity)
  in
  pairs [] arguments

let render { first; rest } ~explain ~exact_heading image : Response.t =
  let results =
    List.map (first :: rest) ~f:(fun coordinate ->
        let outcome, text =
          if explain then Explanation.explain image coordinate
          else
            let outcome = Q.query image coordinate in
            let text =
              match outcome with
              | Ok (Q.Exact answer) -> Text.exact_row answer
              | Ok (Known_present answer) -> Text.present answer
              | Error (Support_unknown _ as unavailable) -> Text.unavailable unavailable
            in
            (outcome, text)
        in
        match outcome with
        | Ok (Q.Exact _) -> (0, exact_heading ^ text)
        | Ok (Known_present _) -> (4, text)
        | Error (Support_unknown _) -> (3, text))
  in
  let exit_code =
    if List.exists results ~f:(fun (code, _) -> code = 3) then 3
    else if List.exists results ~f:(fun (code, _) -> code = 4) then 4
    else 0
  in
  let stdout =
    match results with
    | [ (_, text) ] -> text
    | rows ->
        "One supplied read image; independent questions (no subtotal).\n"
        ^ String.concat
            (List.mapi rows ~f:(fun position (_, text) ->
                 Printf.sprintf "Question %d:\n%s" (position + 1) text))
  in
  { exit_code; stdout; stderr = "" }
