:- begin_tests(stage8_external_backends).

:- use_module('../src/stage8_external_backends').
:- use_module(library(readutil)).

test(lean_exporter_contains_theorem_and_formula) :-
    export_proof_text(sum_formula, lean, Text),
    sub_atom(Text, _, _, _, 'theorem sum_formula'),
    sub_atom(Text, _, _, _, 'recursive_sum n = n*(n+1)/2').

test(coq_exporter_contains_theorem_and_formula) :-
    export_proof_text(sum_formula, coq, Text),
    sub_atom(Text, _, _, _, 'Theorem sum_formula'),
    sub_atom(Text, _, _, _, 'recursive_sum n = n*(n+1)/2').

test(smtlib_exporter_contains_check_sat) :-
    export_proof_text(sum_formula, smtlib, Text),
    sub_atom(Text, _, _, _, '(check-sat)'),
    sub_atom(Text, _, _, _, 'recursive_sum n').

test(tptp_exporter_contains_conjecture) :-
    export_proof_text(sum_formula, tptp, Text),
    sub_atom(Text, _, _, _, 'fof(sum_formula, conjecture'),
    sub_atom(Text, _, _, _, 'recursive_sum(N)').

test(export_proof_acceptance_default_file) :-
    export_proof(sum_formula, lean, File),
    exists_file(File),
    read_file_to_string(File, Contents, []),
    sub_string(Contents, _, _, _, "theorem sum_formula"),
    delete_file(File).

test(export_proof_rejects_unknown_backend,
     [error(domain_error(export_backend, xml), _)]) :-
    export_proof_text(sum_formula, xml, _).

:- end_tests(stage8_external_backends).
