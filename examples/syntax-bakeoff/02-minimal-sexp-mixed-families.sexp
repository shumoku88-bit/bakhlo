; SYNTHETIC S-expression health check only. No parser/writer/migration implements or adopts this schema.
; Starts from syntax-bakeoff/01-minimal.sexp and adds one Scheduled occurrence plus one Attention item.
; Coarse scheduled/attention placeholders are refined into logical subcollections here only so
; terminal/closure absence is not silently treated as empty. This does NOT select a physical file split.

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
    request-origins
    scheduled-occurrences
    attention-items)
  (empty
    reversals
    exchanges
    opening-support
    scheduled-terminals
    attention-closures)
  (not-supplied
    merchants
    original-amounts
    settlement
    bounded-history
    accounting-roles
    actual-routing
    scheduled-routing
    publication-receipts
    capacity))

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

(scheduled-occurrence "s1"
  (scheduled-on "2000-02-01")
  (movement
    (measure "jpy")
    (change
      (locus "wallet")
      (quanta -20))
    (change
      (locus "food")
      (quanta 20))))

(attention-item "a1"
  (context "架空例：期限未確定の確認事項")
  (due (undetermined)))
