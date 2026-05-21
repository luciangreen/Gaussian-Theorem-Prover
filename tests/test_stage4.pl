:- begin_tests(stage4_verification).

:- use_module('../src/stage4_verification').
:- use_module(library(clpfd)).

test(mathematical_induction_validates_sum_formula) :-
    mathematical_induction(stage4_verification:sum_formula_property, 200, proved).

test(mathematical_induction_small_bound) :-
    mathematical_induction(stage4_verification:sum_formula_property, 25, proved).

test(structural_induction_validates_sum_list) :-
    structural_induction(stage4_verification:sum_list_formula_property, [[], [1], [1, 2], [1, 2, 3]], proved).

test(resolution_refutation_proves_query) :-
    resolution([[not(sum_formula), proven_by_induction], [sum_formula]], proven_by_induction).

test(constraint_solver_finds_sum_pair) :-
    solve_constraints([N in 5..5, S #= N*(N+1) div 2], Solution),
    Solution = [5, 15].

test(constraint_solver_handles_zero_edge_value) :-
    solve_constraints([N in 0..0, S #= N*(N+1) div 2], [0, 0]).

test(constraint_solver_handles_one_edge_value) :-
    solve_constraints([N in 1..1, S #= N*(N+1) div 2], [1, 1]).

test(counterexample_search_finds_off_by_one_error) :-
    counterexample_search(sum_formula_property_off_by_one, 0-5, Counterexample),
    between(0, 5, Counterexample),
    \+ sum_formula_property_off_by_one(Counterexample).

test(prove_sum_formula_acceptance) :-
    prove(sum_formula, proved).

test(prove_sum_formula_acceptance_unary) :-
    prove(sum_formula).

test(mathematical_induction_fails_on_base_case, [fail]) :-
    mathematical_induction(property_with_false_base, 5, proved).

test(structural_induction_fails_on_inductive_step, [fail]) :-
    structural_induction(property_with_bad_step, [[], [1], [1, 2]], proved).

sum_formula_property_off_by_one(N) :-
    N >= 0,
    recursive_sum(N, Sum),
    Wrong is N*(N+1) // 2 + 1,
    Sum =:= Wrong.

property_with_false_base(N) :-
    N > 0.

property_with_bad_step([]).
property_with_bad_step([1]).

recursive_sum(0, 0).
recursive_sum(N, Sum) :-
    N > 0,
    N1 is N - 1,
    recursive_sum(N1, Prev),
    Sum is Prev + N.

:- end_tests(stage4_verification).
