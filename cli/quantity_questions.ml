open Base
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module Text = Bakhlo_presentation.Current_quantity_text
module Explanation = Bakhlo_presentation.Current_quantity_explanation
module Answer = Bakhlo_application.Current_quantity_answer
module Summary = Bakhlo_presentation.Current_quantity_summary

type t = { first : D.Effect_coordinate.t; rest : D.Effect_coordinate.t list }
type error = Missing_pair | Empty_identity
type view = Inspect | Explain | Summary

let select_view arguments =
  let view, rest =
    match arguments with
    | "--explain" :: rest -> (Explain, rest)
    | "--summary" :: rest -> (Summary, rest)
    | rest -> (Inspect, rest)
  in
  match rest with
  | ("--explain" | "--summary") :: _ -> Error "choose only one of --summary or --explain"
  | rest -> Ok (view, rest)

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

let render { first; rest } ~view ~exact_heading image : Response.t =
  let results =
    List.map (first :: rest) ~f:(fun coordinate ->
        let outcome, text =
          match view with
          | Explain -> Explanation.explain image coordinate
          | Inspect ->
              let outcome = Q.query image coordinate in
              let text =
                match outcome with
                | Ok (Q.Exact answer) -> Text.exact_row answer
                | Ok (Known_present answer) -> Text.present answer
                | Error (Support_unknown _ as unavailable) -> Text.unavailable unavailable
              in
              (outcome, text)
          | Summary ->
              let outcome = Q.query image coordinate in
              (outcome, Summary.render (Answer.project outcome))
        in
        match outcome with
        | Ok (Q.Exact _) ->
            let heading = match view with Inspect | Explain -> exact_heading | Summary -> "" in
            (0, heading ^ text)
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
        let heading, label =
          match view with
          | Inspect | Explain ->
              ("One supplied read image; independent questions (no subtotal).\n", "Question")
          | Summary -> ("同じ入力への質問です。数量を合計するものではありません。\n", "質問")
        in
        heading
        ^ String.concat
            (List.mapi rows ~f:(fun position (_, text) ->
                 Printf.sprintf "%s %d:\n%s" label (position + 1) text))
  in
  let scope =
    match view with
    | Inspect | Explain -> ""
    | Summary -> "入力された根拠に基づく回答です。実際の残高や使ってよい金額を保証するものではありません。\n"
  in
  { exit_code; stdout = scope ^ stdout; stderr = "" }

let input_refusal view ({ exit_code; stdout = _; stderr } : Response.t) : Response.t =
  let stderr =
    match view with
    | Inspect | Explain -> stderr
    | Summary -> "入力の読み取り・検証を完了できないため、数量には答えていません。\n詳しい理由は、所有者向けの詳細表示（--summary なし）で確認できます。\n"
  in
  { exit_code; stdout = ""; stderr }
