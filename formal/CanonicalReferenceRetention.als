module CanonicalReferenceRetention

// A deliberately small structural slice, NOT a new storage schema:
// one logical entry, versioned source rows, named postings and one relation.
// Quantity fields are bounded magnitudes, not signed household accounting.
sig EntryId {}
sig Key {}
sig Version { entryId: one EntryId }
sig Posting {
  owner: one Version,
  key: one Key,
  magnitude: one Int
}
sig Relation { source: one Posting, demand: one Int }
one sig Book { current: EntryId -> one Version }

fact AdmittedSourceSlice {
  all id: EntryId | Book.current[id].entryId = id
  all v: Version | #owner.v = 2
  all disj p, q: Posting | p.owner = q.owner implies p.key != q.key
  all p: Posting | p.magnitude > 0 and p.magnitude <= 10
  // A two-posting ordinary movement can give these equal magnitudes opposite signs.
  // Coordinates/signs and full Event admission are still outside this slice.
  all v: Version | all p, q: owner.v | p.magnitude = q.magnitude
  all r: Relation | r.demand > 0 and r.demand <= r.source.magnitude
}

fun currentVersions: set Version { EntryId.(Book.current) }
fun referencedVersions: set Version { Relation.source.owner }
fun keptVersions: set Version { currentVersions + referencedVersions }

// Keeping only the named source posting omits its owner's other posting.
fun directPostings: set Posting { owner.currentVersions + Relation.source }
// Retain complete source rows as required by this model's admission premise.
fun completePostings: set Posting { owner.keptVersions }

fun retargeted[r: Relation]: set Posting {
  { p: Posting | p.owner = Book.current[r.source.owner.entryId] and p.key = r.source.key }
}

pred changedMagnitudeWitness {
  some r: Relation | {
    r.source.owner not in currentVersions
    r.source.magnitude = 10
    r.demand = 8
    one retargeted[r]
    retargeted[r].magnitude = 6
  }
}

pred partialOriginalRowWitness {
  some r: Relation | {
    r.source.owner not in currentVersions
    some owner.(r.source.owner) - directPostings
  }
}

pred pruneUnreferencedVersion {
  some r: Relation | r.source.owner not in currentVersions
  some Version - keptVersions
}

pred allRowsNeeded {
  some r: Relation | r.source.owner not in currentVersions
  keptVersions = Version
}

assert RetargetingPreservesRelationBound {
  all r: Relation | one retargeted[r] and r.demand <= retargeted[r].magnitude
}

assert DirectReferencedPostingIsEnough {
  all v: keptVersions | owner.v in directPostings
}

assert CompleteRowsPreserveThisSlice {
  all r: Relation | {
    r.source in completePostings
    r.source.owner in keptVersions
    r.demand > 0 and r.demand <= r.source.magnitude
  }
  all v: keptVersions | owner.v in completePostings
}

// All integer arithmetic stays within 5-bit range: magnitudes <= 10, row count 2.
// SAT witnesses also ensure the successful check is not merely inconsistent input.
run changedMagnitudeWitness for 6 but exactly 1 EntryId, exactly 2 Key,
  exactly 2 Version, exactly 4 Posting, exactly 1 Relation, 5 Int
run partialOriginalRowWitness for 6 but exactly 1 EntryId, exactly 2 Key,
  exactly 2 Version, exactly 4 Posting, exactly 1 Relation, 5 Int
run pruneUnreferencedVersion for 6 but exactly 1 EntryId, exactly 2 Key,
  exactly 3 Version, exactly 6 Posting, exactly 1 Relation, 5 Int
run allRowsNeeded for 6 but exactly 1 EntryId, exactly 2 Key,
  exactly 2 Version, exactly 4 Posting, exactly 1 Relation, 5 Int
check RetargetingPreservesRelationBound for 6 but exactly 1 EntryId, exactly 2 Key,
  exactly 3 Version, exactly 6 Posting, exactly 1 Relation, 5 Int
check DirectReferencedPostingIsEnough for 6 but exactly 1 EntryId, exactly 2 Key,
  exactly 3 Version, exactly 6 Posting, exactly 1 Relation, 5 Int
check CompleteRowsPreserveThisSlice for 6 but exactly 1 EntryId, exactly 2 Key,
  exactly 3 Version, exactly 6 Posting, exactly 1 Relation, 5 Int
