open! Core
open Lib
open Lib.Remove_inteins

(* Indices don't matter here. *)
let region ~start ~end_ =
  Region.v_exn
    ~start:(Coord.one_raw_exn start)
    ~end_:(Coord.one_raw_exn end_)
    ~query:""
    ()

(* This is a critical function, but also pretty tedious, so easy to make a
   mistake. Thus, a bunch of tests.... *)

let%expect_test "trim_inteins: no extein parts gives empty string" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"aaaaXXXXbbbb" ~desc:None
  in
  let extein_parts = [] in
  printf "%S" @@ trim_inteins query_seq extein_parts ;
  [%expect {| "" |}]

let%expect_test "getting extein: no extein" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"aaa" ~desc:None
  in
  let intein_regions = [] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "aaa" |}]

let%expect_test "getting extein: one intein is the whole seq" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"XXXXX" ~desc:None
  in
  let intein_regions = [region ~start:1 ~end_:5] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "" |}]

let%expect_test "getting extein: one intein at start of seq" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"XXXXXaaa" ~desc:None
  in
  let intein_regions = [region ~start:1 ~end_:5] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "aaa" |}]

let%expect_test "getting extein: one intein at end of seq" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"aaaXXXXX" ~desc:None
  in
  let intein_regions = [region ~start:4 ~end_:8] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "aaa" |}]

let%expect_test "getting extein: one intein in middle of seq" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"aaaXXXXXbbbb" ~desc:None
  in
  let intein_regions = [region ~start:4 ~end_:8] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "aaabbbb" |}]

let%expect_test "getting extein: two inteins start and end (single residue)" =
  (* Just to check that it's okay...would never happen. *)
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"XaaaaaX" ~desc:None
  in
  let intein_regions = [region ~start:1 ~end_:1; region ~start:7 ~end_:7] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "aaaaa" |}]

(****** Two inteins ******)

let%expect_test "getting extein: two inteins start and end" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"XXaaaXXXX" ~desc:None
  in
  let intein_regions = [region ~start:1 ~end_:2; region ~start:6 ~end_:9] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "aaa" |}]

let%expect_test "getting extein: two inteins start and middle" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"XXaaaXXXXbbbbb" ~desc:None
  in
  let intein_regions = [region ~start:1 ~end_:2; region ~start:6 ~end_:9] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "aaabbbbb" |}]

let%expect_test "getting extein: two inteins middle and end" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"aaaXXbbbbbXXXX" ~desc:None
  in
  let intein_regions = [region ~start:4 ~end_:5; region ~start:11 ~end_:14] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "aaabbbbb" |}]

let%expect_test "getting extein: two inteins middle and middle" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create
         ~id:"yo"
         ~seq:"aaaXXbbbbbXXXXcccccc"
         ~desc:None
  in
  let intein_regions = [region ~start:4 ~end_:5; region ~start:11 ~end_:14] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "aaabbbbbcccccc" |}]

let%expect_test "getting extein: two inteins middle and middle (single residue \
                 extein parts & out of order)" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create ~id:"yo" ~seq:"aXXbXXXXc" ~desc:None
  in
  let intein_regions = [region ~start:5 ~end_:8; region ~start:2 ~end_:3] in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "abc" |}]

let%expect_test "getting extein: lots of inteins (random ordered region list)" =
  let query_seq =
    Bio_io_ext.Fasta.Record.query_raw
    @@ Bio_io.Fasta.Record.create
         ~id:"yo"
         ~seq:"aXbXccXXddXXeeeXXXfffXXXggggXXXXhhhhXXXXiiiii"
         ~desc:None
  in
  let intein_regions =
    [ region ~start:2 ~end_:2
    ; region ~start:4 ~end_:4
    ; region ~start:7 ~end_:8
    ; region ~start:11 ~end_:12
    ; region ~start:16 ~end_:18
    ; region ~start:22 ~end_:24
    ; region ~start:29 ~end_:32
    ; region ~start:37 ~end_:40 ]
    |> List.permute
  in
  let extein_regions = extein_regions query_seq intein_regions in
  printf "%S" @@ trim_inteins query_seq extein_regions ;
  [%expect {| "abccddeeefffgggghhhhiiiii" |}]
