Bad log level

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder bad_log_level.toml 2> err
  [1]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  "Log level must be one of 'error', 'warning', 'info', or 'debug'. Got 'infoo'"