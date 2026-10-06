; SYNTHETIC candidate: exact huge quanta, two Measures, explicit empty vs not-supplied.
; OpeningSupport designates an Event; it does not duplicate the Event's quantity.
(bakhlo
  (format-version 1)
  (interpretation
    (measures (provided
      (measure (id "jpy") (decimal-scale 0))
      (measure (id "usd") (decimal-scale 2)))))
  (actual
    (events (provided
      (event
        (id "usd-opening")
        (occurrence-day (date "2000-01-01"))
        (description (text "架空の引用 \"demo\"\n次の行も保存する。"))
        (effects
          (effect (key (named "opening")) (locus "wallet") (measure "usd")
            (quanta 100000000000000000000000000000000000001))
          (effect (key (named "offset")) (locus "offset") (measure "usd")
            (quanta -100000000000000000000000000000000000001))))
      (event
        (id "touched-without-origin")
        (occurrence-day (not-supplied))
        (description (text ""))
        (effects
          (effect (key (unkeyed)) (locus "old-only") (measure "jpy") (quanta 1))
          (effect (key (unkeyed)) (locus "old-only") (measure "jpy") (quanta -1))))))
    (event-corrections (provided))
    (occurrence-revisions (provided))
    (reversals (provided))
    (merchants (not-supplied))
    (original-amounts (not-supplied))
    (exchanges (provided))
    (relations (provided))
    (discharges (provided))
    (settlement (not-supplied)))
  (quantity-support
    (zero-origin (provided
      (coordinate (locus "wallet") (measure "jpy"))))
    (opening-support (provided
      (opening
        (coordinate (locus "wallet") (measure "usd"))
        (event "usd-opening"))))
    (observations (provided))
    (presence (provided
      (presence-group
        (reflected-roots)
        (coordinates
          (coordinate (locus "pantry") (measure "jpy"))))))
    (bounded-history (not-supplied)))
  (policy
    (new-write-loci (provided "wallet" "offset" "pantry"))
    (accounting-roles (provided))
    (actual-routing (not-supplied))
    (scheduled-routing (not-supplied)))
  (provenance
    (request-origins (provided
      (request-origin (request-token "req-opening") (original-event "usd-opening"))))
    (publication-receipts (not-supplied)))
  (other-evidence
    (scheduled (not-supplied))
    (capacity (not-supplied))
    (attention (not-supplied))))
