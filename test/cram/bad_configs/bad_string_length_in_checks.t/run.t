Wrong number string length in checks

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ InteinFinder bad_string_length_in_checks.toml 2> err
  [2]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: start_residue"
    ("config error: start_residue -> pass"
     ("expected string to be a single character but got 'apple'"
      (Failure "Char.of_string: \"apple\"")))
    ("config error: start_residue -> maybe"
     ("expected string to be a single character but got 'pie'"
      (Failure "Char.of_string: \"pie\""))))
   ("config error: end_residues"
    ("config error: end_residues -> maybe"
     "expected two end residues but got 'ryan'"))
   ("config error: end_plus_one_residue"
    ("config error: end_plus_one_residue -> pass"
     ("expected string to be a single character but got 'ice cream'"
      (Failure "Char.of_string: \"ice cream\"")))
    ("config error: end_plus_one_residue -> maybe"
     ("expected string to be a single character but got 'magic'"
      (Failure "Char.of_string: \"magic\"")))))
