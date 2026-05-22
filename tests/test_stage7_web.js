/**
 * tests/test_stage7_web.js
 *
 * Node.js tests for the Stage 7 Web/JavaScript pipeline.
 * Run with:  node tests/test_stage7_web.js
 */

'use strict';

const {
  Fraction,
  PrologParser,
  ExampleGenerator,
  GaussianElimination,
  PolynomialDiscovery,
  InductionProver,
  ExplanationGenerator,
} = require('../web/app.js');

/* ── Minimal test harness ── */
let passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) { console.log(`  ✓ ${msg}`); passed++; }
  else       { console.error(`  ✗ ${msg}`); failed++; }
}
function section(name) { console.log(`\n── ${name} ──`); }

/* ────────────────────────────────
   1. Fraction arithmetic
   ──────────────────────────────── */
section('Fraction arithmetic');
{
  const a = new Fraction(1n, 2n);
  const b = new Fraction(1n, 3n);
  assert(a.add(b).toString() === '5/6',   '1/2 + 1/3 = 5/6');
  assert(a.sub(b).toString() === '1/6',   '1/2 - 1/3 = 1/6');
  assert(a.mul(b).toString() === '1/6',   '1/2 × 1/3 = 1/6');
  assert(a.div(b).toString() === '3/2',   '1/2 ÷ 1/3 = 3/2');
  assert(a.neg().toString() === '-1/2',   'neg(1/2) = -1/2');
  assert(new Fraction(6n, 4n).toString() === '3/2', '6/4 reduces to 3/2');
  assert(new Fraction(0n).isZero(),       '0 is zero');
  assert(new Fraction(1n).isOne(),        '1 is one');
  assert(!a.isNeg(),                      '1/2 is not negative');
  assert(a.neg().isNeg(),                 '-1/2 is negative');
}

/* ────────────────────────────────
   2. PrologParser
   ──────────────────────────────── */
section('PrologParser');
{
  const parser = new PrologParser();

  // sum
  const sumSrc = `sum(0, 0).
sum(N, S) :-
    N > 0,
    N1 is N - 1,
    sum(N1, S1),
    S is S1 + N.`;
  const sumP = parser.parse(sumSrc);
  assert(sumP.predicate === 'sum',        'sum: predicate');
  assert(sumP.arity === 2,                'sum: arity 2');
  assert(sumP.inputVar === 'N',           'sum: inputVar = N');
  assert(sumP.outputVar === 'S',          'sum: outputVar = S');
  assert(sumP.baseCases.length === 1,     'sum: 1 base case');
  assert(sumP.baseCases[0].input  === 0,  'sum: base input = 0');
  assert(sumP.baseCases[0].output === 0,  'sum: base output = 0');

  // seq
  const seqSrc = `seq(0, 3).
seq(N, S) :-
    N > 0,
    N1 is N - 1,
    seq(N1, S1),
    S is S1 + 2.`;
  const seqP = parser.parse(seqSrc);
  assert(seqP.predicate === 'seq',        'seq: predicate');
  assert(seqP.baseCases[0].output === 3,  'seq: base output = 3');

  // square (no fact)
  const sqSrc = `square(N, S) :- S is N * N.`;
  const sqP = parser.parse(sqSrc);
  assert(sqP.predicate === 'square',      'square: predicate');
  assert(sqP.baseCases.length === 0,      'square: no fact base cases');
}

/* ────────────────────────────────
   3. ExampleGenerator
   ──────────────────────────────── */
section('ExampleGenerator');
{
  const gen = new ExampleGenerator();

  // sum
  const sumSrc = `sum(0, 0).
sum(N, S) :-
    N > 0,
    N1 is N - 1,
    sum(N1, S1),
    S is S1 + N.`;
  const sumE = gen.generate(sumSrc, 5);
  const sumVals = sumE.examples.map(e => e.output.toNumber());
  assert(JSON.stringify(sumVals) === '[0,1,3,6,10,15]', 'sum: examples 0..5');

  // seq
  const seqSrc = `seq(0, 3).
seq(N, S) :-
    N > 0,
    N1 is N - 1,
    seq(N1, S1),
    S is S1 + 2.`;
  const seqE = gen.generate(seqSrc, 4);
  const seqVals = seqE.examples.map(e => e.output.toNumber());
  assert(JSON.stringify(seqVals) === '[3,5,7,9,11]', 'seq: examples 0..4');

  // square
  const sqSrc = `square(N, S) :- S is N * N.`;
  const sqE = gen.generate(sqSrc, 4);
  const sqVals = sqE.examples.map(e => e.output.toNumber());
  assert(JSON.stringify(sqVals) === '[0,1,4,9,16]', 'square: examples 0..4');

  // factorial
  const factSrc = `fact(0, 1).
fact(N, F) :-
    N > 0,
    N1 is N - 1,
    fact(N1, F1),
    F is N * F1.`;
  const factE = gen.generate(factSrc, 5);
  const factVals = factE.examples.map(e => e.output.toNumber());
  assert(JSON.stringify(factVals) === '[1,1,2,6,24,120]', 'factorial: examples 0..5');
}

/* ────────────────────────────────
   4. GaussianElimination
   ──────────────────────────────── */
section('GaussianElimination');
{
  const ge = new GaussianElimination();

  // 2×3 matrix: n*x + 1*y = b  for degree-1 fit n=0,1
  // [0, 1 | 0]
  // [1, 1 | 1]
  const mat = [
    [new Fraction(0n), new Fraction(1n), new Fraction(0n)],
    [new Fraction(1n), new Fraction(1n), new Fraction(1n)],
  ];
  const res = ge.solve(mat);
  assert(res.status === 'solved', 'Gaussian: 2×2 solved');
  assert(res.solution[0].toString() === '1', 'Gaussian: a0 = 1');
  assert(res.solution[1].toString() === '0', 'Gaussian: a1 = 0');
  assert(res.steps.length > 0, 'Gaussian: steps recorded');

  // Singular matrix
  const sing = [
    [new Fraction(1n), new Fraction(2n), new Fraction(3n)],
    [new Fraction(2n), new Fraction(4n), new Fraction(6n)],
  ];
  const singRes = ge.solve(sing);
  assert(singRes.status === 'singular', 'Gaussian: singular detected');
}

/* ────────────────────────────────
   5. PolynomialDiscovery
   ──────────────────────────────── */
section('PolynomialDiscovery');
{
  const pd = new PolynomialDiscovery(4);
  const gen = new ExampleGenerator();

  // sum → degree 2, formula = 1/2*n^2 + 1/2*n
  const sumSrc = `sum(0, 0).
sum(N, S) :- N > 0, N1 is N - 1, sum(N1, S1), S is S1 + N.`;
  const sumE = gen.generate(sumSrc, 7);
  const sumP = pd.discover(sumE.examples);
  assert(sumP.status === 'found',          'sum: polynomial found');
  assert(sumP.degree === 2,                'sum: degree 2');
  assert(sumP.formula === '1/2*n^2 + 1/2*n', 'sum: formula correct');

  // seq → degree 1, formula = 2*n + 3
  const seqSrc = `seq(0, 3).
seq(N, S) :- N > 0, N1 is N - 1, seq(N1, S1), S is S1 + 2.`;
  const seqE = gen.generate(seqSrc, 7);
  const seqP = pd.discover(seqE.examples);
  assert(seqP.status === 'found',   'seq: polynomial found');
  assert(seqP.degree === 1,         'seq: degree 1');
  assert(seqP.formula === '2*n + 3','seq: formula correct');

  // square → degree 2, formula = n^2
  const sqSrc = `square(N, S) :- S is N * N.`;
  const sqE = gen.generate(sqSrc, 7);
  const sqP = pd.discover(sqE.examples);
  assert(sqP.status === 'found',  'square: polynomial found');
  assert(sqP.degree === 2,        'square: degree 2');
  assert(sqP.formula === 'n^2',   'square: formula n^2');

  // factorial → rejected
  const factSrc = `fact(0, 1).
fact(N, F) :- N > 0, N1 is N - 1, fact(N1, F1), F is N * F1.`;
  const factE = gen.generate(factSrc, 7);
  const factP = pd.discover(factE.examples);
  assert(factP.status === 'rejected', 'factorial: rejected (not polynomial)');
}

/* ────────────────────────────────
   6. InductionProver
   ──────────────────────────────── */
section('InductionProver');
{
  const pd = new PolynomialDiscovery(4);
  const gen = new ExampleGenerator();
  const prover = new InductionProver();

  const sumSrc = `sum(0, 0).
sum(N, S) :- N > 0, N1 is N - 1, sum(N1, S1), S is S1 + N.`;
  const sumE = gen.generate(sumSrc, 7);
  const sumPoly = pd.discover(sumE.examples);
  const proof = prover.prove(sumPoly, sumE.examples);
  assert(proof.status === 'proved',          'induction: sum proved');
  assert(proof.baseCase.ok,                  'induction: base case ok');
  assert(proof.stepChecks.every(s => s.ok),  'induction: all step checks ok');

  // Skipped when no formula
  const factSrc = `fact(0, 1).
fact(N, F) :- N > 0, N1 is N - 1, fact(N1, F1), F is N * F1.`;
  const factE = gen.generate(factSrc, 7);
  const factPoly = pd.discover(factE.examples);
  const factProof = prover.prove(factPoly, factE.examples);
  assert(factProof.status === 'skipped',     'induction: skipped for factorial');
}

/* ────────────────────────────────
   7. ExplanationGenerator
   ──────────────────────────────── */
section('ExplanationGenerator');
{
  const parser = new PrologParser();
  const gen    = new ExampleGenerator();
  const pd     = new PolynomialDiscovery(4);
  const prover = new InductionProver();
  const explainer = new ExplanationGenerator();

  const sumSrc = `sum(0, 0).
sum(N, S) :- N > 0, N1 is N - 1, sum(N1, S1), S is S1 + N.`;
  const parseR = parser.parse(sumSrc);
  const exData = gen.generate(sumSrc, 7);
  const polyR  = pd.discover(exData.examples);
  const proofR = prover.prove(polyR, exData.examples);
  const lines  = explainer.generate(parseR, exData.examples, polyR, proofR);

  assert(Array.isArray(lines) && lines.length > 0, 'explanation: returns lines');
  assert(lines.some(l => l.includes('sum')),        'explanation: mentions predicate');
  assert(lines.some(l => l.includes('induction')), 'explanation: mentions induction');
}

/* ── Summary ── */
console.log(`\n${'─'.repeat(40)}`);
console.log(`Tests complete: ${passed} passed, ${failed} failed.`);
if (failed > 0) process.exit(1);
