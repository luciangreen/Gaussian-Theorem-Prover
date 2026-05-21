:- module(stage1_kernel,
          [ parse_term/2,
            parse_equation/2,
            unify_terms/3,
            rewrite_once/3,
            check_proof/1,
            example_proof/1
          ]).

:- use_module(library(dcg/basics)).

parse_term(Text, Term) :-
    string(Text),
    string_codes(Text, Codes),
    phrase(term(Term), Codes).
parse_term(Text, Term) :-
    atom(Text),
    atom_codes(Text, Codes),
    phrase(term(Term), Codes).

parse_equation(Text, equation(Left, Right)) :-
    string(Text),
    string_codes(Text, Codes),
    phrase(equation(Left, Right), Codes).
parse_equation(Text, equation(Left, Right)) :-
    atom(Text),
    atom_codes(Text, Codes),
    phrase(equation(Left, Right), Codes).

unify_terms(A, B, Subst) :-
    unify(A, B, [], Subst0),
    normalize_subst(Subst0, Subst).

rewrite_once(Term, Rule, Rewritten) :-
    rewrite_here(Term, Rule, Rewritten),
    !.
rewrite_once(fun(Name, Args), Rule, fun(Name, NewArgs)) :-
    rewrite_arg(Args, Rule, NewArgs).

check_proof(Proof) :-
    var(Proof),
    example_proof(Example),
    check_proof(Example),
    Proof = Example.
check_proof(proof(equation(Left, Right), Steps)) :-
    apply_steps(equation(Left, Right), Steps, equation(FinalLeft, FinalRight)),
    unify_terms(FinalLeft, FinalRight, _).

example_proof(
    proof(
        equation(fun(add, [const(0), var(x)]), var(x)),
        [rewrite_left(rule(fun(add, [const(0), var(a)]), var(a)))]
    )
).

apply_steps(State, [], State).
apply_steps(State0, [Step | Rest], StateFinal) :-
    apply_step(State0, Step, State1),
    apply_steps(State1, Rest, StateFinal).

apply_step(equation(Left, Right), rewrite_left(Rule), equation(NewLeft, Right)) :-
    rewrite_once(Left, Rule, NewLeft).
apply_step(equation(Left, Right), rewrite_right(Rule), equation(Left, NewRight)) :-
    rewrite_once(Right, Rule, NewRight).
apply_step(equation(Left, Right), unify_sides, equation(NewLeft, NewRight)) :-
    unify_terms(Left, Right, Subst),
    apply_subst(Left, Subst, NewLeft),
    apply_subst(Right, Subst, NewRight).

rewrite_here(Term, rule(Pattern, Replacement), Rewritten) :-
    unify_terms(Pattern, Term, Subst),
    apply_subst(Replacement, Subst, Rewritten).

rewrite_arg([Arg | Rest], Rule, [NewArg | Rest]) :-
    rewrite_once(Arg, Rule, NewArg),
    !.
rewrite_arg([Arg | Rest], Rule, [Arg | NewRest]) :-
    rewrite_arg(Rest, Rule, NewRest).

unify(var(Name), Term, SubstIn, SubstOut) :-
    bind_var(Name, Term, SubstIn, SubstOut).
unify(Term, var(Name), SubstIn, SubstOut) :-
    bind_var(Name, Term, SubstIn, SubstOut).
unify(const(A), const(B), Subst, Subst) :-
    A == B.
unify(fun(NameA, ArgsA), fun(NameB, ArgsB), SubstIn, SubstOut) :-
    NameA == NameB,
    same_length(ArgsA, ArgsB),
    unify_list(ArgsA, ArgsB, SubstIn, SubstOut).

unify_list([], [], Subst, Subst).
unify_list([A | As], [B | Bs], SubstIn, SubstOut) :-
    apply_subst(A, SubstIn, A1),
    apply_subst(B, SubstIn, B1),
    unify(A1, B1, SubstIn, SubstMid),
    unify_list(As, Bs, SubstMid, SubstOut).

bind_var(Name, Term, SubstIn, SubstOut) :-
    (   select(Name-Existing, SubstIn, Rest)
    ->  unify(Existing, Term, Rest, SubstOut)
    ;   occurs(Name, Term, SubstIn)
    ->  fail
    ;   SubstOut = [Name-Term | SubstIn]
    ).

occurs(Name, var(Name), _).
occurs(Name, var(Other), Subst) :-
    Name \== Other,
    memberchk(Other-Term, Subst),
    occurs(Name, Term, Subst).
occurs(_, var(_), _) :-
    fail.
occurs(Name, fun(_, Args), Subst) :-
    member(Arg, Args),
    occurs(Name, Arg, Subst).
occurs(_, const(_), _) :-
    fail.

apply_subst(var(Name), Subst, Result) :-
    (   memberchk(Name-Term, Subst)
    ->  apply_subst(Term, Subst, Result)
    ;   Result = var(Name)
    ).
apply_subst(const(Value), _Subst, const(Value)).
apply_subst(fun(Name, Args), Subst, fun(Name, NewArgs)) :-
    maplist(apply_subst_with(Subst), Args, NewArgs).

apply_subst_with(Subst, In, Out) :-
    apply_subst(In, Subst, Out).

normalize_subst(SubstIn, SubstOut) :-
    maplist(normalize_binding(SubstIn), SubstIn, SubstNorm),
    sort(SubstNorm, SubstOut).

normalize_binding(Subst, Name-Term, Name-NormTerm) :-
    apply_subst(Term, Subst, NormTerm).

ws --> blanks.

equation(Left, Right) -->
    ws,
    term(Left),
    ws,
    "=",
    ws,
    term(Right),
    ws.

term(Term) --> variable(Term).
term(Term) --> function_or_const(Term).

function_or_const(const(Number)) -->
    integer(Number).

variable(var(Name)) -->
    identifier(Name),
    { atom_chars(Name, [First | _]), char_type(First, upper) }.

function_or_const(fun(Name, Args)) -->
    identifier(Name),
    ws,
    "(",
    ws,
    arguments(Args),
    ws,
    ")",
    { Args \= [] }.
function_or_const(const(Name)) -->
    identifier(Name),
    { atom_chars(Name, [First | _]), char_type(First, lower) }.

arguments([Arg | Rest]) -->
    term(Arg),
    ws,
    ",",
    ws,
    arguments(Rest).
arguments([Arg]) -->
    term(Arg).

identifier(Atom) -->
    identifier_start(C),
    identifier_rest(Cs),
    { atom_codes(Atom, [C | Cs]) }.

identifier_start(C) -->
    [C],
    { code_type(C, alpha) ; C =:= 0'_ }.

identifier_rest([C | Cs]) -->
    [C],
    { code_type(C, alnum) ; C =:= 0'_ },
    !,
    identifier_rest(Cs).
identifier_rest([]) --> [].
