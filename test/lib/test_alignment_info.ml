open! Core
open Lib
open Alignment

let create_record id seq = Record.create ~id ~desc:None ~seq

let raw_query_length q =
  String.filter q ~f:(function '-' -> false | _ -> true) |> String.length

let aln_out ~q ~i : aln_out =
  { query= Bio_io_ext.Fasta.Record.query_aln (create_record "id" q)
  ; intein= Bio_io_ext.Fasta.Record.intein_aln (create_record "id" i)
  ; file_name= "" }

let print_info x = print_s @@ [%sexp_of: Intein_query_info.t] x

module Inteins_on_the_edges = struct
  let%expect_test "intein at end" =
    let q = "abcDEFghi" in
    let i = "------ghi" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ((Residue F))) (intein_start ((Residue g)))
       (intein_penultimate ((Residue h))) (intein_end ((Residue i)))
       (intein_end_plus_one ()) (intein_start_index ((Zero_aln 6)))
       (intein_end_index ((Zero_aln 8)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test "intein at start" =
    let q = "abcDEFghi" in
    let i = "abc------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start ((Residue a)))
       (intein_penultimate ((Residue b))) (intein_end ((Residue c)))
       (intein_end_plus_one ((Residue D))) (intein_start_index ((Zero_aln 0)))
       (intein_end_index ((Zero_aln 2)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test "intein at start & end" =
    let q = "abcDEFghi" in
    let i = "abc---ghi" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start ((Residue a)))
       (intein_penultimate ((Residue h))) (intein_end ((Residue i)))
       (intein_end_plus_one ()) (intein_start_index ((Zero_aln 0)))
       (intein_end_index ((Zero_aln 8)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test "intein = query" =
    let q = "abcDEFghi" in
    let i = "abcDEFghi" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start ((Residue a)))
       (intein_penultimate ((Residue h))) (intein_end ((Residue i)))
       (intein_end_plus_one ()) (intein_start_index ((Zero_aln 0)))
       (intein_end_index ((Zero_aln 8)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end true)) |}]
end

module Basics = struct
  let%expect_test _ =
    let q = "abcDEFghi" in
    let i = "---DEF---" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ((Residue c))) (intein_start ((Residue D)))
     (intein_penultimate ((Residue E))) (intein_end ((Residue F)))
     (intein_end_plus_one ((Residue g))) (intein_start_index ((Zero_aln 3)))
     (intein_end_index ((Zero_aln 5)))
     (intein_start_to_the_right_of_hit_region_start true)
     (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "abcDEFghi" in
    let i = "---DEF---" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
       ((intein_start_minus_one ((Residue c))) (intein_start ((Residue D)))
        (intein_penultimate ((Residue E))) (intein_end ((Residue F)))
        (intein_end_plus_one ((Residue g))) (intein_start_index ((Zero_aln 3)))
        (intein_end_index ((Zero_aln 5)))
        (intein_start_to_the_right_of_hit_region_start true)
        (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "abcDEFghi" in
    let i = "---DEF---" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ((Residue c))) (intein_start ((Residue D)))
     (intein_penultimate ((Residue E))) (intein_end ((Residue F)))
     (intein_end_plus_one ((Residue g))) (intein_start_index ((Zero_aln 3)))
     (intein_end_index ((Zero_aln 5)))
     (intein_start_to_the_right_of_hit_region_start false)
     (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "abcDEFghi" in
    let i = "---DEF---" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ((Residue c))) (intein_start ((Residue D)))
     (intein_penultimate ((Residue E))) (intein_end ((Residue F)))
     (intein_end_plus_one ((Residue g))) (intein_start_index ((Zero_aln 3)))
     (intein_end_index ((Zero_aln 5)))
     (intein_start_to_the_right_of_hit_region_start false)
     (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "---abcDEFghi" in
    let i = "XXXabc------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ()) (intein_start (Gap))
     (intein_penultimate ((Residue b))) (intein_end ((Residue c)))
     (intein_end_plus_one ((Residue D))) (intein_start_index ((Zero_aln 0)))
     (intein_end_index ((Zero_aln 5)))
     (intein_start_to_the_right_of_hit_region_start false)
     (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "abcDEFghi---" in
    let i = "------ghiXXX" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ((Residue F))) (intein_start ((Residue g)))
     (intein_penultimate (Gap)) (intein_end (Gap)) (intein_end_plus_one ())
     (intein_start_index ((Zero_aln 6))) (intein_end_index ((Zero_aln 11)))
     (intein_start_to_the_right_of_hit_region_start true)
     (intein_end_to_the_left_of_hit_region_end false)) |}]
end

(* TODO basics with off-set gaps. *)
module Basics_with_matching_gaps = struct
  let%expect_test _ =
    let q = "-a-b-c-D-E-F-g-h-i-" in
    let i = "-------D-E-F-------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ((Residue c))) (intein_start ((Residue D)))
     (intein_penultimate ((Residue E))) (intein_end ((Residue F)))
     (intein_end_plus_one ((Residue g))) (intein_start_index ((Zero_aln 7)))
     (intein_end_index ((Zero_aln 11)))
     (intein_start_to_the_right_of_hit_region_start true)
     (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "-a-b-c-D-E-F-g-h-i-" in
    let i = "-------D-E-F-------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
       ((intein_start_minus_one ((Residue c))) (intein_start ((Residue D)))
        (intein_penultimate ((Residue E))) (intein_end ((Residue F)))
        (intein_end_plus_one ((Residue g))) (intein_start_index ((Zero_aln 7)))
        (intein_end_index ((Zero_aln 11)))
        (intein_start_to_the_right_of_hit_region_start true)
        (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "-a-b-c-D-E-F-g-h-i-" in
    let i = "-------D-E-F-------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ((Residue c))) (intein_start ((Residue D)))
     (intein_penultimate ((Residue E))) (intein_end ((Residue F)))
     (intein_end_plus_one ((Residue g))) (intein_start_index ((Zero_aln 7)))
     (intein_end_index ((Zero_aln 11)))
     (intein_start_to_the_right_of_hit_region_start false)
     (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "-a-b-c-D-E-F-g-h-i-" in
    let i = "-------D-E-F-------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ((Residue c))) (intein_start ((Residue D)))
     (intein_penultimate ((Residue E))) (intein_end ((Residue F)))
     (intein_end_plus_one ((Residue g))) (intein_start_index ((Zero_aln 7)))
     (intein_end_index ((Zero_aln 11)))
     (intein_start_to_the_right_of_hit_region_start false)
     (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "-------a-b-c-D-E-F-g-h-i-" in
    let i = "-X-X-X-a-b-c-------------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ()) (intein_start (Gap))
     (intein_penultimate ((Residue b))) (intein_end ((Residue c)))
     (intein_end_plus_one ((Residue D))) (intein_start_index ((Zero_aln 1)))
     (intein_end_index ((Zero_aln 11)))
     (intein_start_to_the_right_of_hit_region_start false)
     (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "-a-b-c-D-E-F-g-h-i-------" in
    let i = "-------------g-h-i-X-X-X-" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
    ((intein_start_minus_one ((Residue F))) (intein_start ((Residue g)))
     (intein_penultimate (Gap)) (intein_end (Gap)) (intein_end_plus_one ())
     (intein_start_index ((Zero_aln 13))) (intein_end_index ((Zero_aln 23)))
     (intein_start_to_the_right_of_hit_region_start true)
     (intein_end_to_the_left_of_hit_region_end false)) |}]
end

(** I removed the gap at the start of the query and added one to the end of the
    query. *)
module Basics_with_offset_gaps = struct
  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i-" in
    let i = "-------D-E-F------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 7))) (intein_end_index ((Zero_aln 11)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i-" in
    let i = "-------D-E-F------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 7))) (intein_end_index ((Zero_aln 11)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i-" in
    let i = "-------D-E-F------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 7))) (intein_end_index ((Zero_aln 11)))
       (intein_start_to_the_right_of_hit_region_start false)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i-" in
    let i = "-------D-E-F------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 7))) (intein_end_index ((Zero_aln 11)))
       (intein_start_to_the_right_of_hit_region_start false)
       (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "------a-b-c-D-E-F-g-h-i--" in
    let i = "-X-X-X-a-b-c-------------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 1))) (intein_end_index ((Zero_aln 11)))
       (intein_start_to_the_right_of_hit_region_start false)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "------a-b-c-D-E-F-g-h-i--" in
    let i = "-X-X-X-a-b-c-------------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 1))) (intein_end_index ((Zero_aln 11)))
       (intein_start_to_the_right_of_hit_region_start false)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "------a-b-c-D-E-F-g-h-i--" in
    let i = "-X-X-X-a-b-c-------------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 1))) (intein_end_index ((Zero_aln 11)))
       (intein_start_to_the_right_of_hit_region_start false)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "------a-b-c-D-E-F-g-h-i--" in
    let i = "-X-X-X-a-b-c-------------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 1))) (intein_end_index ((Zero_aln 11)))
       (intein_start_to_the_right_of_hit_region_start false)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i--------" in
    let i = "-------------g-h-i-X-X-X-" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 13))) (intein_end_index ((Zero_aln 23)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i--------" in
    let i = "-------------g-h-i-X-X-X-" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 13))) (intein_end_index ((Zero_aln 23)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i--------" in
    let i = "-------------g-h-i-X-X-X-" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 13))) (intein_end_index ((Zero_aln 23)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i--------" in
    let i = "-------------g-h-i-X-X-X-" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 13))) (intein_end_index ((Zero_aln 23)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end false)) |}]
end

(* Like the previous offset one, but in the other direction. *)
module Basics_with_offset_gaps2 = struct
  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i-" in
    let i = "-----D-E-F--------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 5))) (intein_end_index ((Zero_aln 9)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i--" in
    let i = "-----D-E-F---------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 1)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 5))) (intein_end_index ((Zero_aln 9)))
       (intein_start_to_the_right_of_hit_region_start true)
       (intein_end_to_the_left_of_hit_region_end false)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i--" in
    let i = "-----D-E-F---------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn raw_query_length)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 5))) (intein_end_index ((Zero_aln 9)))
       (intein_start_to_the_right_of_hit_region_start false)
       (intein_end_to_the_left_of_hit_region_end true)) |}]

  let%expect_test _ =
    let q = "a-b-c-D-E-F-g-h-i--" in
    let i = "-----D-E-F---------" in
    let raw_query_length = raw_query_length q in
    let () = assert (String.length q = String.length i) in
    let aln_out = aln_out ~q ~i in
    let intein_out_query_info =
      parse_aln_out
        aln_out
        ~hit_region_start:(C.one_raw_exn 5)
        ~hit_region_end:(C.one_raw_exn 5)
        ~raw_query_length
    in
    print_info intein_out_query_info ;
    [%expect
      {|
      ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
       (intein_end (Gap)) (intein_end_plus_one ())
       (intein_start_index ((Zero_aln 5))) (intein_end_index ((Zero_aln 9)))
       (intein_start_to_the_right_of_hit_region_start false)
       (intein_end_to_the_left_of_hit_region_end false)) |}]
end

let%expect_test _ =
  let q = "-a-b-c-D-E-F-g-h-i-" in
  let i = "-------D-E-F-------" in
  let raw_query_length = raw_query_length q in
  let () = assert (String.length q = String.length i) in
  let aln_out = aln_out ~q ~i in
  let intein_out_query_info =
    parse_aln_out
      aln_out
      ~hit_region_start:(C.one_raw_exn 1)
      ~hit_region_end:(C.one_raw_exn raw_query_length)
      ~raw_query_length
  in
  print_info intein_out_query_info ;
  [%expect
    {|
    ((intein_start_minus_one ((Residue c))) (intein_start ((Residue D)))
     (intein_penultimate ((Residue E))) (intein_end ((Residue F)))
     (intein_end_plus_one ((Residue g))) (intein_start_index ((Zero_aln 7)))
     (intein_end_index ((Zero_aln 11)))
     (intein_start_to_the_right_of_hit_region_start true)
     (intein_end_to_the_left_of_hit_region_end true)) |}]

let%expect_test "completely normal" =
  let q = "Abc-EfghIjk-MnopQr-tU" in
  let i = "-------h-jk--n-------" in
  (* ......123-4567890-123456-78 *)
  (* ......012345678901234567890 *)
  (* ......123456789012345678901 *)
  let raw_query_length = raw_query_length q in
  let () = assert (String.length q = String.length i) in
  let aln_out = aln_out ~q ~i in
  let intein_out_query_info =
    (* these numbers look weird, but mind the gaps in the query!. *)
    parse_aln_out
      aln_out
      ~hit_region_start:(C.one_raw_exn 7)
      ~hit_region_end:(C.one_raw_exn 12)
      ~raw_query_length
  in
  print_info intein_out_query_info ;
  [%expect
    {|
    ((intein_start_minus_one ((Residue g))) (intein_start ((Residue h)))
     (intein_penultimate ((Residue k))) (intein_end ((Residue n)))
     (intein_end_plus_one ((Residue o))) (intein_start_index ((Zero_aln 7)))
     (intein_end_index ((Zero_aln 13)))
     (intein_start_to_the_right_of_hit_region_start true)
     (intein_end_to_the_left_of_hit_region_end true)) |}]

let%expect_test "intein sticks off the front of query" =
  let q = "----Efgh-jklM-opQ----" in
  let i = "AbcdE-ghIj-lMn-pQrstU" in
  (* ......012345678901234567890 *)
  (* ......123456789012345678901 *)
  let () = assert (String.length q = String.length i) in
  let raw_query_length = raw_query_length q in
  let aln_out = aln_out ~q ~i in
  let intein_out_query_info =
    (* these numbers look weird, but mind the gaps in the query!. *)
    parse_aln_out
      aln_out
      ~hit_region_start:(C.one_raw_exn 1)
      ~hit_region_end:(C.one_raw_exn 5)
      ~raw_query_length
  in
  print_info intein_out_query_info ;
  [%expect
    {|
    ((intein_start_minus_one ()) (intein_start (Gap)) (intein_penultimate (Gap))
     (intein_end (Gap)) (intein_end_plus_one ())
     (intein_start_index ((Zero_aln 0))) (intein_end_index ((Zero_aln 20)))
     (intein_start_to_the_right_of_hit_region_start false)
     (intein_end_to_the_left_of_hit_region_end false)) |}]

(* TO TEST: regions within, regions on the edges. *)
