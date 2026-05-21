"""Example Generation Agent (Stage 2)."""

from __future__ import annotations

import ast
import re
from fractions import Fraction
from typing import Any

from src.parser.prolog_parser import _extract_head, _split_args, _split_clauses


class NonTerminationError(RuntimeError):
    """Raised when recursive evaluation appears non-terminating."""


class RecursionDepthError(RuntimeError):
    """Raised when recursion depth exceeds configured limit."""


def _parse_term(token: str) -> Any:
    token = token.strip()
    if re.match(r"^-?\d+$", token):
        return int(token)
    return token


def _is_variable(token: str) -> bool:
    return bool(token) and (token[0].isupper() or token[0] == "_")


class _SafeExprEvaluator(ast.NodeVisitor):
    def __init__(self, env: dict[str, Any]):
        self.env = env

    def visit_Expression(self, node: ast.Expression) -> Any:
        return self.visit(node.body)

    def visit_Name(self, node: ast.Name) -> Any:
        if node.id not in self.env:
            raise ValueError(f"Unknown variable in expression: {node.id}")
        return self.env[node.id]

    def visit_Constant(self, node: ast.Constant) -> Any:
        if isinstance(node.value, (int, float)):
            if isinstance(node.value, float):
                return Fraction(str(node.value))
            return node.value
        raise ValueError(f"Unsupported constant: {node.value!r}")

    def visit_UnaryOp(self, node: ast.UnaryOp) -> Any:
        operand = self.visit(node.operand)
        if isinstance(node.op, ast.USub):
            return -operand
        if isinstance(node.op, ast.UAdd):
            return operand
        raise ValueError("Unsupported unary operation")

    def visit_BinOp(self, node: ast.BinOp) -> Any:
        left = self.visit(node.left)
        right = self.visit(node.right)
        if isinstance(node.op, ast.Add):
            return left + right
        if isinstance(node.op, ast.Sub):
            return left - right
        if isinstance(node.op, ast.Mult):
            return left * right
        if isinstance(node.op, ast.Div):
            return Fraction(left, right)
        raise ValueError("Unsupported binary operation")

    def generic_visit(self, node: ast.AST):
        raise ValueError(f"Unsupported expression node: {type(node).__name__}")


def _eval_expr(expr: str, env: dict[str, Any]) -> Any:
    tree = ast.parse(expr, mode="eval")
    return _SafeExprEvaluator(env).visit(tree)


def _split_goals(body: str) -> list[str]:
    return _split_args(body)


class ExampleGenerator:
    def __init__(self, recursion_depth_limit: int = 50):
        self.recursion_depth_limit = recursion_depth_limit

    def generate_examples(self, source: str, max_n: int = 5) -> dict[str, Any]:
        facts, rules = self._parse_program(source)
        if not facts and not rules:
            raise ValueError("No clauses found")

        predicate = (facts or rules)[0]["predicate"]
        examples = []
        for n in range(0, max_n + 1):
            out = self._evaluate(predicate, n, facts, rules, depth=0, call_stack=set())
            examples.append({"input": n, "output": out})
        return {"predicate": predicate, "examples": examples}

    def _parse_program(self, source: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
        facts: list[dict[str, Any]] = []
        rules: list[dict[str, Any]] = []
        for clause in _split_clauses(source):
            if ":-" in clause:
                head, body = clause.split(":-", 1)
                predicate, args = _extract_head(head.strip())
                rules.append({"predicate": predicate, "head_args": args, "body": _split_goals(body)})
            else:
                predicate, args = _extract_head(clause.strip())
                facts.append({"predicate": predicate, "args": [_parse_term(a) for a in args]})
        return facts, rules

    def _evaluate(
        self,
        predicate: str,
        n: int,
        facts: list[dict[str, Any]],
        rules: list[dict[str, Any]],
        depth: int,
        call_stack: set[tuple[str, int]],
    ) -> Any:
        if depth > self.recursion_depth_limit:
            raise RecursionDepthError("Recursion depth limit exceeded")
        state = (predicate, n)
        if state in call_stack:
            raise NonTerminationError(f"Detected recursive loop at {predicate}({n})")

        for fact in facts:
            if fact["predicate"] == predicate and len(fact["args"]) >= 2 and fact["args"][0] == n:
                return fact["args"][1]

        candidate_rules = [r for r in rules if r["predicate"] == predicate]
        if not candidate_rules:
            raise ValueError(f"No rule or fact can evaluate {predicate}({n})")

        for rule in candidate_rules:
            head_args = rule["head_args"]
            if len(head_args) < 2:
                continue
            env: dict[str, Any] = {}
            env[head_args[0]] = n

            try:
                call_stack.add(state)
                self._run_goals(rule["body"], env, predicate, facts, rules, depth, call_stack)
            except NonTerminationError:
                call_stack.discard(state)
                raise
            except RecursionDepthError:
                call_stack.discard(state)
                raise
            except ValueError:
                call_stack.discard(state)
                continue
            finally:
                call_stack.discard(state)

            out_var = head_args[1]
            if out_var in env:
                return env[out_var]

        raise ValueError(f"No matching rule body succeeded for {predicate}({n})")

    def _run_goals(
        self,
        goals: list[str],
        env: dict[str, Any],
        predicate: str,
        facts: list[dict[str, Any]],
        rules: list[dict[str, Any]],
        depth: int,
        call_stack: set[tuple[str, int]],
    ) -> None:
        for raw_goal in goals:
            goal = raw_goal.strip()
            if not goal:
                continue

            m_cmp = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*(>=|>|=<|<|=:=|=\\=)\s*(.+)$", goal)
            if m_cmp:
                left = _eval_expr(m_cmp.group(1), env)
                right = _eval_expr(m_cmp.group(3), env)
                op = m_cmp.group(2)
                ok = (
                    (op == ">" and left > right)
                    or (op == ">=" and left >= right)
                    or (op == "<" and left < right)
                    or (op == "=<" and left <= right)
                    or (op == "=:=" and left == right)
                    or (op == "=\\=" and left != right)
                )
                if not ok:
                    raise ValueError("Comparison failed")
                continue

            m_is = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s+is\s+(.+)$", goal)
            if m_is:
                lhs, expr = m_is.group(1), m_is.group(2)
                env[lhs] = _eval_expr(expr, env)
                continue

            m_call = re.match(r"^([a-z][a-zA-Z0-9_]*)\s*\((.*)\)$", goal)
            if m_call:
                pred_name = m_call.group(1)
                args = _split_args(m_call.group(2))
                if len(args) < 2:
                    raise ValueError("Only arity-2 predicate calls supported in stage 2")
                in_arg = args[0]
                out_arg = args[1]

                in_value = _eval_expr(in_arg, env) if not _is_variable(in_arg) else env[in_arg]
                rec_value = self._evaluate(pred_name, int(in_value), facts, rules, depth + 1, call_stack)
                env[out_arg] = rec_value
                continue

            raise ValueError(f"Unsupported goal: {goal}")
