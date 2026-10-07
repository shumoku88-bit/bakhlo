; SYNTHETIC ONLY: no private household inputs.
(bakhlo-daily 1)
(scope corrected-entries explicit-plans)
(measures (measure "jpy" 0) (measure "eur" 2))
(labels (provided
  (label "wallet" "財布" "現金の例")
  (label "food" "食費" "費目の例")
  (label "bank" "銀行" "口座の例")))
(approved-loci (provided "wallet" "food" "bank"))
(entries)
(plans
  (plan "planned-food" (date "2026-10-10") (measure "jpy")
    (changes ("wallet" -200) ("food" 200)) (paid-by (none))))
(support
  (zero-origin ("food" "jpy"))
  (openings)
  (observations
    (observation (reflected) (quantities ("wallet" "jpy" 1000)))
    (observation (reflected) (quantities ("wallet" "eur" 10000))))
  (presence (not-supplied)))
