; Synthetic travel book for ordinary + explicit exchange recording.
(bakhlo 3 ordinary-quantity)
(collections
  (provided measures observations zero-origin)
  (empty events event-corrections exchanges)
  (not-supplied))
(locus-admission (approved "bank-jpy" "cash-eur" "food"))
(measure "jpy" (decimal-scale 0))
(measure "eur" (decimal-scale 2))
(observation
  (reflected-roots)
  (assertion (locus "bank-jpy") (measure "jpy") (quanta 10000)))
(zero-origin (locus "cash-eur") (measure "eur"))
(zero-origin (locus "food") (measure "eur"))
