:- begin_tests(stage5_proof_search).

:- use_module('../src/stage5_proof_search').

test(strategy_selection_for_sum_formula) :-
    select_strategy(sum_formula, context(200), Strategies),
    Strategies == [
        strategy(formula_then_verify, 100),
        strategy(direct_verification, 90),
        strategy(counterexample_guard, 40)
    ].

test(lemma_generation_uses_discovery_result) :-
    generate_lemmas(sum_formula, context(200), Lemmas),
    member(lemma(discovered_formula(sum, n*(n+1)/2)), Lemmas),
    member(lemma(counterexample_bound(200)), Lemmas).

test(heuristic_proof_search_builds_candidates) :-
    heuristic_proof_search(
        sum_formula,
        [strategy(direct_verification, 90), strategy(counterexample_guard, 40)],
        Candidates
    ),
    member(candidate(direct_verification, proved, 190, details(stage4_verification)), Candidates),
    member(candidate(counterexample_guard, proved_with_guard, 100, details(counterexample_scan(0-200))), Candidates).

test(rank_proofs_orders_by_score_descending) :-
    rank_proofs(
        [ candidate(alpha, failed, -10, none),
          candidate(beta, proved, 190, none),
          candidate(gamma, proved_with_guard, 100, none)
        ],
        Ranked
    ),
    Ranked == [
        candidate(beta, proved, 190, none),
        candidate(gamma, proved_with_guard, 100, none),
        candidate(alpha, failed, -10, none)
    ].

test(fallback_strategy_selects_first_successful_candidate) :-
    fallback_strategy(
        sum_formula,
        [candidate(primary, failed, 0, none), candidate(backup, proved_with_guard, 1, none)],
        [],
        Fallback
    ),
    Fallback == fallback(backup, [backup, primary], proved_with_guard, none).

test(fallback_strategy_reports_no_successful_candidate) :-
    fallback_strategy(
        sum_formula,
        [candidate(primary, failed, 0, none), candidate(backup, failed, -1, none)],
        [],
        Fallback
    ),
    Fallback == fallback(no_strategy, [backup, primary], failed, none).

test(universal_prove_acceptance_with_evidence) :-
    universal_prove(sum_formula, Result, Evidence),
    Result == proved,
    Evidence = evidence(
        strategies(_),
        lemmas(Lemmas),
        ranked_proofs([candidate(formula_then_verify, proved, _Score, _Details) | _]),
        fallback(fallback(formula_then_verify, _, proved, _)),
        best(candidate(formula_then_verify, proved, _BestScore, _BestDetails))
    ),
    member(lemma(discovered_formula(sum, n*(n+1)/2)), Lemmas).

test(universal_prove_acceptance_unary) :-
    universal_prove(sum_formula, Result),
    Result == proved.

:- end_tests(stage5_proof_search).
