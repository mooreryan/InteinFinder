open! Core

let string_of_record (r : Btab_record.t) =
  let l =
    [ r.query
    ; r.target
    ; Float.to_string r.pident
    ; Int.to_string r.alnlen
    ; Int.to_string r.mismatch
    ; Int.to_string r.gapopen
    ; Int.to_string r.qstart
    ; Int.to_string r.qend
    ; Int.to_string r.tstart
    ; Int.to_string r.tend
    ; Float.to_string r.evalue
    ; Float.to_string r.bits ]
  in
  (* Only show the None stuff at the end if at least one is NOT none. *)
  let l =
    match (r.qlen, r.tlen) with
    | None, None ->
        l
    | _ ->
        l
        @ [ (match r.qlen with Some x -> Int.to_string x | None -> "None")
          ; (match r.tlen with Some x -> Int.to_string x | None -> "None") ]
  in
  String.concat ~sep:"\t" l

let rename_queries : btabs:string list -> name_map:string String.Map.t -> unit =
 fun ~btabs ~name_map ->
  let f name_map btab =
    let open Bio_io.Btab in
    let rename oc =
      In_channel.with_file_iter_records btab ~f:(fun r ->
          let (r : Record.Parsed.t) = Record.parse r in
          let new_name = r.query in
          let old_name = Map.find_exn name_map new_name in
          let r = {r with query= old_name} in
          let r = string_of_record r ^ "\n" in
          Out_channel.output_string oc r )
    in
    let in_dir = Filename.dirname btab in
    (* name_map is new name to old name *)
    (* Important: the temp file must be in the same dir as the btab because on
       biomix the default tmp dir is at a different physical location than the
       home directories. *)
    Utils.with_temp_file ~in_dir (fun out ->
        Out_channel.with_file out ~f:rename ;
        assert (Sys_unix.file_exists_exn out) ;
        Sys_unix.rename out btab ;
        assert (Sys_unix.file_exists_exn btab) ;
        assert (not (Sys_unix.file_exists_exn out)) )
  in
  List.iter btabs ~f:(f name_map)
