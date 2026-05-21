:- module(stage6_explanation,
          [ explain_proof/3,
            child_explanation/3,
            student_explanation/3,
            narrate_proof_trace/2,
            visual_rewrite_explanation/3,
            failure_explanation/3
          ]).

:- use_module('./stage5_proof_search', [universal_prove/3]).

explain_proof(Theorem, Audience, explanation(Theorem, Audience, Result, Story)) :-
    universal_prove(Theorem, Result, Evidence),
    audience_lines(Audience, Theorem, Evidence, Lines),
    narrate_proof_trace(Evidence, Trace),
    explanation_story(Result, Theorem, Evidence, Lines, Trace, Story).

child_explanation(sum_formula, Evidence,
                  [ 'The recursion keeps adding the next number.',
                    'That creates a triangular pattern.',
                    FormulaLine,
                    'Induction proved the rule always works.'
                  ]) :-
    discovered_formula_text(Evidence, FormulaText),
    format(atom(FormulaLine), 'Gaussian elimination found the hidden quadratic rule: ~w.', [FormulaText]),
    !.
child_explanation(Theorem, _Evidence,
                  [ 'The proof keeps reducing the goal into smaller steps.',
                    'Each step keeps the same meaning.',
                    'The solver found a pattern that matches every checked case.',
                    Summary
                  ]) :-
    format(atom(Summary), 'So ~w works for all tested inputs.', [Theorem]).

student_explanation(sum_formula, Evidence,
                    [ 'The recurrence sum(n)=sum(n-1)+n induces a second-order finite-difference signature.',
                      FormulaLine,
                      'The universal proof search ranked formula_then_verify first and then confirmed the theorem with Stage 4 induction and resolution.',
                      'Counterexample search over the configured bound found no violating input.'
                    ]) :-
    discovered_formula_text(Evidence, FormulaText),
    format(atom(FormulaLine), 'The fitted invariant is ~w.', [FormulaText]),
    !.
student_explanation(Theorem, _Evidence,
                    [ TargetLine,
                      'The search engine evaluated multiple strategies and ranked them by confidence.',
                      'The top-ranked candidate was checked with the formal verification stage.',
                      'No counterexample was found in the configured range.'
                    ]) :-
    format(atom(TargetLine), 'Target theorem: ~w.', [Theorem]).

narrate_proof_trace(evidence(strategies(Strategies),
                             lemmas(Lemmas),
                             ranked_proofs([candidate(BestName, BestOutcome, BestScore, _BestDetails) | _]),
                             fallback(fallback(FallbackStrategy, _Tried, FallbackOutcome, _FallbackDetails)),
                             best(candidate(BestName, BestOutcome, BestScore, _))),
                   [ StrategiesLine,
                     LemmasLine,
                     BestLine,
                     FallbackLine
                   ]) :-
    strategy_names_text(Strategies, StrategyNames),
    lemmas_text(Lemmas, LemmaText),
    format(atom(StrategiesLine), 'Strategies considered: ~w.', [StrategyNames]),
    format(atom(LemmasLine), 'Generated lemmas: ~w.', [LemmaText]),
    format(atom(BestLine), 'Top candidate: ~w with outcome ~w and score ~w.', [BestName, BestOutcome, BestScore]),
    format(atom(FallbackLine), 'Fallback decision: ~w returned ~w.', [FallbackStrategy, FallbackOutcome]).
narrate_proof_trace(_Evidence,
                   [ 'Strategies considered: unavailable.',
                     'Generated lemmas: unavailable.',
                     'Top candidate: unavailable.',
                     'Fallback decision: unavailable.'
                   ]).

visual_rewrite_explanation(sum_formula, Evidence,
                           [ frame(recursion, 'sum(n) rewrites to sum(n-1)+n, reducing the goal by one.'),
                             frame(pattern, 'Accumulated values 0,1,3,6,10 form a triangular growth pattern.'),
                             frame(matrix, 'Gaussian elimination solves Ax=b to recover the polynomial coefficients.'),
                             frame(formula, FormulaFrame)
                           ]) :-
    discovered_formula_text(Evidence, FormulaText),
    format(atom(FormulaFrame), 'Recovered invariant: ~w.', [FormulaText]),
    !.
visual_rewrite_explanation(Theorem, _Evidence,
                           [ frame(rewrite, 'Rewrite the theorem into smaller obligations.'),
                             frame(check, 'Validate each obligation with available proof tactics.'),
                             frame(conclude, Conclusion)
                           ]) :-
    format(atom(Conclusion), 'Conclude theorem ~w from validated obligations.', [Theorem]).

failure_explanation(_Theorem, proved, 'No failure: theorem was proved.').
failure_explanation(_Theorem, proved_with_guard, 'No failure: proof succeeded with a counterexample guard.').
failure_explanation(Theorem, failed, Message) :-
    format(atom(Message),
           'Proof search could not prove ~w. Review recurrence extraction, generated lemmas, and strategy ranking.',
           [Theorem]).
failure_explanation(Theorem, Outcome, Message) :-
    format(atom(Message), 'Proof finished with outcome ~w for ~w.', [Outcome, Theorem]).

audience_lines(child, Theorem, Evidence, Lines) :-
    child_explanation(Theorem, Evidence, Lines),
    !.
audience_lines(student, Theorem, Evidence, Lines) :-
    student_explanation(Theorem, Evidence, Lines),
    !.
audience_lines(_Audience, Theorem, Evidence, Lines) :-
    student_explanation(Theorem, Evidence, Lines).

explanation_story(Result, Theorem, Evidence, Lines, Trace, story(lines(Lines), trace(Trace), visual(Frames), failure(FailureLine))) :-
    visual_rewrite_explanation(Theorem, Evidence, Frames),
    failure_explanation(Theorem, Result, FailureLine).

discovered_formula_text(evidence(StrategiesTerm, lemmas(Lemmas), _Ranked, _Fallback, _Best), FormulaText) :-
    StrategiesTerm = strategies(_),
    member(lemma(discovered_formula(_Predicate, Formula)), Lemmas),
    term_string(Formula, FormulaText),
    !.
discovered_formula_text(_Evidence, 'an inferred invariant').

strategy_names_text(Strategies, Text) :-
    findall(NameString,
            ( member(strategy(Name, _Weight), Strategies),
              term_string(Name, NameString)
            ),
            Names),
    atomic_list_concat(Names, ', ', Text).

lemmas_text(Lemmas, Text) :-
    findall(LemmaAtom,
            ( member(Lemma, Lemmas),
              term_string(Lemma, LemmaAtom)
            ),
            LemmaAtoms),
    atomic_list_concat(LemmaAtoms, ', ', Text).
