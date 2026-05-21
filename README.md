# Gaussian Theorem Prover

A theorem-proving and explanation system that takes recursive, logical, or symbolic
programs and discovers possible closed-form rules using Gaussian elimination, then
proves the discovered rule using induction, rewriting, or symbolic verification.

The prover is designed to be understandable to children, students, and non-experts.

## Quick start

```python
from src.parser import PrologParser

parser = PrologParser()
result = parser.parse(open("examples/sum.pl").read())
print(result)
# {
#   "predicate": "sum",
#   "arity": 2,
#   "input_var": "N",
#   "output_var": "S",
#   "base_cases": [{"input": 0, "output": 0}],
#   "recurrence": "sum(n)=sum(n - 1) + n",
#   "base_case": "sum(0)=0"
# }
```

## Running tests

```bash
python -m pytest tests/test_parser.py -v
```

## Repository structure

```
gaussian-theorem-prover/
├── README.md
├── requirements.md          # Implementation stages
├── pr1.txt                  # Full project specification
├── examples/
│   ├── sum.pl
│   ├── square.pl
│   ├── arithmetic_sequence.pl
│   └── factorial_rejected.pl
├── src/
│   └── parser/
│       └── prolog_parser.py  # Stage 1: Parser Agent
├── tests/
│   └── test_parser.py
└── docs/
    └── theory.md
```

## Pipeline

| Stage | Component | Status |
|-------|-----------|--------|
| 1 | Parser Agent | ✅ Complete |
| 2 | Example Generation Agent | ✅ Complete |
| 3 | Polynomial Discovery Agent | ✅ Complete |
| 4 | Gaussian Elimination Agent | ✅ Complete |
| 5 | Induction Proof Agent | 🔲 Planned |
| 6 | Child Explanation Agent | 🔲 Planned |
| 7 | Web Visualisation Agent | 🔲 Planned |

### Stage 4 tests

```bash
python -m pytest tests/test_gaussian.py -v
```

See [requirements.md](requirements.md) and [pr1.txt](pr1.txt) for full details.
