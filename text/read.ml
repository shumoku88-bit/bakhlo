module S = Bakhlo_application.Actual_source
module Q = Bakhlo_application.Current_quantity_query

type error = Input of Input.error | Source of S.error | Support of Q.error
type document = { bytes : string; image : Q.t }

let document_bytes document = document.bytes
let document_image document = document.image

let document_of_string text =
  match Input.decode text with
  | Error error -> Error (Input error)
  | Ok { source; zero_origins; openings; groups; presence } -> (
      match S.create source with
      | Error error -> Error (Source error)
      | Ok source -> (
          match Q.create ~source ~zero_origins ~openings ~groups ~presence with
          | Error error -> Error (Support error)
          | Ok image -> Ok { bytes = text; image }))

let of_string text = Result.map document_image (document_of_string text)
