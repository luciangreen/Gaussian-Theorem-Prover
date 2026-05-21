:- module(stage7_visualisation,
          [ visualise_theorem/3,
            browser_ide/4,
            matrix_animation/3,
            proof_graph_display/3,
            term_rewrite_visualiser/3,
            cfg_visualiser/2,
            proof_tree_explorer/3
          ]).

:- use_module('./stage2_analysis', [example_program/1, generate_call_graph/2]).
:- use_module('./stage3_discovery', [discover_formula/2]).
:- use_module('./stage5_proof_search', [universal_prove/3]).
:- use_module('./stage6_explanation', [explain_proof/3]).

visualise_theorem(Theorem, Audience,
                  visualisation(ide(Ide),
                                matrix(MatrixFrames),
                                proof_graph(ProofGraph),
                                rewrites(RewriteFrames),
                                cfg(CfgGraph),
                                proof_tree(ProofTree))) :-
    universal_prove(Theorem, Result, Evidence),
    explain_proof(Theorem, Audience, explanation(Theorem, Audience, _ExplainedResult, Story)),
    browser_ide(Theorem, Audience, Result, Ide),
    matrix_animation(Theorem, Evidence, MatrixFrames),
    proof_graph_display(Theorem, Evidence, ProofGraph),
    term_rewrite_visualiser(Theorem, Story, RewriteFrames),
    cfg_visualiser(Theorem, CfgGraph),
    proof_tree_explorer(Theorem, Evidence, ProofTree).

browser_ide(Theorem, Audience, Result,
            ide(theorem(Theorem),
                audience(Audience),
                status(Result),
                widgets([editor, matrix_canvas, proof_graph, rewrite_panel, cfg_panel, proof_tree]))).

matrix_animation(sum_formula, Evidence, Frames) :-
    discovered_formula(Evidence, Formula),
    discover_formula(sum, Formula),
    Frames = [ frame(samples, [0-0, 1-1, 2-3]),
               frame(matrix_row, [1, 0, 0], equals, 0),
               frame(matrix_row, [1, 1, 1], equals, 1),
               frame(matrix_row, [1, 2, 4], equals, 3),
               frame(solution, ['a0=0', 'a1=1/2', 'a2=1/2']),
               frame(formula, Formula)
             ],
    !.
matrix_animation(Theorem, _Evidence, Frames) :-
    Frames = [ frame(message, Theorem, 'No matrix animation available for this theorem yet.') ].

proof_graph_display(Theorem,
                    evidence(strategies(Strategies),
                             lemmas(Lemmas),
                             ranked_proofs([candidate(BestName, BestOutcome, BestScore, _BestDetails) | _]),
                             fallback(fallback(FallbackName, _Tried, FallbackOutcome, _FallbackDetails)),
                             best(candidate(BestName, BestOutcome, BestScore, _))),
                    proof_graph(nodes(Nodes), edges(Edges))) :-
    strategy_nodes(Strategies, StrategyNodes),
    lemma_nodes(Lemmas, LemmaNodes),
    append([ [node(theorem(Theorem))], StrategyNodes, LemmaNodes, [node(best(BestName, BestOutcome, BestScore)), node(fallback(FallbackName, FallbackOutcome))] ], Nodes),
    findall(edge(theorem(Theorem), strategy(Name)),
            member(strategy(Name, _Weight), Strategies),
            TheoremToStrategyEdges),
    findall(edge(strategy(Name), best(BestName)),
            member(strategy(Name, _Weight), Strategies),
            StrategyToBestEdges),
    append([TheoremToStrategyEdges,
            StrategyToBestEdges,
            [edge(best(BestName), fallback(FallbackName))]],
           Edges).
proof_graph_display(Theorem, _Evidence,
                    proof_graph(nodes([node(theorem(Theorem)), node(best(unavailable))]),
                                edges([edge(theorem(Theorem), best(unavailable))]))).

term_rewrite_visualiser(Theorem,
                        story(lines(_Lines), trace(Trace), visual(VisualFrames), failure(FailureLine)),
                        Frames) :-
    Frames = [ rewrite(goal, Theorem),
               rewrite(trace, Trace),
               rewrite(visual_frames, VisualFrames),
               rewrite(result, FailureLine)
             ].

cfg_visualiser(_Theorem, cfg(nodes(Nodes), edges(Edges))) :-
    example_program(Program),
    generate_call_graph(Program, Edges),
    call_graph_nodes(Edges, Nodes).

proof_tree_explorer(Theorem,
                    evidence(strategies(_Strategies),
                             lemmas(_Lemmas),
                             ranked_proofs(_RankedProofs),
                             fallback(fallback(FallbackName, Tried, FallbackOutcome, _FallbackDetails)),
                             best(candidate(BestName, BestOutcome, BestScore, _BestDetails))),
                    proof_tree(root(Theorem),
                               best(candidate(BestName, BestOutcome, BestScore)),
                               fallback(fallback(FallbackName, Tried, FallbackOutcome)))).
proof_tree_explorer(Theorem, _Evidence,
                    proof_tree(root(Theorem),
                               best(candidate(unavailable, failed, 0)),
                               fallback(fallback(no_strategy, [], failed)))).

discovered_formula(evidence(strategies(_Strategies), lemmas(Lemmas), _Ranked, _Fallback, _Best), Formula) :-
    member(lemma(discovered_formula(_Predicate, Formula)), Lemmas),
    !.
discovered_formula(_Evidence, n*(n+1)/2).

strategy_nodes(Strategies, Nodes) :-
    findall(node(strategy(Name, Weight)),
            member(strategy(Name, Weight), Strategies),
            Nodes).

lemma_nodes(Lemmas, Nodes) :-
    findall(node(lemma(Lemma)),
            member(Lemma, Lemmas),
            Nodes).

call_graph_nodes(Edges, Nodes) :-
    findall(Node,
            ( member(edge(Caller, _Callee), Edges),
              Node = Caller
            ),
            CallerNodes),
    findall(Node,
            ( member(edge(_Caller, Callee), Edges),
              Node = Callee
            ),
            CalleeNodes),
    append(CallerNodes, CalleeNodes, AllNodes),
    sort(AllNodes, UniqueNodes),
    findall(node(Id), member(Id, UniqueNodes), Nodes).
