open! Core

let remove_if_exists name =
  if Sys_unix.file_exists_exn name then Utils.rm_rf name

let remove_empty_log_files logs_dir =
  Utils.ls_dir logs_dir
  |> List.iter ~f:(fun name -> Utils.remove_file_if_empty name)

let remove_aln_dir aln_dir should_remove_aln_files =
  if should_remove_aln_files then Utils.rm_rf aln_dir

let remove_trimmed_inteins_if_empty trimmed_inteins_file_name =
  Utils.remove_file_if_empty trimmed_inteins_file_name ;
  if not (Sys_unix.file_exists_exn trimmed_inteins_file_name) then
    Logs.info (fun m -> m "There were no trimmable inteins")

let clean_up ~query_splits_dir ~logs_dir ~rpsblast_db_dir ~renamed_queries
    ~aln_dir ~should_remove_aln_files ~trimmed_inteins_file_name =
  remove_if_exists query_splits_dir ;
  remove_empty_log_files logs_dir ;
  remove_if_exists rpsblast_db_dir ;
  remove_if_exists renamed_queries.Filter_and_rename_queries.file_name ;
  remove_aln_dir aln_dir should_remove_aln_files ;
  remove_trimmed_inteins_if_empty trimmed_inteins_file_name
