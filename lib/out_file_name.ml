open! Core

let config_file dir = dir ^/ "1_config.toml"

let intein_hit_info dir = dir ^/ "2_intein_hit_info.tsv"

let intein_hit_checks dir = dir ^/ "3_intein_hit_checks.tsv"

let mmseqs_search_out dir = dir ^/ "1_mmseqs_search_out.tsv"

let mmseqs_search_summary dir = dir ^/ "2_mmseqs_search_summary.tsv"

let pipeline_info dir = dir ^/ "2_pipeline_info.txt"

let putative_intein_regions dir = dir ^/ "1_putative_intein_regions.tsv"

let rpsblast_search_out dir = dir ^/ "1_rpsblast_search_out.tsv"

let rpsblast_search_summary dir = dir ^/ "2_rpsblast_search_summary.tsv"

let trimmed_inteins dir = dir ^/ "4_trimmed_inteins.faa"
