% sum(N, S): S = N*(N+1)/2
% Base case: the sum of nothing is zero.
sum(0, 0).
% Recursive case: sum(N) = sum(N-1) + N
sum(N, S) :-
    N > 0,
    N1 is N - 1,
    sum(N1, S1),
    S is S1 + N.
