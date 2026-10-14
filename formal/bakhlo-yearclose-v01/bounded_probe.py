"""Independent finite Python shadow check, NOT TLC and NOT a TLA+ interpreter.

Uses small explicit states and transitions to sanity-check the *intended*
abstract publication protocol. Do not interpret a pass as validation that the
TLA+ text parses or that any filesystem backend is durable.
"""
from collections import deque
from dataclasses import dataclass, replace


@dataclass(frozen=True)
class State:
    year25: str = "A"
    year26: str = "A"
    staged25: bool = False
    staged26: bool = False
    qualified: bool = False
    phase: str = "idle"
    running: bool = True
    acked: bool = False
    plan_payments: int = 0
    existing2026: int = 1
    old25_retained: bool = True


def transitions(s, atomic):
    out = []
    if s.running and s.phase == "idle" and s.year25 == "A":
        out.append(("BeginAmend", replace(s, phase="draft", staged25=False,
                                          staged26=False, qualified=False)))
    if s.running and s.phase == "draft":
        out.append(("Stage2025", replace(s, phase="staged25", staged25=True)))
    if s.running and s.phase == "staged25" and s.staged25:
        out.append(("Stage2026", replace(s, phase="staged26", staged26=True)))
    if s.running and s.phase == "staged26" and s.staged25 and s.staged26:
        out.append(("ValidateCandidate", replace(s, phase="qualified", qualified=True)))
    if s.running and s.phase == "qualified" and s.qualified and s.staged25 and s.staged26:
        out.append(("SelectCandidate", replace(s, year25="B", year26="B" if atomic else s.year26,
                                               phase="published" if atomic else "half")))
    if not atomic and s.running and s.phase == "half":
        out.append(("FinishBrokenPublish", replace(s, year26="B", phase="published")))
    if s.running and s.phase == "published" and s.year25 == s.year26 == "B":
        out.append(("Acknowledge", replace(s, phase="done", acked=True)))
    if s.running and s.phase in {"idle", "published", "done"} and s.plan_payments == 0:
        out.append(("PayOnce", replace(s, plan_payments=1)))
    if s.running:
        out.append(("Crash", replace(s, running=False)))
    else:
        mode = ("unavailable" if s.year25 != s.year26 else
                "published" if s.year25 == "B" else "idle")
        out.append(("Recover", replace(s, running=True, phase=mode)))
    return out


def invariants(s):
    return {
        "ConsistentSelection": s.year25 == s.year26,
        "NewSelectionQualified": (s.year25 == s.year26 == "A") or (
            s.qualified and s.staged25 and s.staged26),
        "AckIsForNewPair": not s.acked or s.year25 == s.year26 == "B",
        "PreserveExisting2026": s.existing2026 == 1,
        "RetainOldFinal": s.old25_retained,
        "UniquePayment": 0 <= s.plan_payments <= 1,
    }


def check(atomic):
    start = State()
    queue = deque([(start, [])])
    seen = {start}
    while queue:
        state, trace = queue.popleft()
        failures = [k for k, good in invariants(state).items() if not good]
        if failures:
            return len(seen), failures, trace, state
        for act, succ in transitions(state, atomic):
            if succ not in seen:
                seen.add(succ)
                queue.append((succ, trace + [act]))
    return len(seen), [], None, None


if __name__ == "__main__":
    safe_count, safe_fail, _, _ = check(True)
    broken_count, broken_fail, broken_trace, broken_state = check(False)
    print(f"SAFE shadow model: visited={safe_count}, failures={safe_fail}")
    print(f"BROKEN shadow model: visited={broken_count}, failures={broken_fail}")
    print("BROKEN shortest trace: " + " -> ".join(["Init"] + broken_trace))
    print(f"BROKEN pair at violation: {broken_state.year25}+{broken_state.year26}")
    assert safe_fail == [], f"unexpected SAFE-model failure: {safe_fail}"
    assert "ConsistentSelection" in broken_fail, "negative control did not find mismatch"

