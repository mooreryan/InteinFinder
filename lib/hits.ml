open! Core

(** Given a bunch of btab files, define hit regions for each query. This takes
    both mmseqs hits and rpsblast hits to define the regions.*)
module Hit_regions = struct
  (** Keys are query names, values are the regions for that query.*)
  type t = Region.t list String.Map.t [@@deriving sexp_of]

  (* Pull this function out like this so we can quickcheck the process. *)
  let process_parsed_record hits record =
    let record = Btab_record.canonicalize record in
    Map.update hits record.query ~f:(function
        | None ->
            [record]
        | Some records ->
            record :: records )

  (** Parse a record, canonicalize it, then add it to the map of queries to
      hits. *)
  let process_record hits record =
    process_parsed_record hits @@ Bio_io.Btab.Record.parse record

  (** Read and canonicalize records from a btab. Outputs a map from query
      sequence to all hits.*)
  let read_hits_by_query btabs =
    let f records btab =
      Bio_io.Btab.In_channel.with_file_fold_records
        btab
        ~init:records
        ~f:process_record
    in
    List.fold btabs ~init:String.Map.empty ~f

  let sort_hits_by_query hits =
    Map.map hits ~f:(fun hits ->
        List.sort hits ~compare:(fun a z -> Btab_record.compare_qstart_qend a z) )

  (** Take [sorted_hits] output regions for each query. *)
  let regions_of_sorted_hits sorted_hits : t =
    Map.map sorted_hits ~f:(fun records ->
        match records with
        | [] ->
            invalid_arg "records should never be empty" [@coverage off]
        | [record] ->
            let region = Region.of_btab_record_exn record in
            [region]
        | record :: records ->
            let region = Region.of_btab_record_exn record in
            let regions = [region] in
            List.rev @@ List.fold records ~init:regions ~f:Region.update_regions )

  let add_indices : t -> t =
   fun region_list ->
    Map.map region_list ~f:(fun l ->
        List.mapi l ~f:(fun index region -> Region.with_index region ~index) )

  let of_btabs : string list -> t =
   fun btabs ->
    let x = btabs |> read_hits_by_query in
    let y = x |> sort_hits_by_query in
    let z = y |> regions_of_sorted_hits in
    z |> add_indices

  let queries_with_hits t = Map.keys t |> String.Set.of_list

  let to_string :
      t -> query_new_name_to_old_name:string Map.M(String).t -> string =
   fun t ~query_new_name_to_old_name ->
    let region_to_string (region : Region.t) =
      Region.to_string' region ~query_new_name_to_old_name
      |> Option.value_exn
           ~error:
             (Error.createf
                "name of the query in the region (%s) was not found in the \
                 name map"
                region.query )
    in
    Map.fold t ~init:[] ~f:(fun ~key:_ ~data:regions acc ->
        let regions =
          List.map regions ~f:region_to_string |> String.concat ~sep:"\n"
        in
        regions :: acc )
    |> List.rev |> String.concat ~sep:"\n"

  let to_string_header () = Region.to_string_header ()

  let write_hit_regions_file t ~renamed_queries_name_map ~out_file =
    let header = to_string_header () in
    let data =
      to_string t ~query_new_name_to_old_name:renamed_queries_name_map
    in
    Out_channel.write_lines out_file [header; data]

  let pick_queries_with_hits :
         renamed_queries:Filter_and_rename_queries.t
      -> hit_regions:t
      -> Alignment.Record.query_raw String.Map.t =
   fun ~renamed_queries ~hit_regions ->
    let open Bio_io.Fasta in
    let file_name = renamed_queries.file_name in
    let keep_these = queries_with_hits hit_regions in
    In_channel.with_file_fold_records
      file_name
      ~init:String.Map.empty
      ~f:(fun records record ->
        let name = Record.id record in
        if Set.mem keep_these name then
          let data = Alignment.Record.query_raw record in
          Map.add_exn records ~key:name ~data
        else records )
end

(** Each query will have zero or more intein hits. I.e., hits from the query
    sequence to a sequence in the InteinFinder's intein DB. Not the conserved
    domain DB, but the actual intein sequence database. Each of these will also
    be associated with a particular region on the query sequence. The regions on
    the query sequence are defined by ALL the homology search hits, to both the
    seq DB and the domain DB. *)
module Intein_hits = struct
  let hd_exn l ~msg =
    Or_error.try_with (fun () -> List.hd_exn l)
    |> Or_error.tag ~tag:msg |> Or_error.ok_exn

  (* Convenience module. We are treating each btab record as a "hit". *)
  module Hit = struct
    [@@@coverage off]

    type t = {hit: Bio_io.Btab.Record.Parsed.t; region: Region.t}
    [@@deriving sexp_of, fields]

    [@@@coverage on]

    (** Descending bit score comparison for two hits. *)
    let compare_bits_desc a z = Btab_record.compare_bits_desc (hit a) (hit z)

    (** Sort by decreasing bit score. *)
    let sort_list hits = List.sort hits ~compare:compare_bits_desc
  end

  module Region_hits = struct
    (** Assumes that all hits are to the same query. *)
    type t = Hit.t list Int.Map.t [@@deriving sexp_of]

    let empty () : t = Int.Map.empty

    (** Sort each region's hits by the descending bit score. *)
    let sort_hits (t : t) = Map.map t ~f:Hit.sort_list
  end

  (** Kind of awkward name but it is a map from query->region->hits ...thus
      query_region_hits. *)
  module Query_region_hits = struct
    (** multi-layer map: Query -> Region -> InteinDB hits *)
    type t = Region_hits.t String.Map.t [@@deriving sexp_of]

    let empty () : t = String.Map.empty

    let add_hit : t -> query:string -> region:Region.t -> hit:Hit.t -> t =
     fun t ~query ~region ~hit ->
      Map.update t query ~f:(function
          | Some region_hits ->
              Map.update region_hits region.index ~f:(function
                  | Some hits ->
                      hit :: hits
                  | None ->
                      [hit] )
          | None ->
              let region_hits = Region_hits.empty () in
              (* Safe because the region is not present if you get to this
                 branch. *)
              Map.add_exn region_hits ~key:region.index ~data:[hit] )

    let sort t = Map.map t ~f:Region_hits.sort_hits

    let of_mmseqs_search_out : Mmseqs_search.Out.t -> Hit_regions.t -> t =
     fun mmseqs_search_out query_regions ->
      let btab = Mmseqs_search.Out.out mmseqs_search_out in
      let x =
        Bio_io.Btab.In_channel.with_file_fold_records
          btab
          ~init:(empty ())
          ~f:(fun hits record ->
            (* See Regions.process_parsed_record *)
            let record =
              Bio_io.Btab.Record.parse record |> Btab_record.canonicalize
            in
            let query = record.query in
            let this_region = Region.of_btab_record_exn record in
            (* Should be safe because regions were build partially from the
               mmseqs file. If you get an exception here, it is a bug. *)
            let regions_for_query = Map.find_exn query_regions query in
            let this_region =
              List.filter regions_for_query ~f:(fun region ->
                  (* Does the region contain the current region as defined by
                     this hit? If so, keep it. *)
                  Region.contains ~this:region ~other:this_region )
            in
            let this_region =
              hd_exn
                this_region
                ~msg:"Should have one and only one matching region"
            in
            let intein_hit_with_region =
              {Hit.hit= record; region= this_region}
            in
            add_hit hits ~query ~region:this_region ~hit:intein_hit_with_region )
      in
      sort x

    let iter_regions :
           t
        -> jobs:int
        -> f:
             (   query:string
              -> region_index:int
              -> hits:Hit.t list
              -> unit Async.Deferred.t )
        -> unit Async.Deferred.t =
     fun t ~jobs ~f ->
      let open Async in
      Deferred.Map.iteri
        t
        ~how:(`Max_concurrent_jobs jobs)
        ~f:(fun ~key:query ~data:region_hits ->
          Deferred.Map.iteri
            region_hits
            ~how:`Sequential
            ~f:(fun ~key:region_index ~data:hits ->
              f ~query ~region_index ~hits ) )

    let iter_hits :
        t -> f:(query:string -> region:int -> hit:Hit.t -> unit) -> unit =
     fun t ~f ->
      Map.iteri t ~f:(fun ~key:query ~data:region_hits ->
          Map.iteri region_hits ~f:(fun ~key:region ~data:hits ->
              List.iter hits ~f:(fun hit -> f ~query ~region ~hit) ) )

    let process_query_region_hits :
           query_region_hits:t
        -> intein_db_seqs:
             (string, Alignment.Record.intein_raw, 'a) Map_intf.Map.t
        -> queries_with_hits:
             (string, Alignment.Record.query_raw, 'b) Map_intf.Map.t
        -> clip_region_padding:int
        -> query_new_name_to_old_name:string Map.M(String).t
        -> aln_dir:string
        -> log_base:string
        -> jobs:int
        -> min_region_length:int
        -> results_dir:string
        -> should_remove_aln_files:bool
        -> config:Config.t
        -> unit =
     fun ~query_region_hits
         ~intein_db_seqs
         ~queries_with_hits
         ~clip_region_padding
         ~query_new_name_to_old_name
         ~aln_dir
         ~log_base
         ~jobs
         ~min_region_length
         ~results_dir
         ~should_remove_aln_files
         ~config ->
      let module R = Bio_io.Fasta.Record in
      let trimmed_inteins_file_name =
        Out_file_name.trimmed_inteins results_dir
      in
      let query_intein_hit_checks_file_name =
        results_dir ^/ "2_intein_hit_checks.tsv"
      in
      let f () =
        let write_header writer =
          let open Async in
          let flush () = Writer.flushed writer in
          let header = Alignment.uber_header () in
          Writer.write_line writer header ;
          flush ()
        in
        let process_regions ~intein_checks_writer ~trimmed_inteins_writer =
          iter_regions
            query_region_hits
            ~jobs
            ~f:(fun ~query:query_name ~region_index ~hits ->
              let region_is_too_short region min_region_length =
                Region.length region < min_region_length
              in
              let find_sequence_by_name sequences name =
                Map.find_exn sequences name
              in
              let find_query_seq query_name =
                find_sequence_by_name queries_with_hits query_name
              in
              let find_intein_seq intein_name =
                find_sequence_by_name intein_db_seqs intein_name
              in
              let intein_name intein_hit = Btab_record.target intein_hit in
              let process_hit (hit_index : int)
                  ({hit= intein_hit; region} : Hit.t) : unit Async.Deferred.t =
                if region_is_too_short region min_region_length then
                  Async.Deferred.return ()
                else
                  Alignment.run_alignment_and_write_checks
                    ~aln_dir
                    ~query_name
                    ~query_seq:(find_query_seq query_name)
                    ~intein_seq:(find_intein_seq @@ intein_name intein_hit)
                    ~region_index
                    ~hit_index
                    ~log_base
                    ~clip_region_padding
                    ~region
                    ~query_new_name_to_old_name
                    ~intein_checks_writer
                    ~trimmed_inteins_writer
                    ~should_remove_aln_files
                    ~config
              in
              Utils.iter_and_swallow_error (fun () ->
                  Async.Deferred.List.iteri hits ~how:`Sequential ~f:process_hit ) )
        in
        Async.Writer.with_file
          trimmed_inteins_file_name
          ~f:(fun trimmed_inteins_writer ->
            Async.Writer.with_file
              query_intein_hit_checks_file_name
              ~f:(fun intein_checks_writer ->
                let%bind.Async.Deferred () =
                  write_header intein_checks_writer
                in
                process_regions ~intein_checks_writer ~trimmed_inteins_writer ) )
      in
      Async.Thread_safe.block_on_async_exn f
  end
end

type t =
  { queries_with_hits: Alignment.Record.query_raw String.Map.t
  ; query_region_hits: Intein_hits.Query_region_hits.t }

(** The main entry point for this module. Get the hit info, print the regions,
    etc. *)
let create ~btabs ~renamed_queries ~results_dir ~mmseqs_search_out =
  let hit_regions =
    Logs.info (fun m -> m "Getting query regions") ;
    Hit_regions.of_btabs btabs
  in
  let out_file = results_dir ^/ "0_putative_intein_regions.tsv" in
  let () =
    Logs.info (fun m -> m "Writing putative intein regions") ;
    Hit_regions.write_hit_regions_file
      hit_regions
      ~renamed_queries_name_map:
        renamed_queries.Filter_and_rename_queries.name_map
      ~out_file
  in
  let queries_with_hits : Alignment.Record.query_raw String.Map.t =
    Logs.info (fun m -> m "Getting queries with intein seq hits") ;
    Hit_regions.pick_queries_with_hits ~renamed_queries ~hit_regions
  in
  (* Go through the mmseqs btab again. You need to associate each of the hits
     (ie query-inteinDB pair with one of the regions.) *)
  let query_region_hits : Intein_hits.Query_region_hits.t =
    Logs.info (fun m -> m "Making query_region_hits") ;
    (* You will use these to generate clipping regions for the alignment. *)
    Intein_hits.Query_region_hits.of_mmseqs_search_out
      mmseqs_search_out
      hit_regions
  in
  {queries_with_hits; query_region_hits}
