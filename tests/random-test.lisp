(in-package #:cl-koza-ii.tests)

(in-suite cl-koza-ii-tests)

(defun reference-park-miller-sequence (seed count)
  (let ((state seed)
        (modulus 2147483647)
        (result nil))
    (loop repeat count
          do (setf state (mod (* 16807 state) modulus))
             (push (coerce (/ state modulus) 'double-float) result))
    (nreverse result)))

(test park-miller-reference-sequence
  (dolist (seed '(1 2 12345 2147483646))
    (let ((expected (reference-park-miller-sequence seed 10)))
      (with-seed (seed)
        (dotimes (index 10)
          (is (= (park-miller-randomizer) (nth index expected))))))))

(test park-miller-output-range
  (with-seed (1)
    (loop repeat 1000
          do (let ((value (park-miller-randomizer)))
               (is (and (< 0.0d0 value) (<= value 1.0d0)))))))

(test park-miller-zero-seed
  (let ((*seed* 0.0d0))
    (signals error (park-miller-randomizer))))

(test random-floating-point-number-range
  (with-seed (1)
    (dolist (limit '(1.0 10.0 100.0))
      (loop repeat 200
            do (let ((value (random-floating-point-number limit)))
                 (is (and (<= 0.0 value) (< value limit))))))))

(test random-floating-point-number-reproducible
  (let ((first (with-seed (42)
                 (loop repeat 20
                       collect (random-floating-point-number 10.0))))
        (second (with-seed (42)
                  (loop repeat 20
                        collect (random-floating-point-number 10.0)))))
    (is (equal first second))))

(test random-integer-range
  (with-seed (7)
    (dolist (limit '(1 2 7 100))
      (loop repeat 200
            do (let ((value (random-integer limit)))
                 (is (and (integerp value)
                          (<= 0 value)
                          (< value limit))))))))

(test random-integer-coverage
  (with-seed (3)
    (let ((seen (make-hash-table)))
      (loop repeat 1000
            do (setf (gethash (random-integer 7) seen) t))
      (is (= 7 (hash-table-count seen))))))

(test random-integer-reproducible
  (let ((first (with-seed (99)
                 (loop repeat 20 collect (random-integer 13))))
        (second (with-seed (99)
                  (loop repeat 20 collect (random-integer 13)))))
    (is (equal first second))))
