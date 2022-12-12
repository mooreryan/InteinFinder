Zero clip region padding

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ InteinFinder zero_clip_region_padding.toml 2> err
  $ ../../scripts/redact_log_timestamp err | grep Done
  INFO [DATETIME] Done!
  $ sort -t "$(printf '\t')" -k1,1 -k2,2n if_out/results/2_intein_hit_checks.tsv | cut -f1,16 | column -t -s "$(printf '\t')" 
  query                                            overall_check
  the_2_second_sequence                            Pass
  the_3_third_sequence                             Pass (Strict)
  the_4_fourth_sequence                            Pass (Strict)
  the_5_fifth_sequence                             Fail
  z1_little_piece_of___inbase___seq_524            Fail
  z2_little_piece_of___inbase___seq_524            Fail
  z3_start_of___kelley_2016___seq_9                Fail
  z3_start_of___kelley_2016___seq_9                Fail
  z3_start_of___kelley_2016___seq_9                Fail
  z3_start_of___kelley_2016___seq_9                Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  Fail
