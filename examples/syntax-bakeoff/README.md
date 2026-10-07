# Minimal canonical syntax bake-off

This directory contains **two hand-authored synthetic spellings of the same retained evidence** from
[`sexp-v1-candidate/01-retained-evidence.sexp`](../sexp-v1-candidate/01-retained-evidence.sexp),
plus one bounded S-expression health check that adds Scheduled and Attention evidence.

They are comparison artifacts only. No parser, writer, DTO, migration, dependency, storage path or
canonical-format decision is introduced here. No real/private household data is used.

| Candidate | Intent |
| --- | --- |
| [01-minimal.sexp](01-minimal.sexp) | Keep S-expression structure, but remove avoidable family/wrapper nesting and allow independent top-level facts |
| [01-minimal.journal](01-minimal.journal) | Keep the same evidence in a shallow journal: a column-0 record followed by indented member lines, with no `end` markers |
| [02-minimal-sexp-mixed-families.sexp](02-minimal-sexp-mixed-families.sexp) | Start from the minimal S-expression and add one Scheduled occurrence plus one Attention item without adding surface-syntax machinery |

## Shared semantic obligations

The first two candidates deliberately retain the same important distinctions as the source fixture:

- superseded Event `e1` remains present and is explicitly corrected by `e2`;
- occurrence revision is separate from Event correction;
- relation `r1` continues to identify the original `(e1, cash)` Effect;
- discharge is explicit and is not rewritten as an Event correction;
- observations and presence carry their own reflected-root cuts;
- empty, not-supplied, zero, empty text and unknown exact quantity remain distinct;
- individual Effect occurrences and keys remain visible, including the net-zero pair;
- Measure and decimal scale remain explicit and quantities remain signed decimal quanta;
- new-write policy is not inferred from historical use;
- request-origin remains tied to the Event originally created by that request;
- collection supply state is explicit rather than inferred from missing lines;
- declaration order must not decide currentness or repair dangling references.

The expected conditional answers and limitations are still those documented by the
[parent S-expression fixture](../sexp-v1-candidate/README.md). Neither candidate stores those
derived answers.

## Candidate A: minimal S-expression

The S-expression candidate tests how far the existing shape can be simplified without making
meaning positional or implicit:

- `(bakhlo 1)` is a small format marker.
- Independent facts are independent top-level forms rather than children of one giant root.
- One `(collections ...)` declaration owns provided / empty / not-supplied collection state.
- Facts keep named fields where removing names would make roles ambiguous.
- Empty reflected roots use the natural empty list form `(reflected-roots)`.
- No OCaml internal type layout or `[@@deriving sexp]` output is implied.

This intentionally keeps some nested variants such as `(description (text ...))`,
`(key (named ...))` and `(creditor (external ...))` because collapsing them further can make
distinct variants depend on reserved strings or positional interpretation.

## Candidate B: minimal evidence journal

The journal candidate tests a deliberately shallow grammar:

```text
top-level-record [arguments...]
  member [arguments...]
  member [arguments...]

next-top-level-record
  ...
```

Provisional comparison rules:

- a non-indented non-comment line starts a top-level record;
- following indented non-comment lines belong to that record until the next top-level record;
- indentation width is presentation only; the candidate does not require nested indentation levels;
- blank lines are presentation only;
- there are no `end` / `end-event` tokens;
- record-specific connector syntax such as `correct-event X to Y` is avoided;
- quoted strings, escapes, numeric lexical rules and diagnostics are intentionally **not yet specified**;
- schema decoding, not the surface parser, decides what member names and argument shapes are valid.

The journal therefore aims to keep the parser grammar small even when the household schema grows.
Whether that remains true for Scheduled, Attention, settlement and other evidence families is still
an open question.

## S-expression mixed-family health check

[02-minimal-sexp-mixed-families.sexp](02-minimal-sexp-mixed-families.sexp) asks one narrow question:
does the minimal S-expression remain readable when two semantically different household families
are actually supplied?

It adds only synthetic evidence:

- one `scheduled-occurrence` with a stable Scheduled identity, explicit scheduled day and one
  balanced single-Measure movement;
- one `attention-item` with opaque human context and explicit `undetermined` due meaning.

The current LOAM meanings being preserved for this review are important:

- Scheduled is expected evidence, not an Actual Event;
- Scheduled terminal meaning is separate evidence: completion targets Actual, replacement targets a
  successor Scheduled identity, retirement has no target;
- Attention `due on`, `no due date` and `due undetermined` are distinct;
- Attention closure is separate evidence and distinguishes resolved from dropped.

Therefore the health-check fixture does **not** let missing terminal or closure rows mean empty.
For this one comparison, the coarse `scheduled` / `attention` collection placeholders are refined
into logical `scheduled-occurrences`, `scheduled-terminals`, `attention-items` and
`attention-closures` states. The terminal and closure collections are explicitly empty.

That logical refinement is not a decision to split physical persistence files or freeze these
collection names. It only prevents the syntax experiment from buying simplicity with an implicit
semantic default.

The key result to inspect is structural: no new lexical feature, delimiter, indentation rule or
record-specific mini-language was needed. The new meanings use the same Atom/List surface as the
existing facts. Whether the chosen schema names are the best permanent names remains open.

## Stop rules for further shortening

A spelling is **too compressed** if shortening it requires any of the following:

1. deciding meaning from record order, latest date or file position;
2. treating a missing collection/field as empty, zero or not-supplied;
3. collapsing distinct identity roles or normalizing identifiers;
4. dropping Effect occurrence/key identity;
5. merging correction, date revision, reversal, discharge or request provenance;
6. making an important role understandable only by positional convention;
7. adding a growing set of record-specific syntax tricks to keep the text short.

This is the semantic compression limit: fewer characters are not an improvement once one of these
costs appears.

## Human review questions

Review these candidates together with the original S-expression and the uniform-`end`
counterexample. In particular:

- Which one is easiest to scan after six months away from the project?
- Can a human locate an Event, its correction, an observation cut and a provenance link quickly?
- Is a one-line Effect clearer than a nested Effect, or too dense?
- Does the collection-state declaration clarify unknown/empty state or become a header tax?
- Which candidate makes accidental structural edits easier to notice in a Git diff?
- Does either form already tempt us to add shorthand or implicit defaults?
- Can a new evidence family be added without changing the surface grammar?
- In the mixed-family S-expression, do Scheduled and Attention still read as distinct meanings
  rather than being forced into Event-shaped records?

Do **not** choose based on imagined speed, binary size or migration cost here; none has been measured.
The next step after human review should remain bounded. A parser proof-of-concept is only justified
if the syntax comparison leaves a real question that static fixtures cannot answer.
