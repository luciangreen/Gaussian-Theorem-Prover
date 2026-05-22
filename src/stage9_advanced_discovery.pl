:- module(stage9_advanced_discovery,
          [ discover_advanced/3,
            graph_invariants/3,
            cfg_induction/3,
            symbolic_compression/3,
            recursive_decomposition/2,
            spec_to_algorithm/3,
            semantic_pattern_mining/2
          ]).

:- use_module('./stage2_analysis',
              [ example_program/1,
                extract_recurrence/3,
                generate_call_graph/2,
                generate_examples/4
              ]).
:- use_module('./stage3_discovery', [discover_formula/2]).


discover_advanced(sum_formula, Spec,
                  advanced_discovery(
                      theorem(sum_formula),
                      graph_invariants(GraphInvariants),
                      cfg_induction(CfgInduction),
                      symbolic_compression(Compressed, Dictionary),
                      recursive_decomposition(Decomposition),
                      spec_to_algorithm(Algorithm, Alignment),
                      semantic_patterns(Patterns)
                  )) :-
    example_program(Program),
    generate_call_graph(Program, Edges),
    graph_invariants(Edges, sum/2, GraphInvariants),
    cfg_induction(Program, sum/2, CfgInduction),
    discover_formula(sum, Formula),
    symbolic_compression(
        term(theorem(sum_formula), formula(Formula), graph(Edges), specification(Spec)),
        Compressed,
        Dictionary
    ),
    extract_recurrence(Program, sum/2, Recurrence),
    recursive_decomposition(Recurrence, Decomposition),
    spec_to_algorithm(Spec, Algorithm, Alignment),
    generate_examples(Program, sum/2, 8, Examples),
    semantic_pattern_mining(Examples, Patterns),
    !.
discover_advanced(Theorem, Spec,
                  advanced_discovery(
                      theorem(Theorem),
                      graph_invariants([]),
                      cfg_induction(induction_plan(Theorem, [], unknown)),
                      symbolic_compression(compressed(specification(Spec)), []),
                      recursive_decomposition([]),
                      spec_to_algorithm(algorithm(unknown, []), partial_alignment),
                      semantic_patterns([])
                  )).


graph_invariants(Edges, FocusNode,
                 invariants(node(FocusNode), out_degree(OutDegree), in_degree(InDegree), self_recursive(SelfRecursive), reachable(Reachable))) :-
    findall(Callee, member(edge(FocusNode, Callee), Edges), OutNeighbors),
    findall(Caller, member(edge(Caller, FocusNode), Edges), InNeighbors),
    length(OutNeighbors, OutDegree),
    length(InNeighbors, InDegree),
    ( member(FocusNode, OutNeighbors) -> SelfRecursive = yes ; SelfRecursive = no ),
    reachable_nodes(FocusNode, Edges, ReachableWithSource),
    exclude(=(FocusNode), ReachableWithSource, Reachable).


cfg_induction(Program, EntryPred,
              induction_plan(EntryPred, CallOrder, Rule)) :-
    generate_call_graph(Program, Edges),
    reachable_nodes(EntryPred, Edges, Reachable),
    topological_hint(Reachable, CallOrder),
    cfg_rule(EntryPred, Program, Rule).


symbolic_compression(Term, Compressed, Dictionary) :-
    compress_term(Term, [], _FinalSeen, Compressed, [], Dictionary0, 0, _),
    reverse(Dictionary0, Dictionary).


recursive_decomposition(recurrence(Pred, base(BaseN, BaseValue), step(n, rec(n-Delta)+n)),
                        [ base_case(Pred, index(BaseN), value(BaseValue)),
                          recursive_case(Pred, transition(n, n-Delta), combine(add_current_index)),
                          termination_measure(index_decreases_by(Delta))
                        ]) :-
    !.
recursive_decomposition(Recurrence,
                        [ base_case(unknown, source(Recurrence)),
                          recursive_case(unknown, transition(unknown), combine(unknown))
                        ]).


spec_to_algorithm(spec(sum_first_n),
                  algorithm(recursive_accumulator,
                            [ initialise(accumulator, 0),
                              loop(while(n > 0),
                                   [accumulator := accumulator + n, n := n - 1]),
                              output(accumulator)
                            ]),
                  exact_alignment) :-
    !.
spec_to_algorithm(spec(triangular_number),
                  algorithm(closed_form,
                            [ precondition(n >= 0),
                              compute(result := n*(n+1)/2),
                              output(result)
                            ]),
                  exact_alignment) :-
    !.
spec_to_algorithm(Spec,
                  algorithm(synthesised,
                            [ parse_specification(Spec),
                              extract_recurrence_structure,
                              pick_candidate_schema,
                              instantiate_parameters,
                              validate_with_examples
                            ]),
                  partial_alignment).


semantic_pattern_mining(Examples, Patterns) :-
    findall(N-Value,
            member(example(fun(sum, [const(N), const(Value)])), Examples),
            Points),
    Points \= [],
    !,
    pairs_values(Points, Values),
    monotonic_pattern(Values, Monotonic),
    finite_difference_signature(Values, Signature),
    Patterns = [
        pattern(monotonicity, Monotonic),
        pattern(finite_differences, Signature),
        pattern(growth_class, quadratic)
    ].
semantic_pattern_mining(_Examples, [pattern(data, insufficient)]).


reachable_nodes(Start, Edges, Reachable) :-
    reachable_nodes([Start], Edges, [], ReachableUnsorted),
    sort(ReachableUnsorted, Reachable).

reachable_nodes([], _Edges, Visited, Visited).
reachable_nodes([Node | Rest], Edges, Visited, Reachable) :-
    ( member(Node, Visited) ->
        reachable_nodes(Rest, Edges, Visited, Reachable)
    ;
        findall(Next, member(edge(Node, Next), Edges), NextNodes),
        append(Rest, NextNodes, Queue),
        reachable_nodes(Queue, Edges, [Node | Visited], Reachable)
    ).


topological_hint(Reachable, CallOrder) :-
    sort(Reachable, CallOrder).


cfg_rule(EntryPred, Program, recursive_induction(decreasing_argument(1, Delta))) :-
    extract_recurrence(Program, EntryPred, recurrence(_, _, step(n, rec(n-Delta)+n))),
    !.
cfg_rule(_EntryPred, _Program, structural_induction).


compress_term(Term, Seen, Seen, Term, Dictionary, Dictionary, Counter, Counter) :-
    atomic(Term),
    !.
compress_term(Term, SeenIn, SeenOut, ref(Symbol), DictIn, DictOut, CounterIn, CounterOut) :-
    member(seen(Term, Symbol), SeenIn),
    !,
    SeenOut = SeenIn,
    DictOut = DictIn,
    CounterOut = CounterIn.
compress_term(Term, SeenIn, SeenOut, compressed(Symbol, CompressedArgs), DictIn, DictOut, CounterIn, CounterOut) :-
    Term =.. [Functor | Args],
    CounterMid is CounterIn + 1,
    format(atom(Symbol), 'sym_~w_~w', [Functor, CounterMid]),
    compress_args(Args, SeenIn, SeenAfterArgs, CompressedArgs, DictIn, DictAfterArgs, CounterMid, CounterOut),
    SeenOut = [seen(Term, Symbol) | SeenAfterArgs],
    DictOut = [symbol(Symbol, canonical(Term)) | DictAfterArgs].

compress_args([], Seen, Seen, [], Dict, Dict, Counter, Counter).
compress_args([Arg | Rest], SeenIn, SeenOut, [CompressedArg | CompressedRest], DictIn, DictOut, CounterIn, CounterOut) :-
    compress_term(Arg, SeenIn, SeenMid, CompressedArg, DictIn, DictMid, CounterIn, CounterMid),
    compress_args(Rest, SeenMid, SeenOut, CompressedRest, DictMid, DictOut, CounterMid, CounterOut).


monotonic_pattern([_], insufficient_data) :-
    !.
monotonic_pattern(Values, non_decreasing) :-
    non_decreasing_values(Values),
    !.
monotonic_pattern(_Values, mixed).

non_decreasing_values([_]).
non_decreasing_values([A, B | Rest]) :-
    B >= A,
    non_decreasing_values([B | Rest]).

finite_difference_signature(Values, signature(order2_constant(Constant))) :-
    first_differences(Values, First),
    first_differences(First, Second),
    Second = [Constant | Tail],
    all_equal(Tail, Constant),
    !.
finite_difference_signature(_Values, signature(non_quadratic_or_insufficient_data)).

first_differences([_], []).
first_differences([A, B | Rest], [Diff | Diffs]) :-
    Diff is B - A,
    first_differences([B | Rest], Diffs).

all_equal([], _).
all_equal([Value | Rest], Value) :-
    all_equal(Rest, Value).
