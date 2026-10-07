; Synthetic probe owned by the isolated codec trial.
(bakhlo 1)

(collections
  (provided measures events)
  (empty)
  (not-supplied))

(measure "jpy"
  (scale 0))

(event "huge"
  (day (not-supplied))
  (description (text ""))
  (effect
    (key (named "positive"))
    (locus "wallet")
    (measure "jpy")
    (quanta 100000000000000000000000000000000000001))
  (effect
    (key (named "negative"))
    (locus "offset")
    (measure "jpy")
    (quanta -100000000000000000000000000000000000001)))

(future-evidence
  (opaque
    (nested "must survive bounded V1 decoding")))
