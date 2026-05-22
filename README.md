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

## Stage 4 implementation

Stage 4 formal verification is implemented in:

- `src/stage4_verification.pl`

Implemented Stage 4 components:

- mathematical induction (`mathematical_induction/3`)
- structural induction (`structural_induction/3`)
- resolution (`resolution/2`)
- constraint solving (`solve_constraints/2`)
- counterexample search (`counterexample_search/3`)
- theorem proving (`prove/1`, `prove/2`)

### Stage 4 acceptance example

In SWI-Prolog:

```prolog
?- [src/stage4_verification].
?- prove(sum_formula).
true.
?- prove(sum_formula, Result).
Result = proved.
```

### Run Stage 4 tests

```bash
swipl -q -g run_tests -t halt tests/test_stage4.pl
```

## Stage 5 implementation

Stage 5 universal proof search is implemented in:

- `src/stage5_proof_search.pl`

Implemented Stage 5 components:

- strategy selection (`select_strategy/3`)
- heuristic proof search (`heuristic_proof_search/3`)
- lemma generation (`generate_lemmas/3`)
- proof ranking (`rank_proofs/2`)
- fallback strategies (`fallback_strategy/4`)
- universal orchestration (`universal_prove/2`, `universal_prove/3`)

### Stage 5 acceptance example

In SWI-Prolog:

```prolog
?- [src/stage5_proof_search].
?- universal_prove(sum_formula, Result).
Result = proved.
```

### Run Stage 5 tests

```bash
swipl -q -g run_tests -t halt tests/test_stage5.pl
```

## Stage 6 implementation

Stage 6 explanation layer is implemented in:

- `src/stage6_explanation.pl`

Implemented Stage 6 components:

- child explanations (`child_explanation/3`)
- student explanations (`student_explanation/3`)
- proof trace narration (`narrate_proof_trace/2`)
- visual rewrite explanations (`visual_rewrite_explanation/3`)
- failure explanations (`failure_explanation/3`)
- explanation orchestration (`explain_proof/3`)

### Stage 6 acceptance example

In SWI-Prolog:

```prolog
?- [src/stage6_explanation].
?- explain_proof(sum_formula, child, Explanation).
Explanation = explanation(sum_formula, child, proved, _).
```

### Run Stage 6 tests

```bash
swipl -q -g run_tests -t halt tests/test_stage6.pl
```

## Stage 7 implementation

Stage 7 visualisation/web IDE is implemented in:

- `src/stage7_visualisation.pl`

Implemented Stage 7 components:

- browser IDE (`browser_ide/4`)
- matrix animation (`matrix_animation/3`)
- proof graph display (`proof_graph_display/3`)
- term rewrite visualiser (`term_rewrite_visualiser/3`)
- CFG visualiser (`cfg_visualiser/2`)
- proof tree explorer (`proof_tree_explorer/3`)
- visualisation orchestration (`visualise_theorem/3`)

### Stage 7 acceptance example

In SWI-Prolog:

```prolog
?- [src/stage7_visualisation].
?- visualise_theorem(sum_formula, student, Visualisation).
Visualisation = visualisation(_, _, _, _, _, _).
```

### Run Stage 7 tests

```bash
swipl -q -g run_tests -t halt tests/test_stage7.pl
```

## Stage 8 implementation

Stage 8 external backends are implemented in:

- `src/stage8_external_backends.pl`

Implemented Stage 8 components:

- Lean exporter (`lean_exporter/3`)
- Coq exporter (`coq_exporter/3`)
- SMTLIB exporter (`smtlib_exporter/3`)
- TPTP exporter (`tptp_exporter/3`)
- export orchestration (`export_proof/3`, `export_proof_text/3`)

### Stage 8 acceptance example

In SWI-Prolog:

```prolog
?- [src/stage8_external_backends].
?- export_proof(sum_formula, lean, File).
File = 'exports/sum_formula.lean'.
```

### Run Stage 8 tests

```bash
swipl -q -g run_tests -t halt tests/test_stage8.pl
```

## Stage 9 implementation

Stage 9 advanced discovery is implemented in:

- `src/stage9_advanced_discovery.pl`

Implemented Stage 9 components:

- graph invariants (`graph_invariants/3`)
- CFG induction (`cfg_induction/3`)
- symbolic compression (`symbolic_compression/3`)
- recursive decomposition (`recursive_decomposition/2`)
- Spec-to-Algorithm (`spec_to_algorithm/3`)
- semantic pattern mining (`semantic_pattern_mining/2`)
- orchestration (`discover_advanced/3`)

### Stage 9 acceptance example

In SWI-Prolog:

```prolog
?- [src/stage9_advanced_discovery].
?- discover_advanced(sum_formula, spec(sum_first_n), Report).
Report = advanced_discovery(_, _, _, _, _, _, _).
```

### Run Stage 9 tests

```bash
swipl -q -g run_tests -t halt tests/test_stage9.pl
```
