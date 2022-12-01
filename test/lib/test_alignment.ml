open! Core
open Lib
open Alignment

let create_record seq = Record.create ~id:"query" ~desc:None ~seq

let query_aln seq = Bio_io_ext.Fasta.Record.query_aln @@ create_record seq

let%expect_test "first_and_last_non_gap_positions" =
  let p x = print_s @@ [%sexp_of: (C.zero_aln * C.zero_aln) option] x in
  p @@ first_and_last_non_gap_positions @@ query_aln "" ;
  [%expect {| () |}] ;
  p @@ first_and_last_non_gap_positions @@ query_aln "-" ;
  [%expect {| () |}] ;
  p @@ first_and_last_non_gap_positions @@ query_aln "A" ;
  [%expect {| (((Zero_aln 0) (Zero_aln 0))) |}] ;
  p @@ first_and_last_non_gap_positions @@ query_aln "----" ;
  [%expect {| () |}] ;
  p @@ first_and_last_non_gap_positions @@ query_aln "-A--" ;
  [%expect {| (((Zero_aln 1) (Zero_aln 1))) |}] ;
  p @@ first_and_last_non_gap_positions @@ query_aln "--A---A-" ;
  [%expect {| (((Zero_aln 2) (Zero_aln 6))) |}] ;
  p @@ first_and_last_non_gap_positions @@ query_aln "AAAA" ;
  [%expect {| (((Zero_aln 0) (Zero_aln 3))) |}]

module Test_find_next_non_gap_index = struct
  open Expect_test_helpers_base

  let c i = C.zero_aln_exn i

  let%expect_test "index >= string length raises" =
    require_does_raise [%here] (fun () ->
        find_next_non_gap_index "" ~current_index:(c 0) ) ;
    [%expect {| (Invalid_argument "current index >= string length") |}] ;
    require_does_raise [%here] (fun () ->
        find_next_non_gap_index "x" ~current_index:(c 1) ) ;
    [%expect {| (Invalid_argument "current index >= string length") |}]

  let%expect_test "negative index raises" =
    require_does_raise [%here] (fun () ->
        find_next_non_gap_index "-" ~current_index:(c (-1)) ) ;
    [%expect {| "Coord.zero_aln_exn failed (-1)" |}]

  let%expect_test "index at the ends" =
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "A" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "-" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "A-" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "A-" ~current_index:(c 1))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "-A" ~current_index:(c 0))
      ~expect:(Some (c 1)) ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "-A" ~current_index:(c 1))
      ~expect:None

  let%test_unit "input with all gaps" =
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "---" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "---" ~current_index:(c 1))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "---" ~current_index:(c 2))
      ~expect:None

  let%test_unit "it finds the NEXT, not current" =
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "AAA" ~current_index:(c 0))
      ~expect:(Some (c 1)) ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "AAA" ~current_index:(c 1))
      ~expect:(Some (c 2)) ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "AAA" ~current_index:(c 2))
      ~expect:None

  let%test_unit _ =
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "-A-A-" ~current_index:(c 0))
      ~expect:(Some (c 1)) ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "-A-A-" ~current_index:(c 1))
      ~expect:(Some (c 3)) ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "-A-A-" ~current_index:(c 2))
      ~expect:(Some (c 3)) ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "-A-A-" ~current_index:(c 3))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_next_non_gap_index "-A-A-" ~current_index:(c 4))
      ~expect:None
end

module Test_find_previous_non_gap_index = struct
  open Expect_test_helpers_base

  let c i = C.zero_aln_exn i

  let%expect_test "index >= string length raises" =
    require_does_raise [%here] (fun () ->
        find_previous_non_gap_index "" ~current_index:(c 0) ) ;
    [%expect {| (Invalid_argument "current index >= string length") |}] ;
    require_does_raise [%here] (fun () ->
        find_previous_non_gap_index "x" ~current_index:(c 1) ) ;
    [%expect {| (Invalid_argument "current index >= string length") |}]

  let%expect_test "negative index raises" =
    require_does_raise [%here] (fun () ->
        find_previous_non_gap_index "-" ~current_index:(c (-1)) ) ;
    [%expect {| "Coord.zero_aln_exn failed (-1)" |}]

  let%expect_test "index at the ends" =
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "A" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "-" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "A-" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "A-" ~current_index:(c 1))
      ~expect:(Some (c 0)) ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "-A" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "-A" ~current_index:(c 1))
      ~expect:None

  let%test_unit "input with all gaps" =
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "---" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "---" ~current_index:(c 1))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "---" ~current_index:(c 2))
      ~expect:None

  let%test_unit "it finds the PREVIOUS, not current" =
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "AAA" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "AAA" ~current_index:(c 1))
      ~expect:(Some (c 0)) ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "AAA" ~current_index:(c 2))
      ~expect:(Some (c 1))

  let%test_unit _ =
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "-A-A-" ~current_index:(c 0))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "-A-A-" ~current_index:(c 1))
      ~expect:None ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "-A-A-" ~current_index:(c 2))
      ~expect:(Some (c 1)) ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "-A-A-" ~current_index:(c 3))
      ~expect:(Some (c 1)) ;
    [%test_result: C.zero_aln option]
      (find_previous_non_gap_index "-A-A-" ~current_index:(c 4))
      ~expect:(Some (c 3))
end

module Test_map = struct
  open Expect_test_helpers_base

  let print_map_for s =
    print_s @@ [%sexp_of: C.Query_aln_to_raw.t] @@ Alignment.aln_to_raw
    @@ query_aln s

  let%expect_test "all gaps raise" =
    require_does_raise [%here] (fun () -> print_map_for "-") ;
    [%expect
      {| "first_and_last_non_gap_positions returned None.  This can only happen if the aligned query sequence was all gaps.  If you see this message, there is definitely something wrong with your input data.  The bad query was 'query'." |}] ;
    require_does_raise [%here] (fun () -> print_map_for "--") ;
    [%expect
      {| "first_and_last_non_gap_positions returned None.  This can only happen if the aligned query sequence was all gaps.  If you see this message, there is definitely something wrong with your input data.  The bad query was 'query'." |}] ;
    require_does_raise [%here] (fun () -> print_map_for "---") ;
    [%expect
      {| "first_and_last_non_gap_positions returned None.  This can only happen if the aligned query sequence was all gaps.  If you see this message, there is definitely something wrong with your input data.  The bad query was 'query'." |}]

  let%expect_test "no gaps" =
    print_map_for "A" ;
    [%expect {| ((0 (At (Zero_raw 0)))) |}] ;
    print_map_for "AB" ;
    [%expect {|
      ((0 (At (Zero_raw 0)))
       (1 (At (Zero_raw 1)))) |}] ;
    print_map_for "ABC" ;
    [%expect
      {|
        ((0 (At (Zero_raw 0)))
         (1 (At (Zero_raw 1)))
         (2 (At (Zero_raw 2)))) |}]

  let%expect_test _ =
    print_map_for "A-" ;
    [%expect {| ((0 (At (Zero_raw 0))) (1 After)) |}] ;
    print_map_for "-A" ;
    [%expect {| ((0 Before) (1 (At (Zero_raw 0)))) |}]

  let%expect_test _ =
    (* ABC -> 012 in raw, -> 148 in aln. *)
    print_map_for "-A--B---C---" ;
    [%expect
      {|
      ((0 Before)
       (1 (At (Zero_raw 0)))
       (2 (
         Between (
           ((Zero_raw 0))
           ((Zero_raw 1)))))
       (3 (
         Between (
           ((Zero_raw 0))
           ((Zero_raw 1)))))
       (4 (At (Zero_raw 1)))
       (5 (
         Between (
           ((Zero_raw 1))
           ((Zero_raw 2)))))
       (6 (
         Between (
           ((Zero_raw 1))
           ((Zero_raw 2)))))
       (7 (
         Between (
           ((Zero_raw 1))
           ((Zero_raw 2)))))
       (8 (At (Zero_raw 2)))
       (9  After)
       (10 After)
       (11 After)) |}]
end

let%expect_test "concat_none_is_gap" =
  let open El in
  print_endline @@ concat_none_is_gap (Some (Residue 'A')) (Some (Residue 'B')) ;
  [%expect {| AB |}] ;
  print_endline @@ concat_none_is_gap None (Some (Residue 'B')) ;
  [%expect {| -B |}] ;
  print_endline @@ concat_none_is_gap (Some Gap) (Some (Residue 'B')) ;
  [%expect {| -B |}] ;
  print_endline @@ concat_none_is_gap (Some (Residue 'A')) None ;
  [%expect {| A- |}] ;
  print_endline @@ concat_none_is_gap (Some (Residue 'A')) (Some Gap) ;
  [%expect {| A- |}] ;
  print_endline @@ concat_none_is_gap None None ;
  [%expect {| -- |}] ;
  print_endline @@ concat_none_is_gap (Some Gap) (Some Gap) ;
  [%expect {| -- |}] ;
  print_endline @@ concat_none_is_gap None (Some Gap) ;
  [%expect {| -- |}] ;
  print_endline @@ concat_none_is_gap (Some Gap) None ;
  [%expect {| -- |}] ;
  print_endline @@ concat_none_is_gap None None ;
  [%expect {| -- |}] ;
  print_endline @@ concat_none_is_gap (Some Gap) (Some Gap) ;
  [%expect {| -- |}]

let%expect_test "read_aln_out_file (all bad seqs)" =
  Utils.with_temp_file (fun file_name ->
      Out_channel.write_all file_name ~data:">s1\nAAAA\n>s2\nBBBB\n>s3\nCCCC" ;
      Or_error.try_with (fun () -> read_aln_out_file file_name)
      |> [%sexp_of: aln_out Or_error.t] |> print_s ) ;
  [%expect
    {|
    (Error
     (Failure
       "Expected one query, one clipped query, and one intein, but got something else in alignment out file:\
      \n>s1\
      \nAAAA\
      \n>s2\
      \nBBBB\
      \n>s3\
      \nCCCC")) |}]

let%expect_test "read_aln_out_file (extra seqs)" =
  let data =
    let s1 = [%string ">%{Bio_io_ext.Fasta.Record.query_prefix}s1\nAAAA"] in
    let s2 = [%string ">%{Bio_io_ext.Fasta.Record.intein_prefix}s2\nBBBB"] in
    let s3 =
      [%string ">%{Bio_io_ext.Fasta.Record.clipped_query_prefix}s3\nCCCC"]
    in
    let s4 = [%string ">s4\nDDDD"] in
    String.concat [s1; s2; s3; s4] ~sep:"\n"
  in
  Utils.with_temp_file (fun file_name ->
      Out_channel.write_all file_name ~data ;
      Or_error.try_with (fun () -> read_aln_out_file file_name)
      |> [%sexp_of: aln_out Or_error.t] |> print_s ) ;
  [%expect
    {|
    (Error
     (Failure "expected three sequences in the alignment output file but got 4")) |}]

let%expect_test "the seq order doesn't matter for read_aln_out_file" =
  let query = [%string ">%{Bio_io_ext.Fasta.Record.query_prefix}s1\nAAAA"] in
  let intein = [%string ">%{Bio_io_ext.Fasta.Record.intein_prefix}s2\nBBBB"] in
  let clipped =
    [%string ">%{Bio_io_ext.Fasta.Record.clipped_query_prefix}s3\nCCCC"]
  in
  let check seqs =
    Utils.with_temp_file (fun file_name ->
        let data = String.concat seqs ~sep:"\n" in
        Out_channel.write_all file_name ~data ;
        let out = read_aln_out_file file_name in
        printf
          "intein: %s\nquery: %s\n"
          (Sexp.to_string_hum @@ [%sexp_of: Record.intein_aln] @@ out.intein)
          (Sexp.to_string_hum @@ [%sexp_of: Record.query_aln] @@ out.query) )
  in
  check [query; clipped; intein] ;
  [%expect
    {|
    intein: (Intein_aln ((id IF_INTEIN_DB___s2) (desc ()) (seq BBBB)))
    query: (Query_aln ((id IF_USER_QUERY___s1) (desc ()) (seq AAAA))) |}] ;
  check [query; intein; clipped] ;
  [%expect
    {|
    intein: (Intein_aln ((id IF_INTEIN_DB___s2) (desc ()) (seq BBBB)))
    query: (Query_aln ((id IF_USER_QUERY___s1) (desc ()) (seq AAAA))) |}] ;
  check [clipped; query; intein] ;
  [%expect
    {|
    intein: (Intein_aln ((id IF_INTEIN_DB___s2) (desc ()) (seq BBBB)))
    query: (Query_aln ((id IF_USER_QUERY___s1) (desc ()) (seq AAAA))) |}] ;
  check [clipped; intein; query] ;
  [%expect
    {|
    intein: (Intein_aln ((id IF_INTEIN_DB___s2) (desc ()) (seq BBBB)))
    query: (Query_aln ((id IF_USER_QUERY___s1) (desc ()) (seq AAAA))) |}] ;
  check [intein; query; clipped] ;
  [%expect
    {|
    intein: (Intein_aln ((id IF_INTEIN_DB___s2) (desc ()) (seq BBBB)))
    query: (Query_aln ((id IF_USER_QUERY___s1) (desc ()) (seq AAAA))) |}] ;
  check [intein; clipped; query] ;
  [%expect
    {|
    intein: (Intein_aln ((id IF_INTEIN_DB___s2) (desc ()) (seq BBBB)))
    query: (Query_aln ((id IF_USER_QUERY___s1) (desc ()) (seq AAAA))) |}]

let%expect_test "Mafft.run" =
  let out_file = "teehee" in
  Utils.touch out_file |> ignore ;
  let opts : Mafft.opts = {exe= "mafft"; in_file= "silly"; out_file} in
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        let%bind.Async.Deferred.Or_error out =
          Mafft.run ~opts ~log_base:"log_base"
        in
        Async.Deferred.Or_error.return out )
  in
  Utils.remove_if_exists out_file ;
  print_s @@ [%sexp_of: string Or_error.t] result ;
  [%expect
    {|
      (Error
       ("expected file 'silly' to exist, but it did not"
        "expected file 'teehee' not to exist, but it did")) |}]
