(in-package #:cl-koza-ii.tests)

(def-suite cl-koza-ii-tests
  :description "Test suite for cl-koza-ii")

(defun run-tests ()
  (fiveam:run! 'cl-koza-ii-tests))
