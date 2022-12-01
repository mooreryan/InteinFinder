It works with more rpsblast splits than there are input sequences.

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder too_many_rpsblast_hits.toml 2> err
  $ ../../scripts/redact_log_timestamp err | grep Done
  INFO [DATETIME] Done!
