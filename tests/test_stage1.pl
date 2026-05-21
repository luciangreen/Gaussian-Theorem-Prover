:- begin_tests(stage1_kernel).

:- use_module('../src/stage1_kernel').

test(parse_term_function) :-
    parse_term("add(0,X)", fun(add, [const(0), var('X')])).

test(parse_equation_text) :-
    parse_equation("add(0,X)=X", equation(fun(add, [const(0), var('X')]), var('X'))).

test(unification_with_substitution) :-
    unify_terms(fun(add, [var('X'), const(1)]), fun(add, [const(2), var('Y')]), Subst),
    memberchk('X'-const(2), Subst),
    memberchk('Y'-const(1), Subst).

test(rewrite_nested_term) :-
    rewrite_once(fun(s, [fun(add, [const(0), var('X')])]),
                 rule(fun(add, [const(0), var('A')]), var('A')),
                 fun(s, [var('X')])).

test(check_proof_returns_example_when_unbound) :-
    check_proof(Proof),
    Proof = proof(
        equation(fun(add, [const(0), var('X')]), var('X')),
        [rewrite_left(rule(fun(add, [const(0), var('A')]), var('A')))]
    ).

test(check_explicit_proof) :-
    check_proof(
        proof(
            equation(fun(add, [const(0), var('X')]), var('X')),
            [rewrite_left(rule(fun(add, [const(0), var('A')]), var('A')))]
        )
    ).

:- end_tests(stage1_kernel).
