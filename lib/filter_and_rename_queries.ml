open! Core

[@@@coverage off]

type t = {file_name: string; name_map: string Map.M(String).t}
[@@deriving fields, sexp_of]

[@@@coverage on]

let new_name i =
  let i = Zero_indexed_int.to_one_indexed_string i in
  [%string "seq_%{i}"]

let old_name r = Bio_io.Fasta.Record.id r

let write_renamed oc orig new_name =
  let module R = Bio_io.Fasta.Record in
  let uppercase_seq = String.uppercase @@ R.seq orig in
  orig |> R.with_seq uppercase_seq |> R.with_id new_name |> R.with_desc None
  |> R.to_string_nl
  |> Out_channel.output_string oc

(* Writes fasta file with sequences renamed. Returns the name map from new name
   to old name. *)
let rename_seqs ~seq_file ~out_dir ~min_length =
  let open Bio_io.Fasta in
  let out_file = out_dir ^/ "queries_renamed.fa" in
  let write_and_update_name_map ~i ~r ~oc ~name_map =
    let new_name = new_name i in
    let old_name = old_name r in
    let () = write_renamed oc r new_name in
    Map.add_exn name_map ~key:new_name ~data:old_name
  in
  let record_is_long_enough r = Record.seq_length r >= min_length in
  let at_least_one_record_was_long_enough = ref false in
  let f oc =
    In_channel.with_file_foldi_records
      seq_file
      ~init:String.Map.empty
      ~f:(fun i name_map r ->
        let i = Zero_indexed_int.of_zero_indexed_int i in
        if record_is_long_enough r then (
          at_least_one_record_was_long_enough := true ;
          write_and_update_name_map ~i ~r ~oc ~name_map )
        else name_map )
  in
  let name_map = Out_channel.with_file out_file ~f in
  if not !at_least_one_record_was_long_enough then
    failwith
      "There were no sequences that passed the length filter! Did you set it \
       too high?" ;
  {file_name= out_file; name_map}
