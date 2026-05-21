:- module(stage4_verification,
          [ prove/1,
            prove/2,
            mathematical_induction/3,
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
    mathematical_induction(stage4_verification:sum_formula_property, MaxN, proved),
    structural_induction(stage4_verification:sum_list_formula_property, [[], [1], [1, 2], [1, 2, 3]], proved),
    resolution([[not(sum_formula), proven_by_induction], [sum_formula]], proven_by_induction),
    solve_constraints([N in MaxN..MaxN, S #= N*(N+1) div 2], [MaxN, _]),
    \+ counterexample_search(sum_formula_property, 0-MaxN, _).

mathematical_induction(Property, MaxN, proved) :-
    integer(MaxN),
    MaxN >= 0,
    call(Property, 0),
    forall(
        between(0, MaxN, K),
        inductive_implication(Property, K)
    ).

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
