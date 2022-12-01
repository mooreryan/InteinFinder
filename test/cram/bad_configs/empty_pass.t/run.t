Empty pass spec in checks

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder empty_pass.toml 2> err
  [1]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: start_residue"
    ("config error: start_residue -> pass"
     "expected a non-empty list, but got an empty list"))
   ("config error: end_residues"
    ("config error: end_residues -> pass"
     "expected a non-empty list, but got an empty list"))
   ("config error: end_plus_one_residue"
    ("config error: end_plus_one_residue -> pass"
     "expected a non-empty list, but got an empty list")))
