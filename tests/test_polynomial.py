"""Tests for Stage 3: Polynomial Discovery Agent."""

import os
import sys
import unittest
from fractions import Fraction

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.examples import ExampleGenerator
from src.polynomial import PolynomialDiscoveryAgent


EXAMPLES_DIR = os.path.join(os.path.dirname(__file__), "..", "examples")


def _load(filename: str) -> str:
    with open(os.path.join(EXAMPLES_DIR, filename), encoding="utf-8") as fh:
        return fh.read()


class TestPolynomialDiscovery(unittest.TestCase):
    def setUp(self):
        self.generator = ExampleGenerator(recursion_depth_limit=50)
        self.agent = PolynomialDiscoveryAgent(max_degree=4)

    def test_build_sum_matrix_degree_2(self):
        examples = self.generator.generate_examples(_load("sum.pl"), max_n=2)["examples"]
        matrix = self.agent.build_coefficient_matrix(examples, degree=2)
        expected = [
            [Fraction(0), Fraction(0), Fraction(1), Fraction(0)],
            [Fraction(1), Fraction(1), Fraction(1), Fraction(1)],
            [Fraction(4), Fraction(2), Fraction(1), Fraction(3)],
        ]
        self.assertEqual(matrix, expected)

    def test_sum_polynomial_discovery(self):
        examples = self.generator.generate_examples(_load("sum.pl"), max_n=5)
        result = self.agent.discover(examples)
        self.assertEqual(result["status"], "found")
        self.assertEqual(result["degree"], 2)
        self.assertEqual(result["coefficients"], [Fraction(1, 2), Fraction(1, 2), Fraction(0)])

    def test_square_polynomial_discovery(self):
        examples = self.generator.generate_examples(_load("square.pl"), max_n=5)
        result = self.agent.discover(examples)
        self.assertEqual(result["status"], "found")
        self.assertEqual(result["degree"], 2)
        self.assertEqual(result["coefficients"], [Fraction(1), Fraction(0), Fraction(0)])

    def test_arithmetic_sequence_polynomial_discovery(self):
        examples = self.generator.generate_examples(_load("arithmetic_sequence.pl"), max_n=5)
        result = self.agent.discover(examples)
        self.assertEqual(result["status"], "found")
        self.assertEqual(result["degree"], 1)
        self.assertEqual(result["coefficients"], [Fraction(2), Fraction(3)])

    def test_factorial_rejected(self):
        examples = self.generator.generate_examples(_load("factorial_rejected.pl"), max_n=5)
        result = self.agent.discover(examples)
        self.assertEqual(result["status"], "rejected")
        self.assertIsNone(result["degree"])
        self.assertEqual(result["coefficients"], [])
        self.assertIn("No polynomial formula found", result["reason"])


if __name__ == "__main__":
    unittest.main()
