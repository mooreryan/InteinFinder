No trimmed inteins

  $ InteinFinder no_inteins.toml 2> err
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
  INFO [DATETIME] There were no trimmable inteins
  INFO [DATETIME] Done!

Check

  $ ls if_out/results/
  1_putative_intein_regions.tsv
  3_intein_hit_checks.tsv
