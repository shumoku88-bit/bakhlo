The cutover-day import reads a LOAM directory and creates a new Bakhlo
directory. Synthetic LOAM household only.

  $ mkdir -p loam/config b
  $ body() { printf "$2" > "b/$1"; }
  $ body Actual 'LOAM-NORMALIZED-ACTUAL\t4\nTX\ta\t2026-10-03\tNODESC\nEFFECT\twallet\tjpy\t-10\nEFFECT\tfood\tjpy\t10\nENDTX\n'
  $ body Scheduled 'LOAM-SCHEDULED-LIFECYCLE\t1\nBEGIN\tScheduled\nLOAM-SCHEDULED-MEMORY\t1\nSCHEDULED\tp\t2026-11-01\tjpy\nCHANGE\twallet\t-5\nCHANGE\tfood\t5\nEND\tScheduled\nBEGIN\tCompletion\nLOAM-SCHEDULED-COMPLETION-MEMORY\t1\nEND\tCompletion\nBEGIN\tRetirement\nLOAM-SCHEDULED-RETIREMENT-MEMORY\t1\nEND\tRetirement\nBEGIN\tReplacement\nLOAM-SCHEDULED-REPLACEMENT-MEMORY\t1\nEND\tReplacement\n'
  $ body ZeroOrigin 'LOAM-ZERO-ORIGIN-COVERAGE\t1\nCOORDINATE\tfood\tjpy\n'
  $ body OpeningSupport 'LOAM-OPENING-SUPPORT\t1\n'
  $ body CurrentQuantityAnchor 'LOAM-CURRENT-QUANTITY-ANCHOR\t2\nGROUP\nASSERT\twallet\tjpy\t1000\nEND\n'
  $ body CurrentQuantityPresence 'LOAM-CURRENT-QUANTITY-PRESENCE\t1\n'
  $ body LocusAdmission 'LOAM-LOCUS-ADMISSION-VOCABULARY\t1\nLOCUS\twallet\nLOCUS\tfood\n'
  $ body AccountingRole 'LOAM-ACCOUNTING-ROLE-MAP\t1\nROLE\twallet\tASSET\nROLE\tfood\tEXPENSE\n'
  $ body Attention 'LOAM-ATTENTION-MEMORY\t1\nITEM\tt1\tNO_DUE_DATE\t-\tcheck\n'
  $ household() {
  >   printf 'LOAM-HOUSEHOLD-IMAGE\t2\n'
  >   for s in "$@"; do printf 'SECTION\t%s\t%d\n' "$s" "$(wc -c < "b/$s" | tr -d ' ')"; cat "b/$s"; done
  > }
  $ household Actual Scheduled ZeroOrigin OpeningSupport CurrentQuantityAnchor CurrentQuantityPresence LocusAdmission AccountingRole Attention > loam/household.loam
  $ printf 'jpy\t0\n' > loam/config/measure-presentation.tsv
  $ printf 'wallet\tjpy\n' > loam/config/daily-pace.tsv
  $ printf 'budget\n' > loam/config/purpose-catalog.tsv
  $ printf 'standalone\n' > loam/config/accounting-roles.tsv
  $ : > loam/config/daily-pace.tsv.loam-writer-lock
  $ ls -lR loam | cksum > before

  $ import() { import_loam "$@"; }
  $ import loam new rev-1
  PASS: imported 1 entries, 1 open plans, Attention into $TESTCASE_ROOT/new. LOAM was only read.

Budget configuration, locks and the standalone roles file stay in LOAM; the
roles and Attention come from the household.

  $ (cd new && find . -type f | sort)
  ./LOAM-RECORD.md
  ./attention.loam
  ./book.sexp
  ./config/accounting-roles.tsv
  ./config/daily-pace.tsv
  ./config/measure-presentation.tsv
  $ cat new/config/accounting-roles.tsv
  LOAM-ACCOUNTING-ROLE-MAP	1
  ROLE	wallet	ASSET
  ROLE	food	EXPENSE
  $ grep -c 'rev-1' new/LOAM-RECORD.md
  1
  $ ls -lR loam | cksum | cmp - before

An existing destination is never touched, and a refused import creates nothing.

  $ import loam new rev-1
  Import refused: destination-exists. LOAM untouched; no destination created.
  [2]
  $ household Actual Scheduled ZeroOrigin OpeningSupport CurrentQuantityAnchor CurrentQuantityPresence LocusAdmission > loam/household.loam
  $ import loam other rev-1
  Import refused: accounting-role-authority-missing. LOAM untouched; no destination created.
  [2]
  $ ls | grep -c other
  0
  [1]
