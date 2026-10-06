; SYNTHETIC candidate: same facts as 01, with references before definitions.
; Record encounter order changes; graph selection/answers must not depend on that order.
(bakhlo
  (format-version 1)
  (provenance
    (publication-receipts (not-supplied))
    (request-origins (provided
      (request-origin (request-token "req-discharge") (original-event "e3"))
      (request-origin (request-token "req-old") (original-event "e1"))
      (request-origin (request-token "req-correction") (original-event "e2")))))
  (quantity-support
    (bounded-history (not-supplied))
    (presence (provided
      (presence-group
        (reflected-roots)
        (coordinates
          (coordinate (locus "pantry") (measure "jpy"))))))
    (observations (provided
      (observation-group
        (reflected-roots)
        (assertions
          (assertion (locus "food") (measure "jpy") (quanta 50))))
      (observation-group
        (reflected-roots "e1")
        (assertions
          (assertion (locus "wallet") (measure "jpy") (quanta 1000))))))
    (opening-support (provided))
    (zero-origin (provided
      (coordinate (locus "quiet") (measure "jpy")))))
  (actual
    (discharges (provided
      (discharge (event "e3") (relation "r1") (quanta 4))))
    (relations (provided
      (relation
        (id "r1")
        (source (event "e1") (effect-key "cash"))
        (debtor (household))
        (creditor (external "counterparty-demo"))
        (quanta 6))))
    (occurrence-revisions (provided
      (occurrence-revision
        (id "e1")
        (event "e1")
        (day "1850-01-01")
        (corrects (base-occurrence "e1")))))
    (event-corrections (provided
      (event-correction (target "e1") (replacement "e2"))))
    (events (provided
      (event
        (id "e3")
        (occurrence-day (date "1999-12-31"))
        (description (text ""))
        (effects
          (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -4))
          (effect (key (named "offset")) (locus "food") (measure "jpy") (quanta 4))))
      (event
        (id "e2")
        (occurrence-day (date "1900-01-01"))
        (description (not-supplied))
        (effects
          (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -12))
          (effect (key (named "offset")) (locus "food") (measure "jpy") (quanta 12))))
      (event
        (id "net-zero")
        (occurrence-day (not-supplied))
        (description (not-supplied))
        (effects
          (effect (key (unkeyed)) (locus "old-only") (measure "jpy") (quanta 1))
          (effect (key (unkeyed)) (locus "old-only") (measure "jpy") (quanta -1))))
      (event
        (id "e1")
        (occurrence-day (date "2000-01-10"))
        (description (text "架空例：訂正前の出来事も残す。"))
        (effects
          (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -10))
          (effect (key (named "offset")) (locus "food") (measure "jpy") (quanta 10))))))
    (settlement (not-supplied))
    (exchanges (provided))
    (original-amounts (not-supplied))
    (merchants (not-supplied))
    (reversals (provided)))
  (other-evidence
    (attention (not-supplied))
    (scheduled (not-supplied))
    (capacity (not-supplied)))
  (policy
    (scheduled-routing (not-supplied))
    (actual-routing (not-supplied))
    (accounting-roles (not-supplied))
    (new-write-loci (provided "wallet" "food" "quiet" "pantry")))
  (interpretation
    (measures (provided
      (measure (id "jpy") (decimal-scale 0))))))
