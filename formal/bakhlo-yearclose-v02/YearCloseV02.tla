--------------------------- MODULE YearCloseV02 ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
  Bakhlo Annual Close & Carryover Safety Model v0.2.
  
  Focus:
  - Independent revisions for 2025 and 2026 books.
  - 2026 carryover references a specific 2025 authoritative revision.
  - 2026 records are represented as a set of stable record identities.
  - Staging carryover captures observed (rev25, rev26) and current records.
  - Concurrent append to 2026 book while amendment is in progress.
  - Publication guards:
      - Safe model: Verifies observed generations match current selections
        (Optimistic Concurrency Control / OCC). Rejects stale candidates.
      - Broken models:
        1. Stale publish (omits OCC check) -> leads to 2026 record loss.
        2. Non-atomic publish -> leads to dangling/half-published state.
        3. Old carryover publication -> leads to inconsistent carryover reference.
  - Crash recovery wipes volatile uncommitted candidate state.
***************************************************************************)

CONSTANTS
  RecordID,                  \* Set of stable record identities, e.g. {"r1", "r2"}
  CheckGenerationOnPublish,  \* BOOLEAN: whether to verify observed revision before publishing
  AtomicPublish,             \* BOOLEAN: whether 2025/2026 switch is assumed atomic
  CorrectCarryoverStaging    \* BOOLEAN: whether staged carryover correctly targets new 2025 revision

ASSUME CheckGenerationOnPublish \in BOOLEAN
ASSUME AtomicPublish \in BOOLEAN
ASSUME CorrectCarryoverStaging \in BOOLEAN

VARIABLES
  \* Authoritative durable state
  rev25,                      \* Nat: currently published 2025 revision
  rev26,                      \* Nat: currently published 2026 revision
  records26,                  \* SUBSET RecordID: active committed records in 2026
  carryoverRef26,             \* Nat: 2025 revision referenced by 2026 carryover
  historyCommittedRecords26,  \* SUBSET RecordID: history of all records committed to 2026

  \* Staged / in-flight candidate state (volatile workspace)
  staged25,                   \* BOOLEAN: 2025 amended candidate exists
  staged26,                   \* BOOLEAN: 2026 carryover candidate exists
  observedRev25,              \* Nat: 2025 revision observed when candidate was built
  observedRev26,              \* Nat: 2026 revision observed when candidate was built
  stagedRecords26,            \* SUBSET RecordID: records retained in 2026 candidate
  stagedCarryoverRef,          \* Nat: 2025 revision referenced by candidate carryover
  qualified,                  \* BOOLEAN: candidate pair verified by domain rules

  \* Process & Protocol lifecycle
  phase,                      \* Protocol phase
  running,                    \* BOOLEAN: process is running (FALSE = crashed)
  acked                       \* BOOLEAN: publication acknowledged to caller

vars == <<rev25, rev26, records26, carryoverRef26, historyCommittedRecords26,
          staged25, staged26, observedRev25, observedRev26,
          stagedRecords26, stagedCarryoverRef, qualified,
          phase, running, acked>>

Phases == {"idle", "amending25", "staged26", "qualified",
           "half_published", "published", "rejected", "done", "unavailable"}

(***************************************************************************
  Initial State:
  - 2025 is at revision 1 (Final).
  - 2026 is at revision 1, referencing 2025 revision 1, containing {"r1"}.
***************************************************************************)
Init ==
  /\ rev25 = 1
  /\ rev26 = 1
  /\ records26 = {"r1"}
  /\ carryoverRef26 = 1
  /\ historyCommittedRecords26 = {"r1"}
  /\ staged25 = FALSE
  /\ staged26 = FALSE
  /\ observedRev25 = 0
  /\ observedRev26 = 0
  /\ stagedRecords26 = {}
  /\ stagedCarryoverRef = 0
  /\ qualified = FALSE
  /\ phase = "idle"
  /\ running = TRUE
  /\ acked = FALSE

(***************************************************************************
  Concurrent Append to Current Year (2026):
  A user or background process records a new transaction in 2026.
  This advances 2026 revision independently from 2025.
***************************************************************************)
Append2026 ==
  \E r \in RecordID \ records26:
    /\ running
    /\ records26' = records26 \cup {r}
    /\ historyCommittedRecords26' = historyCommittedRecords26 \cup {r}
    /\ rev26' = rev26 + 1
    /\ UNCHANGED <<rev25, carryoverRef26, staged25, staged26,
                    observedRev25, observedRev26, stagedRecords26,
                    stagedCarryoverRef, qualified, phase, running, acked>>

(***************************************************************************
  Step 1: Begin exceptional amendment of 2025 book (revision 1 -> 2).
***************************************************************************)
BeginAmend2025 ==
  /\ running
  /\ phase \in {"idle", "rejected"}
  /\ rev25 = 1
  /\ phase' = "amending25"
  /\ staged25' = TRUE
  /\ staged26' = FALSE
  /\ qualified' = FALSE
  /\ observedRev25' = 0
  /\ observedRev26' = 0
  /\ stagedRecords26' = {}
  /\ stagedCarryoverRef' = 0
  /\ UNCHANGED <<rev25, rev26, records26, carryoverRef26,
                  historyCommittedRecords26, running, acked>>

(***************************************************************************
  Step 2: Stage 2026 carryover candidate based on amended 2025 candidate.
  Observes the CURRENT authoritative state of 2026 (observedRev26, records26),
  and sets carryover to refer to amended 2025 (revision 2 if correct, 1 if broken).
***************************************************************************)
Stage2026Carryover ==
  /\ running
  /\ phase = "amending25"
  /\ staged25
  /\ phase' = "staged26"
  /\ staged26' = TRUE
  /\ observedRev25' = rev25
  /\ observedRev26' = rev26
  /\ stagedRecords26' = records26
  /\ stagedCarryoverRef' = IF CorrectCarryoverStaging THEN 2 ELSE 1
  /\ UNCHANGED <<rev25, rev26, records26, carryoverRef26,
                  historyCommittedRecords26, staged25, qualified,
                  running, acked>>

(***************************************************************************
  Step 3: Validate candidate pair (Core admission, root-cut consistency).
***************************************************************************)
ValidateCandidate ==
  /\ running
  /\ phase = "staged26"
  /\ staged25 /\ staged26
  /\ phase' = "qualified"
  /\ qualified' = TRUE
  /\ UNCHANGED <<rev25, rev26, records26, carryoverRef26,
                  historyCommittedRecords26, staged25, staged26,
                  observedRev25, observedRev26, stagedRecords26,
                  stagedCarryoverRef, running, acked>>

(***************************************************************************
  Step 4A: Publish Candidates (Generation check passes or disabled).
  In Safe model (CheckGenerationOnPublish=TRUE), succeeds ONLY IF
  the observed generations match current authoritative revisions.
  In Broken model (CheckGenerationOnPublish=FALSE), blindly publishes,
  overwriting current 2026 with stale stagedRecords26.
***************************************************************************)
PublishCandidate ==
  /\ running
  /\ phase = "qualified"
  /\ qualified /\ staged25 /\ staged26
  /\ IF CheckGenerationOnPublish
     THEN observedRev25 = rev25 /\ observedRev26 = rev26
     ELSE TRUE
  /\ rev25' = 2
  /\ rev26' = IF AtomicPublish THEN rev26 + 1 ELSE rev26
  /\ records26' = IF AtomicPublish THEN stagedRecords26 ELSE records26
  /\ carryoverRef26' = IF AtomicPublish THEN stagedCarryoverRef ELSE carryoverRef26
  /\ phase' = IF AtomicPublish THEN "published" ELSE "half_published"
  /\ staged25' = FALSE
  /\ staged26' = FALSE
  /\ qualified' = FALSE
  /\ UNCHANGED <<historyCommittedRecords26, observedRev25, observedRev26,
                  stagedRecords26, stagedCarryoverRef, running, acked>>

(***************************************************************************
  Step 4B: Reject Stale Candidates (Safe OCC behavior).
  When observed generations no longer match current authoritative state,
  refuse publication and preserve current authoritative data untouched.
***************************************************************************)
RejectStaleCandidate ==
  /\ running
  /\ phase = "qualified"
  /\ qualified /\ staged25 /\ staged26
  /\ CheckGenerationOnPublish
  /\ (observedRev25 # rev25 \/ observedRev26 # rev26)
  /\ phase' = "rejected"
  /\ staged25' = FALSE
  /\ staged26' = FALSE
  /\ qualified' = FALSE
  /\ UNCHANGED <<rev25, rev26, records26, carryoverRef26,
                  historyCommittedRecords26, observedRev25, observedRev26,
                  stagedRecords26, stagedCarryoverRef, running, acked>>

(***************************************************************************
  Step 4C: Finish Broken Non-Atomic Publish (for negative control).
***************************************************************************)
FinishBrokenPublish ==
  /\ ~AtomicPublish
  /\ running
  /\ phase = "half_published"
  /\ rev26' = rev26 + 1
  /\ records26' = stagedRecords26
  /\ carryoverRef26' = stagedCarryoverRef
  /\ phase' = "published"
  /\ UNCHANGED <<rev25, historyCommittedRecords26, staged25, staged26,
                  observedRev25, observedRev26, stagedRecords26,
                  stagedCarryoverRef, qualified, running, acked>>

(***************************************************************************
  Step 5: Client Acknowledgment.
***************************************************************************)
Acknowledge ==
  /\ running
  /\ phase = "published"
  /\ carryoverRef26 = rev25
  /\ phase' = "done"
  /\ acked' = TRUE
  /\ UNCHANGED <<rev25, rev26, records26, carryoverRef26,
                  historyCommittedRecords26, staged25, staged26,
                  observedRev25, observedRev26, stagedRecords26,
                  stagedCarryoverRef, qualified, running>>

(***************************************************************************
  Crash & Recovery:
  In-flight volatile candidate memory is wiped upon crash recovery.
  If authoritative state became inconsistent before crash, recover into unavailable.
***************************************************************************)
Crash ==
  /\ running
  /\ running' = FALSE
  /\ UNCHANGED <<rev25, rev26, records26, carryoverRef26,
                  historyCommittedRecords26, staged25, staged26,
                  observedRev25, observedRev26, stagedRecords26,
                  stagedCarryoverRef, qualified, phase, acked>>

Recover ==
  /\ ~running
  /\ running' = TRUE
  /\ staged25' = FALSE
  /\ staged26' = FALSE
  /\ qualified' = FALSE
  /\ observedRev25' = 0
  /\ observedRev26' = 0
  /\ stagedRecords26' = {}
  /\ stagedCarryoverRef' = 0
  /\ phase' = IF carryoverRef26 # rev25 THEN "unavailable"
               ELSE IF phase \in {"published", "done"} THEN phase
               ELSE "idle"
  /\ UNCHANGED <<rev25, rev26, records26, carryoverRef26,
                  historyCommittedRecords26, acked>>

Next ==
  \/ Append2026
  \/ BeginAmend2025
  \/ Stage2026Carryover
  \/ ValidateCandidate
  \/ PublishCandidate
  \/ RejectStaleCandidate
  \/ FinishBrokenPublish
  \/ Acknowledge
  \/ Crash
  \/ Recover

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(***************************************************************************
  INVARIANTS
***************************************************************************)

TypeOK ==
  /\ rev25 \in Nat
  /\ rev26 \in Nat
  /\ records26 \subseteq RecordID
  /\ carryoverRef26 \in Nat
  /\ historyCommittedRecords26 \subseteq RecordID
  /\ staged25 \in BOOLEAN
  /\ staged26 \in BOOLEAN
  /\ observedRev25 \in Nat
  /\ observedRev26 \in Nat
  /\ stagedRecords26 \subseteq RecordID
  /\ stagedCarryoverRef \in Nat
  /\ qualified \in BOOLEAN
  /\ phase \in Phases
  /\ running \in BOOLEAN
  /\ acked \in BOOLEAN

\* Invariant 1: Carryover consistency (published 2026 carryover matches published 2025)
ConsistentCarryover ==
  (phase \in {"published", "done"} \/ acked) => (carryoverRef26 = rev25)

\* Invariant 2: Current year records are preserved (NO UNINTENTIONAL RECORD LOSS)
PreserveCurrentYear ==
  historyCommittedRecords26 \subseteq records26

\* Invariant 3: Revision 1 of 2025 cannot be silently overwritten without qualified carryover
ClosedRevisionImmutable ==
  (rev25 = 1) \/ (rev25 = 2 /\ carryoverRef26 = 2)

\* Invariant 4: New publication is fully qualified
NewSelectionQualified ==
  acked => (rev25 = 2 /\ carryoverRef26 = 2)

\* Invariant 5: Fail-closed on recovery
FailClosedRecovery ==
  /\ (phase = "unavailable") => ~acked
  /\ (phase \in {"published", "done"} \/ acked) => (phase # "unavailable" /\ carryoverRef26 = rev25)

=============================================================================
