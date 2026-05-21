:- begin_tests(stage8_external_backends).

:- use_module('../src/stage8_external_backends').
:- use_module(library(readutil)).

test(export_proof_text_lean_contains_theorem_and_formula) :-
    export_proof_text(sum_formula, lean, Text),
    sub_atom(Text, _, _, _, 'theorem sum_formula'),
    sub_atom(Text, _, _, _, 'recursive_sum n = n*(n+1)/2').

test(export_proof_text_coq_contains_theorem_and_formula) :-
    export_proof_text(sum_formula, coq, Text),
    sub_atom(Text, _, _, _, 'Theorem sum_formula'),
    sub_atom(Text, _, _, _, 'recursive_sum n = n*(n+1)/2').

test(export_proof_text_smtlib_contains_check_sat) :-
    export_proof_text(sum_formula, smtlib, Text),
    sub_atom(Text, _, _, _, '(check-sat)'),
    sub_atom(Text, _, _, _, 'recursive_sum n').

test(export_proof_text_tptp_contains_conjecture) :-
    export_proof_text(sum_formula, tptp, Text),
    sub_atom(Text, _, _, _, 'fof(sum_formula, conjecture'),
    sub_atom(Text, _, _, _, 'recursive_sum(N)').

test(export_proof_acceptance_default_file) :-
    export_proof(sum_formula, lean, File),
    exists_file(File),
    read_file_to_string(File, Contents, []),
    sub_string(Contents, _, _, _, "theorem sum_formula"),
    cleanup_export_file(File).

test(export_proof_rejects_unknown_backend,
     [error(domain_error(export_backend, xml), _)]) :-
    export_proof_text(sum_formula, xml, _).

test(export_proof_rejects_unknown_theorem_formula,
     [error(existence_error(export_profile, missing_formula_theorem), _)]) :-
    export_proof_text(missing_formula_theorem, lean, _).

:- end_tests(stage8_external_backends).

cleanup_export_file(File) :-
    (   exists_file(File)
    ->  delete_file(File)
    ;   true
    ),
    file_directory_name(File, Directory),
    (   exists_directory(Directory)
    ->  directory_files(Directory, Entries),
        subtract(Entries, ['.', '..'], UserEntries),
        (   UserEntries == []
        ->  delete_directory(Directory)
        ;   true
        )
    ;   true
    ).
