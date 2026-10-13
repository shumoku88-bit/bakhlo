module D = Bakhlo_domain
(** Opt-in annual read/validation boundary, NOT a production storage entrance.
    No selected-store implementation, publication, migration or new wire format.
    The default Daily_book/CLI/TUI paths are unchanged. *)

type fingerprint

val fingerprint : string -> fingerprint
(** Computes a content identifier from the exact input bytes (MD5).
    No unchecked hash-string constructor. This detects accidental changes, not
    malicious collisions or authority; authority belongs to the source below. *)

type selected = { year : int; revision : int; fingerprint : fingerprint }
type selection = { generation : int; years : selected list }
type original = { generation : int; year : int; revision : int; contents : string }

type error =
  | Selection_missing
  | Selection_unknown of string
  | Selection_corrupt of string
  | Year_missing of int
  | Original_missing of int
  | Original_unavailable of string
  | Mixed_generation of { expected : int; actual : int }
  | Mixed_session
  | Year_mismatch of { expected : int; actual : int }
  | Revision_mismatch of { year : int; expected : int; actual : int }
  | Fingerprint_mismatch of int
  | Unsupported_format of int
  | Admission_failed of { year : int; reason : string }
  | Entry_outside_year of { year : int; entry : string }
  | Not_previous_year of { prior : int; current : int }

module type VERIFIED_SELECTION_SOURCE = sig
  type snapshot

  val acquire : unit -> (snapshot, error) result
  (** MUST establish an authoritative, verified, immutable selection snapshot.
      Missing/corrupt/unresolved state must fail. A self-declared file header or
      user-supplied selection/hash is NOT verification. There is deliberately no
      production implementation or generic "trust these records" constructor. *)

  val selection : snapshot -> selection
  (** All years belong to ONE atomic generation; stable for the snapshot lifetime. *)

  val read : snapshot -> year:int -> (original, error) result
  (** Read-only bytes of the selected original, tagged with snapshot generation,
      year and revision. Must not repair, rewrite or substitute current HEAD.
      The boundary independently checks tags, fingerprint and Core admission. *)
end

type balance = Exact of D.Quantity.t | Zero_origin | Known_present | Unknown

module Make (Source : VERIFIED_SELECTION_SOURCE) : sig
  type session
  type year_version
  type carry_forward
  type annual_read

  val begin_session : unit -> (session, error) result

  val load_year : session -> year:int -> (year_version, error) result
  (** Explicitly parses existing monolithic Daily S-expressions only; Records
      and future formats refuse, without auto-detection/migration into a new path. *)

  val derive_carry_forward : session -> year_version -> (carry_forward, error) result
  (** Opaque disposable derivative of verified original + Core query image.
      Not independent observation evidence. No persisted/claimed balance input. *)

  val read_with_carry : session -> year:int -> carry_forward -> (annual_read, error) result
  (** Checks prior year/revision/fingerprint/session before admitting current year.
      A new session requires reloading/rederiving; never mixes session handles. *)

  val current_book : annual_read -> Daily_book.t
  (** Admitted CURRENT partition only, NOT a combined book or full balance answer.
      Cross-year references still refuse via Daily_book; resolver is deferred. *)

  val carry_balance : annual_read -> D.Effect_coordinate.t -> balance
  (** Prior-year closing answer from Core, NOT current-year balance arithmetic.
      Only available after freshness validation. Zero_origin is emitted only for
      an exact zero with that premise; nonzero origin-supported totals are Exact.
      No independent observation, support inference, or Unknown-to-zero fallback. *)
end
