; SYNTHETIC ordinary Movement proposal; exactly one supplied Event.
(event "purchase"
  (day (date "2000-01-10"))
  (description (text "架空の支出：訂正前も残す。"))
  (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -100))
  (effect (key (unkeyed)) (locus "food") (measure "jpy") (quanta 100)))
