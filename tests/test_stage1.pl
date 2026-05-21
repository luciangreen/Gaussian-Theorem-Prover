:- begin_tests(stage1_kernel).

:- use_module('../src/stage1_kernel').

test(parse_term_function) :-
    parse_term("add(0,X)", fun(add, [const(0), var('X')])).

test(parse_equation_text) :-
    parse_equation("add(0,X)=X", equation(fun(add, [const(0), var('X')]), var('X'))).

test(unification_with_substitution) :-
    unify_terms(fun(add, [var(x), const(1)]), fun(add, [const(2), var(y)]), Subst),
    memberchk(x-const(2), Subst),
    memberchk(y-const(1), Subst).

test(rewrite_nested_term) :-
    rewrite_once(fun(s, [fun(add, [const(0), var(x)])]),
                 rule(fun(add, [const(0), var(a)]), var(a)),
                 fun(s, [var(x)])).

test(check_proof_generates_example) :-
    check_proof(Proof),
    Proof = proof(
        equation(fun(add, [const(0), var(x)]), var(x)),
        [rewrite_left(rule(fun(add, [const(0), var(a)]), var(a)))]
    ).

test(check_explicit_proof) :-
    check_proof(
        proof(
            equation(fun(add, [const(0), var(x)]), var(x)),
            [rewrite_left(rule(fun(add, [const(0), var(a)]), var(a)))]
        )
    ).

:- end_tests(stage1_kernel).
