(* Report period windows resolved from the configured boundary presets, shared by
   the reports and the Actual so both read one period engine. *)
module Cal = Daily_calendar

let boundary_file = "boundary-presets.tsv"

type preset = Month | Cycle | Previous_cycle | Year | All_time
type period = { preset : preset; start_day : string; end_exclusive : string; label : string }

(* Every window of boundary-presets.tsv as (name, start, end-exclusive). *)
let parse_boundary_presets text =
  match Boundary_presets.parse text with
  | Ok presets -> Ok (Boundary_presets.windows presets)
  | Error () -> Error "Malformed boundary-presets.tsv; no period was inferred."

let resolve ~today ~preset ~offset ~boundary_presets_text =
  match preset with
  | Month -> (
      let base_month_start = String.sub today 0 8 ^ "01" in
      match Cal.shift_months base_month_start offset with
      | Error e -> Error e
      | Ok start_day -> (
          match Cal.shift_months start_day 1 with
          | Error e -> Error e
          | Ok end_exclusive ->
              Ok
                {
                  preset;
                  start_day;
                  end_exclusive;
                  label = Printf.sprintf "Month of %s" (String.sub start_day 0 7);
                }))
  | Year -> (
      let base_year_start = String.sub today 0 4 ^ "-01-01" in
      match Cal.shift_years base_year_start offset with
      | Error e -> Error e
      | Ok start_day -> (
          match Cal.shift_years start_day 1 with
          | Error e -> Error e
          | Ok end_exclusive ->
              Ok
                {
                  preset;
                  start_day;
                  end_exclusive;
                  label = Printf.sprintf "Year %s" (String.sub start_day 0 4);
                }))
  | All_time ->
      Ok
        {
          preset;
          start_day = "0001-01-01";
          end_exclusive = "9999-12-31";
          label = "All Time (Full Ledger)";
        }
  | Cycle | Previous_cycle -> (
      match boundary_presets_text with
      | None -> Error "Cycle not configured in boundary-presets.tsv."
      | Some text -> (
          match parse_boundary_presets text with
          | Error e -> Error e
          | Ok windows -> (
              let current_window =
                List.find_opt (fun (_, a, b) -> a <= today && today < b) windows
              in
              match current_window with
              | None -> Error "No explicit boundary preset contains today."
              | Some (name, cur_a, cur_b) ->
                  let name_windows = List.filter (fun (n, _, _) -> n = name) windows in
                  let current_idx =
                    match
                      List.find_index (fun (_, a, b) -> a = cur_a && b = cur_b) name_windows
                    with
                    | Some idx -> idx
                    | None -> 0
                  in
                  let target_idx =
                    if preset = Previous_cycle then current_idx - 1 + offset
                    else current_idx + offset
                  in
                  if target_idx < 0 || target_idx >= List.length name_windows then
                    Error "Cycle boundary is outside configured presets."
                  else
                    let _, start_day, end_exclusive = List.nth name_windows target_idx in
                    let cycle_name =
                      if preset = Previous_cycle then "Previous Cycle" else "Cycle"
                    in
                    Ok
                      {
                        preset;
                        start_day;
                        end_exclusive;
                        label = Printf.sprintf "%s (%s .. %s)" cycle_name start_day end_exclusive;
                      })))

