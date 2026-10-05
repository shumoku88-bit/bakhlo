type t = {
  source : Bakhlo_application.Actual_source.command;
  zero_origins : Bakhlo_domain.Effect_coordinate.t list;
  openings : Bakhlo_application.Current_quantity_query.opening list;
  groups : Bakhlo_application.Current_quantity_groups.group list;
  presence : Bakhlo_application.Current_quantity_query.presence option;
}
(** Experimental synthetic read profile, NOT canonical household storage/wire format.
    Header [bakhlo-read 1 ordinary-actual-quantity], final [end] and newline required.
    Spaces/tabs delimit tokens; blank lines/indentation allowed, comments unsupported.
    Identity/date/description fields MUST be quoted. Bytes are preserved, not trimmed
    or Unicode-normalized; literal control bytes refuse. Escapes: quote, backslash,
    n/r/t and xHH (exact one byte). Raw high bytes are opaque, not UTF-8 validation.
    Quantities are unquoted [+-]?[0-9]+, unbounded exact signed integer quanta.

    Top-level records (quoted fields shown in quotes):
    [event "id" "base-date"] or [event "id" none] / zero or more
    [effect anonymous "locus" "measure" QUANTA] or
    [effect key "key" "locus" "measure" QUANTA] / [end-event].
    [correct "target" "replacement"], [describe "event" "text"],
    [origin "locus" "measure"], [opening "locus" "measure" "event"].
    [group] / [reflect "root"] or [assert "locus" "measure" QUANTA] / [end-group].
    At most one [presence] / [reflect "root"] or [present "locus" "measure"] /
    [end-presence]. No presence block means no supplied presence evidence; empty
    explicit presence remains Some empty. Groups remain independent/order retained.
    References may be forward; none date supplies NO fact, not a default. Missing
    current validity, malformed dates, zero/unbalanced physical evidence, source
    closure and support ownership are refused by existing Application gates.

    ONLY ordinary Actual Events, base validity, Event corrections/descriptions and
    four support families are expressible. Validity revisions, Merchant, original
    amounts, Exchange, Reversal, relations, discharges, Scheduled etc MUST refuse;
    never filter a richer document into this profile. Omitted metadata is unresolved,
    not known-none. No implicit evidence, full Actual/household coverage, generation
    allocation, authority, partial-source salvage, publication or format upgrade.
    Decode is not admission; Event key uniqueness is checked at end-event. *)

type error =
  | Syntax of { line : int; problem : string }
  | Unsupported_version of { line : int; version : string }
  | Unsupported_profile of { line : int; profile : string }
  | Unsupported_record of { line : int; name : string }
  | Invalid_event of {
      line : int;
      event : Bakhlo_domain.Identifier.Event.t;
      error : Bakhlo_domain.Event.error;
    }

val decode : string -> (t, error) result
