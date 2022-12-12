open! Core

let config_file dir = dir ^/ "1_config.toml"

let intein_db_search_with_regions dir =
  dir ^/ "2_intein_db_search_with_regions.tsv"

let intein_hit_checks dir = dir ^/ "2_intein_hit_checks.tsv"

let intein_db_search_out dir = dir ^/ "1_intein_db_search_out.tsv"

let intein_db_search_summary dir = dir ^/ "3_intein_db_search_summary.tsv"

let pipeline_info dir = dir ^/ "2_pipeline_info.txt"

let putative_intein_regions dir = dir ^/ "1_putative_intein_regions.tsv"

let cdm_db_search_out dir = dir ^/ "1_cdm_db_search_out.tsv"

let cdm_db_search_summary dir = dir ^/ "2_cdm_db_search_summary.tsv"

let trimmed_inteins dir = dir ^/ "3_trimmed_inteins.faa"
