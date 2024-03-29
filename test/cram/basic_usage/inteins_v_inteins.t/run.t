Inteins vs inteins

  $ InteinFinder inteins_v_inteins.toml 2> err
  $ ../../scripts/redact_log_timestamp err
  INFO [DATETIME] Renaming queries
  INFO [DATETIME] Splitting queries
  INFO [DATETIME] Making profile DB
  INFO [DATETIME] Running rpsblast
  INFO [DATETIME] Running mmseqs
  INFO [DATETIME] Getting query regions
  INFO [DATETIME] Writing putative intein regions
  INFO [DATETIME] Getting queries with intein seq hits
  INFO [DATETIME] Making query_region_hits
  INFO [DATETIME] Reading intein DB into memory
  INFO [DATETIME] Processing regions
  INFO [DATETIME] Writing name map
  INFO [DATETIME] Renaming queries in btab files
  INFO [DATETIME] Summarizing intein DB search
  INFO [DATETIME] Summarizing conserved domain DB search
  INFO [DATETIME] Done!

Show output directory

  $ tree --nolinks if_out | ../../scripts/redact_date /dev/stdin | grep -v -E '[0-9]+ directories, [0-9]+ files'
  if_out
  |-- _done
  |-- logs
  |   |-- 1_config.toml
  |   |-- 2_pipeline_info.txt
  |   `-- if_log.DATE.mmseqs_search.txt
  |-- results
  |   |-- 1_putative_intein_regions.tsv
  |   |-- 2_intein_hit_checks.tsv
  |   `-- 3_trimmed_inteins.faa
  `-- search
      |-- cdm_db
      |   |-- 1_cdm_db_search_out.tsv
      |   `-- 2_cdm_db_search_summary.tsv
      `-- intein_db
          |-- 1_intein_db_search_out.tsv
          |-- 2_intein_db_search_with_regions.tsv
          `-- 3_intein_db_search_summary.tsv
  

Show the putative intein regions

  $ column -t -s "$(printf '\t')" if_out/results/1_putative_intein_regions.tsv
  query                  region_index  start  end
  green_2018___seq_11    1             1      153
  kelley_2016___seq_111  1             1      312
  green_2018___seq_250   1             1      138
  green_2018___seq_359   1             1      307
  inbase___seq_219       1             1      378
  inbase___seq_236       1             1      322
  inbase___seq_440       1             1      455
  inbase___seq_524       1             1      532
  kelley_2016___seq_1    1             1      331
  kelley_2016___seq_9    1             1      331

Show some of the intein hit checks.

  $ sort -t "$(printf '\t')" -k1,1 -k2,2n if_out/results/2_intein_hit_checks.tsv | head | column -t -s "$(printf '\t')"
  green_2018___seq_11    1  green_2018___seq_11    None  C  H  N  None  153  Pass (T1 C)  Pass (T1 HN)  NA  Pass (At 1)  Pass (At 153)  Pass  Pass (T1)
  green_2018___seq_250   1  green_2018___seq_250   None  C  H  N  None  138  Pass (T1 C)  Pass (T1 HN)  NA  Pass (At 1)  Pass (At 138)  Pass  Pass (T1)
  green_2018___seq_359   1  green_2018___seq_359   None  S  R  D  None  307  Pass (T1 S)  Pass (T2 RD)  NA  Pass (At 1)  Pass (At 307)  Pass  Pass (T2)
  inbase___seq_219       1  inbase___seq_219       None  C  H  N  None  378  Pass (T1 C)  Pass (T1 HN)  NA  Pass (At 1)  Pass (At 378)  Pass  Pass (T1)
  inbase___seq_236       1  inbase___seq_236       None  A  H  N  None  322  Pass (T1 A)  Pass (T1 HN)  NA  Pass (At 1)  Pass (At 322)  Pass  Pass (T1)
  inbase___seq_440       1  inbase___seq_440       None  C  S  N  None  455  Pass (T1 C)  Pass (T1 SN)  NA  Pass (At 1)  Pass (At 455)  Pass  Pass (T1)
  inbase___seq_524       1  inbase___seq_524       None  S  H  N  None  532  Pass (T1 S)  Pass (T1 HN)  NA  Pass (At 1)  Pass (At 532)  Pass  Pass (T1)
  kelley_2016___seq_1    1  kelley_2016___seq_1    None  A  H  N  None  331  Pass (T1 A)  Pass (T1 HN)  NA  Pass (At 1)  Pass (At 331)  Pass  Pass (T1)
  kelley_2016___seq_111  1  kelley_2016___seq_111  None  C  G  N  None  312  Pass (T1 C)  Pass (T1 GN)  NA  Pass (At 1)  Pass (At 312)  Pass  Pass (T1)
  kelley_2016___seq_9    1  kelley_2016___seq_9    None  S  H  N  None  331  Pass (T1 S)  Pass (T1 HN)  NA  Pass (At 1)  Pass (At 331)  Pass  Pass (T1)
