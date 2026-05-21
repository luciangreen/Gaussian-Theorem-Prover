"""Tests for Stage 2: Example Generation Agent."""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.examples import ExampleGenerator, NonTerminationError, RecursionDepthError


EXAMPLES_DIR = os.path.join(os.path.dirname(__file__), "..", "examples")


def _load(filename: str) -> str:
    with open(os.path.join(EXAMPLES_DIR, filename), encoding="utf-8") as fh:
        return fh.read()


class TestExampleGeneration(unittest.TestCase):
    def setUp(self):
        self.generator = ExampleGenerator(recursion_depth_limit=50)

    def test_sum_examples(self):
        result = self.generator.generate_examples(_load("sum.pl"), max_n=5)
        pairs = [(item["input"], item["output"]) for item in result["examples"]]
        self.assertEqual(pairs, [(0, 0), (1, 1), (2, 3), (3, 6), (4, 10), (5, 15)])

    def test_arithmetic_sequence_examples(self):
        result = self.generator.generate_examples(_load("arithmetic_sequence.pl"), max_n=5)
        pairs = [(item["input"], item["output"]) for item in result["examples"]]
        self.assertEqual(pairs, [(0, 3), (1, 5), (2, 7), (3, 9), (4, 11), (5, 13)])

    def test_square_examples(self):
        result = self.generator.generate_examples(_load("square.pl"), max_n=5)
        pairs = [(item["input"], item["output"]) for item in result["examples"]]
        self.assertEqual(pairs, [(0, 0), (1, 1), (2, 4), (3, 9), (4, 16), (5, 25)])

    def test_factorial_examples(self):
        result = self.generator.generate_examples(_load("factorial_rejected.pl"), max_n=5)
        pairs = [(item["input"], item["output"]) for item in result["examples"]]
        self.assertEqual(pairs, [(0, 1), (1, 1), (2, 2), (3, 6), (4, 24), (5, 120)])

    def test_nontermination_detection(self):
        src = """
        loop(N, S) :-
            N >= 0,
            loop(N, S1),
            S is S1 + 1.
        """
        with self.assertRaises(NonTerminationError):
            self.generator.generate_examples(src, max_n=2)

    def test_recursion_limit(self):
        src = """
        deep(0, 0).
        deep(N, S) :-
            N > 0,
            N1 is N - 1,
            deep(N1, S1),
            S is S1 + 1.
        """
        small_limit_generator = ExampleGenerator(recursion_depth_limit=2)
        with self.assertRaises(RecursionDepthError):
            small_limit_generator.generate_examples(src, max_n=5)


if __name__ == "__main__":
    unittest.main()
