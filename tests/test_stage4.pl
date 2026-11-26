:- begin_tests(stage4_verification).

:- use_module('../src/stage4_verification').
:- use_module(library(clpfd)).

test(mathematical_induction_validates_sum_formula) :-
    mathematical_induction(stage4_verification:sum_formula_property, 200, checked_up_to(200)).

test(mathematical_induction_small_bound) :-
    mathematical_induction(stage4_verification:sum_formula_property, 25, checked_up_to(25)).

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
    mathematical_induction(property_with_false_base, 5, _).

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

test(sum_formula_proved_for_every_n) :-
    polynomial_induction(n*(n+1)/2, n, n, proved(base_case(0), inductive_step(degree(2), zero_at([0,1,2])))).

test(squares_formula_proved) :-
    polynomial_induction(n*(n+1)*(2*n+1)/6, n^2, n, proved(_, _)).

test(cubes_formula_proved) :-
    polynomial_induction((n*(n+1)/2)^2, n^3, n, proved(_, _)).

test(wrong_formula_not_proved) :-
    polynomial_induction(n*n/2, n, n, Outcome),
    assertion(Outcome == not_proved(inductive_step_fails)).

test(formula_matching_many_values_but_wrong_not_proved) :-
    % Agrees with n*(n+1)/2 at n = 0..5 but is not the sum formula.
    polynomial_induction(n*(n+1)/2 + n*(n-1)*(n-2)*(n-3)*(n-4)*(n-5), n, n, Outcome),
    assertion(Outcome == not_proved(inductive_step_fails)).

test(bad_base_case_not_proved) :-
    polynomial_induction(n*(n+1)/2 + 1, n, n, Outcome),
    assertion(Outcome == not_proved(base_case_not_zero)).

test(bounded_check_is_not_called_proved, [fail]) :-
    mathematical_induction(stage4_verification:sum_formula_property, 10, proved).

:- end_tests(stage4_verification).
