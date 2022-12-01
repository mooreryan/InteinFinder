Input files that don't exist.

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder input_files_that_dont_exist.toml 2> err
  [1]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: inteins"
    "expected file 'fake_inteins' to exist, but it does not")
   ("config error: queries"
    "expected file 'fake_queries' to exist, but it does not")
   ("config error: smp_dir"
    "expected file 'fake_smp_dir' to exist, but it does not"))
