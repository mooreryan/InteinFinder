Bad mafft config

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ InteinFinder bad_mafft_config.toml 2> err
  [2]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  ("config error: mafft -> exe"
   "expected 'mafft_6736XE7robbOW5i' to be executable, but it was not")
