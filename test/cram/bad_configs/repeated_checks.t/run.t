Repeated checks

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ InteinFinder repeated_checks.toml 2> err
  [2]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: start_residue" ("duplicate key" A))
   ("config error: end_residues" ("duplicate key" AA))
   ("config error: end_plus_one_residue" ("duplicate keys" (A B))))
