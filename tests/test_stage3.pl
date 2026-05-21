:- begin_tests(stage3_discovery).

:- use_module('../src/stage3_discovery').
:- use_module('../src/stage2_analysis').

test(finite_differences_for_triangular_values) :-
    finite_differences([0, 1, 3, 6, 10], Layers),
    Layers == [[0, 1, 3, 6, 10], [1, 2, 3, 4], [1, 1, 1]].

test(build_matrix_degree_two) :-
    Points = [0-0, 1-1, 2-3],
    build_matrix(Points, 2, Matrix, Vector),
    Matrix == [[1, 0, 0], [1, 1, 1], [1, 2, 4]],
    Vector == [0, 1, 3].

test(gaussian_elimination_solves_quadratic_system) :-
    Matrix = [[1, 0, 0], [1, 1, 1], [1, 2, 4]],
    Vector = [0, 1, 3],
    gaussian_elimination(Matrix, Vector, Coefficients),
    Coefficients == [0, 1 rdiv 2, 1 rdiv 2].

test(extract_invariant_sum_formula) :-
    extract_invariant(sum, [0, 1 rdiv 2, 1 rdiv 2], Formula),
    Formula == n*(n+1)/2.

test(discover_formula_acceptance) :-
    discover_formula(sum, Formula),
    Formula == n*(n+1)/2.

test(polynomial_fit_from_stage2_examples) :-
    example_program(Program),
    generate_examples(Program, sum/2, 4, Examples),
    findall(N-V, member(example(fun(sum, [const(N), const(V)])), Examples), Points),
    build_matrix(Points, 2, Matrix, Vector),
    polynomial_fit(Matrix, Vector, Coefficients),
    Coefficients == [0, 1 rdiv 2, 1 rdiv 2].

:- end_tests(stage3_discovery).
