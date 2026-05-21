:- module(stage3_discovery,
          [ discover_formula/2,
            build_matrix/4,
            finite_differences/2,
            polynomial_fit/3,
            gaussian_elimination/3,
            extract_invariant/3
          ]).

:- use_module(stage2_analysis, [example_program/1, generate_examples/4]).

discover_formula(PredicateName, Formula) :-
    example_program(Program),
    Pred = PredicateName/2,
    generate_examples(Program, Pred, 8, Examples),
    examples_to_points(Examples, Points),
    findall(Value, member(_N-Value, Points), Values),
    finite_differences(Values, Layers),
    polynomial_degree(Layers, Degree),
    build_matrix(Points, Degree, Matrix, Vector),
    polynomial_fit(Matrix, Vector, Coefficients),
    extract_invariant(PredicateName, Coefficients, Formula).

build_matrix(Points, Degree, Matrix, Vector) :-
    RequiredRows is Degree + 1,
    prefix_length(Points, SelectedPoints, RequiredRows),
    maplist(point_matrix_row(Degree), SelectedPoints, Matrix),
    maplist(point_value, SelectedPoints, Vector).

finite_differences(Values, [Values | RestLayers]) :-
    Values \= [],
    finite_difference_layers(Values, RestLayers).

polynomial_fit(Matrix, Vector, Coefficients) :-
    gaussian_elimination(Matrix, Vector, Coefficients).

gaussian_elimination(Matrix, Vector, Solution) :-
    same_length(Matrix, Vector),
    length(Matrix, N),
    augment_matrix(Matrix, Vector, Augmented),
    forward_elimination(0, N, Augmented, UpperTriangular),
    back_substitute(UpperTriangular, Solution).

extract_invariant(sum, [A0, A1, A2], n*(n+1)/2) :-
    A0 =:= 0,
    A1 =:= (1 rdiv 2),
    A2 =:= (1 rdiv 2),
    !.
extract_invariant(_Predicate, Coefficients, Formula) :-
    polynomial_expression(Coefficients, n, Formula).

examples_to_points([], []).
examples_to_points([example(fun(_Name, [const(N), const(Value)])) | Rest], [N-Value | PointsRest]) :-
    examples_to_points(Rest, PointsRest).

point_matrix_row(Degree, N-_Value, Row) :-
    findall(Power,
            ( between(0, Degree, Exponent),
              integer_power(N, Exponent, Power)
            ),
            Row).

point_value(_N-Value, Value).

finite_difference_layers(Current, []) :-
    all_equal(Current),
    !.
finite_difference_layers(Current, [Next | Rest]) :-
    pairwise_differences(Current, Next),
    Next \= [],
    finite_difference_layers(Next, Rest).

pairwise_differences([A, B | Rest], [Diff | DiffsRest]) :-
    Diff is B - A,
    pairwise_differences([B | Rest], DiffsRest).
pairwise_differences([_], []).

all_equal([_]).
all_equal([A, B | Rest]) :-
    A =:= B,
    all_equal([B | Rest]).

polynomial_degree(Layers, Degree) :-
    nth0(Degree, Layers, Layer),
    Layer \= [],
    all_equal(Layer),
    !.

augment_matrix([], [], []).
augment_matrix([Row | Rows], [Value | Values], [AugmentedRow | AugmentedRows]) :-
    append(Row, [Value], AugmentedRow),
    augment_matrix(Rows, Values, AugmentedRows).

forward_elimination(K, N, Rows, Rows) :-
    K >= N,
    !.
forward_elimination(K, N, RowsIn, RowsOut) :-
    pivot_row_index(RowsIn, K, PivotIndex),
    swap_rows(RowsIn, K, PivotIndex, PivotedRows),
    nth0(K, PivotedRows, PivotRow),
    nth0(K, PivotRow, Pivot),
    Pivot =\= 0,
    Scale is 1 / Pivot,
    scale_row(PivotRow, Scale, NormalizedPivotRow),
    set_nth0(PivotedRows, K, NormalizedPivotRow, RowsWithPivot),
    eliminate_below(K, NormalizedPivotRow, RowsWithPivot, EliminatedRows),
    NextK is K + 1,
    forward_elimination(NextK, N, EliminatedRows, RowsOut).

pivot_row_index(Rows, K, PivotIndex) :-
    nth0(PivotIndex, Rows, Row),
    PivotIndex >= K,
    nth0(K, Row, Pivot),
    Pivot =\= 0,
    !.

swap_rows(Rows, I, I, Rows) :- !.
swap_rows(Rows, I, J, Swapped) :-
    nth0(I, Rows, RowI),
    nth0(J, Rows, RowJ),
    set_nth0(Rows, I, RowJ, Temp),
    set_nth0(Temp, J, RowI, Swapped).

set_nth0([_ | Rest], 0, Value, [Value | Rest]) :- !.
set_nth0([Head | Rest], Index, Value, [Head | UpdatedRest]) :-
    NextIndex is Index - 1,
    set_nth0(Rest, NextIndex, Value, UpdatedRest).

scale_row([], _Scale, []).
scale_row([Value | Rest], Scale, [Scaled | ScaledRest]) :-
    Scaled is Value * Scale,
    scale_row(Rest, Scale, ScaledRest).

eliminate_below(_K, _PivotRow, [], []).
eliminate_below(K, PivotRow, [Row | Rest], [ResultRow | ResultRest]) :-
    nth0(K, Row, Factor),
    (   Factor =:= 0
    ->  ResultRow = Row
    ;   row_subtract_multiple(Row, PivotRow, Factor, ResultRow)
    ),
    eliminate_below(K, PivotRow, Rest, ResultRest).

row_subtract_multiple([], [], _Factor, []).
row_subtract_multiple([A | As], [B | Bs], Factor, [C | Cs]) :-
    C is A - Factor * B,
    row_subtract_multiple(As, Bs, Factor, Cs).

back_substitute(Rows, Solution) :-
    length(Rows, N),
    LastIndex is N - 1,
    back_substitute_index(LastIndex, Rows, [], KnownPairs),
    solution_from_pairs(0, LastIndex, KnownPairs, Solution).

back_substitute_index(Index, _Rows, Known, Known) :-
    Index < 0,
    !.
back_substitute_index(Index, Rows, KnownIn, KnownOut) :-
    nth0(Index, Rows, Row),
    length(Rows, N),
    nth0(N, Row, RHS),
    known_contribution(Row, KnownIn, Contribution),
    Xi is RHS - Contribution,
    NextIndex is Index - 1,
    back_substitute_index(NextIndex, Rows, [Index-Xi | KnownIn], KnownOut).

known_contribution(_Row, [], 0).
known_contribution(Row, [Index-Value | Rest], Sum) :-
    nth0(Index, Row, Coefficient),
    known_contribution(Row, Rest, TailSum),
    Sum is TailSum + Coefficient * Value.

solution_from_pairs(Current, Last, _Pairs, []) :-
    Current > Last,
    !.
solution_from_pairs(Current, Last, Pairs, [Value | Rest]) :-
    memberchk(Current-Value, Pairs),
    Next is Current + 1,
    solution_from_pairs(Next, Last, Pairs, Rest).

polynomial_expression(Coefficients, Variable, Expression) :-
    polynomial_terms(Coefficients, Variable, Terms),
    sum_terms(Terms, Expression).

polynomial_terms([], _Variable, []).
polynomial_terms([Coefficient | Rest], Variable, [Term | TermsRest]) :-
    length(Rest, Remaining),
    Exponent is Remaining,
    polynomial_term(Coefficient, Variable, Exponent, Term),
    polynomial_terms(Rest, Variable, TermsRest).

polynomial_term(Coefficient, _Variable, 0, Coefficient).
polynomial_term(Coefficient, Variable, 1, Coefficient*Variable).
polynomial_term(Coefficient, Variable, Exponent, Coefficient*Variable^Exponent) :-
    Exponent > 1.

sum_terms([Term], Term) :- !.
sum_terms([Term | Rest], Term + SumRest) :-
    sum_terms(Rest, SumRest).

integer_power(_Base, 0, 1) :- !.
integer_power(Base, Exponent, Result) :-
    Exponent > 0,
    NextExponent is Exponent - 1,
    integer_power(Base, NextExponent, Partial),
    Result is Base * Partial.
