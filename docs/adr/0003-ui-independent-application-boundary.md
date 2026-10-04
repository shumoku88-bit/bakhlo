# ADR 0003 — Inward application boundaries, not a UI

Status: accepted direction; current contracts/evidence belong to architecture,
interfaces and VERIFICATION, not this historical decision.

## Decision and reason

Application owns typed semantic answers/refusals; Presentation formats them without
revalidation or aggregate reconstruction. CLI owns syntax, help and process responses;
the shell owns actual effects. Domain/Application never depend on UI/transport/filesystem.

```text
CLI -> Presentation -> Application -> Domain
 |---------------------->|------------>|
```

This prevents a second client from repeating accounting meaning or reusing argv as an
application API. Existing operations take explicit immutable inputs: no dummy State,
session, generic view-model/command bus or hidden now. Materialized indexes are not
canonical facts or speculative caches.

At this decision no TUI/web/dashboard/components or toolkit was authorized. Subsequent
[client direction](../ARCHITECTURE.md#client-access-direction) records Notty preference and
optional Bonsai evaluation, not toolkit adoption. OxCaml/anticipatory load/navigation state
remain outside scope. Base + Zarith and the selected test dependencies remain the budget.
Introduce effects/state only for real operations; source consistency, Actual/Scheduled,
uncertainty and independent support remain semantic boundaries.

## Qualification / revisit

Typed clients, public abstraction/specimens, CLI integration and clean engine-only
builds test the boundary. Compiler failure must be the relevant diagnostic, not an
unrelated missing artifact. No stable prototype API or golden-text compatibility is
required; the user explicitly authorizes removing obsolete routes before release.

A future second frontend or storage/write operation earns its own boundary/qualification.
Measure named workloads before cache/incremental work. UI/toolkit/public protocol and
operational guarantees do not follow from this decision.
