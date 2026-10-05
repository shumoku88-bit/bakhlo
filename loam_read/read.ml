open Base
module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query

type t =
  { original_bytes : string
  ; sections : Envelope.section list
  ; operation_origins : Input.operation_origin list
  ; quantity_image : Q.t
  }
type origin_error =
  | Repeated_request of { request_token : string; position : int }
  | Repeated_event of { event : D.Identifier.Event.t; position : int }
  | Unknown_event of { event : D.Identifier.Event.t; position : int }
type error =
  | Envelope of Envelope.error
  | Input of Input.error
  | Source of A.Actual_source.error
  | Operation_origins of origin_error
  | Support of Q.error

let qualify_origins source origins =
  let events = A.Correction_frontier.retained_events (A.Actual_source.frontier source) in
  Result.map
    (List.fold_result origins ~init:(1, Set.empty (module String), Set.empty (module D.Identifier.Event))
       ~f:(fun (position, requests, owned_events) ({ request_token; event } : Input.operation_origin) ->
         if Set.mem requests request_token then Error (Repeated_request { request_token; position })
         else if Set.mem owned_events event then Error (Repeated_event { event; position })
         else match D.Event_memory.find_by_id events event with
           | None -> Error (Unknown_event { event; position })
           | Some _ -> Ok (position + 1, Set.add requests request_token, Set.add owned_events event)))
    ~f:(fun _ -> ())

let of_string original_bytes =
  let ( let* ) result f = Result.bind result ~f in
  let* envelope = Result.map_error (Envelope.of_string original_bytes) ~f:(fun e -> Envelope e) in
  let* { Input.source = command; operation_origins; zero_origins; openings; groups; presence } =
    Result.map_error (Input.decode envelope) ~f:(fun e -> Input e) in
  let* source = Result.map_error (A.Actual_source.create command) ~f:(fun e -> Source e) in
  let* () = Result.map_error (qualify_origins source operation_origins) ~f:(fun e -> Operation_origins e) in
  let* quantity_image = Result.map_error
    (Q.create ~source ~zero_origins ~openings ~groups ~presence:(Some presence)) ~f:(fun e -> Support e) in
  Ok { original_bytes; sections = Envelope.sections envelope; operation_origins; quantity_image }

let original_bytes t = t.original_bytes
let sections t = t.sections
let operation_origins t = t.operation_origins
let quantity_image t = t.quantity_image
