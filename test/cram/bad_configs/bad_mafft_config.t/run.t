Bad mafft config

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder bad_mafft_config.toml 2> err
  [1]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: mafft -> exe"
    "expected 'mafft_6736XE7robbOW5i' to be executable, but it was not")
   ("config error: mafft -> max_concurrent_jobs"
    "expected threads >= 1, but got 0"))
