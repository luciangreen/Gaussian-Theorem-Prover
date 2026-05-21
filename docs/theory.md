# Theory

## Overview

The Gaussian Theorem Prover pipeline discovers closed-form polynomial rules from
recursive Prolog-like programs and then proves them by induction.

## Pipeline

```
Input Program
  → Parser                  (Stage 1) ✅
  → Example Generator       (Stage 2) ✅
  → Polynomial Candidate Builder + Gaussian Elimination  (Stages 3-4)
  → Proof Verifier (Induction)  (Stage 5)
  → Explanation Generator   (Stage 6)
  → Web Visualisation        (Stage 7)
```

## Stage 1 — Parser

The parser reads a Prolog-like source file and extracts:

- The **predicate name** (e.g. `sum`).
- The **arity** (number of arguments).
- The **input variable** — the counter that decreases toward the base case.
- The **output variable** — the accumulated result.
- **Base cases** — input→output pairs derived from Prolog facts.
- A **recurrence string** — human-readable recurrence relation.

### Identification heuristics

| Signal | Variable role |
|--------|--------------|
| Appears in guard `N > 0` | Input (counter) |
| Decremented: `N1 is N - 1` | Input (counter) |
| Assigned in accumulation `S is S1 + N` | Output (result) |

### Internal representation

```python
{
  "predicate":  str,
  "arity":      int,
  "input_var":  str | None,
  "output_var": str | None,
  "base_cases": list[{"input": value, "output": value}],
  "recurrence": str,   # e.g. "sum(n)=sum(n-1)+n"
  "base_case":  str,   # e.g. "sum(0)=0"
}
```

## Supported example types

| Program | Formula | Parser result |
|---------|---------|---------------|
| `sum.pl` | N(N+1)/2 | recurrence: `sum(n)=sum(n - 1) + n` |
| `square.pl` | N² | direct rule, no recurrence |
| `arithmetic_sequence.pl` | 2N+3 | recurrence: `seq(n)=seq(n - 1) + 2` |
| `factorial_rejected.pl` | N! (not polynomial) | recurrence: `fact(n)=n * fact(n - 1)` |
