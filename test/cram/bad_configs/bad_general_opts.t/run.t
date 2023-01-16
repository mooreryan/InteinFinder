Bad general opts

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ InteinFinder bad_general_opts.toml 2> err
  [2]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: clip_region_padding" "expected an int >= 0, but got -1")
   ("config error: min_query_length" "expected an int >= 0, but got -1")
   ("config error: min_region_length" "expected an int >= 0, but got -1")
   ("config error: threads" "expected an int > 0, but got 0"))
