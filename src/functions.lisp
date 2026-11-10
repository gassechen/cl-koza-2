(defpackage #:gp.functions
  (:use #:cl)
  (:export #:%
   ))

(in-package #:gp.functions)

(defun % (numerator denominator)
  "The Protected Division Function"
  (values (if (= 0 denominator)
              1
              (/ numerator denominator))))
