:- module(stage4_verification,
          [ prove/1,
            prove/2,
            mathematical_induction/3,
            polynomial_induction/4,
            structural_induction/3,
            resolution/2,
            solve_constraints/2,
            counterexample_search/3
          ]).

:- use_module('./stage3_discovery', [discover_formula/2]).
:- use_module(library(clpfd)).

prove(Theorem) :-
    prove(Theorem, proved).

prove(sum_formula, proved) :-
    verification_bound(MaxN),
    discover_formula(sum, n*(n+1)/2),
    % The proof: base case and inductive step for every n (polynomial_induction/4).
    polynomial_induction(n*(n+1)/2, n, n, proved(_)),
    % Further checks of the program itself on the first values.
    mathematical_induction(stage4_verification:sum_formula_property, MaxN, checked_up_to(MaxN)),
    structural_induction(stage4_verification:sum_list_formula_property, [[], [1], [1, 2], [1, 2, 3]], proved),
    resolution([[not(sum_formula), proven_by_induction], [sum_formula]], proven_by_induction),
    solve_constraints([N in MaxN..MaxN, S #= N*(N+1) div 2], [MaxN, _]),
    \+ counterexample_search(sum_formula_property, 0-MaxN, _).

%% mathematical_induction(+Property, +MaxN, -Outcome)
%% Checks the property for 0 and for each step from K to K+1 up to MaxN.
%% This is a bounded check, not a proof for every n, so the outcome is
%% checked_up_to(MaxN). polynomial_induction/4 gives the proof.
mathematical_induction(Property, MaxN, checked_up_to(MaxN)) :-
    integer(MaxN),
    MaxN >= 0,
    call(Property, 0),
    forall(
        between(0, MaxN, K),
        inductive_implication(Property, K)
    ).

%% polynomial_induction(+Formula, +Term, +Var, -Outcome)
%% Proves that Formula(Var) is the sum of Term(i) for i from 1 to Var, for
%% every natural number Var, by induction:
%%   base case:      Formula(0) = 0, the empty sum;
%%   inductive step: Formula(Var+1) - Formula(Var) = Term(Var+1) for all Var.
%% Both sides of the step are polynomials in Var of degree at most D (the
%% degree of Formula), so their difference is a polynomial of degree at most
%% D. A polynomial of degree at most D that is zero at D+1 distinct points is
%% zero everywhere, so checking the step exactly (with fractions) at
%% Var = 0, ..., D proves it for all Var. Outcome is
%% proved(base_case(0), inductive_step(degree(D), zero_at(Points))) or
%% not_proved(Reason).
polynomial_induction(Formula, Term, Var, Outcome) :-
    (   poly_degree(Formula, Var, D),
        poly_degree(Term, Var, DT)
    ->  (   r_eval(Formula, Var, r(0, 1), r(F0, _)), F0 =\= 0
        ->  Outcome = not_proved(base_case_not_zero)
        ;   Deg is max(D, DT + 1),
            numlist(0, Deg, Points),
            (   forall(member(K, Points),
                       ( K1 is K + 1,
                         r_eval(Formula, Var, r(K1, 1), A),
                         r_eval(Formula, Var, r(K, 1), B),
                         r_eval(Term, Var, r(K1, 1), C),
                         r_sub(A, B, Diff),
                         r_eq(Diff, C) ))
            ->  Outcome = proved(base_case(0), inductive_step(degree(Deg), zero_at(Points)))
            ;   Outcome = not_proved(inductive_step_fails)
            )
        )
    ;   Outcome = not_proved(not_a_polynomial)
    ).

% Degree of a polynomial expression in Var (fails if it is not one).
poly_degree(X, Var, 1) :- X == Var, !.
poly_degree(X, _, 0) :- number(X), !.
poly_degree(A+B, V, D) :- !, poly_degree(A, V, DA), poly_degree(B, V, DB), D is max(DA, DB).
poly_degree(A-B, V, D) :- !, poly_degree(A, V, DA), poly_degree(B, V, DB), D is max(DA, DB).
poly_degree(-A, V, D) :- !, poly_degree(A, V, D).
poly_degree(A*B, V, D) :- !, poly_degree(A, V, DA), poly_degree(B, V, DB), D is DA + DB.
poly_degree(A/B, V, D) :- !, poly_degree(B, V, 0), poly_degree(A, V, D).
poly_degree(A^K, V, D) :- integer(K), K >= 0, !, poly_degree(A, V, DA), D is DA * K.

% Exact evaluation with fractions r(Numerator, Denominator).
r_eval(X, Var, Value, Value) :- X == Var, !.
r_eval(X, _, _, r(X, 1)) :- integer(X), !.
r_eval(A+B, V, X, R) :- !, r_eval(A, V, X, RA), r_eval(B, V, X, RB), r_add(RA, RB, R).
r_eval(A-B, V, X, R) :- !, r_eval(A, V, X, RA), r_eval(B, V, X, RB), r_sub(RA, RB, R).
r_eval(-A, V, X, R) :- !, r_eval(A, V, X, RA), r_sub(r(0, 1), RA, R).
r_eval(A*B, V, X, R) :- !, r_eval(A, V, X, RA), r_eval(B, V, X, RB), r_mul(RA, RB, R).
r_eval(A/B, V, X, R) :- !, r_eval(A, V, X, RA), r_eval(B, V, X, r(BN, BD)), BN =\= 0, r_mul(RA, r(BD, BN), R).
r_eval(A^K, V, X, R) :- integer(K), K >= 0, !, r_eval(A, V, X, RA), r_pow(RA, K, R).

r_norm(r(N, D), r(N1, D1)) :- G is gcd(N, D), ( D < 0 -> S = -1 ; S = 1 ), N1 is S*N // G, D1 is S*D // G.
r_add(r(A, B), r(C, D), R) :- N is A*D + C*B, M is B*D, r_norm(r(N, M), R).
r_sub(r(A, B), r(C, D), R) :- N is A*D - C*B, M is B*D, r_norm(r(N, M), R).
r_mul(r(A, B), r(C, D), R) :- N is A*C, M is B*D, r_norm(r(N, M), R).
r_pow(_, 0, r(1, 1)) :- !.
r_pow(R, K, P) :- K1 is K - 1, r_pow(R, K1, P1), r_mul(R, P1, P).
r_eq(r(A, B), r(C, D)) :- A*D =:= C*B.

structural_induction(Property, Samples, proved) :-
    is_list(Samples),
    call(Property, []),
    forall(
        member(Structure, Samples),
        structural_chain(Property, Structure)
    ).

resolution(Clauses, Query) :-
    negate_literal(Query, NegatedQuery),
    normalize_clauses([[NegatedQuery] | Clauses], Normalized),
    resolution_refutation(Normalized).

solve_constraints(Constraints, Solution) :-
    is_list(Constraints),
    term_variables(Constraints, Vars),
    maplist(call, Constraints),
    labeling([], Vars),
    Solution = Vars.

counterexample_search(Property, Min-Max, Counterexample) :-
    integer(Min),
    integer(Max),
    Min =< Max,
    between(Min, Max, Candidate),
    \+ call(Property, Candidate),
    Counterexample = Candidate,
    !.

sum_formula_property(N) :-
    integer(N),
    N >= 0,
    recursive_sum(N, Sum),
    Formula is N*(N+1) // 2,
    Sum =:= Formula.

sum_list_formula_property(List) :-
    is_list(List),
    prefix_interval(List, 1),
    list_sum(List, Sum),
    length(List, N),
    Formula is N*(N+1) // 2,
    Sum =:= Formula.

recursive_sum(0, 0).
recursive_sum(N, Sum) :-
    N > 0,
    N1 is N - 1,
    recursive_sum(N1, Prev),
    Sum is Prev + N.

prefix_interval([], _).
prefix_interval([Head | Tail], Expected) :-
    Head =:= Expected,
    NextExpected is Expected + 1,
    prefix_interval(Tail, NextExpected).

list_sum(List, Sum) :-
    foldl(plus_acc, List, 0, Sum).

plus_acc(Value, AccIn, AccOut) :-
    AccOut is AccIn + Value.

extend_successor_structure(List, Extended) :-
    length(List, Len),
    NextValue is Len + 1,
    append(List, [NextValue], Extended).

inductive_implication(Property, K) :-
    call(Property, K),
    K1 is K + 1,
    call(Property, K1).

structural_chain(Property, Structure) :-
    length(Structure, Depth),
    structural_chain_depth(Property, Depth, []).

structural_chain_depth(Property, 0, Current) :-
    call(Property, Current).
structural_chain_depth(Property, Depth, Current) :-
    Depth > 0,
    call(Property, Current),
    extend_successor_structure(Current, Next),
    call(Property, Next),
    NextDepth is Depth - 1,
    structural_chain_depth(Property, NextDepth, Next).

normalize_clauses(Clauses, Normalized) :-
    maplist(sort, Clauses, SortedPerClause),
    sort(SortedPerClause, Normalized).

resolution_refutation(Clauses) :-
    member([], Clauses),
    !.
resolution_refutation(Clauses) :-
    select(C1, Clauses, Remaining),
    member(C2, Remaining),
    resolve_clauses(C1, C2, Resolvent),
    \+ member(Resolvent, Clauses),
    normalize_clauses([Resolvent | Clauses], NextClauses),
    resolution_refutation(NextClauses).

resolve_clauses(C1, C2, Resolvent) :-
    member(Literal, C1),
    negate_literal(Literal, Negated),
    member(Negated, C2),
    select(Literal, C1, Rest1),
    select(Negated, C2, Rest2),
    append(Rest1, Rest2, Combined),
    sort(Combined, Candidate),
    \+ tautology(Candidate),
    Resolvent = Candidate.

tautology(Clause) :-
    member(Lit, Clause),
    negate_literal(Lit, Negated),
    member(Negated, Clause),
    !.

negate_literal(not(Literal), Literal) :- !.
negate_literal(Literal, not(Literal)).

verification_bound(200).
