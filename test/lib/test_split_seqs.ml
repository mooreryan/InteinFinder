open! Core
open Lib
open Split_seqs

(** [with_seq_file f] calls [f] with the name of a fasta file. *)
let with_seq_file f =
  Utils.with_temp_dir (fun dir ->
      Utils.with_temp_file ~in_dir:dir (fun file ->
          let data = ">s1\nAAAA\n>s2\nBBBB\n>s3\nCCCC" in
          Out_channel.write_all file ~data ;
          f ~dir ~file ) )

let test_split_seqs num_splits =
  with_seq_file (fun ~dir ~file:seq_file ->
      let split_file_names = split_seqs ~seq_file ~num_splits ~out_dir:dir in
      (* Sequences and filenames are correct. *)
      List.iter split_file_names.file_names ~f:(fun name ->
          printf "=== file '%s'\n" @@ Filename.basename name ;
          In_channel.read_all name |> print_string ) )

let%expect_test "one split" =
  test_split_seqs 1 ;
  [%expect
    {|
      === file 'query_split.split_0.fa'
      >s1
      AAAA
      >s2
      BBBB
      >s3
      CCCC |}]

let%expect_test "two splits" =
  test_split_seqs 2 ;
  [%expect
    {|
      === file 'query_split.split_0.fa'
      >s1
      AAAA
      >s3
      CCCC
      === file 'query_split.split_1.fa'
      >s2
      BBBB |}]

let%expect_test "three splits" =
  test_split_seqs 3 ;
  [%expect
    {|
      === file 'query_split.split_0.fa'
      >s1
      AAAA
      === file 'query_split.split_1.fa'
      >s2
      BBBB
      === file 'query_split.split_2.fa'
      >s3
      CCCC |}]

let%expect_test "more splits than number of seqs" =
  test_split_seqs 4 ;
  [%expect
    {|
      === file 'query_split.split_0.fa'
      >s1
      AAAA
      === file 'query_split.split_1.fa'
      >s2
      BBBB
      === file 'query_split.split_2.fa'
      >s3
      CCCC |}]
