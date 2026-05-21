:- begin_tests(stage4_verification).

:- use_module('../src/stage4_verification').
:- use_module(library(clpfd)).

test(mathematical_induction_sum_formula_property) :-
    mathematical_induction(stage4_verification:sum_formula_property, 25, proved).

test(structural_induction_sum_list_formula_property) :-
    structural_induction(stage4_verification:sum_list_formula_property, [[], [1], [1, 2], [1, 2, 3]], proved).

test(resolution_refutation_proves_query) :-
    resolution([[not(sum_formula), proven_by_induction], [sum_formula]], proven_by_induction).

test(constraint_solver_finds_sum_pair) :-
    solve_constraints([N in 5..5, S #= N*(N+1) div 2], Solution),
    Solution = [5, 15].

test(counterexample_search_finds_false_property_case) :-
    counterexample_search(sum_formula_property_off_by_one, 0-5, Counterexample),
    Counterexample == 0.

test(prove_sum_formula_acceptance) :-
    prove(sum_formula),
    prove(sum_formula, proved).

sum_formula_property_off_by_one(N) :-
    N >= 0,
    recursive_sum(N, Sum),
    Wrong is N*(N+1) // 2 + 1,
    Sum =:= Wrong.

recursive_sum(0, 0).
recursive_sum(N, Sum) :-
    N > 0,
    N1 is N - 1,
    recursive_sum(N1, Prev),
    Sum is Prev + N.

:- end_tests(stage4_verification).
