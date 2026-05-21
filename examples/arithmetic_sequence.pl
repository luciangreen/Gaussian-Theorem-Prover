% seq(N, S): S = 2*N + 3  (arithmetic sequence starting at 3, step 2)
% Base case: seq(0) = 3.
seq(0, 3).
% Recursive case: seq(N) = seq(N-1) + 2
seq(N, S) :-
    N > 0,
    N1 is N - 1,
    seq(N1, S1),
    S is S1 + 2.
