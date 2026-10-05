import Std

/-!
Optional specification laws only; no upstream imports or OCaml refinement.
Checked with Lean 4.33.1. Ordinary product build/test/release does not use this file.
Rows are supplied root/terminal associations, not raw graphs. `reflected` is the
root predicate (finite exact-ID membership in OCaml); terminal changes must leave
root IDs intact. No claim here that a graph edit preserves those assumptions.
-/

set_option autoImplicit false

namespace Bakhlo.RootCutSpec

variable {Root Terminal Updated : Type}

def exclude (reflected : Root → Bool) (rows : List (Root × Terminal)) :
    List (Root × Terminal) :=
  rows.filter fun row => !(reflected row.1)

def updateTerminals (change : Terminal → Updated) (rows : List (Root × Terminal)) :
    List (Root × Updated) :=
  rows.map fun row => (row.1, change row.2)

/-- Arbitrary terminal-only changes cannot change reflected-root selection. -/
theorem exclusion_commutes_with_terminal_update
    (reflected : Root → Bool) (change : Terminal → Updated)
    (rows : List (Root × Terminal)) :
    exclude reflected (updateTerminals change rows) =
      updateTerminals change (exclude reflected rows) := by
  induction rows with
  | nil => rfl
  | cons row rest ih =>
      rcases row with ⟨root, terminal⟩
      cases h : reflected root <;> simp [exclude, updateTerminals, h] at * <;> exact ih

/-- An explicitly empty root predicate preserves every row and its order. -/
theorem empty_cut (rows : List (Root × Terminal)) :
    exclude (fun _ => false) rows = rows := by
  simp [exclude]

/-- Successive root exclusions equal union, independent of terminal values. -/
theorem composition (first second : Root → Bool) (rows : List (Root × Terminal)) :
    exclude second (exclude first rows) =
      exclude (fun root => first root || second root) rows := by
  induction rows with
  | nil => rfl
  | cons row rest ih =>
      rcases row with ⟨root, terminal⟩
      cases h₁ : first root <;> cases h₂ : second root <;>
        simp [exclude, h₁, h₂] at * <;> exact ih

/-- A coordinate's signed contribution, skipping whole reflected roots. This
    assumes supplied rows/contributions, not graph correctness or unit conversion. -/
def quantityDelta (reflected : Root → Bool) (contribution : Terminal → Int) :
    List (Root × Terminal) → Int
  | [] => 0
  | row :: rest =>
      if reflected row.1 then quantityDelta reflected contribution rest
      else contribution row.2 + quantityDelta reflected contribution rest

def supportedQuantity (asserted : Option Int) (delta : Int) : Option Int :=
  asserted.map fun quantity => quantity + delta

/-- No amount of activity or net-zero arithmetic supplies an absent assertion. -/
theorem absent_assertion_stays_unsupported (delta : Int) :
    supportedQuantity none delta = none := by
  rfl

/-- Exact assertion translation changes the supported result by the same amount. -/
theorem assertion_translation (asserted delta shift : Int) :
    supportedQuantity (some (asserted + shift)) delta =
      (supportedQuantity (some asserted) delta).map (fun result => result + shift) := by
  simp [supportedQuantity, Int.add_comm, Int.add_left_comm]

/-- Changes to reflected terminals cannot affect a coordinate's delta, provided
    root IDs are fixed and all unreflected contributions are unchanged. -/
theorem reflected_contribution_noninterference
    (reflected : Root → Bool) (before : Terminal → Int) (after : Updated → Int)
    (change : Terminal → Updated) (rows : List (Root × Terminal)) :
    (∀ row ∈ rows, reflected row.1 = false → after (change row.2) = before row.2) →
    quantityDelta reflected after (updateTerminals change rows) =
      quantityDelta reflected before rows := by
  induction rows with
  | nil => intro _; rfl
  | cons row rest ih =>
      intro agreement
      have tailAgreement :
          ∀ r ∈ rest, reflected r.1 = false → after (change r.2) = before r.2 := by
        intro r member unreflected
        exact agreement r (List.mem_cons_of_mem row member) unreflected
      have tailEqual := ih tailAgreement
      simp only [updateTerminals] at tailEqual
      cases h : reflected row.1 with
      | false =>
          have headEqual := agreement row (by simp) h
          simp [quantityDelta, updateTerminals, h, tailEqual, headEqual]
      | true => simp [quantityDelta, updateTerminals, h, tailEqual]

variable {Coordinate Premise : Type}

/-- Lookup-level explicit re-observation. Premise includes BOTH original assertion
    and its reflected cut; it is not only a numerical result or stable group ID. -/
def reobserved (old incoming : Coordinate → Option Premise) (coordinate : Coordinate) :
    Option Premise :=
  match incoming coordinate with
  | none => old coordinate
  | some premise => some premise

/-- A deliberately supplied new observation wins only at its named coordinate. -/
theorem incoming_premise_wins
    (old incoming : Coordinate → Option Premise) (coordinate : Coordinate) (premise : Premise)
    (observed : incoming coordinate = some premise) :
    reobserved old incoming coordinate = some premise := by
  simp [reobserved, observed]

/-- Unrelated assertion AND cut survive, not merely the same computed amount. -/
theorem unrelated_premise_preserved
    (old incoming : Coordinate → Option Premise) (coordinate : Coordinate)
    (unobserved : incoming coordinate = none) :
    reobserved old incoming coordinate = old coordinate := by
  simp [reobserved, unobserved]

/-- Re-observing the same premises twice is lookup-idempotent, not publisher retry. -/
theorem reobservation_lookup_idempotent (old incoming : Coordinate → Option Premise) :
    reobserved (reobserved old incoming) incoming = reobserved old incoming := by
  funext coordinate
  cases h : incoming coordinate <;> simp [reobserved, h]

#print axioms incoming_premise_wins
#print axioms unrelated_premise_preserved
#print axioms reobservation_lookup_idempotent
#print axioms absent_assertion_stays_unsupported
#print axioms assertion_translation
#print axioms reflected_contribution_noninterference
#print axioms exclusion_commutes_with_terminal_update
#print axioms empty_cut
#print axioms composition

end Bakhlo.RootCutSpec
