:- begin_tests(stage6_explanation).

:- use_module('../src/stage6_explanation').

test(child_explanation_for_sum_formula_mentions_quadratic_rule) :-
    ExampleEvidence = evidence(
        strategies([]),
        lemmas([lemma(discovered_formula(sum, n*(n+1)/2))]),
        ranked_proofs([]),
        fallback(fallback(no_strategy, [], failed, none)),
        best(candidate(none, failed, 0, none))
    ),
    child_explanation(sum_formula, ExampleEvidence, Lines),
    member('The recursion keeps adding the next number.', Lines),
    member('That creates a triangular pattern.', Lines),
    member(Line, Lines),
    sub_atom(Line, _, _, _, 'hidden quadratic rule').

test(student_explanation_for_sum_formula_mentions_invariant) :-
    ExampleEvidence = evidence(
        strategies([]),
        lemmas([lemma(discovered_formula(sum, n*(n+1)/2))]),
        ranked_proofs([]),
        fallback(fallback(no_strategy, [], failed, none)),
        best(candidate(none, failed, 0, none))
    ),
    student_explanation(sum_formula, ExampleEvidence, Lines),
    member(Line, Lines),
    sub_atom(Line, _, _, _, 'fitted invariant').

test(narrate_proof_trace_summarizes_best_and_fallback) :-
    Evidence = evidence(
        strategies([strategy(formula_then_verify, 100), strategy(direct_verification, 90)]),
        lemmas([lemma(discovered_formula(sum, n*(n+1)/2))]),
        ranked_proofs([candidate(formula_then_verify, proved, 200, details(stage4_verification))]),
        fallback(fallback(formula_then_verify, [formula_then_verify], proved, details(stage4_verification))),
        best(candidate(formula_then_verify, proved, 200, details(stage4_verification)))
    ),
    narrate_proof_trace(Evidence, Trace),
    member('Top candidate: formula_then_verify with outcome proved and score 200.', Trace),
    member('Fallback decision: formula_then_verify returned proved.', Trace).

test(visual_rewrite_explanation_returns_formula_frame) :-
    Evidence = evidence(
        strategies([]),
        lemmas([lemma(discovered_formula(sum, n*(n+1)/2))]),
        ranked_proofs([]),
        fallback(fallback(no_strategy, [], failed, none)),
        best(candidate(none, failed, 0, none))
    ),
    visual_rewrite_explanation(sum_formula, Evidence, Frames),
    member(frame(formula, FormulaFrame), Frames),
    sub_atom(FormulaFrame, _, _, _, 'Recovered invariant').

test(failure_explanation_handles_failed_outcome) :-
    failure_explanation(sum_formula, failed, Message),
    sub_atom(Message, _, _, _, 'could not prove sum_formula').

test(explain_proof_acceptance_student) :-
    explain_proof(sum_formula, student, Explanation),
    Explanation = explanation(
        sum_formula,
        student,
        proved,
        story(lines(Lines), trace(Trace), visual(Frames), failure('No failure: theorem was proved.'))
    ),
    member(Line, Lines),
    sub_atom(Line, _, _, _, 'fitted invariant'),
    member('Top candidate: formula_then_verify with outcome proved and score 200.', Trace),
    member(frame(formula, _), Frames).

test(explain_proof_acceptance_child) :-
    explain_proof(sum_formula, child, explanation(sum_formula, child, proved, story(lines(Lines), trace(_), visual(_), failure(_)))),
    member('That creates a triangular pattern.', Lines).

:- end_tests(stage6_explanation).
