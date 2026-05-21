# Gaussian Theorem Prover

## Stage 1 implementation

This repository now includes a minimal Stage 1 theorem-proving kernel in:

- `/tmp/workspace/luciangreen/Gaussian-Theorem-Prover/src/stage1_kernel.pl`

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
Proof = proof(equation(fun(add, [const(0), var(x)]), var(x)), [rewrite_left(rule(fun(add, [const(0), var(a)]), var(a)))]) ;
false.
```

### Run tests

```bash
swipl -q -g run_tests -t halt tests/test_stage1.pl
```
