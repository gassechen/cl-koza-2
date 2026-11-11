(in-package #:cl-koza-2.functions)

(defun % (numerator denominator)
  "The Protected Division Function."
  (if (= 0 denominator)
      1
      (/ numerator denominator)))
