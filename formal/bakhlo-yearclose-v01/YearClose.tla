----------------------------- MODULE YearClose -----------------------------
EXTENDS Naturals

(***************************************************************************
  Bakhlo annual close: abstract two-year publication safety model v0.1.
  It is deliberately NOT a filesystem or fsync model.  The selected year
  revisions are treated as the durable, externally observable selection.
  AtomicPublish=TRUE assumes a single atomic selection of a consistent pair;
  the storage mechanism that could implement this assumption is UNKNOWN.
  AtomicPublish=FALSE deliberately exposes a broken two-step publication.

  2025 is already Final.  A normal edit of the closed year is excluded;
  BeginAmend models an authorized exceptional amendment of the 2025 book.
  "A" and "B" are distinct immutable candidate generations.  Generation B
  of 2026 carries from 2025 generation B and keeps existing 2026 facts.
  Support/root-cut semantics are abstracted behind ValidateCandidate.
***************************************************************************)
CONSTANT AtomicPublish
ASSUME AtomicPublish \in BOOLEAN

VARIABLES year25, year26, staged25, staged26, qualified, phase,
          running, acked, planPayments, existing2026, old25Retained

vars == <<year25, year26, staged25, staged26, qualified, phase,
          running, acked, planPayments, existing2026, old25Retained>>

Phases == {"idle", "draft", "staged25", "staged26", "qualified",
           "half", "published", "done", "unavailable"}

Init ==
  /\ year25 = "A"
  /\ year26 = "A"
  /\ staged25 = FALSE
  /\ staged26 = FALSE
  /\ qualified = FALSE
  /\ phase = "idle"
  /\ running = TRUE
  /\ acked = FALSE
  /\ planPayments = 0
  /\ existing2026 = 1
  /\ old25Retained = TRUE

BeginAmend ==
  /\ running
  /\ phase = "idle"
  /\ year25 = "A"
  /\ phase' = "draft"
  /\ staged25' = FALSE
  /\ staged26' = FALSE
  /\ qualified' = FALSE
  /\ UNCHANGED <<year25, year26, running, acked,
                  planPayments, existing2026, old25Retained>>

Stage2025 ==
  /\ running
  /\ phase = "draft"
  /\ phase' = "staged25"
  /\ staged25' = TRUE
  /\ UNCHANGED <<year25, year26, staged26, qualified, running,
                  acked, planPayments, existing2026, old25Retained>>

Stage2026 ==
  /\ running
  /\ phase = "staged25"
  /\ staged25
  /\ phase' = "staged26"
  /\ staged26' = TRUE
  /\ UNCHANGED <<year25, year26, staged25, qualified, running,
                  acked, planPayments, existing2026, old25Retained>>

ValidateCandidate ==
  /\ running
  /\ phase = "staged26"
  /\ staged25 /\ staged26
  /\ phase' = "qualified"
  /\ qualified' = TRUE
  /\ UNCHANGED <<year25, year26, staged25, staged26, running,
                  acked, planPayments, existing2026, old25Retained>>

SelectCandidate ==
  /\ running
  /\ phase = "qualified"
  /\ qualified /\ staged25 /\ staged26
  /\ year25' = "B"
  /\ year26' = IF AtomicPublish THEN "B" ELSE year26
  /\ phase' = IF AtomicPublish THEN "published" ELSE "half"
  /\ UNCHANGED <<staged25, staged26, qualified, running,
                  acked, planPayments, existing2026, old25Retained>>

FinishBrokenPublish ==
  /\ ~AtomicPublish
  /\ running
  /\ phase = "half"
  /\ year26' = "B"
  /\ phase' = "published"
  /\ UNCHANGED <<year25, staged25, staged26, qualified, running,
                  acked, planPayments, existing2026, old25Retained>>

Acknowledge ==
  /\ running
  /\ phase = "published"
  /\ year25 = "B" /\ year26 = "B"
  /\ phase' = "done"
  /\ acked' = TRUE
  /\ UNCHANGED <<year25, year26, staged25, staged26, qualified,
                  running, planPayments, existing2026, old25Retained>>

(***************************************************************************
  A single pre-existing plan may be fulfilled once.  This is only a bounded
  domain guard: no real cross-file payment transaction is being claimed.
***************************************************************************)
PayOnce ==
  /\ running
  /\ phase \in {"idle", "published", "done"}
  /\ planPayments = 0
  /\ planPayments' = 1
  /\ UNCHANGED <<year25, year26, staged25, staged26, qualified,
                  phase, running, acked, existing2026, old25Retained>>

Crash ==
  /\ running
  /\ running' = FALSE
  /\ UNCHANGED <<year25, year26, staged25, staged26, qualified,
                  phase, acked, planPayments, existing2026, old25Retained>>

Recover ==
  /\ ~running
  /\ running' = TRUE
  /\ phase' = IF year25 # year26 THEN "unavailable"
               ELSE IF year25 = "B" THEN "published" ELSE "idle"
  /\ UNCHANGED <<year25, year26, staged25, staged26, qualified,
                  acked, planPayments, existing2026, old25Retained>>

Next ==
  \/ BeginAmend
  \/ Stage2025
  \/ Stage2026
  \/ ValidateCandidate
  \/ SelectCandidate
  \/ FinishBrokenPublish
  \/ Acknowledge
  \/ PayOnce
  \/ Crash
  \/ Recover

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ year25 \in {"A", "B"}
  /\ year26 \in {"A", "B"}
  /\ staged25 \in BOOLEAN
  /\ staged26 \in BOOLEAN
  /\ qualified \in BOOLEAN
  /\ phase \in Phases
  /\ running \in BOOLEAN
  /\ acked \in BOOLEAN
  /\ planPayments \in 0..1
  /\ existing2026 \in Nat
  /\ old25Retained \in BOOLEAN

(***************************************************************************
  These are PUBLICATION invariants, not filesystem implementation proofs.
***************************************************************************)
ConsistentSelection == year25 = year26
NewSelectionQualified ==
  ((year25 = "B" \/ year26 = "B")
    => (qualified /\ staged25 /\ staged26))
AckIsForNewPair == acked => (year25 = "B" /\ year26 = "B")
PreserveExisting2026 == existing2026 = 1
RetainOldFinal == old25Retained
UniquePayment == planPayments <= 1

=============================================================================
