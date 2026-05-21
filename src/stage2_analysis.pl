:- module(stage2_analysis,
          [ extract_recurrence/3,
            generate_call_graph/2,
            termination_heuristic/3,
            generate_examples/4,
            example_program/1
          ]).

extract_recurrence(Clauses, Pred, recurrence(Pred, base(BaseN, BaseValue), step(n, rec(n-Delta)+n))) :-
    predicate_clause(Clauses, Pred, BaseClause),
    base_clause(BaseClause, BaseN, BaseValue),
    predicate_clause(Clauses, Pred, RecursiveClause),
    recursive_step_clause(Pred, RecursiveClause, Delta).

generate_call_graph(Clauses, Edges) :-
    findall(edge(Caller, Callee),
            ( member(clause(Head, Body), Clauses),
              pred_id(Head, Caller),
              member(BodyItem, Body),
              body_call_term(BodyItem, Call),
              pred_id(Call, Callee)
            ),
            RawEdges),
    sort(RawEdges, Edges).

termination_heuristic(Clauses, Pred, terminates(decreasing_argument(1, Delta))) :-
    predicate_clause(Clauses, Pred, Clause),
    recursive_step_clause(Pred, Clause, Delta),
    Delta > 0,
    !.
termination_heuristic(Clauses, Pred, unknown) :-
    predicate_exists(Clauses, Pred).

generate_examples(Clauses, Pred, MaxN, Examples) :-
    integer(MaxN),
    MaxN >= 0,
    extract_recurrence(Clauses, Pred, recurrence(_Pred, base(BaseN, BaseValue), step(n, rec(n-Delta)+n))),
    Pred = Name/Arity,
    Arity =:= 2,
    findall(example(fun(Name, [const(N), const(Value)])),
            ( between(BaseN, MaxN, N),
              aligned_index(N, BaseN, Delta),
              recurrence_value(N, BaseN, BaseValue, Delta, Value)
            ),
            Examples).

example_program([
    clause(fun(sum, [const(0), const(0)]), []),
    clause(fun(sum, [var('N'), var('S')]),
           [ call(fun(sum, [fun(sub, [var('N'), const(1)]), var('S1')])),
             call(fun(add, [var('S1'), var('N'), var('S')]))
           ]),
    clause(fun(triangular, [var('N'), var('S')]), [call(fun(sum, [var('N'), var('S')]))])
]).

predicate_exists(Clauses, Pred) :-
    predicate_clause(Clauses, Pred, _).

predicate_clause(Clauses, Pred, clause(Head, Body)) :-
    member(clause(Head, Body), Clauses),
    pred_id(Head, Pred).

pred_id(fun(Name, Args), Name/Arity) :-
    length(Args, Arity).

base_clause(clause(fun(_Name, [const(BaseN), const(BaseValue)]), Body), BaseN, BaseValue) :-
    integer(BaseN),
    number(BaseValue),
    \+ has_recursive_call(_/_, Body).

recursive_step_clause(Pred, clause(fun(Name, [var(NVar), var(SVar)]), Body), Delta) :-
    Pred = Name/2,
    has_recursive_call(Pred, Body),
    recursive_call(Body, Name, NVar, RecOutVar, Delta),
    has_additive_accumulator(Body, RecOutVar, NVar, SVar).

has_recursive_call(Pred, Body) :-
    member(Item, Body),
    body_call_term(Item, Call),
    pred_id(Call, Pred),
    !.

recursive_call(Body, Name, NVar, RecOutVar, Delta) :-
    member(Item, Body),
    body_call_term(Item, fun(Name, [fun(sub, [var(NVar), const(Delta)]), var(RecOutVar)])),
    integer(Delta),
    Delta > 0,
    !.

has_additive_accumulator(Body, RecOutVar, NVar, SVar) :-
    member(Item, Body),
    body_call_term(Item, fun(add, [var(RecOutVar), var(NVar), var(SVar)])),
    !.
has_additive_accumulator(Body, RecOutVar, NVar, SVar) :-
    member(Item, Body),
    body_call_term(Item, fun(add, [var(NVar), var(RecOutVar), var(SVar)])),
    !.

body_call_term(call(Term), Term).
body_call_term(Term, Term).

aligned_index(N, BaseN, Delta) :-
    Diff is N - BaseN,
    0 is Diff mod Delta.

recurrence_value(N, BaseN, BaseValue, _Delta, BaseValue) :-
    N =:= BaseN,
    !.
recurrence_value(N, BaseN, BaseValue, Delta, Value) :-
    N > BaseN,
    PrevN is N - Delta,
    PrevN >= BaseN,
    recurrence_value(PrevN, BaseN, BaseValue, Delta, PrevValue),
    Value is PrevValue + N.
