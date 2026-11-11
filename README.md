# cl-koza-2

Common Lisp implementation of John Koza's genetic programming system.

This repository contains the **`cl-koza-2`** system, a Common Lisp
implementation of the Koza II kernel with automatically defined functions
(ADFs), based on *Genetic Programming II*.

## cl-koza-2

### Status

Phases 1–4 are complete:

- ADF kernel with an arbitrary architecture of
  **ADF0 … ADF(N-1) + RPB** (result-producing branch), where `N >= 0`.
  With `N = 0`, a program consists only of the result-producing branch.
- The legacy two-ADF program API and `run-genetic-programming-system`
  remain supported as compatibility layers.
- Generic tree interpreter with explicit terminal environments and no
  dependency on dynamically bound ADF variables.
- Examples: **even-5-parity** with two ADFs, **even-5-parity-3-adfs**
  with three hierarchical ADFs, and **even-5-parity-n-adfs** with a
  configurable number of ADFs.
- Parallel fitness evaluation and initial-population generation through
  `lparallel`, with deterministic results independent of worker count.
- FiveAM test suite integrated with ASDF.

### Requirements

- A Common Lisp implementation (tested with SBCL).
- ASDF.
- Quicklisp for `lparallel`, `cl-cpus`, and `fiveam` (the latter for the
  test suite).

### Installation

Place the repository in a directory known to ASDF, for example:

```text
~/quicklisp/local-projects/cl-koza-2
```

Then load the system:

```lisp
(asdf:load-system "cl-koza-2")
```

### Quick start

Load the example system and verify the known correct program from
*Genetic Programming II*:

```lisp
(asdf:load-system "cl-koza-2/examples/even-5-parity")

(cl-koza-2.examples.even-5-parity:verify-known-program)
```

This prints the standardized fitness and number of hits, and returns two
values: `T` when the known program has fitness 0, and `T` when it solves all
32 fitness cases.

Run a small smoke test:

```lisp
(cl-koza-2.examples.even-5-parity:run-example
 :maximum-generations 1
 :size-of-population 8
 :seed 1.0)
```

`run-example` defaults to the book-sized run of 51 generations and a
population of 4000 individuals:

```lisp
(cl-koza-2.examples.even-5-parity:run-example)
```

The same run can be started directly with `run`:

```lisp
(cl-koza-2.examples.even-5-parity:run 51 4000 1.0 :verbose t)
```

The three-ADF version uses the generalized `run-adf-system` entry point:

```lisp
(asdf:load-system "cl-koza-2/examples/even-5-parity-3-adfs")

(cl-koza-2.examples.even-5-parity-3-adfs:verify-known-program)

(cl-koza-2.examples.even-5-parity-3-adfs:run-example
 :maximum-generations 1
 :size-of-population 8
 :seed 1.0)
```

The parameterized version defaults to four ADFs and accepts any
non-negative branch count:

```lisp
(asdf:load-system "cl-koza-2/examples/even-5-parity-n-adfs")

(cl-koza-2.examples.even-5-parity-n-adfs:run-example
 :number-of-adfs 6
 :maximum-generations 1
 :size-of-population 8
 :seed 1.0)
```

### Architecture

An overall program is an `adf-program` with `N` automatically defined
function branches followed by the result-producing branch:

| Branch | Purpose |
| --- | --- |
| `ADF0 … ADF(N-1)` | Automatically defined functions |
| `RPB` | Result-producing branch, the program's output |

`N` may be zero, in which case the program contains only `RPB`. The kernel
does not restrict which ADF a branch calls; that is determined by the
problem's function sets. In the original even-5-parity example, there are two
ADFs. ADF0 and ADF1 each take three arguments (`ARG0`, `ARG1`, `ARG2`), ADF1
may call ADF0, and the result-producing branch may call both ADFs. ADF0 does
not call another ADF. The three-ADF example adds ADF2, which may call ADF0
and ADF1, and lets the result-producing branch call all three ADFs. The
parameterized example generalizes this pattern: `ADF(I)` may call
`ADF0 … ADF(I-1)`, and the result-producing branch may call every ADF.

The main program operations are exported from `cl-koza-2.program`:

- `make-adf-program`, `adf-program-adfs`, `adf-program-adf`,
  `adf-program-branch-count`, `adf-program-rpb`
- Legacy accessors: `adf-program-adf0`, `adf-program-adf1`
- `branch-index`, `branch-names`, `program-branch`,
  `replace-program-branch`, `map-program-branches`
- `copy-individual-substituting-branch`
- `count-crossover-points`, `count-function-points`, `max-depth-of-tree`
- `get-subtree`, `get-function-subtree`

`make-adf-program` accepts `:adfs` (a list of branch bodies) together with
`:rpb`. The legacy keywords `:adf0` and `:adf1` remain supported when
`:adfs` is omitted; calling it with no arguments still creates a program with
two `NIL` ADFs.

The generic tree interpreter is exported from `cl-koza-2.interpreter` and
re-exported from `cl-koza-2`:

- `evaluate-adf-program` evaluates the result-producing branch.
- `evaluate-adf-branch` evaluates a selected branch.
- `evaluate-adf-tree` evaluates an arbitrary tree in the context of a
  program.

Each evaluator accepts an `:environment` alist of terminal or argument
bindings. ADF calls are resolved against the program's branch vector, so the
interpreter does not use dynamically bound ADF variables. It supports
`AND`, `OR`, `IF`, and `PROGN` as special forms and calls other symbols as
Common Lisp functions.

The generalized kernel entry point is exported from `cl-koza-2`:

```lisp
(run-adf-system problem-function
                seed
                maximum-generations
                size-of-population
                &rest seeded-programs)
```

The legacy entry point remains available:

```lisp
(run-genetic-programming-system problem-function
                                seed
                                maximum-generations
                                size-of-population
                                &rest seeded-programs)
```

#### Problem-function contract

`run-adf-system` expects `problem-function` to return six values:

1. A list of branch specs for `ADF0 … ADF(N-1)`
2. A branch spec for the result-producing branch
3. Fitness-cases creator
4. Fitness function
5. Parameter definer
6. Termination predicate

A branch spec is created with:

```lisp
(make-branch-spec :function-set-creator #'creator
                  :terminal-set-creator #'creator)
```

The length of the first value determines the number of ADFs. `NIL` creates a
program with no ADFs. The fitness function receives an `adf-program` and the
fitness cases, and returns two values: the standardized fitness and the
number of hits.

`run-genetic-programming-system` is the compatibility wrapper for the
legacy two-ADF contract. Its `problem-function` returns ten values:

1. ADF0 function-set creator
2. ADF1 function-set creator
3. Result-producing branch function-set creator
4. ADF0 terminal-set creator
5. ADF1 terminal-set creator
6. Result-producing branch terminal-set creator
7. Fitness-cases creator
8. Fitness function
9. Parameter definer
10. Termination predicate

A function-set creator returns two values: the function set and its argument
map (the number of arguments expected by each function). A terminal-set
creator returns the terminal set.

The parameter definer sets the kernel's dynamic variables, including:

- `*number-of-fitness-cases*`
- `*max-depth-for-new-individuals*`
- `*max-depth-for-new-subtrees-in-mutants*`
- `*max-depth-for-individuals-after-crossover*`
- `*fitness-proportionate-reproduction-fraction*`
- `*crossover-at-any-point-fraction*`
- `*crossover-at-function-point-fraction*`
- `*method-of-selection*`, `*tournament-size*`
- `*method-of-generation*`
- `*verbose*`

Fitness evaluation in the legacy two-ADF example is sequential because its
evaluator relies on dynamically bound special variables and is not
thread-safe. The generic interpreter uses explicit environments and does not
depend on those dynamic variables.

### Example: even-5-parity

The `even-5-parity` example defines the Boolean function sets, terminal sets,
fitness cases, fitness function, parameters, and termination criterion used
by the book. Its known correct program is:

```lisp
(make-adf-program
 :adf0 '(or (and arg0 arg1)
            (and (nand arg0 arg0) (nand arg1 arg1)))
 :adf1 '(nand (or (and arg0 arg1)
                  (and (nand arg0 arg0) (nand arg1 arg1)))
              (or (and arg0 arg1)
                  (and (nand arg0 arg0) (nand arg1 arg1))))
 :rpb '(adf1 (adf0 (adf0 d0 d1 d0) (adf0 d2 d3 d0) d0)
             d4 d0))
```

`verify-known-program` evaluates it and reports:

```text
Known program: standardized-fitness=0 hits=32
```

### Parallel execution

`cl-koza-2` uses `lparallel` by default for fitness evaluation and for
generating the initial random population. The worker pool is created on
demand and reused across runs.

```lisp
(let ((*parallel-evaluation-p* nil))
  (run-adf-system 'my-problem 1.0 50 1000))
```

Set `*parallel-evaluation-p*` to `NIL` for fitness functions that are not
thread-safe. Set `*parallel-generation-p*` to `NIL` to generate the initial
population serially. Initial generation uses deterministic per-individual
seeds and serialized uniqueness resolution, so the same randomizer seed
produces the same population regardless of the number of workers.

### Example: even-5-parity with three ADFs

The `even-5-parity-3-adfs` example keeps the same fitness cases and Boolean
function sets, but uses a hierarchical three-ADF architecture: ADF2 may call
ADF0 and ADF1, and the result-producing branch may call all three ADFs. Its
known correct program reuses the two-ADF solution and wraps the original
ADF1 call through ADF2:

```lisp
(make-adf-program
 :adfs (list
        '(or (and arg0 arg1)
             (and (nand arg0 arg0) (nand arg1 arg1)))
        '(nand (or (and arg0 arg1)
                   (and (nand arg0 arg0) (nand arg1 arg1)))
               (or (and arg0 arg1)
                   (and (nand arg0 arg0) (nand arg1 arg1))))
        '(adf1 arg0 arg1 arg2))
 :rpb '(adf2 (adf0 (adf0 d0 d1 d0) (adf0 d2 d3 d0) d0)
             d4 d0))
```

`verify-known-program` reports:

```text
Known program: standardized-fitness=0.0 hits=32
```

The example uses the generic `run-adf-system` entry point and the
`evaluate-adf-program` interpreter.

### Example: even-5-parity with N ADFs

The `even-5-parity-n-adfs` example parameterizes the hierarchical
architecture. `*number-of-adfs*` defaults to `4`; `run`, `run-example`, and
`verify-known-program` also accept an explicit branch count.

```lisp
(asdf:load-system "cl-koza-2/examples/even-5-parity-n-adfs")

(cl-koza-2.examples.even-5-parity-n-adfs:run-example
 :number-of-adfs 4
 :maximum-generations 1
 :size-of-population 8
 :seed 1.0)
```

`run` supports `N >= 0`, including programs with no ADFs. The known correct
program is available for `N >= 2`: it keeps the two-ADF solution in ADF0 and
ADF1, adds pass-through branches for higher indices, and calls the last ADF
from the result-producing branch.

```lisp
(cl-koza-2.examples.even-5-parity-n-adfs:verify-known-program 4)
```

### Tests

The test suite uses FiveAM and is registered as `cl-koza-2/tests`:

```lisp
(asdf:test-system "cl-koza-2")
```

At the time of writing the suite reports:

```text
Pass: 3008 (99%)
Skip: 2 ( 0%)
Fail: 0 ( 0%)
```

The two skipped tests document known issues:

- `run-genetic-programming-system` accepts `maximum-generations` equal to
  zero, but `report-on-run` later signals an error because
  `*best-of-run-individual*` remains `NIL`.
- `(random-integer 0)` returns `0` instead of signaling an error, even
  though the documented range `0..N-1` is empty for `N = 0`.

### Roadmap

- **Phase 1 (done):** kernel with ADF0, ADF1 and RPB; even-5-parity example;
  FiveAM test suite.
- **Phase 2 (done):** generalized program representation, problem contract,
  and kernel to an arbitrary number of ADFs (`ADF0 … ADF(N-1) + RPB`,
  including `N = 0`), while keeping the two-ADF API as a compatibility
  layer. Kernel tests cover zero, one, two, three, and four ADFs.
- **Phase 3 (done):** generic tree interpreter with explicit environments and
  an even-5-parity example with three hierarchical ADFs.
- **Phase 4 (done):** parallel fitness evaluation and initial-population
  generation with `lparallel`, including reproducibility and serial fallbacks,
  plus a parameterized even-5-parity example for arbitrary ADF counts.
- **Future work:** architecture-selection experiments and additional N-ADF
  benchmarks.

### Project layout

```text
cl-koza-2.asd          ASDF systems
src/                    Koza II kernel
examples/               Koza II examples
tests/                  FiveAM test suite
doc/                    Koza II reference material
```

### References

- John R. Koza, *Genetic Programming II: Automatic Discovery of Reusable
  Programs*.
- The reference PDF is available at
  `doc/koza_jr_ed_genetic_programming_ii_automatic_discovery_of_reu.pdf`.
- Multiple function-defining branches: section 6.7.
- Retrospective even-5-parity architecture experiments, including three-ADF
  architectures: section 7.4.

## License

New code and modifications in this repository are under the MIT License
(see `COPYING`).

Copyright (c) Gastón Novita, All rights reserved.

## Koza attribution

This is an independent Common Lisp implementation inspired by John R. Koza's
*Genetic Programming II: Automatic Discovery of Reusable Programs* (MIT Press,
1994). Koza's book and original Little Lisp software are copyrighted by John R.
Koza. The Koza I/Little Lisp source code is not included in this repository.

The following license was part of the original project and is reproduced for
attribution and historical reference. It applies to Koza's Little Lisp software,
not to the new code in this repository, which remains under the MIT License above.

### Little Lisp License

Copyright (c) John Koza, All rights reserved.
U.S. Patent #4,935,877.  Other patents pending.

ROYALTY-FREE LICENSE FOR GENETIC PROGRAMMING SOFTWARE FOR ACADEMIC PURPOSES
===========================================================================

As you requested, I am including herewith, FOR YOUR INFORMATION AND
INSPECTION ONLY, a copy of my "SIMPLE LISP" software for genetic
programming.  Please be advised that this software is copyrighted and
is the subject of my United States patents 4,935,877 5,136,686, and
5,148,513, foreign counterparts, and other patents pending.

IF YOU WISH TO USE THIS SOFTWARE, you may have a royalty-free,
non-exclusive license under these proprietary rights, without the
right of sublicense, to use (but not to make or sell) the software
for academic purposes only and only then if you receive no money
or other valuable consideration as a result of its use.
Neither the software (or copies thereof) nor this license is
transferrable for any reason.  This license grants you the right
to make copies of the software which are necessary for your use,
and your use only, provided each copy incorporates this license.

The programs, procedures, and applications presented in this software
have been included for their instructional value.  The publisher and
author offer NO WARRANTY OF FITNESS OR MERCHANTABILITY for any
particular purpose or accept any liability with respect
to these programs, procedures, and applications.

If you wish such a licence under these terms, please indicate so
by signing and dating a copy of this notice and returning it to me
at John Koza, Box K, Los Altos, California 94023 USA.

I would like the above license and hereby agree to the terms set forth above.

LICENSEE:

NAME (Print) ____________________________

Signature _________________________________

Date _______________

PHYSICAL ADDRESS _______________________________

CITY, STATE, ZIP _______________________________

COUNTRY _____________________________

E-MAIL ADDRESS _______________________________________

PHONE ___________________________
