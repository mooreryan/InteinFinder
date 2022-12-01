Huge clip region padding doesn't crash, but it doesn't as well as the
normal clip region.

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder huge_clip_region_padding.toml 2> err
  $ ../../scripts/redact_log_timestamp err | grep Done
  INFO [DATETIME] Done!
  $ sort -t "$(printf '\t')" -k1,1 -k2,2n if_out/results/2_intein_hit_checks.tsv | cut -f1,2,3,9,15,16 | column -t -s "$(printf '\t')" 
  query                                            region  intein_target        intein_length  region_check  overall_check
  the_2_second_sequence                            1       inbase___seq_440     1162           End_pass      Fail
  the_2_second_sequence                            1       inbase___seq_524     1239           Fail          Fail
  the_3_third_sequence                             0       inbase___seq_219     367            Pass          Pass (Strict)
  the_4_fourth_sequence                            1       inbase___seq_440     407            Pass          Pass (Strict)
  the_5_fifth_sequence                             0       inbase___seq_524     842            Fail          Fail
  z1_little_piece_of___inbase___seq_524            0       inbase___seq_524     None           Fail          Fail
  z2_little_piece_of___inbase___seq_524            0       inbase___seq_524     None           Fail          Fail
  z3_start_of___kelley_2016___seq_9                0       green_2018___seq_11  None           Start_pass    Fail
  z3_start_of___kelley_2016___seq_9                0       inbase___seq_236     None           Start_pass    Fail
  z3_start_of___kelley_2016___seq_9                0       kelley_2016___seq_1  None           Start_pass    Fail
  z3_start_of___kelley_2016___seq_9                0       kelley_2016___seq_9  None           Start_pass    Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  0       green_2018___seq_11  None           Fail          Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  0       inbase___seq_236     None           Fail          Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  0       kelley_2016___seq_1  None           Fail          Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  0       kelley_2016___seq_9  None           Fail          Fail
