# Gaussian Theorem Prover — Requirements

See [pr1.txt](pr1.txt) for the full project specification.

## Implementation stages

| Stage | Component | Status |
|-------|-----------|--------|
| 1 | Parser Agent | ✅ Complete |
| 2 | Example Generation Agent | ✅ Complete |
| 3 | Polynomial Discovery Agent | ✅ Complete |
| 4 | Gaussian Elimination Agent | ✅ Complete |
| 5 | Induction Proof Agent | 🔲 Planned |
| 6 | Child Explanation Agent | 🔲 Planned |
| 7 | Web Visualisation Agent | 🔲 Planned |

## Stage 1 — Parser Agent

### Input

A Prolog-like program defining a recursive predicate.

### Output (internal representation)

```json
{
  "predicate": "sum",
  "arity": 2,
  "input_var": "N",
  "output_var": "S",
  "base_cases": [{"input": 0, "output": 0}],
  "recurrence": "sum(n)=sum(n - 1) + n",
  "base_case": "sum(0)=0"
}
```

### Running the parser

```python
from src.parser import PrologParser

parser = PrologParser()
result = parser.parse(open("examples/sum.pl").read())
print(result)
```

### Running the tests

```bash
python -m pytest tests/test_parser.py -v
```

## Stage 2 — Example Generation Agent

### Input

Prolog-like program source for a single predicate.

### Output (examples as input/output pairs)

```json
{
  "predicate": "sum",
  "examples": [
    {"input": 0, "output": 0},
    {"input": 1, "output": 1},
    {"input": 2, "output": 3}
  ]
}
```

### Requirements implemented

- Executes recursive definitions safely.
- Limits recursion depth with configurable cap.
- Detects nontermination via recursive-loop detection.
- Stores generated examples as input/output pairs.

### Running example-generation tests

```bash
python -m pytest tests/test_examples.py -v
```

## Stage 3 — Polynomial Discovery Agent

### Input

Examples as input/output pairs from Stage 2.

### Output (candidate polynomial)

```json
{
  "predicate": "sum",
  "degree": 2,
  "coefficients_readable": ["1/2", "1/2", "0"],
  "formula": "1/2*n^2 + 1/2*n",
  "status": "found"
}
```

### Requirements implemented

- Tries polynomial degrees 0, 1, 2, 3, and 4.
- Builds coefficient matrices from examples.
- Uses exact rational arithmetic (`fractions.Fraction`).
- Rejects candidates that fail available test examples.

### Running polynomial-discovery tests

```bash
python -m pytest tests/test_polynomial.py -v
```

## Stage 4 — Gaussian Elimination Agent

### Input

Square augmented matrix from Stage 3 candidate equations.

### Output

- Solved coefficients using exact rational arithmetic.
- Row-by-row operation log in plain English.
- Machine-readable proof trace containing matrix snapshots.

### Requirements implemented

- Solves coefficient matrices step by step.
- Uses fractions (`fractions.Fraction`) without floating point.
- Explains each row operation in plain English.
- Exports a machine-readable proof trace.

### Running Gaussian-elimination tests

```bash
python -m pytest tests/test_gaussian.py -v
```
