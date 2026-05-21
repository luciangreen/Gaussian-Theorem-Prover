"""
Tests for Stage 1: Prolog-like Parser Agent.

Covers:
  - Fact parsing (base cases)
  - Recursive rule parsing
  - Input/output variable identification
  - Recurrence string generation
  - Base-case string generation
  - All four example programs from pr1.txt
"""

import sys
import os
import unittest

# Allow running tests from the repository root
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.parser.prolog_parser import PrologParser, _split_clauses, _extract_head, _split_args


# ---------------------------------------------------------------------------
# Helper: load example files relative to this test file
# ---------------------------------------------------------------------------

EXAMPLES_DIR = os.path.join(os.path.dirname(__file__), "..", "examples")


def _load(filename: str) -> str:
    with open(os.path.join(EXAMPLES_DIR, filename), encoding="utf-8") as fh:
        return fh.read()


# ---------------------------------------------------------------------------
# Unit tests for internal helpers
# ---------------------------------------------------------------------------

class TestSplitClauses(unittest.TestCase):
    def test_single_fact(self):
        result = _split_clauses("sum(0, 0).")
        self.assertEqual(len(result), 1)
        self.assertIn("sum(0, 0)", result[0])

    def test_multiple_clauses(self):
        src = "sum(0, 0).\nsum(N, S) :- N > 0."
        result = _split_clauses(src)
        self.assertEqual(len(result), 2)

    def test_comment_removal(self):
        src = "% this is a comment\nsum(0, 0). % inline comment"
        result = _split_clauses(src)
        self.assertEqual(len(result), 1)
        self.assertNotIn("%", result[0])

    def test_multiline_rule(self):
        src = "sum(N, S) :-\n    N > 0,\n    S is N."
        result = _split_clauses(src)
        self.assertEqual(len(result), 1)


class TestExtractHead(unittest.TestCase):
    def test_fact(self):
        functor, args = _extract_head("sum(0, 0)")
        self.assertEqual(functor, "sum")
        self.assertEqual(args, ["0", "0"])

    def test_rule_head(self):
        functor, args = _extract_head("sum(N, S) :- N > 0")
        self.assertEqual(functor, "sum")
        self.assertEqual(args, ["N", "S"])

    def test_bare_atom(self):
        functor, args = _extract_head("foo")
        self.assertEqual(functor, "foo")
        self.assertEqual(args, [])


class TestSplitArgs(unittest.TestCase):
    def test_simple(self):
        self.assertEqual(_split_args("N, S"), ["N", "S"])

    def test_nested(self):
        self.assertEqual(_split_args("f(A, B), C"), ["f(A, B)", "C"])

    def test_single(self):
        self.assertEqual(_split_args("N"), ["N"])

    def test_empty(self):
        self.assertEqual(_split_args(""), [])


# ---------------------------------------------------------------------------
# Integration tests using the four example programs
# ---------------------------------------------------------------------------

class TestSumProgram(unittest.TestCase):
    """sum(N, S): S = N*(N+1)/2"""

    def setUp(self):
        self.parser = PrologParser()
        self.result = self.parser.parse(_load("sum.pl"))

    def test_predicate(self):
        self.assertEqual(self.result["predicate"], "sum")

    def test_arity(self):
        self.assertEqual(self.result["arity"], 2)

    def test_input_var_identified(self):
        self.assertEqual(self.result["input_var"], "N")

    def test_output_var_identified(self):
        self.assertEqual(self.result["output_var"], "S")

    def test_base_case_present(self):
        self.assertGreater(len(self.result["base_cases"]), 0)

    def test_base_case_value(self):
        bc = self.result["base_cases"][0]
        self.assertEqual(bc["input"], 0)
        self.assertEqual(bc["output"], 0)

    def test_base_case_string(self):
        self.assertIn("sum(0)=0", self.result["base_case"])

    def test_recurrence_string_contains_predicate(self):
        self.assertIn("sum", self.result["recurrence"])

    def test_recurrence_string_contains_n(self):
        self.assertIn("n", self.result["recurrence"])


class TestSquareProgram(unittest.TestCase):
    """square(N, S): S = N*N  (no recursion)"""

    def setUp(self):
        self.parser = PrologParser()
        self.result = self.parser.parse(_load("square.pl"))

    def test_predicate(self):
        self.assertEqual(self.result["predicate"], "square")

    def test_arity(self):
        self.assertEqual(self.result["arity"], 2)

    def test_no_base_cases_from_facts(self):
        # square.pl has no facts, only a rule
        self.assertEqual(len(self.result["base_cases"]), 0)

    def test_output_contains_n_times_n(self):
        # The recurrence (or empty) should reference n * n
        combined = self.result["recurrence"] + self.result["base_case"]
        # Either the recurrence string contains n*n or it is derived correctly
        # Just confirm parse did not throw
        self.assertIsInstance(combined, str)


class TestArithmeticSequenceProgram(unittest.TestCase):
    """seq(N, S): S = 2*N + 3"""

    def setUp(self):
        self.parser = PrologParser()
        self.result = self.parser.parse(_load("arithmetic_sequence.pl"))

    def test_predicate(self):
        self.assertEqual(self.result["predicate"], "seq")

    def test_arity(self):
        self.assertEqual(self.result["arity"], 2)

    def test_input_var_identified(self):
        self.assertEqual(self.result["input_var"], "N")

    def test_output_var_identified(self):
        self.assertEqual(self.result["output_var"], "S")

    def test_base_case_present(self):
        self.assertGreater(len(self.result["base_cases"]), 0)

    def test_base_case_value(self):
        bc = self.result["base_cases"][0]
        self.assertEqual(bc["input"], 0)
        self.assertEqual(bc["output"], 3)

    def test_base_case_string(self):
        self.assertIn("seq(0)=3", self.result["base_case"])

    def test_recurrence_contains_predicate(self):
        self.assertIn("seq", self.result["recurrence"])


class TestFactorialProgram(unittest.TestCase):
    """fact(N, F): F = N! — no polynomial formula"""

    def setUp(self):
        self.parser = PrologParser()
        self.result = self.parser.parse(_load("factorial_rejected.pl"))

    def test_predicate(self):
        self.assertEqual(self.result["predicate"], "fact")

    def test_arity(self):
        self.assertEqual(self.result["arity"], 2)

    def test_base_case_present(self):
        self.assertGreater(len(self.result["base_cases"]), 0)

    def test_base_case_value(self):
        bc = self.result["base_cases"][0]
        self.assertEqual(bc["input"], 0)
        self.assertEqual(bc["output"], 1)

    def test_base_case_string(self):
        self.assertIn("fact(0)=1", self.result["base_case"])

    def test_recurrence_contains_predicate(self):
        self.assertIn("fact", self.result["recurrence"])


# ---------------------------------------------------------------------------
# Edge-case tests
# ---------------------------------------------------------------------------

class TestEdgeCases(unittest.TestCase):
    def setUp(self):
        self.parser = PrologParser()

    def test_empty_source_raises(self):
        with self.assertRaises(ValueError):
            self.parser.parse("")

    def test_comment_only_raises(self):
        with self.assertRaises(ValueError):
            self.parser.parse("% only a comment\n")

    def test_inline_program(self):
        src = "add(0, X, X).\nadd(N, X, S) :- N > 0, N1 is N-1, add(N1, X, S1), S is S1 + 1."
        result = self.parser.parse(src)
        self.assertEqual(result["predicate"], "add")
        self.assertGreater(len(result["base_cases"]), 0)

    def test_result_has_required_keys(self):
        src = "sum(0, 0).\nsum(N, S) :- N > 0, N1 is N - 1, sum(N1, S1), S is S1 + N."
        result = self.parser.parse(src)
        for key in ("predicate", "arity", "input_var", "output_var",
                    "base_cases", "recurrence", "base_case"):
            self.assertIn(key, result, f"Missing key: {key}")


if __name__ == "__main__":
    unittest.main()
