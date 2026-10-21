(** Editor sessions over Actual and Scheduled records (reversal, date
    correction, Merchant, cancellation, continuation, batch amounts,
    generation, plan creation). At most one is open over the current route.
    Publications are reviewed against the bytes the session started from; the
    Shell reports every outcome and a failure keeps the session in review. *)

type session =
  | Reversal of Reversal_session.t
  | Date_correction of Date_correction_session.t
  | Event_merchant of Merchant_session.t
  | Scheduled_cancel of Scheduled_cancellation_session.t
  | Scheduled_continuation of Scheduled_continuation_session.t
  | Scheduled_bulk of Scheduled_bulk_session.t
  | Scheduled_generate of Scheduled_generation_session.t
  | Scheduled_create of Scheduled_session.t

type t

val config_files : string list
val create : unit -> t
val modal : t -> bool
val active : t -> session option

val open_session : session -> t -> t
(** Workflows that select a record open its session through the Shell. *)

val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val published : Screen.env -> Screen.geometry -> Screen.publish_outcome -> t -> t * Screen.request
val reloaded : Screen.env -> t -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view
