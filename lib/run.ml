open! Core

(* Write query_intein_hit_info_file_name, intein_hit_info *)
let write_query_intein_hit_info_file ~query_region_hits ~renamed_queries
    ~result_dir =
  let query_intein_hit_info_file_name =
    Out_file_name.intein_hit_info result_dir
  in
  Out_channel.with_file query_intein_hit_info_file_name ~f:(fun oc ->
      let header' =
        [ "query"
        ; "region"
        ; "region_start"
        ; "region_end"
        ; "target"
        ; "pident"
        ; "alnlen"
        ; "mismatch"
        ; "gapopen"
        ; "qstart"
        ; "qend"
        ; "tstart"
        ; "tend"
        ; "evalue"
        ; "bits"
        ; "qlen"
        ; "tlen" ]
      in
      let header = String.concat ~sep:"\t" header' in
      Out_channel.output_string oc (header ^ "\n") ;
      (* Print out the intein hits in the correct order *)
      Hits.Intein_hits.Query_region_hits.iter_hits
        query_region_hits
        ~f:(fun ~query ~region_index:_ ~hit ->
          let query =
            Map.find_exn
              renamed_queries.Filter_and_rename_queries.name_map
              query
          in
          let region : Region.t = hit.Hits.Intein_hits.Hit.region in
          let hit : Bio_io.Btab.Record.Parsed.t = hit.hit in
          let l =
            [ query
            ; Zero_indexed_int.to_one_indexed_string region.index
            ; (* NOTE: this isn't the region defined by the one single intein,
                 but the region defined by all the hits. *)
              Coord.to_one_indexed_string region.start
            ; Coord.to_one_indexed_string region.end_
            ; hit.target
            ; Float.to_string hit.pident
            ; Int.to_string hit.alnlen
            ; Int.to_string hit.mismatch
            ; Int.to_string hit.gapopen
            ; Int.to_string hit.qstart
            ; Int.to_string hit.qend
            ; Int.to_string hit.tstart
            ; Int.to_string hit.tend
            ; Float.to_string hit.evalue
            ; Float.to_string hit.bits
            ; (match hit.qlen with Some x -> Int.to_string x | None -> "None")
            ; (match hit.tlen with Some x -> Int.to_string x | None -> "None")
            ]
          in
          let line = String.concat ~sep:"\t" l ^ "\n" in
          Out_channel.output_string oc line ) )

let read_intein_db_seqs config : Alignment.Record.intein_raw String.Map.t =
  let read_intein_db_seqs file =
    Bio_io.Fasta.In_channel.with_file_fold_records
      file
      ~init:String.Map.empty
      ~f:(fun map record ->
        (* Some stuff in Hits.Intein_hits.Query_region_hits assumes this is
           true. *)
        assert (Bio_io.Fasta.Record.seq_length record >= 3) ;
        let key = Bio_io.Fasta.Record.id record in
        let data = Alignment.Record.intein_raw record in
        match Map.add map ~key ~data with
        | `Ok new_map ->
            new_map
        | `Duplicate ->
            map )
  in
  read_intein_db_seqs config.Config.inteins_file

(* This is so the user knows the names of the stuff in the alignments. *)
let write_name_map ~dir ~renamed_queries =
  let name_map_file_name = dir ^/ "1_name_map.tsv" in
  Out_channel.with_file name_map_file_name ~f:(fun oc ->
      let print = Out_channel.output_string oc in
      print "new_name\told_name\n" ;
      Map.iteri
        renamed_queries.Filter_and_rename_queries.name_map
        ~f:(fun ~key ~data -> print [%string "%{key}\t%{data}\n"]) )

let write_done_file config =
  (* If you make it here everything should be good *)
  ignore @@ Utils.touch (config.Config.out_dir ^/ "_done")

let run : Config.t -> string -> unit =
 fun config config_file ->
  Logging.set_log_level config.log_level ;
  (* Set up stuff. *)
  let dir = Dir.v config.out_dir |> Dir.mkdirs in
  Config.write_pipeline_info config dir.logs ;
  Config.write_config_file ~config_file ~dir:dir.logs ;
  let log_base = dir.logs ^/ "if_log" in
  let renamed_queries : Filter_and_rename_queries.t =
    Logs.info (fun m -> m "Renaming queries") ;
    Filter_and_rename_queries.rename_seqs
      ~seq_file:config.queries_file
      ~out_dir:config.out_dir
      ~min_length:config.min_query_length
  in
  let renamed_split_queries =
    Logs.info (fun m -> m "Splitting queries") ;
    Split_seqs.split_seqs
      ~seq_file:renamed_queries.file_name
      ~num_splits:config.threads
      ~out_dir:dir.query_splits
  in
  let smp_files = Smp_files.paths_exn config.smp_dir in
  let makeprofiledb_out =
    Logs.info (fun m -> m "Making profile DB") ;
    Rpsblast.Makeprofiledb.run
      ~exe:config.makeprofiledb.exe
      ~smp_files
      ~out_dir:dir.rpsblast_db
      ~log_base
  in
  let rpsblast_search_out =
    Logs.info (fun m -> m "Running rpsblast") ;
    Rpsblast.Search.run
      ~exe:config.rpsblast.exe
      ~query_files:renamed_split_queries.file_names
      ~target_db:makeprofiledb_out.db
      ~out_dir:dir.search
      ~evalue:config.rpsblast.evalue
      ~log_base
  in
  let mmseqs_search_out =
    Logs.info (fun m -> m "Running mmseqs") ;
    Mmseqs_search.run
      ~config:config.mmseqs
      ~queries:renamed_queries.file_name
      ~targets:config.inteins_file
      ~out_dir:dir.search
      ~log_base
      ~threads:config.threads
  in
  let btabs =
    [ Mmseqs_search.Out.out mmseqs_search_out
    ; Rpsblast.Search.Out.out rpsblast_search_out ]
  in
  let {Hits.queries_with_hits; query_region_hits} =
    Hits.create
      ~btabs
      ~renamed_queries
      ~results_dir:dir.results
      ~mmseqs_search_out
  in
  let () =
    write_query_intein_hit_info_file
      ~query_region_hits
      ~renamed_queries
      ~result_dir:dir.results
  in
  (* Read the intein DB seqs into memory. *)
  let intein_db_seqs : Alignment.Record.intein_raw String.Map.t =
    Logs.info (fun m -> m "Reading intein DB into memory") ;
    read_intein_db_seqs config
  in
  let () =
    Logs.info (fun m -> m "Processing regions") ;
    Hits.Intein_hits.Query_region_hits.process_query_region_hits
      ~query_region_hits
      ~intein_db_seqs
      ~queries_with_hits
      ~clip_region_padding:config.clip_region_padding
      ~query_new_name_to_old_name:renamed_queries.name_map
      ~aln_dir:dir.aln
      ~log_base
      ~jobs:config.threads
      ~results_dir:dir.results
      ~min_region_length:config.min_region_length
      ~should_remove_aln_files:config.remove_aln_files
      ~config
  in
  let () =
    Logs.info (fun m -> m "Writing name map") ;
    write_name_map ~dir:dir.aln ~renamed_queries
  in
  (* User wants to see the original names of the query sequences in the search
     files rather than the internal names used by the pipeline. *)
  let () =
    Logs.info (fun m -> m "Renaming queries in btab files") ;
    Rename_btab_queries.rename_queries ~btabs ~name_map:renamed_queries.name_map
  in
  (* Run the summaries on the renamed query outfiles. Better for user to read
     them. *)
  Search_summary.summarize_searches
    ~dir:dir.search
    ~mmseqs_search_out
    ~rpsblast_search_out ;
  Clean_up.clean_up
    ~query_splits_dir:dir.query_splits
    ~logs_dir:dir.logs
    ~rpsblast_db_dir:dir.rpsblast_db
    ~renamed_queries
    ~aln_dir:dir.aln
    ~should_remove_aln_files:config.remove_aln_files
    ~trimmed_inteins_file_name:(Out_file_name.trimmed_inteins dir.results) ;
  write_done_file config ;
  Logs.info (fun m -> m "Done!") ;
  ()
