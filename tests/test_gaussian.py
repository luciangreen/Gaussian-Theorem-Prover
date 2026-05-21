"""Tests for Stage 4: Gaussian Elimination Agent."""

import os
import sys
import unittest
from fractions import Fraction

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.gaussian import GaussianEliminationAgent


class TestGaussianEliminationAgent(unittest.TestCase):
    def setUp(self):
        self.agent = GaussianEliminationAgent()

    def test_solves_sum_matrix(self):
        matrix = [
            [0, 0, 1, 0],
            [1, 1, 1, 1],
            [4, 2, 1, 3],
        ]
        result = self.agent.solve(matrix)
        self.assertEqual(result["status"], "solved")
        self.assertEqual(result["solution"], [Fraction(1, 2), Fraction(1, 2), Fraction(0)])
        self.assertTrue(result["row_operations"])
        self.assertIn("steps", result["proof_trace"])
        self.assertEqual(result["proof_trace"]["solution"], [Fraction(1, 2), Fraction(1, 2), Fraction(0)])

    def test_detects_singular_matrix(self):
        matrix = [
            [1, 1, 1],
            [2, 2, 2],
        ]
        result = self.agent.solve(matrix)
        self.assertEqual(result["status"], "singular")
        self.assertEqual(result["solution"], [])
        self.assertIn("No non-zero pivot found", result["reason"])

    def test_validates_matrix_shape(self):
        with self.assertRaises(ValueError):
            self.agent.solve([[1, 2], [3, 4], [5, 6]])


if __name__ == "__main__":
    unittest.main()
