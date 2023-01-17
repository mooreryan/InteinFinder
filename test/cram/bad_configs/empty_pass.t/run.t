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
  (("config error: start_residue"
    "Expected tiers to start at one and increase by one, but got: (2)")
   ("config error: end_residues"
    "Expected tiers to start at one and increase by one, but got: (2)")
   ("config error: end_plus_one_residue"
    "Expected tiers to start at one and increase by one, but got: (2)"))
