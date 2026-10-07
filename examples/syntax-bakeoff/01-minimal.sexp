; SYNTHETIC syntax bake-off only. No parser/writer/migration implements or adopts this schema.
; Same retained evidence as examples/sexp-v1-candidate/01-retained-evidence.sexp.
; Goal: remove avoidable wrapper structure while keeping explicit states, identities and relations.

(bakhlo 1)

(collections
  (provided
    measures
    events
    event-corrections
    occurrence-revisions
    relations
    discharges
    observations
    presence
    zero-origin
    new-write-loci
    request-origins)
  (empty
    reversals
    exchanges
    opening-support)
  (not-supplied
    merchants
    original-amounts
    settlement
    bounded-history
    accounting-roles
    actual-routing
    scheduled-routing
    publication-receipts
    scheduled
    capacity
    attention))

(measure "jpy"
  (scale 0))

(event "e1"
  (day (date "2000-01-10"))
  (description (text "架空例：訂正前の出来事も残す。"))
  (effect
    (key (named "cash"))
    (locus "wallet")
    (measure "jpy")
    (quanta -10))
  (effect
    (key (named "offset"))
    (locus "food")
    (measure "jpy")
    (quanta 10)))

(event "e2"
  (day (date "1900-01-01"))
  (description (not-supplied))
  (effect
    (key (named "cash"))
    (locus "wallet")
    (measure "jpy")
    (quanta -12))
  (effect
    (key (named "offset"))
    (locus "food")
    (measure "jpy")
    (quanta 12)))

(event "e3"
  (day (date "1999-12-31"))
  (description (text ""))
  (effect
    (key (named "cash"))
    (locus "wallet")
    (measure "jpy")
    (quanta -4))
  (effect
    (key (named "offset"))
    (locus "food")
    (measure "jpy")
    (quanta 4)))

(event "net-zero"
  (day (not-supplied))
  (description (not-supplied))
  (effect
    (key (unkeyed))
    (locus "old-only")
    (measure "jpy")
    (quanta 1))
  (effect
    (key (unkeyed))
    (locus "old-only")
    (measure "jpy")
    (quanta -1)))

(event-correction
  (target "e1")
  (replacement "e2"))

(occurrence-revision "e1"
  (event "e1")
  (day "1850-01-01")
  (corrects (base-occurrence "e1")))

(relation "r1"
  (source
    (event "e1")
    (effect-key "cash"))
  (debtor (household))
  (creditor (external "counterparty-demo"))
  (quanta 6))

(discharge
  (event "e3")
  (relation "r1")
  (quanta 4))

(zero-origin
  (locus "quiet")
  (measure "jpy"))

(observation
  (reflected-roots "e1")
  (assertion
    (locus "wallet")
    (measure "jpy")
    (quanta 1000)))

(observation
  (reflected-roots)
  (assertion
    (locus "food")
    (measure "jpy")
    (quanta 50)))

(presence
  (reflected-roots)
  (coordinate
    (locus "pantry")
    (measure "jpy")))

(new-write-loci
  "wallet"
  "food"
  "quiet"
  "pantry")

(request-origin
  (request-token "req-old")
  (original-event "e1"))

(request-origin
  (request-token "req-correction")
  (original-event "e2"))

(request-origin
  (request-token "req-discharge")
  (original-event "e3"))
