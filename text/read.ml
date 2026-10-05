module S = Bakhlo_application.Actual_source
module Q = Bakhlo_application.Current_quantity_query

type error = Input of Input.error | Source of S.error | Support of Q.error

let of_string text =
  match Input.decode text with
  | Error error -> Error (Input error)
  | Ok { source; zero_origins; openings; groups; presence } -> (
      match S.create source with
      | Error error -> Error (Source error)
      | Ok source -> (
          match Q.create ~source ~zero_origins ~openings ~groups ~presence with
          | Error error -> Error (Support error)
          | Ok image -> Ok image))
