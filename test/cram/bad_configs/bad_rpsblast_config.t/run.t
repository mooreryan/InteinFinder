Bad rpsblast config

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ InteinFinder bad_rpsblast_config.toml 2> err
  [2]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: rpsblast -> exe"
    "expected 'rpsblast_dfVRzbebY1aa6sl' to be executable, but it was not")
   ("config error: rpsblast -> evalue"
    "expected E-value >= 0.0, but got -3.000000"))
