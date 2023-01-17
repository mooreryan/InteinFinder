Empty pass spec in checks

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ InteinFinder empty_pass.toml 2> err
  [2]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: start_residue" "Bad tiers: (2)")
   ("config error: end_residues"
    ("config error: end_residues -> pass"
     "expected a non-empty list, but got an empty list"))
   ("config error: end_plus_one_residue" "Bad tiers: (2)"))
