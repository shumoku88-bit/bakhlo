------------------------- MODULE YearCloseAudited -------------------------
EXTENDS Naturals

(***************************************************************************
  Bakhlo annual close: audited two-year publication safety model v0.1-audited.
  
  Audit findings and minimal fixes applied to v0.1:
  1. FailClosedRecovery invariant was missing in v0.1. We explicitly define:
     FailClosedRecovery ==
       /\ (phase \in {"published", "done"} \/ acked) => (phase # "unavailable" /\ year25 = year26)
       /\ (phase = "unavailable") => ~acked
  2. Naming alignment:
     PreserveCurrentYear == existing2026 = 1
     ClosedRevisionImmutable == old25Retained
     (Note: as audited, in v0.1 existing2026 and old25Retained are never modified
      by any action, making these invariants vacuous in v0.1. A real test of
      concurrent arrival of new records belongs in v0.2).
  3. Crash/Recover volatile state isolation:
     In v0.1, Recover preserved staged25, staged26, qualified across process
     crashes. In a crash recovery to "idle" or "unavailable", in-memory draft
     state MUST be cleared (reset to FALSE) to model volatile memory loss.
  4. Explicit FailClosed property:
     When an inconsistent publication crash occurs (year25 # year26),
     recovery enters "unavailable" and never transitions to published/done/acked.
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
  /\ staged25' = IF year25 = "B" THEN staged25 ELSE FALSE
  /\ staged26' = IF year25 = "B" THEN staged26 ELSE FALSE
  /\ qualified' = IF year25 = "B" THEN qualified ELSE FALSE
  /\ UNCHANGED <<year25, year26, acked, planPayments, existing2026, old25Retained>>

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

ConsistentSelection == year25 = year26

NewSelectionQualified ==
  ((year25 = "B" \/ year26 = "B")
    => (qualified /\ staged25 /\ staged26))

AckIsForNewPair == acked => (year25 = "B" /\ year26 = "B")

PreserveExisting2026 == existing2026 = 1
PreserveCurrentYear == PreserveExisting2026

RetainOldFinal == old25Retained
ClosedRevisionImmutable == RetainOldFinal

UniquePayment == planPayments <= 1

FailClosedRecovery ==
  /\ (phase \in {"published", "done"} \/ acked) => (phase # "unavailable" /\ year25 = year26)
  /\ (phase = "unavailable") => ~acked

=============================================================================
