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
    "expected key to be a single residue but got 'apple'"
    "expected key to be a single residue but got 'pie'")
   ("config error: end_residues"
    "expected key to be two end residues but got 'ryan'")
   ("config error: end_plus_one_residue"
    "expected key to be a single residue but got 'ice cream'"
    "expected key to be a single residue but got 'magic'"))
