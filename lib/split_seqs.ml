open! Core

[@@@coverage off]

type t = {file_names: string list; dir: string; basename: string}
[@@deriving fields, sexp_of]

type oc = {file_name: string; out_channel: Out_channel.t}

[@@@coverage on]

(** Helper to pack an [Out_channel.t] with a [file_name]. *)
let close_all ocs =
  Array.iter ocs ~f:(fun oc -> Out_channel.close oc.out_channel)

let pluck_file_names ocs =
  Array.fold ocs ~init:[] ~f:(fun file_names oc -> oc.file_name :: file_names)
  |> List.rev

(** Range for iterating over the splits based on [num_splits]. *)
let split_range num_splits =
  List.range 0 num_splits ~start:`inclusive ~stop:`exclusive

let make_out_channels ~num_splits ~out_dir ~out_basename =
  (* [file_name i] returns the name of the file given the split index [i]. *)
  let file_name i = out_dir ^/ [%string "%{out_basename}.split_%{i#Int}.fa"] in
  (* [f ocs i] take the split index [i] and add a new [oc] to the list [ocs]. *)
  let f ocs i =
    let file_name = file_name i in
    let oc = {file_name; out_channel= Out_channel.create file_name} in
    oc :: ocs
  in
  split_range num_splits |> List.fold ~init:[] ~f |> Array.of_list_rev

(* [num_seqs_or_n seq_file n] returns [n] if there are at least [n] sequences in
   the fasta file, else it returns the actual number of sequences in the
   sequence file. *)
let num_seqs_or_n seq_file n =
  match
    Bio_io.Fasta.In_channel.with_file_fold_records
      seq_file
      ~init:0
      ~f:(fun i _ -> if i >= n then raise Exit else i + 1 )
  with
  | exception Exit ->
      n
  | num_seqs ->
      num_seqs

let split_seqs ~seq_file ~num_splits ~out_dir =
  let out_basename = "query_split" in
  (* Make sure out directory exists. *)
  Core_unix.mkdir_p out_dir ;
  (* Don't generate more splits than there are sequences. *)
  let num_splits = num_seqs_or_n seq_file num_splits in
  let ocs = make_out_channels ~num_splits ~out_dir ~out_basename in
  let open Bio_io.Fasta in
  In_channel.with_file_iteri_records seq_file ~f:(fun i record ->
      let oc = ocs.(i % num_splits) in
      let uppercase_seq = String.uppercase @@ Record.seq record in
      let record = Record.with_seq uppercase_seq record in
      Out_channel.output_string oc.out_channel @@ Record.to_string_nl record ) ;
  close_all ocs ;
  let file_names = pluck_file_names ocs in
  {file_names; dir= out_dir; basename= out_basename}
