(* A report period as the reports and the Actual show it: Period's window with its
   label. *)
module P = Bakhlo_household.Period

let boundary_file = "boundary-presets.tsv"

type preset = Month | Cycle | Previous_cycle | Year | All_time
type period = { preset : preset; start_day : string; end_exclusive : string; label : string }

let resolve ~today ~preset ~offset ~boundary_presets_text =
  let span =
    match preset with
    | Month -> P.Month
    | Cycle -> P.Cycle
    | Previous_cycle -> P.Previous_cycle
    | Year -> P.Year
    | All_time -> P.All
  in
  match P.window ~config:boundary_presets_text ~day:today span ~offset with
  | Error why -> Error (P.message ~today why)
  | Ok (start_day, end_exclusive) ->
      let label =
        match preset with
        | Month -> Printf.sprintf "Month of %s" (String.sub start_day 0 7)
        | Year -> Printf.sprintf "Year %s" (String.sub start_day 0 4)
        | All_time -> "All Time (Full Ledger)"
        | Cycle -> Printf.sprintf "Cycle (%s .. %s)" start_day end_exclusive
        | Previous_cycle -> Printf.sprintf "Previous Cycle (%s .. %s)" start_day end_exclusive
      in
      Ok { preset; start_day; end_exclusive; label }
