; DELIBERATELY INVALID synthetic v1 candidate. NOT a valid canonical generation.
; e1 was dropped as if only current Events mattered; retained references now dangle.
; Expected review outcome: REFUSE, never repair from e2, load an ancestor, or skip evidence.
(bakhlo
  (format-version 1)
  (interpretation
    (measures (provided
      (measure (id "jpy") (decimal-scale 0)))))
  (actual
    (events (provided
      (event
        (id "e2")
        (occurrence-day (date "1900-01-01"))
        (description (not-supplied))
        (effects
          (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -12))
          (effect (key (named "offset")) (locus "food") (measure "jpy") (quanta 12))))
      (event
        (id "e3")
        (occurrence-day (date "1999-12-31"))
        (description (text ""))
        (effects
          (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -4))
          (effect (key (named "offset")) (locus "food") (measure "jpy") (quanta 4))))
      (event
        (id "net-zero")
        (occurrence-day (not-supplied))
        (description (not-supplied))
        (effects
          (effect (key (unkeyed)) (locus "old-only") (measure "jpy") (quanta 1))
          (effect (key (unkeyed)) (locus "old-only") (measure "jpy") (quanta -1))))))
    (event-corrections (provided
      (event-correction (target "e1") (replacement "e2"))))
    (occurrence-revisions (provided
      (occurrence-revision
        (id "e1")
        (event "e1")
        (day "1850-01-01")
        (corrects (base-occurrence "e1")))))
    (reversals (provided))
    (merchants (not-supplied))
    (original-amounts (not-supplied))
    (exchanges (provided))
    (relations (provided
      (relation
        (id "r1")
        (source (event "e1") (effect-key "cash"))
        (debtor (household))
        (creditor (external "counterparty-demo"))
        (quanta 6))))
    (discharges (provided
      (discharge (event "e3") (relation "r1") (quanta 4))))
    (settlement (not-supplied)))
  (quantity-support
    (zero-origin (provided
      (coordinate (locus "quiet") (measure "jpy"))))
    (opening-support (provided))
    (observations (provided
      (observation-group
        (reflected-roots "e1")
        (assertions
          (assertion (locus "wallet") (measure "jpy") (quanta 1000))))
      (observation-group
        (reflected-roots)
        (assertions
          (assertion (locus "food") (measure "jpy") (quanta 50))))))
    (presence (provided
      (presence-group
        (reflected-roots)
        (coordinates
          (coordinate (locus "pantry") (measure "jpy"))))))
    (bounded-history (not-supplied)))
  (policy
    (new-write-loci (provided "wallet" "food" "quiet" "pantry"))
    (accounting-roles (not-supplied))
    (actual-routing (not-supplied))
    (scheduled-routing (not-supplied)))
  (provenance
    (request-origins (provided
      (request-origin (request-token "req-old") (original-event "e1"))
      (request-origin (request-token "req-correction") (original-event "e2"))
      (request-origin (request-token "req-discharge") (original-event "e3"))))
    (publication-receipts (not-supplied)))
  (other-evidence
    (scheduled (not-supplied))
    (capacity (not-supplied))
    (attention (not-supplied))))
