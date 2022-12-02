Bad rpsblast exe

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder bad_rpsblast_exe.toml 2> err
  [1]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  ("config error: rpsblast -> exe"
   "expected 'qdrwqdrwqdrwqdrw' to be executable, but it was not")
