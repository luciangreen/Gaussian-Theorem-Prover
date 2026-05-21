:- begin_tests(stage2_analysis).

:- use_module('../src/stage2_analysis').

test(extract_recurrence_for_sum) :-
    example_program(Program),
    extract_recurrence(Program, sum/2, Recurrence),
    Recurrence = recurrence(sum/2, base(0, 0), step(n, rec(n-1)+n)).

test(generate_call_graph) :-
    example_program(Program),
    generate_call_graph(Program, Graph),
    Graph == [
        edge(sum/2, add/3),
        edge(sum/2, sum/2),
        edge(triangular/2, sum/2)
    ].

test(termination_heuristic_decreasing_argument) :-
    example_program(Program),
    termination_heuristic(Program, sum/2, Result),
    Result == terminates(decreasing_argument(1, 1)).

test(termination_heuristic_unknown) :-
    Program = [
        clause(fun(loop, [var('N')]), [call(fun(loop, [var('N')]))])
    ],
    termination_heuristic(Program, loop/1, Result),
    Result == unknown.

test(generate_examples_from_recurrence) :-
    example_program(Program),
    generate_examples(Program, sum/2, 5, Examples),
    Examples == [
        example(fun(sum, [const(0), const(0)])),
        example(fun(sum, [const(1), const(1)])),
        example(fun(sum, [const(2), const(3)])),
        example(fun(sum, [const(3), const(6)])),
        example(fun(sum, [const(4), const(10)])),
        example(fun(sum, [const(5), const(15)]))
    ].

:- end_tests(stage2_analysis).
