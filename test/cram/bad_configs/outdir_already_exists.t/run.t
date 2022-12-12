An error occurs if the directory already exists.

  $ mkdir snazzy_out
  $ InteinFinder outdir_already_exists.toml 2> err
  [2]
  $ ../../scripts/redact_log_timestamp err
  ERROR [DATETIME] could not generate config:
  ("config error: out_dir"
   "expected file 'snazzy_out' not to exist, but it does")
