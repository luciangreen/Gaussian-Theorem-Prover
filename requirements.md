# Gaussian Theorem Prover — Requirements

See [pr1.txt](pr1.txt) for the full project specification.

## Implementation stages

| Stage | Component | Status |
|-------|-----------|--------|
| 1 | Parser Agent | ✅ Complete |
| 2 | Example Generation Agent | 🔲 Planned |
| 3 | Polynomial Discovery Agent | 🔲 Planned |
| 4 | Gaussian Elimination Agent | 🔲 Planned |
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
