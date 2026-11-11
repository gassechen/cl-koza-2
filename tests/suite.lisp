(in-package #:cl-koza-2.tests)

(def-suite cl-koza-2-tests
  :description "Test suite for cl-koza-2")

(defun run-tests ()
  (fiveam:run! 'cl-koza-2-tests))
