"""Gaussian Elimination Agent (Stage 4)."""

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


def _format_row(row: list[Fraction]) -> str:
    return "[" + ", ".join(_format_fraction(value) for value in row) + "]"


class GaussianEliminationAgent:
    """Solves square augmented matrices with exact Gaussian elimination."""

    def solve(self, matrix: list[list[Any]]) -> dict[str, Any]:
        if not matrix:
            raise ValueError("Matrix must not be empty")
        size = len(matrix)
        expected_cols = size + 1
        if any(len(row) != expected_cols for row in matrix):
            raise ValueError(
                f"Expected a square augmented matrix with {expected_cols} columns per row"
            )

        work: list[list[Fraction]] = [
            [_to_fraction(value) for value in row]
            for row in matrix
        ]
        initial_matrix = [row[:] for row in work]
        steps: list[dict[str, Any]] = []

        def add_step(
            *,
            operation: str,
            row: int | None = None,
            target_row: int | None = None,
            with_row: int | None = None,
            factor: Fraction | None = None,
            description: str,
        ) -> None:
            steps.append(
                {
                    "operation": operation,
                    "row": row,
                    "target_row": target_row,
                    "with_row": with_row,
                    "factor": factor,
                    "factor_readable": _format_fraction(factor) if factor is not None else None,
                    "description": description,
                    "matrix": [r[:] for r in work],
                    "matrix_readable": [_format_row(r) for r in work],
                }
            )

        for col in range(size):
            pivot = None
            for row in range(col, size):
                if work[row][col] != 0:
                    pivot = row
                    break
            if pivot is None:
                return self._singular_result(initial_matrix, work, steps, col)

            if pivot != col:
                work[col], work[pivot] = work[pivot], work[col]
                add_step(
                    operation="swap",
                    row=col,
                    with_row=pivot,
                    description=f"Swap row {col + 1} with row {pivot + 1} to move a non-zero pivot into position.",
                )

            pivot_value = work[col][col]
            if pivot_value != 1:
                scale_factor = Fraction(1, 1) / pivot_value
                work[col] = [value * scale_factor for value in work[col]]
                add_step(
                    operation="scale",
                    row=col,
                    factor=scale_factor,
                    description=f"Scale row {col + 1} by {_format_fraction(scale_factor)} so the pivot becomes 1.",
                )

            for row in range(size):
                if row == col:
                    continue
                factor = work[row][col]
                if factor == 0:
                    continue
                work[row] = [
                    work[row][i] - factor * work[col][i]
                    for i in range(expected_cols)
                ]
                add_step(
                    operation="eliminate",
                    row=col,
                    target_row=row,
                    factor=factor,
                    description=(
                        f"Subtract {_format_fraction(factor)} × row {col + 1} "
                        f"from row {row + 1} to clear column {col + 1}."
                    ),
                )

        solution = [work[row][size] for row in range(size)]
        return {
            "status": "solved",
            "solution": solution,
            "solution_readable": [_format_fraction(value) for value in solution],
            "final_matrix": [row[:] for row in work],
            "final_matrix_readable": [_format_row(row) for row in work],
            "row_operations": [step["description"] for step in steps],
            "proof_trace": {
                "initial_matrix": initial_matrix,
                "initial_matrix_readable": [_format_row(row) for row in initial_matrix],
                "steps": steps,
                "final_matrix": [row[:] for row in work],
                "final_matrix_readable": [_format_row(row) for row in work],
                "solution": solution,
                "solution_readable": [_format_fraction(value) for value in solution],
            },
        }

    def _singular_result(
        self,
        initial_matrix: list[list[Fraction]],
        current_matrix: list[list[Fraction]],
        steps: list[dict[str, Any]],
        pivot_column: int,
    ) -> dict[str, Any]:
        return {
            "status": "singular",
            "reason": f"No non-zero pivot found in column {pivot_column + 1}.",
            "solution": [],
            "solution_readable": [],
            "final_matrix": [row[:] for row in current_matrix],
            "final_matrix_readable": [_format_row(row) for row in current_matrix],
            "row_operations": [step["description"] for step in steps],
            "proof_trace": {
                "initial_matrix": initial_matrix,
                "initial_matrix_readable": [_format_row(row) for row in initial_matrix],
                "steps": steps,
                "final_matrix": [row[:] for row in current_matrix],
                "final_matrix_readable": [_format_row(row) for row in current_matrix],
                "solution": [],
                "solution_readable": [],
                "status": "singular",
                "reason": f"No non-zero pivot found in column {pivot_column + 1}.",
            },
        }
