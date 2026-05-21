"""Polynomial Discovery Agent (Stage 3)."""

from __future__ import annotations

from fractions import Fraction
from typing import Any


def _to_fraction(value: Any) -> Fraction:
    if isinstance(value, Fraction):
        return value
    if isinstance(value, int):
        return Fraction(value)
    if isinstance(value, float):
        return Fraction(str(value))
    if isinstance(value, str):
        try:
            return Fraction(value)
        except ValueError as exc:
            raise ValueError(f"Invalid fraction string value: {value!r}") from exc
    raise TypeError(
        f"Unsupported type for fraction conversion: {type(value).__name__}. "
        "Expected int, float, str, or Fraction."
    )


def _format_fraction(value: Fraction) -> str:
    if value.denominator == 1:
        return str(value.numerator)
    return f"{value.numerator}/{value.denominator}"


class PolynomialDiscoveryAgent:
    """Fits polynomial candidates from input/output examples."""

    def __init__(self, max_degree: int = 4):
        self.max_degree = max_degree

    def build_coefficient_matrix(self, examples: list[dict[str, Any]], degree: int) -> list[list[Fraction]]:
        """Build an augmented matrix for fitting a polynomial of degree `degree`."""
        needed = degree + 1
        if len(examples) < needed:
            raise ValueError(
                f"Need at least {needed} examples to fit degree {degree} polynomial, "
                f"but only {len(examples)} provided"
            )

        matrix: list[list[Fraction]] = []
        for pair in examples[:needed]:
            x = _to_fraction(pair["input"])
            y = _to_fraction(pair["output"])
            row = [x ** power for power in range(degree, -1, -1)]
            row.append(y)
            matrix.append(row)
        return matrix

    def discover(self, example_data: dict[str, Any]) -> dict[str, Any]:
        """
        Try polynomial degrees 0..max_degree and return first valid candidate.
        Returns rejection details if no polynomial candidate validates.
        """
        predicate = example_data.get("predicate")
        examples = example_data.get("examples", [])
        if not examples:
            raise ValueError("No examples provided in example_data")

        normalized = [
            {"input": _to_fraction(item["input"]), "output": _to_fraction(item["output"])}
            for item in examples
        ]

        attempted_degrees: list[int] = []
        skipped_degrees: list[int] = []
        for degree in range(0, self.max_degree + 1):
            if len(normalized) < degree + 1:
                skipped_degrees.extend(range(degree, self.max_degree + 1))
                break
            attempted_degrees.append(degree)
            matrix = self.build_coefficient_matrix(normalized, degree)
            coefficients = self._solve_augmented_matrix(matrix)
            if coefficients is None:
                continue
            if self._candidate_matches_all_points(coefficients, normalized):
                return {
                    "predicate": predicate,
                    "degree": degree,
                    "coefficients": coefficients,
                    "coefficients_readable": [_format_fraction(c) for c in coefficients],
                    "formula": self._format_formula(coefficients),
                    "matrix": matrix,
                    "status": "found",
                    "attempted_degrees": attempted_degrees,
                    "skipped_degrees": skipped_degrees,
                }

        return {
            "predicate": predicate,
            "degree": None,
            "coefficients": [],
            "coefficients_readable": [],
            "formula": None,
            "matrix": [],
            "status": "rejected",
            "reason": f"No polynomial formula found up to degree {self.max_degree}",
            "attempted_degrees": attempted_degrees,
            "skipped_degrees": skipped_degrees,
        }

    def _candidate_matches_all_points(
        self, coefficients: list[Fraction], examples: list[dict[str, Fraction]]
    ) -> bool:
        for pair in examples:
            if self._evaluate_polynomial(coefficients, pair["input"]) != pair["output"]:
                return False
        return True

    def _evaluate_polynomial(self, coefficients: list[Fraction], x: Fraction) -> Fraction:
        value = Fraction(0)
        for coefficient in coefficients:
            value = (value * x) + coefficient
        return value

    def _solve_augmented_matrix(self, matrix: list[list[Fraction]]) -> list[Fraction] | None:
        """Solve a square augmented matrix with exact Gaussian elimination."""
        size = len(matrix)
        work = [row[:] for row in matrix]

        for col in range(size):
            pivot = None
            for row in range(col, size):
                if work[row][col] != 0:
                    pivot = row
                    break
            if pivot is None:
                return None
            if pivot != col:
                work[col], work[pivot] = work[pivot], work[col]

            pivot_value = work[col][col]
            work[col] = [value / pivot_value for value in work[col]]

            for row in range(col + 1, size):
                factor = work[row][col]
                if factor == 0:
                    continue
                work[row] = [
                    work[row][i] - factor * work[col][i]
                    for i in range(size + 1)
                ]

        coefficients = [Fraction(0) for _ in range(size)]
        for row in range(size - 1, -1, -1):
            if work[row][row] == 0:
                return None
            rhs = work[row][size]
            for col in range(row + 1, size):
                rhs -= work[row][col] * coefficients[col]
            coefficients[row] = rhs / work[row][row]
        return coefficients

    def _format_formula(self, coefficients: list[Fraction]) -> str:
        degree = len(coefficients) - 1
        terms: list[str] = []
        for index, coefficient in enumerate(coefficients):
            if coefficient == 0:
                continue
            power = degree - index
            coeff_text = _format_fraction(abs(coefficient))
            if power == 0:
                term = coeff_text
            elif power == 1:
                term = f"{coeff_text}*n"
            else:
                term = f"{coeff_text}*n^{power}"
            sign = "-" if coefficient < 0 else "+"
            if not terms:
                terms.append(term if sign == "+" else f"-{term}")
            else:
                terms.append(f" {sign} {term}")

        return "".join(terms) if terms else "0"
