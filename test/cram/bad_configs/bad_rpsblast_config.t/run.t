Bad rpsblast config

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder bad_rpsblast_config.toml 2> err
  [1]
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
    "expected E-value >= 0.0, but got -3.000000")
   ("config error: rpsblast -> num_splits"
    "expected num_split >= 1, but got 0"))
