open! Core
open Lib
open Hits

let btab_data =
  "q1\tt1\t0\t0\t0\t0\t10\t20\t0\t0\t0\t10\t0\t0\n\
   q1\tt2\t0\t0\t0\t0\t15\t25\t0\t0\t0\t100\t0\t0\n\
   q1\tt3\t0\t0\t0\t0\t100\t200\t0\t0\t0\t200\t0\t0\n\
   q1\tt4\t0\t0\t0\t0\t115\t225\t0\t0\t0\t20\t0\t0\n"

let regions =
  String.Map.of_alist_exn
    [ ( "q1"
      , [ Region.v_exn
            ~start:(Coord.one_raw_exn 5)
            ~end_:(Coord.one_raw_exn 30)
            ~index:(Zero_indexed_int.of_zero_indexed_int 0)
            ~query:"q1"
            ()
        ; Region.v_exn
            ~start:(Coord.one_raw_exn 90)
            ~end_:(Coord.one_raw_exn 250)
            ~index:(Zero_indexed_int.of_zero_indexed_int 1)
            ~query:"q1"
            () ] ) ]

let%expect_test _ =
  Utils.with_temp_file (fun btab ->
      Out_channel.write_all btab ~data:btab_data ;
      let mmseqs_search_out = Mmseqs_search.Out.v ~out:btab ~log:"ignore" in
      print_s
      @@ [%sexp_of: Intein_hits.Query_region_hits.t]
      @@ Intein_hits.Query_region_hits.of_mmseqs_search_out
           mmseqs_search_out
           regions ) ;
  [%expect
    {|
    ((q1
      ((0
        (((hit
           ((query q1) (target t2) (pident 0) (alnlen 0) (mismatch 0) (gapopen 0)
            (qstart 15) (qend 25) (tstart 0) (tend 0) (evalue 0) (bits 100)
            (qlen (0)) (tlen (0))))
          (region ((start (One_raw 5)) (end_ (One_raw 30)) (index 0) (query q1))))
         ((hit
           ((query q1) (target t1) (pident 0) (alnlen 0) (mismatch 0) (gapopen 0)
            (qstart 10) (qend 20) (tstart 0) (tend 0) (evalue 0) (bits 10)
            (qlen (0)) (tlen (0))))
          (region ((start (One_raw 5)) (end_ (One_raw 30)) (index 0) (query q1))))))
       (1
        (((hit
           ((query q1) (target t3) (pident 0) (alnlen 0) (mismatch 0) (gapopen 0)
            (qstart 100) (qend 200) (tstart 0) (tend 0) (evalue 0) (bits 200)
            (qlen (0)) (tlen (0))))
          (region
           ((start (One_raw 90)) (end_ (One_raw 250)) (index 1) (query q1))))
         ((hit
           ((query q1) (target t4) (pident 0) (alnlen 0) (mismatch 0) (gapopen 0)
            (qstart 115) (qend 225) (tstart 0) (tend 0) (evalue 0) (bits 20)
            (qlen (0)) (tlen (0))))
          (region
           ((start (One_raw 90)) (end_ (One_raw 250)) (index 1) (query q1))))))))) |}]
