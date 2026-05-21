:- module(stage5_proof_search,
          [ universal_prove/2,
            universal_prove/3,
            select_strategy/3,
            heuristic_proof_search/3,
            generate_lemmas/3,
            rank_proofs/2,
            fallback_strategy/4
          ]).

:- use_module('./stage3_discovery', [discover_formula/2]).
:- use_module('./stage4_verification', [prove/2, counterexample_search/3]).
:- use_module(library(pairs)).

universal_prove(Theorem, Result) :-
    universal_prove(Theorem, Result, _Evidence).

universal_prove(Theorem, Result,
                evidence(strategies(Strategies),
                         lemmas(Lemmas),
                         ranked_proofs(RankedProofs),
                         fallback(Fallback),
                         best(BestProof))) :-
    default_context(Context),
    select_strategy(Theorem, Context, Strategies),
    generate_lemmas(Theorem, Context, Lemmas),
    heuristic_proof_search(Theorem, Strategies, Candidates),
    rank_proofs(Candidates, RankedProofs),
    fallback_strategy(Theorem, RankedProofs, [], Fallback),
    best_candidate(RankedProofs, BestProof),
    resolve_final_result(BestProof, Fallback, Result).

default_context(context(200)).

select_strategy(sum_formula, _Context,
                [ strategy(formula_then_verify, 100),
                  strategy(direct_verification, 90),
                  strategy(counterexample_guard, 40)
                ]) :-
    !.
select_strategy(_Theorem, _Context,
                [ strategy(direct_verification, 90),
                  strategy(counterexample_guard, 40)
                ]).

generate_lemmas(sum_formula, context(CounterexampleBound), Lemmas) :-
    discover_formula(sum, Formula),
    Lemmas = [ lemma(discovered_formula(sum, Formula)),
               lemma(counterexample_bound(CounterexampleBound))
             ],
    !.
generate_lemmas(Theorem, context(CounterexampleBound),
                [ lemma(target(Theorem)),
                  lemma(counterexample_bound(CounterexampleBound))
                ]).

heuristic_proof_search(Theorem, Strategies, Candidates) :-
    maplist(execute_strategy(Theorem), Strategies, Candidates).

execute_strategy(Theorem, strategy(Name, Weight), candidate(Name, Outcome, Score, Details)) :-
    strategy_result(Name, Theorem, Outcome, Details),
    score_for_outcome(Outcome, Weight, Score).

strategy_result(formula_then_verify, Theorem, proved,
                details(formula(Formula), stage4_verification)) :-
    discoverable_theorem(Theorem),
    discover_formula(sum, Formula),
    prove(Theorem, proved),
    !.
strategy_result(formula_then_verify, _Theorem, failed, details(not_applicable)).

strategy_result(direct_verification, Theorem, Outcome, details(stage4_verification)) :-
    (   prove(Theorem, proved)
    ->  Outcome = proved
    ;   Outcome = failed
    ).

strategy_result(counterexample_guard, Theorem, Outcome,
                details(counterexample_scan(0-Bound))) :-
    theorem_property(Theorem, Property),
    verification_bound(Bound),
    (   counterexample_search(Property, 0-Bound, _)
    ->  Outcome = failed
    ;   Outcome = proved_with_guard
    ),
    !.
strategy_result(counterexample_guard, _Theorem, failed, details(not_applicable)).

theorem_property(sum_formula, sum_formula_property).

score_for_outcome(proved, Weight, Score) :-
    Score is Weight + 100.
score_for_outcome(proved_with_guard, Weight, Score) :-
    Score is Weight + 60.
score_for_outcome(failed, Weight, Score) :-
    Score is Weight - 100.

rank_proofs(Candidates, Ranked) :-
    map_list_to_pairs(candidate_score, Candidates, Pairs),
    keysort(Pairs, SortedAscending),
    reverse(SortedAscending, SortedDescending),
    pairs_values(SortedDescending, Ranked).

candidate_score(candidate(_Name, _Outcome, Score, _Details), Score).

fallback_strategy(_Theorem, [], Tried,
                  fallback(no_strategy, Tried, failed, none)).
fallback_strategy(Theorem, [candidate(Name, Outcome, _Score, Details) | Rest], Tried, Fallback) :-
    NextTried = [Name | Tried],
    (   successful_outcome(Outcome)
    ->  Fallback = fallback(Name, NextTried, Outcome, Details)
    ;   fallback_strategy(Theorem, Rest, NextTried, Fallback)
    ).

successful_outcome(proved).
successful_outcome(proved_with_guard).

best_candidate([Best | _], Best) :-
    !.
best_candidate([], candidate(none, failed, 0, none)).

resolve_final_result(candidate(_Name, Outcome, _Score, _Details), _Fallback, Outcome) :-
    successful_outcome(Outcome),
    !.
resolve_final_result(_Best,
                     fallback(_Strategy, _Tried, Outcome, _Details),
                     Outcome).

sum_formula_property(N) :-
    integer(N),
    N >= 0,
    recursive_sum_local(N, Sum),
    compute_triangular_value(N, Formula),
    Sum =:= Formula.

recursive_sum_local(0, 0).
recursive_sum_local(N, Sum) :-
    N > 0,
    N1 is N - 1,
    recursive_sum_local(N1, Prev),
    Sum is Prev + N.

verification_bound(200).

discoverable_theorem(sum_formula).

compute_triangular_value(N, Value) :-
    Value is N*(N+1) // 2.
