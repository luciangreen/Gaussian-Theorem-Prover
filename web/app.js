/* ============================================================
   Gaussian Theorem Prover — Web IDE  (Stage 7 of pr1.txt)
   Full pipeline implemented in pure JavaScript:
     Stage 1  — Prolog-like parser
     Stage 2  — Example generator
     Stages 3–4 — Polynomial discovery via Gaussian elimination
     Stage 5  — Induction-based proof verifier
     Stage 6  — Child-friendly explanation generator
   ============================================================ */

'use strict';

/* ─────────────────────────────────────────────────────────────
   1.  Exact rational arithmetic  (BigInt fractions)
   ───────────────────────────────────────────────────────────── */

function _gcd(a, b) {
  if (a < 0n) a = -a;
  if (b < 0n) b = -b;
  while (b !== 0n) { const t = b; b = a % b; a = t; }
  return a === 0n ? 1n : a;
}

class Fraction {
  constructor(num, den = 1n) {
    num = typeof num === 'bigint' ? num : BigInt(Math.trunc(Number(num)));
    den = typeof den === 'bigint' ? den : BigInt(Math.trunc(Number(den)));
    if (den === 0n) throw new Error('Division by zero');
    if (den < 0n) { num = -num; den = -den; }
    const g = _gcd(num < 0n ? -num : num, den);
    this.num = num / g;
    this.den = den / g;
  }
  static of(n) { return new Fraction(BigInt(n)); }
  add(o) { return new Fraction(this.num * o.den + o.num * this.den, this.den * o.den); }
  sub(o) { return new Fraction(this.num * o.den - o.num * this.den, this.den * o.den); }
  mul(o) { return new Fraction(this.num * o.num, this.den * o.den); }
  div(o) { return new Fraction(this.num * o.den, this.den * o.num); }
  neg()  { return new Fraction(-this.num, this.den); }
  abs()  { return new Fraction(this.num < 0n ? -this.num : this.num, this.den); }
  eq(o)  { return this.num === o.num && this.den === o.den; }
  isZero()  { return this.num === 0n; }
  isOne()   { return this.num === 1n && this.den === 1n; }
  isNeg()   { return this.num < 0n; }
  toNumber(){ return Number(this.num) / Number(this.den); }
  toString(){
    return this.den === 1n ? String(this.num) : `${this.num}/${this.den}`;
  }
  /** HTML-safe string (no special chars needed here, but kept for symmetry) */
  toHTML() { return this.toString(); }
}

const F0 = new Fraction(0n);
const F1 = new Fraction(1n);

/* ─────────────────────────────────────────────────────────────
   2.  Prolog source parser  (Stage 1)
   ───────────────────────────────────────────────────────────── */

function _stripComments(src) {
  return src.split('\n').map(line => {
    const i = line.indexOf('%');
    return i >= 0 ? line.slice(0, i) : line;
  }).join('\n');
}

function _splitClauses(src) {
  src = _stripComments(src);
  // split on '.' followed by optional whitespace and a newline / end-of-string
  const parts = src.split(/\.\s*(?=\n|$)/);
  return parts.map(p => p.trim()).filter(p => p.length > 0);
}

/**
 * Depth-aware comma split — respects nested parentheses.
 * Used for both argument lists and rule bodies.
 */
function _splitArgs(str) {
  const parts = [];
  let depth = 0, cur = '';
  for (const ch of str) {
    if      (ch === '(')                { depth++; cur += ch; }
    else if (ch === ')')                { depth--; cur += ch; }
    else if (ch === ',' && depth === 0) { parts.push(cur.trim()); cur = ''; }
    else                                { cur += ch; }
  }
  if (cur.trim()) parts.push(cur.trim());
  return parts;
}

/** Parse the head of a clause into {functor, args}. */
function _parseHead(clause) {
  let head = clause.includes(':-') ? clause.split(':-')[0].trim() : clause.trim();
  let m = head.match(/^([a-z][a-zA-Z0-9_]*)\s*\((.*)\)\s*$/s);
  if (m) return { functor: m[1], args: _splitArgs(m[2]) };
  m = head.match(/^([a-z][a-zA-Z0-9_]*)\s*$/);
  if (m) return { functor: m[1], args: [] };
  return { functor: null, args: [] };
}

function _isVariable(token) {
  token = token.trim();
  return token.length > 0 && /^[A-Z_]/.test(token);
}

function _parseTerm(token) {
  token = token.trim();
  const n = Number(token);
  return Number.isInteger(n) && String(n) === token ? n : token;
}

class PrologParser {
  /**
   * Parse a Prolog-like source string.
   * Returns { predicate, arity, inputVar, outputVar, baseCases, recurrence, baseCase }
   */
  parse(source) {
    const clauses = _splitClauses(source);
    if (!clauses.length) throw new Error('No clauses found in source.');

    const facts = [], rules = [];
    for (const c of clauses) {
      (c.includes(':-') ? rules : facts).push(c);
    }

    const first = (facts.length ? facts : rules)[0];
    const { functor: predicate } = _parseHead(first);
    if (!predicate) throw new Error('Cannot determine predicate name.');

    const headArgs = rules.length ? _parseHead(rules[0]).args : _parseHead(facts[0]).args;
    const arity = headArgs.length;

    const { inputVar, outputVar } = this._identifyIOVars(headArgs, rules);
    const baseCases = this._parseBaseCases(facts, predicate, inputVar, outputVar, headArgs);
    const { recurrence, baseCase } = this._deriveRecurrence(
      rules, predicate, inputVar, outputVar, baseCases
    );

    return { predicate, arity, inputVar, outputVar, baseCases, recurrence, baseCase };
  }

  _identifyIOVars(headArgs, rules) {
    const vars = headArgs.filter(_isVariable);
    if (!vars.length)    return { inputVar: null,    outputVar: null };
    if (vars.length === 1) return { inputVar: vars[0], outputVar: null };

    // Score variables by how they appear in rule bodies
    const inScore = {}, outScore = {};
    vars.forEach(v => { inScore[v] = 0; outScore[v] = 0; });

    for (const rule of rules) {
      if (!rule.includes(':-')) continue;
      const goals = _splitArgs(rule.split(':-')[1]);
      for (const g of goals) {
        const goal = g.trim();
        // Guard: N > 0  or  N >= 0
        let m = goal.match(/^([A-Z][a-zA-Z0-9_]*)\s*[>]=?\s*\d+/);
        if (m && m[1] in inScore) inScore[m[1]] += 2;
        // Decrement: N1 is N - 1  → N is input
        m = goal.match(/^([A-Z][a-zA-Z0-9_]*)\s+is\s+([A-Z][a-zA-Z0-9_]*)\s*-\s*\d+/);
        if (m && m[2] in inScore) inScore[m[2]] += 3;
        // Assignment: S is expr → S is output, vars on RHS score as input
        m = goal.match(/^([A-Z][a-zA-Z0-9_]*)\s+is\s+(.+)$/);
        if (m) {
          const [, lhs, rhs] = m;
          if (lhs in outScore) outScore[lhs] += 2;
          for (const v of vars) {
            if (new RegExp(`\\b${v}\\b`).test(rhs)) inScore[v] += 1;
          }
        }
      }
    }

    const bestIn  = vars.reduce((a, b) => inScore[a] >= inScore[b] ? a : b);
    const rest    = vars.filter(v => v !== bestIn);
    const bestOut = rest.length ? rest.reduce((a, b) => outScore[a] >= outScore[b] ? a : b) : null;
    return { inputVar: bestIn, outputVar: bestOut };
  }

  _parseBaseCases(facts, predicate, inputVar, outputVar, headArgs) {
    const cases = [];
    for (const fact of facts) {
      const { functor, args } = _parseHead(fact);
      if (functor !== predicate || args.length !== headArgs.length) continue;
      const iIdx = inputVar  && headArgs.includes(inputVar)  ? headArgs.indexOf(inputVar)  : 0;
      const oIdx = outputVar && headArgs.includes(outputVar) ? headArgs.indexOf(outputVar) : (headArgs.length > 1 ? 1 : 0);
      if (!args.length) continue;
      cases.push({ input: _parseTerm(args[iIdx] ?? '0'), output: _parseTerm(args[oIdx] ?? '0') });
    }
    return cases;
  }

  _deriveRecurrence(rules, predicate, inputVar, outputVar, baseCases) {
    const baseCase = baseCases.length
      ? `${predicate}(${baseCases[0].input}) = ${baseCases[0].output}`
      : '';

    if (!rules.length || !inputVar || !outputVar) return { recurrence: '', baseCase };

    const rule = rules[0];
    const goals = _splitArgs(rule.split(':-')[1]);
    const n = inputVar.toLowerCase();

    // Collect IS assignments
    const assign = {};
    for (const g of goals) {
      const m = g.trim().match(/^([A-Z][a-zA-Z0-9_]*)\s+is\s+(.+)$/);
      if (m) assign[m[1]] = m[2];
    }

    // Find recursive call
    const ruleArgs = _parseHead(rule).args;
    const iIdx = ruleArgs.includes(inputVar)  ? ruleArgs.indexOf(inputVar)  : 0;
    const oIdx = ruleArgs.includes(outputVar) ? ruleArgs.indexOf(outputVar) : 1;
    let recIn = null, recOut = null;
    for (const g of goals) {
      const m = g.trim().match(/^([a-z][a-zA-Z0-9_]*)\s*\((.+)\)/s);
      if (m && m[1] === predicate) {
        const ra = _splitArgs(m[2]);
        if (iIdx < ra.length) recIn  = ra[iIdx];
        if (oIdx < ra.length) recOut = ra[oIdx];
        break;
      }
    }

    let recStr = '';
    const outExpr = assign[outputVar] || '';
    if (outExpr && recOut) {
      // Express recursive input in terms of n
      const recInExpr = (recIn && assign[recIn])
        ? assign[recIn].replace(new RegExp(`\\b${inputVar}\\b`, 'g'), n)
        : (recIn || n);

      let expr = outExpr
        .replace(new RegExp(`\\b${recOut}\\b`, 'g'), `${predicate}(${recInExpr})`)
        .replace(new RegExp(`\\b${inputVar}\\b`, 'g'), n);

      // Substitute auxiliary variables
      for (const [v, val] of Object.entries(assign)) {
        if (v === inputVar || v === outputVar || v === recOut) continue;
        const resolved = val.replace(new RegExp(`\\b${inputVar}\\b`, 'g'), n);
        expr = expr.replace(new RegExp(`\\b${v}\\b`, 'g'), resolved);
      }
      recStr = `${predicate}(${n}) = ${expr}`;
    }

    return { recurrence: recStr, baseCase };
  }
}

/* ─────────────────────────────────────────────────────────────
   3.  Arithmetic expression evaluator
   ───────────────────────────────────────────────────────────── */

function _tokenize(expr) {
  const tokens = [];
  let i = 0;
  while (i < expr.length) {
    if (/\s/.test(expr[i])) { i++; continue; }
    if (/\d/.test(expr[i])) {
      let j = i;
      while (j < expr.length && /\d/.test(expr[j])) j++;
      tokens.push({ t: 'num', v: BigInt(expr.slice(i, j)) });
      i = j;
    } else if (/[A-Za-z_]/.test(expr[i])) {
      let j = i;
      while (j < expr.length && /[A-Za-z0-9_]/.test(expr[j])) j++;
      tokens.push({ t: 'id', v: expr.slice(i, j) });
      i = j;
    } else if (['+','-','*','/','(',')'].includes(expr[i])) {
      tokens.push({ t: 'op', v: expr[i] });
      i++;
    } else {
      throw new Error(`Unknown character '${expr[i]}' in expression`);
    }
  }
  return tokens;
}

class _ExprParser {
  constructor(tokens, env) { this.tk = tokens; this.i = 0; this.env = env; }
  peek()    { return this.tk[this.i]; }
  next()    { return this.tk[this.i++]; }
  parse()   { return this._addSub(); }
  _addSub() {
    let v = this._mulDiv();
    while (this.peek()?.v === '+' || this.peek()?.v === '-') {
      const op = this.next().v;
      const r = this._mulDiv();
      v = op === '+' ? v.add(r) : v.sub(r);
    }
    return v;
  }
  _mulDiv() {
    let v = this._unary();
    while (this.peek()?.v === '*' || this.peek()?.v === '/') {
      const op = this.next().v;
      const r = this._unary();
      v = op === '*' ? v.mul(r) : v.div(r);
    }
    return v;
  }
  _unary() {
    if (this.peek()?.v === '-') { this.next(); return this._primary().neg(); }
    if (this.peek()?.v === '+') { this.next(); }
    return this._primary();
  }
  _primary() {
    const tok = this.peek();
    if (!tok) throw new Error('Unexpected end of expression');
    if (tok.t === 'num') { this.next(); return new Fraction(tok.v); }
    if (tok.t === 'id')  {
      this.next();
      if (!(tok.v in this.env)) throw new Error(`Unbound variable: ${tok.v}`);
      const val = this.env[tok.v];
      return val instanceof Fraction ? val : new Fraction(BigInt(Math.trunc(val)));
    }
    if (tok.v === '(') {
      this.next();
      const v = this.parse();
      if (this.peek()?.v !== ')') throw new Error("Expected ')'");
      this.next();
      return v;
    }
    throw new Error(`Unexpected token: ${tok.v}`);
  }
}

function _evalExpr(expr, env) {
  return new _ExprParser(_tokenize(expr.trim()), env).parse();
}

/* ─────────────────────────────────────────────────────────────
   4.  Example generator  (Stage 2)
   ───────────────────────────────────────────────────────────── */

class ExampleGenerator {
  constructor(depthLimit = 60) { this.limit = depthLimit; }

  generate(source, maxN = 7) {
    const clauses = _splitClauses(source);
    const facts = [], rules = [];
    for (const c of clauses) {
      const h = _parseHead(c);
      if (c.includes(':-')) {
        rules.push({ predicate: h.functor, headArgs: h.args, body: _splitArgs(c.split(':-')[1]) });
      } else {
        facts.push({ predicate: h.functor, args: h.args.map(_parseTerm) });
      }
    }
    const predicate = (facts[0] ?? rules[0])?.predicate;
    if (!predicate) throw new Error('No predicate found.');

    const examples = [];
    for (let n = 0; n <= maxN; n++) {
      const out = this._eval(predicate, n, facts, rules, 0, new Set());
      examples.push({ input: n, output: out });
    }
    return { predicate, examples };
  }

  _eval(pred, n, facts, rules, depth, stack) {
    if (depth > this.limit) throw new Error('Recursion depth exceeded.');
    const key = `${pred}_${n}`;
    if (stack.has(key)) throw new Error(`Infinite recursion: ${pred}(${n})`);

    // Try facts first (base cases)
    for (const f of facts) {
      if (f.predicate === pred && f.args.length >= 2 && f.args[0] === n) {
        return Fraction.of(f.args[1]);
      }
    }

    // Try rules
    const matching = rules.filter(r => r.predicate === pred);
    if (!matching.length) throw new Error(`No rule for ${pred}(${n}).`);

    stack.add(key);
    try {
      for (const rule of matching) {
        if (rule.headArgs.length < 2) continue;
        const env = { [rule.headArgs[0]]: Fraction.of(n) };
        let ok = false;
        try {
          this._runGoals(rule.body, env, facts, rules, depth, stack);
          ok = true;
        } catch (e) {
          const msg = e.message || '';
          if (msg.startsWith('Recursion depth') || msg.startsWith('Infinite recursion')) throw e;
          // guard failure or unbound variable — try next rule
        }
        if (ok) {
          const outVar = rule.headArgs[1];
          if (outVar && outVar in env) return env[outVar];
        }
      }
    } finally {
      stack.delete(key);
    }
    throw new Error(`Cannot evaluate ${pred}(${n}).`);
  }

  _runGoals(goals, env, facts, rules, depth, stack) {
    for (const raw of goals) {
      const goal = raw.trim();
      if (!goal) continue;

      // Comparison: Var op Expr
      const cmp = goal.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*(>=|>|=<|<|=:=|=\\=)\s*(.+)$/);
      if (cmp) {
        const lv = _evalExpr(cmp[1], env).toNumber();
        const rv = _evalExpr(cmp[3], env).toNumber();
        const op = cmp[2];
        const ok =
          (op === '>'  && lv >  rv) || (op === '>=' && lv >= rv) ||
          (op === '<'  && lv <  rv) || (op === '=<' && lv <= rv) ||
          (op === '=:='&& lv === rv)|| (op === '=\\=' && lv !== rv);
        if (!ok) throw new Error('Guard failed');
        continue;
      }

      // Assignment: Var is Expr
      const asgn = goal.match(/^([A-Za-z_][A-Za-z0-9_]*)\s+is\s+(.+)$/);
      if (asgn) {
        env[asgn[1]] = _evalExpr(asgn[2], env);
        continue;
      }

      // Recursive call: pred(Arg, OutVar)
      const call = goal.match(/^([a-z][a-zA-Z0-9_]*)\s*\((.+)\)$/s);
      if (call) {
        const callArgs = _splitArgs(call[2]);
        if (callArgs.length < 2) throw new Error('Only arity-2 calls supported.');
        const inVal = _isVariable(callArgs[0])
          ? (callArgs[0] in env ? env[callArgs[0]] : (() => { throw new Error(`Unbound: ${callArgs[0]}`); })())
          : _evalExpr(callArgs[0], env);
        const result = this._eval(call[1], Math.trunc(inVal.toNumber()), facts, rules, depth + 1, stack);
        env[callArgs[1].trim()] = result;
        continue;
      }

      throw new Error(`Unsupported goal: ${goal}`);
    }
  }
}

/* ─────────────────────────────────────────────────────────────
   5.  Gaussian elimination  (Stage 4)
   ───────────────────────────────────────────────────────────── */

class GaussianElimination {
  /**
   * Solve a square augmented matrix using reduced row echelon form.
   * Returns { status, solution, initialMatrix, steps, finalMatrix }
   * Each step: { op, desc, matrix (snapshot after op), row, targetRow?, withRow?, factor? }
   */
  solve(matrix) {
    if (!matrix.length) throw new Error('Empty matrix.');
    const size = matrix.length;
    const cols = size + 1;
    if (matrix.some(r => r.length !== cols)) {
      throw new Error(`Expected ${size}×${cols} augmented matrix.`);
    }

    // Convert to Fraction
    const work = matrix.map(row =>
      row.map(v => v instanceof Fraction ? v : new Fraction(BigInt(Math.trunc(Number(v)))))
    );
    const initial = work.map(r => r.map(f => new Fraction(f.num, f.den)));
    const steps = [];

    const snap    = () => work.map(r => r.map(f => new Fraction(f.num, f.den)));
    const record  = (op, desc, extra) => steps.push({ op, desc, matrix: snap(), ...extra });

    for (let col = 0; col < size; col++) {
      // Find pivot
      let pivot = null;
      for (let r = col; r < size; r++) { if (!work[r][col].isZero()) { pivot = r; break; } }
      if (pivot === null) {
        return { status: 'singular', reason: `No pivot in column ${col + 1}.`,
                 initialMatrix: initial, steps, finalMatrix: snap(), solution: [] };
      }

      if (pivot !== col) {
        [work[col], work[pivot]] = [work[pivot], work[col]];
        record('swap',
          `Swap row ${col+1} with row ${pivot+1} to bring a non-zero pivot into position.`,
          { row: col, withRow: pivot });
      }

      const pv = work[col][col];
      if (!pv.isOne()) {
        const scale = F1.div(pv);
        work[col] = work[col].map(v => v.mul(scale));
        record('scale',
          `Scale row ${col+1} by ${scale} so the pivot becomes 1.`,
          { row: col, factor: scale });
      }

      for (let r = 0; r < size; r++) {
        if (r === col) continue;
        const fac = work[r][col];
        if (fac.isZero()) continue;
        for (let j = 0; j < cols; j++) {
          work[r][j] = work[r][j].sub(fac.mul(work[col][j]));
        }
        record('eliminate',
          `Subtract ${fac} × row ${col+1} from row ${r+1} to clear column ${col+1}.`,
          { row: col, targetRow: r, factor: fac });
      }
    }

    return {
      status: 'solved',
      solution: work.map(r => r[size]),
      initialMatrix: initial,
      steps,
      finalMatrix: work.map(r => r.map(f => new Fraction(f.num, f.den))),
    };
  }
}

/* ─────────────────────────────────────────────────────────────
   6.  Polynomial discovery  (Stage 3)
   ───────────────────────────────────────────────────────────── */

class PolynomialDiscovery {
  constructor(maxDegree = 4) {
    this.maxDegree = maxDegree;
    this.gauss = new GaussianElimination();
  }

  discover(examples) {
    const pts = examples.map(({ input, output }) => ({
      x: Fraction.of(input),
      y: output instanceof Fraction ? output : Fraction.of(Math.trunc(output.toNumber?.() ?? output)),
    }));

    const tried = [];
    for (let d = 0; d <= this.maxDegree; d++) {
      if (pts.length < d + 1) break;
      tried.push(d);
      const mat = this._buildMatrix(pts, d);
      const res = this.gauss.solve(mat);
      if (res.status !== 'solved') continue;
      const coeffs = res.solution;
      if (this._matchesAll(coeffs, pts)) {
        return {
          status: 'found',
          degree: d,
          coefficients: coeffs,
          formula: this._fmt(coeffs, d),
          matrix: mat,
          gaussianResult: res,
          triedDegrees: tried,
        };
      }
    }
    return { status: 'rejected', reason: `No polynomial fit up to degree ${this.maxDegree}.`, triedDegrees: tried };
  }

  _buildMatrix(pts, degree) {
    return pts.slice(0, degree + 1).map(({ x, y }) => {
      const row = [];
      for (let p = degree; p >= 0; p--) {
        let v = F1;
        for (let i = 0; i < p; i++) v = v.mul(x);
        row.push(v);
      }
      row.push(y);
      return row;
    });
  }

  _matchesAll(coeffs, pts) {
    return pts.every(({ x, y }) => this._evalPoly(coeffs, x).eq(y));
  }

  _evalPoly(coeffs, x) {
    let v = F0;
    for (const c of coeffs) v = v.mul(x).add(c);
    return v;
  }

  _fmt(coeffs, degree) {
    const terms = [];
    coeffs.forEach((c, i) => {
      if (c.isZero()) return;
      const power   = degree - i;
      const absC    = c.abs();
      const isOne   = absC.isOne();
      let term;
      if      (power === 0) term = absC.toString();
      else if (power === 1) term = isOne ? 'n' : `${absC}*n`;
      else                  term = isOne ? `n^${power}` : `${absC}*n^${power}`;

      if (!terms.length) terms.push(c.isNeg() ? `-${term}` : term);
      else               terms.push(c.isNeg() ? ` - ${term}` : ` + ${term}`);
    });
    return terms.length ? terms.join('') : '0';
  }
}

/* ─────────────────────────────────────────────────────────────
   7.  Induction proof verifier  (Stage 5)
   ───────────────────────────────────────────────────────────── */

class InductionProver {
  /**
   * Verify the polynomial formula by:
   *   (a) Checking the base case numerically.
   *   (b) Checking that p(n+1) − p(n) = f(n+1) − f(n) for every consecutive example pair.
   * Returns { status, baseCase, stepChecks, formula }
   */
  prove(polyResult, examples) {
    if (polyResult.status !== 'found') {
      return { status: 'skipped', reason: 'No polynomial formula to prove.' };
    }

    const { coefficients: coeffs, degree, formula } = polyResult;
    const poly = new PolynomialDiscovery();

    // Base case
    const bc = examples[0];
    const p0 = poly._evalPoly(coeffs, Fraction.of(bc.input));
    const f0 = bc.output instanceof Fraction ? bc.output : Fraction.of(bc.output);
    const bcOk = p0.eq(f0);

    // Inductive step: consecutive differences
    const stepChecks = [];
    let stepOk = true;
    for (let i = 0; i < examples.length - 1; i++) {
      const { input: n,  output: fn  } = examples[i];
      const { input: n1, output: fn1 } = examples[i + 1];
      const pn  = poly._evalPoly(coeffs, Fraction.of(n));
      const pn1 = poly._evalPoly(coeffs, Fraction.of(n1));
      const diffP = pn1.sub(pn);
      const fvN  = fn  instanceof Fraction ? fn  : Fraction.of(Math.trunc(fn));
      const fvN1 = fn1 instanceof Fraction ? fn1 : Fraction.of(Math.trunc(fn1));
      const diffF = fvN1.sub(fvN);
      const ok = diffP.eq(diffF);
      if (!ok) stepOk = false;
      stepChecks.push({ n, diffF: diffF.toString(), diffP: diffP.toString(), ok });
    }

    return {
      status: (bcOk && stepOk) ? 'proved' : 'failed',
      baseCase: { input: bc.input, expected: f0.toString(), computed: p0.toString(), ok: bcOk },
      stepChecks,
      formula,
      degree,
    };
  }
}

/* ─────────────────────────────────────────────────────────────
   8.  Explanation generator  (Stage 6)
   ───────────────────────────────────────────────────────────── */

class ExplanationGenerator {
  generate(parseResult, examples, polyResult, proofResult) {
    const { predicate, recurrence, baseCase } = parseResult;
    const lines = [];

    lines.push(`The program computes <strong>${predicate}(n)</strong> — a function that takes a number and returns a result.`);

    if (baseCase) {
      lines.push(`It starts at the base case: <strong>${baseCase}</strong>.`);
    }
    if (recurrence) {
      lines.push(`The recursive rule says: <strong>${recurrence}</strong>.`);
    }

    lines.push('');
    const exStr = examples.slice(0, 6).map(({ input, output }) =>
      `${predicate}(${input}) = ${output instanceof Fraction ? output : output}`
    ).join(',&nbsp; ');
    lines.push(`We ran the program to collect input-output pairs: ${exStr}, &hellip;`);

    lines.push('');
    if (polyResult.status === 'found') {
      const { formula, degree } = polyResult;
      lines.push(`By trying polynomials of degree 0, 1, 2, …, Gaussian elimination found a degree-${degree} formula:`);
      lines.push(`<strong>${predicate}(n) = ${formula}</strong>`);
      lines.push('Gaussian elimination works by setting up a grid of equations — one row per known value — then simplifying step by step until the hidden coefficients appear.');

      if (proofResult.status === 'proved') {
        lines.push('');
        lines.push('We used <strong>mathematical induction</strong> to prove the formula is always correct:');
        lines.push(`&bull; <strong>Base case:</strong> ${predicate}(${proofResult.baseCase.input}) = ${proofResult.baseCase.computed} ✓`);
        lines.push('&bull; <strong>Inductive step:</strong> the formula correctly predicts each successive value ✓');
        lines.push(`&bull; <strong>Conclusion:</strong> ${predicate}(n) = ${formula} for every n &ge; 0.`);
      } else if (proofResult.status === 'failed') {
        lines.push(`<em>Note: the formula was discovered but induction verification found a mismatch — please check manually.</em>`);
      }
    } else {
      lines.push(`<strong>No polynomial formula was found.</strong>`);
      lines.push(`The growth of <strong>${predicate}(n)</strong> is not polynomial — it may grow like a factorial, exponential, or other non-polynomial function.`);
      lines.push('Gaussian elimination tried degrees 0 through 4 and none of them fit all the examples exactly.');
      lines.push('A different proof method (such as multiplicative induction) would be needed here.');
    }

    lines.push('');
    lines.push('<em>Why Gaussian elimination?</em> It is the same method used to solve systems of simultaneous equations in school algebra — extended to find hidden patterns in sequences of numbers.');

    return lines;
  }
}

/* ─────────────────────────────────────────────────────────────
   9.  Preset programs
   ───────────────────────────────────────────────────────────── */

const PRESETS = {
  sum: `sum(0, 0).
sum(N, S) :-
    N > 0,
    N1 is N - 1,
    sum(N1, S1),
    S is S1 + N.`,

  seq: `% Arithmetic sequence starting at 3 with step 2
seq(0, 3).
seq(N, S) :-
    N > 0,
    N1 is N - 1,
    seq(N1, S1),
    S is S1 + 2.`,

  square: `% Direct definition — no recursion needed
square(N, S) :-
    S is N * N.`,

  factorial: `% Factorial grows faster than any polynomial
fact(0, 1).
fact(N, F) :-
    N > 0,
    N1 is N - 1,
    fact(N1, F1),
    F is N * F1.`,
};

function loadPreset(name) {
  const src = PRESETS[name];
  if (src) document.getElementById('source-input').value = src;
  // Hide results so the user knows they need to re-run
  document.getElementById('results').classList.add('hidden');
  _setStatus('Preset loaded — click Run to analyse.', '');
}

/* ─────────────────────────────────────────────────────────────
   10. Matrix stepper state
   ───────────────────────────────────────────────────────────── */

let _matrixData  = null;   // { degree, initialMatrix, steps, finalMatrix }
let _matrixIdx   = -1;     // -1 = initial matrix; 0..n = after step n

function _initMatrixStepper(polyResult) {
  const gr = polyResult.gaussianResult;
  _matrixData = {
    degree:        polyResult.degree,
    initialMatrix: gr.initialMatrix,
    steps:         gr.steps,
    finalMatrix:   gr.finalMatrix,
  };
  _matrixIdx = -1;
  _renderMatrixStep(-1);
}

function prevStep() {
  if (_matrixIdx > -1) { _matrixIdx--; _renderMatrixStep(_matrixIdx); }
}
function nextStep() {
  if (_matrixData && _matrixIdx < _matrixData.steps.length - 1) {
    _matrixIdx++;
    _renderMatrixStep(_matrixIdx);
  }
}

function _renderMatrixStep(idx) {
  if (!_matrixData) return;
  const { degree, initialMatrix, steps } = _matrixData;
  const total = steps.length;

  // Select matrix snapshot and step metadata
  let mat, desc, pivotRow = -1, targetRow = -1, activeRows = [];
  if (idx < 0) {
    mat  = initialMatrix;
    desc = `Initial coefficient matrix for degree-${degree} polynomial fitting`;
  } else {
    const step = steps[idx];
    mat  = step.matrix;
    desc = step.desc;
    if (step.op === 'eliminate') { pivotRow = step.row; targetRow = step.targetRow; }
    else if (step.op === 'swap') { activeRows = [step.row, step.withRow]; }
    else if (step.op === 'scale'){ activeRows = [step.row]; }
  }

  // Build column headers
  const numCols = mat[0].length;
  const headers = [];
  for (let p = degree; p >= 0; p--) {
    if      (p === 0) headers.push('1');
    else if (p === 1) headers.push('n');
    else              headers.push(`n<sup>${p}</sup>`);
  }
  headers.push('f(n)');

  // Build table HTML
  let tbl = '<thead><tr>';
  headers.forEach((h, j) => {
    tbl += `<th${j === numCols - 1 ? ' class="aug"' : ''}>${h}</th>`;
  });
  tbl += '</tr></thead><tbody>';

  mat.forEach((row, i) => {
    let cls = '';
    if      (i === pivotRow)              cls = 'row-pivot';
    else if (i === targetRow)             cls = 'row-target';
    else if (activeRows.includes(i))      cls = 'row-active';
    tbl += `<tr${cls ? ` class="${cls}"` : ''}>`;
    row.forEach((cell, j) => {
      tbl += `<td${j === numCols - 1 ? ' class="aug"' : ''}>${cell instanceof Fraction ? cell.toString() : cell}</td>`;
    });
    tbl += '</tr>';
  });
  tbl += '</tbody>';

  document.getElementById('matrix-table').innerHTML = tbl;
  document.getElementById('step-desc').textContent = desc;
  document.getElementById('step-info').textContent =
    idx < 0 ? `Step 0 / ${total} — initial` : `Step ${idx + 1} / ${total}`;
  document.getElementById('btn-prev').disabled = idx <= -1;
  document.getElementById('btn-next').disabled = idx >= total - 1;
}

/* ─────────────────────────────────────────────────────────────
   11. UI rendering helpers
   ───────────────────────────────────────────────────────────── */

function _setStatus(msg, cls) {
  const el = document.getElementById('status-bar');
  el.textContent = msg;
  el.className = cls || '';
}

function _renderParse(p) {
  const dl = document.createElement('dl');
  dl.className = 'info-grid';
  const rows = [
    ['Predicate',    p.predicate],
    ['Arity',        String(p.arity)],
    ['Input var',    p.inputVar  || '—'],
    ['Output var',   p.outputVar || '—'],
    ['Base case(s)', p.baseCases.map(bc => `${p.predicate}(${bc.input}) = ${bc.output}`).join(';  ') || '—'],
    ['Recurrence',   p.recurrence || '—'],
  ];
  for (const [k, v] of rows) {
    dl.innerHTML += `<dt>${k}</dt><dd>${_esc(v)}</dd>`;
  }
  document.getElementById('parse-result').replaceChildren(dl);
}

function _renderExamples(exData) {
  const { predicate, examples } = exData;
  let html = `<table class="examples-table"><thead><tr><th>n</th><th>${_esc(predicate)}(n)</th></tr></thead><tbody>`;
  for (const { input, output } of examples) {
    const outStr = output instanceof Fraction ? output.toString() : String(output);
    html += `<tr><td>${input}</td><td>${_esc(outStr)}</td></tr>`;
  }
  html += '</tbody></table>';
  document.getElementById('examples-result').innerHTML = html;
}

function _renderMatrix(polyResult) {
  const container = document.getElementById('matrix-result');
  if (polyResult.status === 'rejected') {
    container.innerHTML = '<p style="color:var(--danger)">No polynomial fit found — Gaussian elimination not applicable.</p>';
    return;
  }

  container.innerHTML = `
    <div class="step-controls">
      <button class="btn btn-secondary btn-sm" id="btn-prev" onclick="prevStep()" disabled>◀ Prev</button>
      <span class="step-info" id="step-info"></span>
      <button class="btn btn-secondary btn-sm" id="btn-next" onclick="nextStep()">Next ▶</button>
    </div>
    <div class="step-desc" id="step-desc"></div>
    <div class="matrix-scroll">
      <table class="matrix-table" id="matrix-table"></table>
    </div>`;

  _initMatrixStepper(polyResult);
}

function _renderFormula(polyResult) {
  const el = document.getElementById('formula-result');
  if (polyResult.status === 'rejected') {
    el.innerHTML = `
      <div class="formula-box rejected">No polynomial formula found</div>
      <p style="font-size:.9rem;color:var(--text-muted)">${_esc(polyResult.reason)}</p>`;
    return;
  }

  const { formula, degree, coefficients } = polyResult;
  // Build coefficient table
  let cTbl = '<table class="coeff-table"><thead><tr>';
  for (let i = 0; i <= degree; i++) {
    const p = degree - i;
    cTbl += `<th>a<sub>${p}</sub> (n<sup>${p}</sup> term)</th>`;
  }
  cTbl += '</tr></thead><tbody><tr>';
  coefficients.forEach(c => { cTbl += `<td>${c.toString()}</td>`; });
  cTbl += '</tr></tbody></table>';

  el.innerHTML = `
    <div class="formula-box">f(n) = ${_esc(formula)}</div>
    <p style="font-size:.88rem;color:var(--text-muted);margin-bottom:.5rem">
      Degree-${degree} polynomial — coefficients (highest power first):
    </p>
    ${cTbl}`;
}

function _renderProof(proofResult) {
  const el = document.getElementById('proof-result');

  if (proofResult.status === 'skipped') {
    el.innerHTML = `<span class="proof-badge skipped">⟲ Skipped — ${_esc(proofResult.reason)}</span>`;
    return;
  }

  const { baseCase, stepChecks, formula } = proofResult;
  let html = '';

  // Base case
  html += `<div class="proof-section">
    <h3>Base case</h3>
    <div class="proof-row ${baseCase.ok ? 'step-ok' : 'step-fail'}">
      <span class="icon">${baseCase.ok ? '✓' : '✗'}</span>
      <span>f(${baseCase.input}) = ${_esc(baseCase.expected)}, formula gives ${_esc(baseCase.computed)} ${baseCase.ok ? '✓' : '✗'}</span>
    </div>
  </div>`;

  // Inductive step
  html += `<div class="proof-section"><h3>Inductive step — consecutive differences</h3>`;
  for (const sc of stepChecks.slice(0, 7)) {
    html += `<div class="proof-row ${sc.ok ? 'step-ok' : 'step-fail'}">
      <span class="icon">${sc.ok ? '✓' : '✗'}</span>
      <span>n=${sc.n}: f(n+1)−f(n) = ${_esc(sc.diffF)}, formula gives ${_esc(sc.diffP)} ${sc.ok ? '✓' : '✗'}</span>
    </div>`;
  }
  html += '</div>';

  // Conclusion
  const proved = proofResult.status === 'proved';
  html += `<div>
    <span class="proof-badge ${proved ? 'proved' : 'failed'}">
      ${proved ? '✓ Proved by induction' : '✗ Proof failed'}
    </span>`;
  if (proved) {
    html += `<p style="font-size:.9rem;margin-top:.6rem">
      Therefore <strong>f(n) = ${_esc(formula)}</strong> for all n ≥ 0.
    </p>`;
  }
  html += '</div>';

  el.innerHTML = html;
}

function _renderExplanation(lines) {
  const html = lines
    .map(l => l === '' ? '<br>' : `<p>${l}</p>`)
    .join('');
  document.getElementById('explanation-result').innerHTML =
    `<div class="explanation-text">${html}</div>`;
}

function _esc(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/* ─────────────────────────────────────────────────────────────
   12. Main pipeline entry point
   ───────────────────────────────────────────────────────────── */

function runPipeline() {
  const source = document.getElementById('source-input').value.trim();
  if (!source) { _setStatus('Please enter a program.', 'err'); return; }

  document.getElementById('results').classList.add('hidden');
  document.getElementById('run-btn').disabled = true;
  _setStatus('Running…', '');

  // Run asynchronously so the browser can repaint first
  setTimeout(() => {
    try {
      // Stage 1 — Parse
      const parser = new PrologParser();
      const parseResult = parser.parse(source);

      // Stage 2 — Examples
      const gen = new ExampleGenerator();
      const exData = gen.generate(source, 7);

      // Stages 3–4 — Polynomial discovery
      const pd = new PolynomialDiscovery(4);
      const polyResult = pd.discover(exData.examples);

      // Stage 5 — Induction proof
      const prover = new InductionProver();
      const proofResult = prover.prove(polyResult, exData.examples);

      // Stage 6 — Explanation
      const explainer = new ExplanationGenerator();
      const lines = explainer.generate(parseResult, exData.examples, polyResult, proofResult);

      // Render all sections
      _renderParse(parseResult);
      _renderExamples(exData);
      _renderMatrix(polyResult);
      _renderFormula(polyResult);
      _renderProof(proofResult);
      _renderExplanation(lines);

      document.getElementById('results').classList.remove('hidden');

      const formulaMsg = polyResult.status === 'found'
        ? `Formula found: f(n) = ${polyResult.formula}`
        : 'No polynomial formula — see explanation.';
      _setStatus(formulaMsg, polyResult.status === 'found' ? 'ok' : '');
    } catch (err) {
      _setStatus(`Error: ${err.message}`, 'err');
      console.error(err);
    } finally {
      document.getElementById('run-btn').disabled = false;
    }
  }, 10);
}

/* ─────────────────────────────────────────────────────────────
   Node.js compatibility shim — allows unit testing with require()
   ───────────────────────────────────────────────────────────── */
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    Fraction,
    PrologParser,
    ExampleGenerator,
    GaussianElimination,
    PolynomialDiscovery,
    InductionProver,
    ExplanationGenerator,
  };
}
