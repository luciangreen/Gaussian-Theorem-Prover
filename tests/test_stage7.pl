:- begin_tests(stage7_visualisation).

:- use_module('../src/stage7_visualisation').

test(browser_ide_has_expected_widgets) :-
    browser_ide(sum_formula, student, proved, Ide),
    Ide = ide(theorem(sum_formula), audience(student), status(proved), widgets(Widgets)),
    member(editor, Widgets),
    member(matrix_canvas, Widgets),
    member(proof_tree, Widgets).

test(matrix_animation_for_sum_formula_contains_formula_frame) :-
    Evidence = evidence(
        strategies([]),
        lemmas([lemma(discovered_formula(sum, n*(n+1)/2))]),
        ranked_proofs([]),
        fallback(fallback(no_strategy, [], failed, none)),
        best(candidate(none, failed, 0, none))
    ),
    matrix_animation(sum_formula, Evidence, Frames),
    member(frame(formula, n*(n+1)/2), Frames),
    member(frame(solution, _), Frames).

test(proof_graph_display_links_theorem_to_best_candidate) :-
    Evidence = evidence(
        strategies([strategy(formula_then_verify, 100), strategy(direct_verification, 90)]),
        lemmas([lemma(discovered_formula(sum, n*(n+1)/2))]),
        ranked_proofs([candidate(formula_then_verify, proved, 200, details(stage4_verification))]),
        fallback(fallback(formula_then_verify, [formula_then_verify], proved, details(stage4_verification))),
        best(candidate(formula_then_verify, proved, 200, details(stage4_verification)))
    ),
    proof_graph_display(sum_formula, Evidence, proof_graph(nodes(_Nodes), edges(Edges))),
    member(edge(theorem(sum_formula), strategy(formula_then_verify)), Edges),
    member(edge(best(formula_then_verify), fallback(formula_then_verify)), Edges).

test(term_rewrite_visualiser_includes_trace_and_failure_line) :-
    Story = story(lines(['line']), trace(['trace line']), visual([frame(formula, 'Recovered invariant')]), failure('No failure: theorem was proved.')),
    term_rewrite_visualiser(sum_formula, Story, Frames),
    member(rewrite(trace, ['trace line']), Frames),
    member(rewrite(result, 'No failure: theorem was proved.'), Frames).

test(cfg_visualiser_returns_sum_call_graph) :-
    cfg_visualiser(sum_formula, cfg(nodes(Nodes), edges(Edges))),
    member(node(sum/2), Nodes),
    member(edge(triangular/2, sum/2), Edges).

test(proof_tree_explorer_summarizes_best_and_fallback) :-
    Evidence = evidence(
        strategies([strategy(formula_then_verify, 100)]),
        lemmas([]),
        ranked_proofs([candidate(formula_then_verify, proved, 200, details(stage4_verification))]),
        fallback(fallback(formula_then_verify, [formula_then_verify], proved, details(stage4_verification))),
        best(candidate(formula_then_verify, proved, 200, details(stage4_verification)))
    ),
    proof_tree_explorer(sum_formula, Evidence, Tree),
    Tree = proof_tree(
        root(sum_formula),
        best(candidate(formula_then_verify, proved, 200)),
        fallback(fallback(formula_then_verify, [formula_then_verify], proved))
    ).

test(visualise_theorem_returns_full_visualisation_bundle) :-
    visualise_theorem(sum_formula, child, Visualisation),
    Visualisation = visualisation(
        ide(ide(theorem(sum_formula), audience(child), status(proved), widgets(_))),
        matrix(MatrixFrames),
        proof_graph(proof_graph(nodes(_), edges(_))),
        rewrites(RewriteFrames),
        cfg(cfg(nodes(_), edges(_))),
        proof_tree(proof_tree(root(sum_formula), best(_), fallback(_)))
    ),
    member(frame(formula, n*(n+1)/2), MatrixFrames),
    member(rewrite(goal, sum_formula), RewriteFrames).

:- end_tests(stage7_visualisation).
