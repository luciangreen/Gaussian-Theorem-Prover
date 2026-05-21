% fact(N, F): F = N!
% Factorial grows faster than any polynomial — no closed-form polynomial exists.
% Base case: fact(0) = 1.
fact(0, 1).
% Recursive case: fact(N) = N * fact(N-1)
fact(N, F) :-
    N > 0,
    N1 is N - 1,
    fact(N1, F1),
    F is N * F1.
