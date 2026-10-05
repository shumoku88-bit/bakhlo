(** Pure read-side LOAM input profile. Not LOAM authority, full-household admission,
    Bakhlo canonical storage, durable publication, migration or runtime selection.
    All physical sections/raw bytes survive; only Actual + four quantity supports
    and request/Event origins are qualified for this conditional quantity scope. *)
type t
type origin_error =
  | Repeated_request of { request_token : string; position : int }
  | Repeated_event of { event : Bakhlo_domain.Identifier.Event.t; position : int }
  | Unknown_event of { event : Bakhlo_domain.Identifier.Event.t; position : int }
type error =
  | Envelope of Envelope.error
  | Input of Input.error
  | Source of Bakhlo_application.Actual_source.error
  | Operation_origins of origin_error
  | Support of Bakhlo_application.Current_quantity_query.error

(** Envelope/decode, whole Actual admission, all origins, whole support before
    any lookup. Exact request tokens map one-to-one to retained Events, including
    superseded Events: never transfer to corrections or infer success/payment.
    All required profile sections must be physically present with supported frames;
    missing optional-world sections are a profile refusal, not household corruption.
    Settlement/unknown Actual records refuse without filtering. This profile is
    deliberately narrower than full normalized LOAM admission. Caller owns supplying
    one coherent generation: string/parse success is not live-file snapshot evidence.
    No I/O or fallback. *)
val of_string : string -> (t, error) result
val original_bytes : t -> string
val sections : t -> Envelope.section list
val operation_origins : t -> Input.operation_origin list
val quantity_image : t -> Bakhlo_application.Current_quantity_query.t
