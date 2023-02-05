open! Core

let log_index i =
  if i % 100000 = 0 then
    let i = Float.(of_int i / of_int 1000000) in
    eprintf "Reading: %.1fM\r%!" i

let with_file_foldi_lines file ~init ~f =
  In_channel.with_file file ~f:(fun ic ->
      snd
      @@ In_channel.fold_lines ic ~init:(0, init) ~f:(fun (i, acc) line ->
             (i + 1, f i acc line) ) )

(* Note: There should only be a single overall pass per query. *)

(* overall check is 16th, start_position_check is 13th, end_position_check is
   14th *)

(* A pass of any tier counts as a pass. *)
let is_overall_pass overall_check =
  String.is_prefix overall_check ~prefix:"Pass"

(* let position_pass_at = Re.Perl.compile_pat "Pass \\(At ([0-9]+)\\)" *)

let position_pass_at =
  Re.(compile @@ seq [str "Pass (At "; group @@ rep1 digit; str ")"])

(* Raises if it doesn't match. *)
let get_position position =
  match
    Re.all position_pass_at position |> List.map ~f:(fun g -> Re.Group.get g 1)
  with
  | [] ->
      None
  | [position] ->
      (* Positions are one-indexed in the files, so convert here to
         zero-indexed. *)
      Some (Coord.one_raw_exn @@ Int.of_string position)
  | _ ->
      Utils.impossible "should only have a single match group" [@coverage off]

module Intein = struct
  [@@@coverage off]

  (** [Fail query] has the name of the query. [Pass region] has the [Region.t]
      (which includes the query). *)
  type t = Fail of string | Pass of Region.t [@@deriving variants]

  [@@@coverage on]

  let checks_pass = is_pass

  let create line =
    let a = String.split ~on:'\t' line |> Array.of_list in
    let query = a.(0) in
    (* Regions are 1-indexed in the output files. *)
    let region_index =
      Zero_indexed_int.of_zero_indexed_int (Int.of_string a.(1) - 1)
    in
    match (get_position a.(12), get_position a.(13)) with
    | Some start_position, Some end_position ->
        let region =
          Region.v_exn
            ~start:start_position
            ~end_:end_position
            ~index:region_index
            ~query
            ()
        in
        (* If the region is present, the intein can still be a failure if one of
           the other checks fail. So you need to still check it. *)
        if is_overall_pass a.(15) then Pass region else Fail query
    | _ ->
        Fail query
end

(** This sort is purly on the start and stop positions. Ignores the region
    index. We don't need it for this, and I will just assume it is wrong. It is
    basically the same as [Btab_record.compare_qstart_qend]. *)
let sort_regions regions =
  let compare_start_end : Region.t -> Region.t -> int =
   fun a z ->
    (* First try to compare based on increasing start. *)
    match Coord.compare a.start z.start with
    (* If start is equal for both regions, sort the one with the lower end
       first. *)
    | 0 ->
        (* NOTE: if you get here then you probably have a very weird problem
           with your inteins, but we will worry about that another time. *)
        Coord.compare a.end_ z.end_
    (* If not equal, just return the original sort result. *)
    | n ->
        n
  in
  List.sort regions ~compare:compare_start_end

[@@@coverage off]

(** I.e., what you need for a [String.sub] call. *)
type extein_part = {pos: int; len: int} [@@deriving sexp_of]

[@@@coverage on]

(* IMPORTANT: Only regions that PASS should be included in [intein_regions].
   Anything in this list will be trimmed out here. *)
let extein_regions :
    Bio_io_ext.Fasta.Record.query_raw -> Region.t list -> extein_part list =
 fun (Bio_io_ext.Fasta.Record.Query_raw query_seq) intein_regions ->
  let query_seq_end =
    Bio_io.Fasta.Record.seq_length query_seq |> Coord.one_raw_exn
  in
  let sorted_intein_regions = sort_regions intein_regions in
  let extein_parts, current_extein_pos =
    List.fold
      sorted_intein_regions
      (* Starting on 1 even if the intein is at the start of the sequence is
         fine...the extein part will be the empty string and no problems. See
         below. *)
      ~init:([], Some (Coord.one_raw_exn 1))
      ~f:(fun (extein_parts, current_extein_pos) intein_region ->
        let current_extein_pos =
          current_extein_pos
          |> Option.value_exn
               ~here:[%here]
               ~message:
                 "current_extein_pos was None but there are still more intein \
                  regions"
        in
        let len =
          Coord.length
            ~start:current_extein_pos
            ~end_:intein_region.start
            ~end_is:`exclusive
            ()
        in
        let extein_part =
          if len = 0 then None
          else Some {pos= Coord.to_zero_indexed_int current_extein_pos; len}
        in
        let next_extein_pos =
          let intein_end_is_before_query_end =
            Coord.(intein_region.end_ < query_seq_end)
          in
          if intein_end_is_before_query_end then
            Some (Coord.incr intein_region.end_)
          else None
        in
        (extein_part :: extein_parts, next_extein_pos) )
  in
  let extein_parts =
    match current_extein_pos with
    | None ->
        (* The final intein was at the very end of the sequence and there is no
           more extein to pull off *)
        extein_parts
    | Some current_extein_pos ->
        (* The final intein was NOT at the end of the sequence and there is
           still intein to pull off. *)
        let len =
          (* Check <= because there could be one little piece of extein passed
             the intein. *)
          assert (Coord.(current_extein_pos <= query_seq_end)) ;
          Coord.length
            ~start:current_extein_pos
            ~end_:query_seq_end
            ~end_is:`inclusive
            ()
        in
        let extein_part =
          assert (len > 0) ;
          Some {pos= Coord.to_zero_indexed_int current_extein_pos; len}
        in
        let new_extein_parts = extein_part :: extein_parts in
        new_extein_parts
  in
  extein_parts |> List.filter_opt |> List.rev

(** Given a query sequence and the extein parts,
    [trim_inteins query_seq extein_parts] returns a the query as a string with
    all of the bonafide inteins removed. Note that if a query has more than one
    intein, only the ones with overall pass will be trimmed out. Thus, inteins
    may remain after this. *)
let trim_inteins (Bio_io_ext.Fasta.Record.Query_raw query_seq) extein_parts =
  let s = Bio_io.Fasta.Record.seq query_seq in
  List.map extein_parts ~f:(fun {pos; len} -> String.sub s ~pos ~len)
  |> String.concat ~sep:""

(* Return a map of query IDs => check list *)
let read_intein_hit_checks file =
  let expected_header = Alignment.uber_header () in
  (* map key is the query, value is a list of checks *)
  with_file_foldi_lines
    file
    ~init:String.Map.empty
    ~f:(fun i query_inteins line ->
      log_index i ;
      if i = 0 && String.(expected_header <> line) then
        failwiths
          ~here:[%here]
          "Intein hit checks had the wrong header. Did you provide \
           2_intein_hit_checks.tsv?"
          line
          String.sexp_of_t
      else if i = 0 then query_inteins
      else
        let query, region =
          match Intein.create line with
          | Pass region ->
              (region.query, Some region)
          | Fail query ->
              (query, None)
        in
        (* We want to track Fail intiens as well so that we can warn the user
           later if needed. *)
        Map.update query_inteins query ~f:(function
            | None ->
                [region]
            | Some inteins ->
                region :: inteins ) )

(* Drop the Nones (aka Fails) and warn the user if there is a mix of passes and
   fails. *)
let keep_passing_inteins query_id intein_regions =
  let all_good = List.filter_opt intein_regions in
  let all_good_count = List.length all_good in
  (* If it is zero, then there are only bad inteins...no warning necessary as it
     won't get printed anyway. IF it is less than the starting number, then you
     know at least one bad one was present. *)
  if all_good_count > 0 && all_good_count < List.length intein_regions then
    Logs.warn (fun m ->
        m
          "Query %S had at least one non-bonafide intein along with at least \
           one bonafide intein.  It will still have at least one intein \
           present."
          query_id ) ;
  all_good

let read_query_seqs file (query_inteins : Region.t option list String.Map.t) =
  let open Bio_io.Fasta in
  In_channel.with_file_iteri_records file ~f:(fun i record ->
      log_index i ;
      let id = Record.id record in
      match Map.find query_inteins id with
      | None ->
          ()
      | Some intein_regions -> (
        (* Warn the user if any of the intein_regions were non-Pass, then remove
           those. *)
        match keep_passing_inteins id intein_regions with
        | _hd :: _tl as intein_regions ->
            let extein_regions =
              extein_regions
                (Bio_io_ext.Fasta.Record.query_raw record)
                intein_regions
            in
            let extein_seq =
              trim_inteins
                (Bio_io_ext.Fasta.Record.query_raw record)
                extein_regions
            in
            let extein_record = Record.with_seq extein_seq record in
            Out_channel.output_string Out_channel.stdout
            @@ Record.to_string_nl extein_record
        | [] ->
            (* All the intein regions were Fails, so we print nothing. *)
            () ) )

let run ~intein_hit_checks ~queries =
  Logs.info (fun m -> m "Reading intein hit checks") ;
  let query_inteins = read_intein_hit_checks intein_hit_checks in
  Logs.info (fun m -> m "Reading the query sequences") ;
  read_query_seqs queries query_inteins
