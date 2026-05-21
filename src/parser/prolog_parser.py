"""
Prolog-like Parser — Stage 1 of the Gaussian Theorem Prover pipeline.

Responsible for reading Prolog-like input and converting it into an
internal representation that the rest of the pipeline can consume.

Supports:
  - Facts:  predicate(Arg1, Arg2).
  - Rules:  Head :- Body.
  - Arithmetic:  X is Expr
  - Comparisons: N > 0, N >= 0
  - Recursive calls inside rule bodies

Internal representation (dict):
  {
    "predicate":  str,            # name, e.g. "sum"
    "arity":      int,            # number of *user-visible* arguments
    "input_var":  str | None,     # the counter/index argument, e.g. "N"
    "output_var": str | None,     # the result argument, e.g. "S"
    "base_cases": [               # one entry per fact / base-case clause
        {"input": value, "output": value}
    ],
    "recurrence": str,            # human-readable recurrence, e.g. "sum(n)=sum(n-1)+n"
    "base_case":  str,            # human-readable base case, e.g. "sum(0)=0"
  }
"""

import re
from fractions import Fraction
from typing import Any


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def _strip_comments(source: str) -> str:
    """Remove % line comments from Prolog source."""
    lines = []
    for line in source.splitlines():
        idx = line.find("%")
        if idx != -1:
            line = line[:idx]
        lines.append(line)
    return "\n".join(lines)


def _split_clauses(source: str) -> list[str]:
    """
    Split a Prolog program into individual clauses (terminated by '.').
    Handles multi-line clauses and skips blank/comment-only clauses.
    """
    # Keep original whitespace structure; only strip comments.
    source = _strip_comments(source)
    # Split on '.' that end a clause (not inside atoms/strings)
    raw = re.split(r"\.\s*(?=\n|$)", source)
    clauses = [c.strip() for c in raw if c.strip()]
    return clauses


def _parse_term(text: str):
    """
    Try to parse a term as an integer, Fraction, or leave it as a string.
    """
    text = text.strip()
    try:
        return int(text)
    except ValueError:
        pass
    try:
        return Fraction(text)
    except ValueError:
        pass
    return text


def _extract_head(clause: str):
    """
    Extract head from a clause (everything before ':-' or the whole clause).
    Returns (functor, args_list_str).
    """
    if ":-" in clause:
        head = clause.split(":-")[0].strip()
    else:
        head = clause.strip()

    m = re.match(r"([a-z][a-zA-Z0-9_]*)\s*\((.*)\)\s*$", head, re.DOTALL)
    if m:
        return m.group(1), _split_args(m.group(2))
    # Might be a bare atom with no args
    m2 = re.match(r"([a-z][a-zA-Z0-9_]*)\s*$", head)
    if m2:
        return m2.group(1), []
    return None, []


def _split_args(args_str: str) -> list[str]:
    """
    Split a comma-separated argument list respecting nested parentheses.
    """
    args = []
    depth = 0
    current = []
    for ch in args_str:
        if ch == "(":
            depth += 1
            current.append(ch)
        elif ch == ")":
            depth -= 1
            current.append(ch)
        elif ch == "," and depth == 0:
            args.append("".join(current).strip())
            current = []
        else:
            current.append(ch)
    if current:
        args.append("".join(current).strip())
    return [a for a in args if a]


def _split_body_goals(body: str) -> list[str]:
    """Split rule body into individual goals (comma-separated, depth-aware)."""
    return _split_args(body)


def _is_variable(token: str) -> bool:
    """Prolog variables start with an uppercase letter or underscore."""
    token = token.strip()
    return bool(token) and (token[0].isupper() or token[0] == "_")


def _is_numeric(token: str) -> bool:
    try:
        float(token)
        return True
    except (ValueError, TypeError):
        return False


# ---------------------------------------------------------------------------
# Arithmetic expression simplification (very lightweight symbolic layer)
# ---------------------------------------------------------------------------

def _simplify_arith(expr: str, var_map: dict) -> str:
    """
    Apply known variable substitutions to an arithmetic expression string
    and return a simplified human-readable string.

    var_map: {var_name: replacement_str}
    """
    # Replace variables longest-first to avoid partial substitution
    for var in sorted(var_map, key=len, reverse=True):
        expr = re.sub(r"\b" + re.escape(var) + r"\b", var_map[var], expr)
    return expr.strip()


# ---------------------------------------------------------------------------
# Core parser class
# ---------------------------------------------------------------------------

class PrologParser:
    """
    Parses a Prolog-like program defining a single recursive predicate and
    returns a structured internal representation.

    Usage::

        parser = PrologParser()
        result = parser.parse(source_code)
    """

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def parse(self, source: str) -> dict:
        """
        Parse *source* (a Prolog-like program string) and return an internal
        representation dict.

        Raises ``ValueError`` if the source cannot be parsed meaningfully.
        """
        clauses = _split_clauses(source)
        if not clauses:
            raise ValueError("No clauses found in source.")

        facts = []
        rules = []
        for clause in clauses:
            if ":-" in clause:
                rules.append(clause)
            else:
                facts.append(clause)

        if not facts and not rules:
            raise ValueError("No facts or rules found.")

        # Determine the primary predicate from the first clause
        first_clause = (facts + rules)[0]
        predicate, _ = _extract_head(first_clause)
        if predicate is None:
            raise ValueError(f"Cannot determine predicate from: {first_clause!r}")

        # Use rule head args (which have variable names) for arity/IO detection;
        # fall back to fact args when there are no rules.
        if rules:
            _, head_args = _extract_head(rules[0])
        else:
            _, head_args = _extract_head(facts[0])

        arity = len(head_args)

        # Identify which argument is the input (counter) and which is output (result)
        input_var, output_var = self._identify_io_vars(head_args, rules, predicate)

        # Parse base cases from facts (use rule head_args for positional mapping)
        base_cases = self._parse_base_cases(facts, predicate, input_var, output_var, head_args)

        # Parse the recurrence from rules
        recurrence_str, base_case_str = self._derive_recurrence(
            rules, predicate, input_var, output_var, base_cases
        )

        return {
            "predicate": predicate,
            "arity": arity,
            "input_var": input_var,
            "output_var": output_var,
            "base_cases": base_cases,
            "recurrence": recurrence_str,
            "base_case": base_case_str,
        }

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _identify_io_vars(
        self, head_args: list[str], rules: list[str], predicate: str
    ) -> tuple[str | None, str | None]:
        """
        Heuristically decide which argument is the *input* (counter) and
        which is the *output* (result).

        Strategy:
          1. The input variable usually appears in a guard like `N > 0` or
             in `N1 is N - 1` (decremented).
          2. The output variable usually appears in `S is ... + N` (accumulated).
          3. If there is only one variable argument, it is treated as input.
        """
        variables = [a for a in head_args if _is_variable(a)]
        constants = [a for a in head_args if not _is_variable(a)]

        if len(variables) == 0:
            return None, None
        if len(variables) == 1:
            return variables[0], None

        # With 2+ variables, look at the rule bodies
        input_score: dict[str, int] = {v: 0 for v in variables}
        output_score: dict[str, int] = {v: 0 for v in variables}

        for rule in rules:
            if ":-" not in rule:
                continue
            _, body_str = rule.split(":-", 1)
            goals = _split_body_goals(body_str)

            for goal in goals:
                goal = goal.strip()
                # Guard: N > 0  or  N >= 0  — typical for input counter
                m = re.match(r"([A-Z][a-zA-Z0-9_]*)\s*[>]=?\s*\d+", goal)
                if m and m.group(1) in input_score:
                    input_score[m.group(1)] += 2

                # Decrement: N1 is N - 1  → N is input
                m2 = re.match(
                    r"([A-Z][a-zA-Z0-9_]*)\s+is\s+([A-Z][a-zA-Z0-9_]*)\s*-\s*\d+",
                    goal,
                )
                if m2 and m2.group(2) in input_score:
                    input_score[m2.group(2)] += 3

                # Accumulate: S is S1 + N  → S is output, N is input
                m3 = re.match(
                    r"([A-Z][a-zA-Z0-9_]*)\s+is\s+(.+)",
                    goal,
                )
                if m3:
                    lhs = m3.group(1)
                    rhs = m3.group(2)
                    if lhs in output_score:
                        output_score[lhs] += 2
                    # Any var referenced on RHS in an accumulation
                    for v in variables:
                        if re.search(r"\b" + re.escape(v) + r"\b", rhs):
                            input_score[v] += 1

        best_input = max(input_score, key=lambda v: input_score[v])
        remaining = [v for v in variables if v != best_input]
        best_output = max(remaining, key=lambda v: output_score[v]) if remaining else None

        return best_input, best_output

    def _parse_base_cases(
        self,
        facts: list[str],
        predicate: str,
        input_var: str | None,
        output_var: str | None,
        head_args: list[str],
    ) -> list[dict]:
        """Extract base-case input→output pairs from Prolog facts."""
        base_cases = []
        for fact in facts:
            functor, args = _extract_head(fact)
            if functor != predicate:
                continue
            if len(args) != len(head_args):
                continue

            # Map fact arguments to input/output positions using the rule's
            # head variable order.  Fall back to position 0 (input) and
            # position 1 (output, or 0 if arity is 1) when variables are absent.
            input_idx = head_args.index(input_var) if input_var in head_args else 0
            if output_var in head_args:
                output_idx = head_args.index(output_var)
            else:
                output_idx = 1 if len(head_args) > 1 else 0

            input_val = _parse_term(args[input_idx]) if input_idx < len(args) else 0
            if not args:
                continue  # skip malformed facts with no arguments
            output_val = _parse_term(args[output_idx]) if output_idx < len(args) else _parse_term(args[0])

            base_cases.append({"input": input_val, "output": output_val})

        # Also look for base cases in rules whose guard is always false for
        # n > 0 (i.e., the rule handles n = 0 separately) — not required for
        # the minimal parser but structure is in place.
        return base_cases

    def _derive_recurrence(
        self,
        rules: list[str],
        predicate: str,
        input_var: str | None,
        output_var: str | None,
        base_cases: list[dict],
    ) -> tuple[str, str]:
        """
        Extract a human-readable recurrence string and base-case string.

        Returns (recurrence_str, base_case_str).
        """
        # Build base case string
        if base_cases:
            bc = base_cases[0]
            base_case_str = f"{predicate}({bc['input']})={bc['output']}"
        else:
            base_case_str = ""

        if not rules or input_var is None or output_var is None:
            return "", base_case_str

        # Analyse the first recursive rule
        rule = rules[0]
        _, body_str = rule.split(":-", 1)
        goals = _split_body_goals(body_str)

        # Collect IS assignments: var → expression
        assignments: dict[str, str] = {}
        for goal in goals:
            goal = goal.strip()
            m = re.match(r"([A-Z][a-zA-Z0-9_]*)\s+is\s+(.+)", goal)
            if m:
                assignments[m.group(1).strip()] = m.group(2).strip()

        # Find recursive call and its argument mapping
        rec_input_arg = None
        rec_output_arg = None
        for goal in goals:
            goal = goal.strip()
            m = re.match(
                r"([a-z][a-zA-Z0-9_]*)\s*\((.+)\)", goal, re.DOTALL
            )
            if m and m.group(1) == predicate:
                rec_args = _split_args(m.group(2))
                # Find which arg maps to input / output position
                head_functor, head_args_full = _extract_head(rule)
                input_idx = (
                    head_args_full.index(input_var)
                    if input_var in head_args_full
                    else 0
                )
                output_idx = (
                    head_args_full.index(output_var)
                    if output_var in head_args_full
                    else 1
                )
                if input_idx < len(rec_args):
                    rec_input_arg = rec_args[input_idx]
                if output_idx < len(rec_args):
                    rec_output_arg = rec_args[output_idx]
                break

        # Build human-readable recurrence
        # Substitute known auxiliary variables back toward n / s
        n = input_var.lower()

        # Express the recursive input in terms of n
        rec_input_expr = self._resolve_expr(
            rec_input_arg or "", assignments, input_var, n
        )

        # Express the output formula in terms of n and the recursive output
        output_expr_raw = assignments.get(output_var, "")
        if rec_output_arg:
            output_expr = self._resolve_expr(
                output_expr_raw, assignments, input_var, n,
                recursive_out_var=rec_output_arg,
                predicate=predicate,
                rec_input_expr=rec_input_expr,
            )
        else:
            output_expr = self._resolve_expr(
                output_expr_raw, assignments, input_var, n
            )

        if output_expr:
            recurrence_str = f"{predicate}({n})={output_expr}"
        elif rec_input_expr:
            recurrence_str = f"{predicate}({n})={predicate}({rec_input_expr})+?"
        else:
            recurrence_str = ""

        return recurrence_str, base_case_str

    def _resolve_expr(
        self,
        expr: str,
        assignments: dict[str, str],
        input_var: str,
        n: str,
        recursive_out_var: str | None = None,
        predicate: str = "",
        rec_input_expr: str = "",
        _visited: frozenset | None = None,
    ) -> str:
        """
        Recursively substitute auxiliary variables in *expr* to get a
        human-readable expression in terms of *n*.
        """
        if _visited is None:
            _visited = frozenset()

        if not expr:
            return expr

        # Replace recursive output variable with predicate(rec_input_expr)
        if recursive_out_var and predicate and rec_input_expr:
            expr = re.sub(
                r"\b" + re.escape(recursive_out_var) + r"\b",
                f"{predicate}({rec_input_expr})",
                expr,
            )

        # Substitute auxiliary variables (e.g. N1 → n-1)
        for var, val in assignments.items():
            if var in _visited:
                continue
            if var == input_var or var == recursive_out_var:
                continue
            if not re.search(r"\b" + re.escape(var) + r"\b", expr):
                continue
            resolved_val = self._resolve_expr(
                val, assignments, input_var, n,
                recursive_out_var=recursive_out_var,
                predicate=predicate,
                rec_input_expr=rec_input_expr,
                _visited=_visited | {var},
            )
            expr = re.sub(r"\b" + re.escape(var) + r"\b", resolved_val, expr)

        # Replace the input variable with n
        expr = re.sub(r"\b" + re.escape(input_var) + r"\b", n, expr)

        return expr.strip()
