Length filter is too high and filters out all the sequences.

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ InteinFinder bad_length_filter.toml 2> err
  [2]
  $ ../../scripts/redact_log_timestamp err | grep -A1 Failure
    (Failure
     "There were no sequences that passed the length filter! Did you set it too high?")
