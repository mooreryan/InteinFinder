open! Core
open Lib

(* See the excel sheet if you need to change this. *)
let btab_data_with_tlen =
  "q1\tt0_longest_alnlen\t0.1\t300\t0\t0\t0\t0\t0\t0\t0\t10\t0\t3000\n\
   q1\tt1_tie_alnlen\t0.1\t300\t0\t0\t0\t0\t0\t0\t0\t10\t0\t3000\n\
   q1\tt2_best_alnperc\t0.1\t200\t0\t0\t0\t0\t0\t0\t0\t10\t0\t250\n\
   q1\tt3_tie_alnperc\t0.1\t200\t0\t0\t0\t0\t0\t0\t0\t10\t0\t250\n\
   q1\tt4_best_pid\t0.2\t100\t0\t0\t0\t0\t0\t0\t0\t10\t0\t200\n\
   q1\tt5_tie_pid\t0.2\t100\t0\t0\t0\t0\t0\t0\t0\t10\t0\t200\n\
   q1\tt6_best_bit\t0.1\t100\t0\t0\t0\t0\t0\t0\t0\t20\t0\t200\n\
   q1\tt7_tie_bit\t0.1\t100\t0\t0\t0\t0\t0\t0\t0\t20\t0\t200\n\
   q2\tt0_longest_alnlen\t0.1\t300\t0\t0\t0\t0\t0\t0\t0\t10\t0\t3000\n\
   q2\tt1_tie_alnlen\t0.1\t300\t0\t0\t0\t0\t0\t0\t0\t10\t0\t3000\n\
   q2\tt2_best_alnperc\t0.1\t200\t0\t0\t0\t0\t0\t0\t0\t10\t0\t250\n\
   q2\tt3_tie_alnperc\t0.1\t200\t0\t0\t0\t0\t0\t0\t0\t10\t0\t250\n\
   q2\tt4_best_pid\t0.2\t100\t0\t0\t0\t0\t0\t0\t0\t10\t0\t200\n\
   q2\tt5_tie_pid\t0.2\t100\t0\t0\t0\t0\t0\t0\t0\t10\t0\t200\n\
   q2\tt6_best_bit\t0.1\t100\t0\t0\t0\t0\t0\t0\t0\t20\t0\t200\n\
   q2\tt7_tie_bit\t0.1\t100\t0\t0\t0\t0\t0\t0\t0\t20\t0\t200\n"

let%expect_test _ =
  Utils.with_temp_file (fun btab ->
      Out_channel.write_all btab ~data:btab_data_with_tlen ;
      print_s
      @@ [%sexp_of: Search_summary.t String.Map.t]
      @@ Search_summary.summarize btab ) ;
  [%expect
    {|
    ((q1
      ((query q1) (total_hits 8) (pident 0.2) (pident_target t4_best_pid)
       (bits 20) (bits_target t6_best_bit) (alnlen 300)
       (alnlen_target t0_longest_alnlen) (alnperc (0.8))
       (alnperc_target (t2_best_alnperc))))
     (q2
      ((query q2) (total_hits 8) (pident 0.2) (pident_target t4_best_pid)
       (bits 20) (bits_target t6_best_bit) (alnlen 300)
       (alnlen_target t0_longest_alnlen) (alnperc (0.8))
       (alnperc_target (t2_best_alnperc))))) |}]

let%expect_test _ =
  Utils.with_temp_file (fun btab ->
      Out_channel.write_all btab ~data:btab_data_with_tlen ;
      Search_summary.print_summary Out_channel.stdout
      @@ Search_summary.summarize btab ) ;
  [%expect
    {|
    query	total_hits	best_pident	pident_target	best_bits	bits_target	best_alnlen	alnlen_target	best_alnperc	alnperc_target
    q1	8	0.2	t4_best_pid	20.	t6_best_bit	300	t0_longest_alnlen	0.8	t2_best_alnperc
    q2	8	0.2	t4_best_pid	20.	t6_best_bit	300	t0_longest_alnlen	0.8	t2_best_alnperc |}]

let btab_data_no_tlen =
  "q1\tt0_longest_alnlen\t0.1\t300\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q1\tt1_tie_alnlen\t0.1\t300\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q1\tt2_best_alnperc\t0.1\t200\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q1\tt3_tie_alnperc\t0.1\t200\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q1\tt4_best_pid\t0.2\t100\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q1\tt5_tie_pid\t0.2\t100\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q1\tt6_best_bit\t0.1\t100\t0\t0\t0\t0\t0\t0\t0\t20\n\
   q1\tt7_tie_bit\t0.1\t100\t0\t0\t0\t0\t0\t0\t0\t20\n\
   q2\tt0_longest_alnlen\t0.1\t300\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q2\tt1_tie_alnlen\t0.1\t300\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q2\tt2_best_alnperc\t0.1\t200\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q2\tt3_tie_alnperc\t0.1\t200\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q2\tt4_best_pid\t0.2\t100\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q2\tt5_tie_pid\t0.2\t100\t0\t0\t0\t0\t0\t0\t0\t10\n\
   q2\tt6_best_bit\t0.1\t100\t0\t0\t0\t0\t0\t0\t0\t20\n\
   q2\tt7_tie_bit\t0.1\t100\t0\t0\t0\t0\t0\t0\t0\t20\n"

let%expect_test _ =
  Utils.with_temp_file (fun btab ->
      Out_channel.write_all btab ~data:btab_data_no_tlen ;
      print_s
      @@ [%sexp_of: Search_summary.t String.Map.t]
      @@ Search_summary.summarize btab ) ;
  [%expect
    {|
    ((q1
      ((query q1) (total_hits 8) (pident 0.2) (pident_target t4_best_pid)
       (bits 20) (bits_target t6_best_bit) (alnlen 300)
       (alnlen_target t0_longest_alnlen) (alnperc ()) (alnperc_target ())))
     (q2
      ((query q2) (total_hits 8) (pident 0.2) (pident_target t4_best_pid)
       (bits 20) (bits_target t6_best_bit) (alnlen 300)
       (alnlen_target t0_longest_alnlen) (alnperc ()) (alnperc_target ())))) |}]

let%expect_test _ =
  Utils.with_temp_file (fun btab ->
      Out_channel.write_all btab ~data:btab_data_no_tlen ;
      Search_summary.print_summary Out_channel.stdout
      @@ Search_summary.summarize btab ) ;
  [%expect
    {|
    query	total_hits	best_pident	pident_target	best_bits	bits_target	best_alnlen	alnlen_target	best_alnperc	alnperc_target
    q1	8	0.2	t4_best_pid	20.	t6_best_bit	300	t0_longest_alnlen	None	None
    q2	8	0.2	t4_best_pid	20.	t6_best_bit	300	t0_longest_alnlen	None	None |}]
