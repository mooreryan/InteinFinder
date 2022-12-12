Run the pipeline

  $ InteinFinder config.toml 2> err
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

Check the trimmed inteins

  $ cat if_out/results/3_trimmed_inteins.faa
  >s1_contains___green_2018___seq_11___region_1___start_51___end_213
  CLAKGTRLLRYDGSEVNVEDVXXXXXREGDELLGPDGTPRRAFNIVNXXXXXGQDRLYRIKIDSEIEDLVVTPNHILVLHRENETVEITAEEFAALEAAERSQYRAPRTFPEQWNQASGDIVAQAPSFFIKDISLEAETTEWAGFRVDKDQLYLRYDYLVLHN
  >s2_contains___green_2018___seq_250___region_1___start_51___end_202
  CLNIHELIIKCYKSTRSNPLIXXXXXXXFYKECLSSNKQLLKTYEKYKLXXXXXXXHPQIRQTTKQYRYKLLNNKYCSIAVTHNHQVLTIIGWRKADALKYKEKIVENTLKEQNMNFLIQNIDFQQQKYSMNDLSVSETQAFMCSNQYILHN
