(** Durable Append-Only Storage Engine for Records S-expression.
    Provides strict process-level locking, log sequence number (LSN) conflict detection,
    deterministic torn-write recovery, request-token idempotency, and in-doubt commit evidence. *)

type engine

type client_session = {
  session_id : string;
  mutable last_acknowledged_token : string option;
  mutable last_acknowledged_lsn : int;
}

type commit_result =
  | Commit_success of { lsn : int; event_id : string }
  | Idempotent_duplicate of { lsn : int; event_id : string }
  | Lsn_conflict of { expected : int; actual : int }
  | Payload_drift_refused of string
  | Storage_error of string
  | Sync_uncertain of { lsn : int; event_id : string; error : string }

type in_doubt_status =
  | In_doubt_none
  | In_doubt_detected of {
      unacknowledged_token : string;
      lsn : int;
      event_id : string;
    }

type recovery_action =
  | Clean of { last_lsn : int; total_frames : int }
  | Torn_write_truncated of { valid_lsn : int; truncated_bytes : int }
  | Corrupt_fail_closed of { offset : int; reason : string }
  | Truncate_failed of string

val create_session : session_id:string -> ?last_token:string -> ?last_lsn:int -> unit -> client_session
(** Create an in-memory or resumed client session with tracked acknowledgment state. *)

val acknowledge_session : client_session -> token:string -> lsn:int -> unit
(** Advance client session acknowledgment state upon verified reception of Ack. *)

val check_in_doubt : engine -> session:client_session -> in_doubt_status
(** Compare engine's durable state against client session to detect unconfirmed in-doubt commits. *)

val recover_and_open : string -> (engine * recovery_action, string) result
(** Inspect log file, recover any trailing torn-write IF safe, and open engine.
    Fails closed if mid-file corruption is detected. *)

val close_engine : engine -> unit
(** Close all associated file descriptors and resources. *)

val current_lsn : engine -> int
(** Query the currently highest committed LSN in storage. *)

val path : engine -> string
(** Return underlying log file path. *)

val latest_token : engine -> string option
(** Most recent request token committed to the log, if any. *)

val latest_event_id : engine -> string option
(** Most recent event ID associated with the committed token, if any. *)

type token_record = {
  token : string;
  event_id : string;
  lsn : int;
  payload_summary : string;
}

val find_token : engine -> string -> token_record option
(** Lookup committed token record in engine index, if present. *)

val has_token : engine -> string -> bool
(** Return true if token was committed to the durable log. *)

val append_payload :
  engine ->
  session:client_session ->
  expected_lsn:int ->
  token:string option ->
  event_id:string ->
  payload:Records_book.payload ->
  commit_result
(** Atomically append a frame to the log under exclusive process lock,
    verifying LSN order, validating idempotency, and flushing via fsync. *)

val append_entry :
  engine ->
  session:client_session ->
  expected_lsn:int ->
  Records_book.entry ->
  commit_result
(** Convenience wrapper to append an entry record with its request token. *)

val append_plan :
  engine ->
  session:client_session ->
  expected_lsn:int ->
  Records_book.plan ->
  commit_result

val append_budget :
  engine ->
  session:client_session ->
  expected_lsn:int ->
  Records_book.budget ->
  commit_result
