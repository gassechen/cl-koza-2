(in-package #:cl-koza-ii.tests)

(in-suite cl-koza-ii-tests)

(test maximum-generations-zero-known-issue
  (skip "KNOWN ISSUE: run-genetic-programming-system accepts maximum-generations 0, but report-on-run signals an error because *best-of-run-individual* remains NIL. Expected: reject 0 at the API boundary or handle it gracefully."))

(test random-integer-zero-known-issue
  (skip "KNOWN ISSUE: (random-integer 0) returns 0 instead of signaling an error, although the documented range 0..N-1 is empty for N=0."))
