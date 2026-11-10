(defpackage #:gp.random
  (:use #:cl)
  (:export
   #:*seed*
   #:random-integer
   #:random-floating-point-number
   ))

(in-package #:gp.random)

(defvar *seed* :unbound
  "The seed for the Park-Miller congruential randomizer.")

(defun park-miller-randomizer ()
  "The Park-Miller multiplicative congruential randomizer
   (CACM, October 88, Page 1195).  Creates pseudo random floating
   point numbers in the range 0.0 < x <= 1.0.  The seed value
   for this randomizer is called *seed*, so you should
   record/set this if you want to make your runs reproducible."
  (assert (not (zerop *seed*)) () "*seed* cannot be zero.")

  (let ((multiplier (float (expt 7 5) 1.0d0))
        (modulus (float (- (expt 2 31) 1) 1.0d0)))
    (let ((temp (* multiplier *seed*)))
      (setf *seed* (mod temp modulus))
      ;;Produces floating-point number in the range
      ;;  0.0 < x <= 1.0
      (/ *seed* modulus))))

(defun random-floating-point-number (n)
  "Returns a pseudo random floating-point number
   in range 0.0 <= number < n"
  ;;(declare (type double-float n))
  (let ((random-number (park-miller-randomizer)))
    ;; We subtract the randomly generated number from 1.0
    ;; before scaling so that we end up in the range
    ;; 0.0 <= x < 1.0, not 0.0 < x <= 1.0
    (* n (- 1.0d0 random-number))))

(defun random-integer (n)
  "Returns a pseudo-random integer in the range 0 ---> n-1."
  (let ((random-number (random-floating-point-number 1.0)))
    (floor (* n random-number))))
