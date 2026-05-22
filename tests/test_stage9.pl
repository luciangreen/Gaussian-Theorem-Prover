:- begin_tests(stage9_advanced_discovery).

:- use_module('../src/stage9_advanced_discovery').
:- use_module('../src/stage2_analysis', [example_program/1, generate_call_graph/2]).


test(graph_invariants_marks_recursive_sum_node) :-
    example_program(Program),
    generate_call_graph(Program, Edges),
    graph_invariants(Edges, sum/2, invariants(node(sum/2), out_degree(OutDegree), in_degree(InDegree), self_recursive(yes), reachable(Reachable))),
    OutDegree >= 1,
    InDegree >= 1,
    member(add/3, Reachable),
    member(sum/2, Reachable).


test(cfg_induction_extracts_decreasing_argument_rule) :-
    example_program(Program),
    cfg_induction(Program, sum/2, induction_plan(sum/2, CallOrder, recursive_induction(decreasing_argument(1, 1)))),
    member(sum/2, CallOrder).


test(symbolic_compression_reuses_repeated_subterms) :-
    symbolic_compression(fun(add, [fun(add, [const(1), const(2)]), fun(add, [const(1), const(2)])]), Compressed, Dictionary),
    Compressed = compressed(_, [compressed(_, _), ref(_)]),
    member(symbol(_, canonical(fun(add, [const(1), const(2)]))), Dictionary).


test(recursive_decomposition_splits_base_and_step) :-
    recursive_decomposition(recurrence(sum/2, base(0, 0), step(n, rec(n-1)+n)), Decomposition),
    member(base_case(sum/2, index(0), value(0)), Decomposition),
    member(termination_measure(index_decreases_by(1)), Decomposition).


test(spec_to_algorithm_handles_known_sum_spec) :-
    spec_to_algorithm(spec(sum_first_n), Algorithm, Alignment),
    Alignment == exact_alignment,
    Algorithm = algorithm(recursive_accumulator, Steps),
    member(initialise(accumulator, 0), Steps).


test(semantic_pattern_mining_detects_quadratic_signature) :-
    Examples = [
        example(fun(sum, [const(0), const(0)])),
        example(fun(sum, [const(1), const(1)])),
        example(fun(sum, [const(2), const(3)])),
        example(fun(sum, [const(3), const(6)])),
        example(fun(sum, [const(4), const(10)]))
    ],
    semantic_pattern_mining(Examples, Patterns),
    member(pattern(growth_class, quadratic), Patterns),
    member(pattern(finite_differences, signature(order2_constant(1))), Patterns).


test(discover_advanced_acceptance_for_sum_formula) :-
    discover_advanced(sum_formula, spec(sum_first_n), Report),
    Report = advanced_discovery(
        theorem(sum_formula),
        graph_invariants(invariants(node(sum/2), out_degree(_), in_degree(_), self_recursive(yes), reachable(Reachable))),
        cfg_induction(induction_plan(sum/2, _, recursive_induction(decreasing_argument(1, 1)))),
        symbolic_compression(_, Dictionary),
        recursive_decomposition(Decomposition),
        spec_to_algorithm(algorithm(recursive_accumulator, _), exact_alignment),
        semantic_patterns(Patterns)
    ),
    member(add/3, Reachable),
    Dictionary \= [],
    member(base_case(sum/2, index(0), value(0)), Decomposition),
    member(pattern(growth_class, quadratic), Patterns).


:- end_tests(stage9_advanced_discovery).
