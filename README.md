# Gaussian Theorem Prover

## Stage 1 implementation

This repository now includes a minimal Stage 1 theorem-proving kernel in:

- `src/stage1_kernel.pl`

Implemented Stage 1 components:

- parser (`parse_term/2`, `parse_equation/2`)
- term representation (`var/1`, `const/1`, `fun/2`)
- unification (`unify_terms/3`)
- basic rewriting (`rewrite_once/3`)
- proof objects (`proof(equation(...), Steps)`)
- proof checker (`check_proof/1`)

### Acceptance example

In SWI-Prolog:

```prolog
?- [src/stage1_kernel].
?- check_proof(Proof).
Proof = proof(equation(fun(add, [const(0), var('X')]), var('X')), [rewrite_left(rule(fun(add, [const(0), var('A')]), var('A')))]) ;
false.
```

### Run tests

```bash
swipl -q -g run_tests -t halt tests/test_stage1.pl
```

## Stage 2 implementation

Stage 2 recursive program analysis is implemented in:

- `src/stage2_analysis.pl`

Implemented Stage 2 components:

- recurrence extraction (`extract_recurrence/3`)
- call graph generation (`generate_call_graph/2`)
- termination heuristics (`termination_heuristic/3`)
- example generation (`generate_examples/4`)

### Stage 2 example

In SWI-Prolog:

```prolog
?- [src/stage2_analysis].
?- example_program(P), extract_recurrence(P, sum/2, R).
P = [clause(fun(sum, [const(0), const(0)]), []), clause(fun(sum, [var('N'), var('S')]), [call(fun(sum, [fun(sub, [var('N'), const(1)]), var('S1')])), call(fun(add, [var('S1'), var('N'), var('S')]))]), clause(fun(triangular, [var('N'), var('S')]), [call(fun(sum, [var('N'), var('S')]))])],
R = recurrence(sum/2, base(0, 0), step(n, rec(n-1)+n)).
```

### Run Stage 1 and Stage 2 tests

```bash
swipl -q -g run_tests -t halt tests/test_stage1.pl
swipl -q -g run_tests -t halt tests/test_stage2.pl
```

## Stage 3 implementation

Stage 3 Gaussian discovery is implemented in:

- `src/stage3_discovery.pl`

Implemented Stage 3 components:

- matrix builder (`build_matrix/4`)
- finite differences (`finite_differences/2`)
- polynomial fitting (`polynomial_fit/3`)
- Gaussian elimination (`gaussian_elimination/3`)
- invariant extraction (`extract_invariant/3`)
- formula discovery (`discover_formula/2`)

### Stage 3 acceptance example

In SWI-Prolog:

```prolog
?- [src/stage3_discovery].
?- discover_formula(sum, F).
F = n*(n+1)/2.
```

### Run Stage 3 tests

```bash
swipl -q -g run_tests -t halt tests/test_stage3.pl
```
