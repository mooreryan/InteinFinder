open! Core
open Lib
open Hits

(* Also has tests for the Region module, which used to be a submodule of this
   one. *)

let region_v ~start ~end_ ~query ?index () =
  Region.v_exn
    ~start:(Coord.one_raw_exn start)
    ~end_:(Coord.one_raw_exn end_)
    ~query
    ?index
    ()

let default_record =
  Bio_io.Btab.Record.Parsed.
    { query= ""
    ; target= ""
    ; pident= 0.0
    ; alnlen= 0
    ; mismatch= 0
    ; gapopen= 0
    ; qstart= 1
    ; qend= 1
    ; tstart= 1
    ; tend= 1
    ; evalue= 0.0
    ; bits= 0.0
    ; qlen= None
    ; tlen= None }

let p (r : Bio_io.Btab.Record.Parsed.t) =
  printf
    "qstart %d, qend %d, tstart %d, tend %d"
    r.qstart
    r.qend
    r.tstart
    r.tend

let%expect_test _ =
  p
  @@ Btab_record.canonicalize
       {default_record with qstart= 1; qend= 10; tstart= 1; tend= 10} ;
  [%expect {| qstart 1, qend 10, tstart 1, tend 10 |}]

let%expect_test _ =
  p
  @@ Btab_record.canonicalize
       {default_record with qstart= 10; qend= 1; tstart= 1; tend= 10} ;
  [%expect {| qstart 1, qend 10, tstart 1, tend 10 |}]

let%expect_test _ =
  p
  @@ Btab_record.canonicalize
       {default_record with qstart= 1; qend= 10; tstart= 10; tend= 1} ;
  [%expect {| qstart 1, qend 10, tstart 1, tend 10 |}]

let%expect_test _ =
  p
  @@ Btab_record.canonicalize
       {default_record with qstart= 10; qend= 1; tstart= 10; tend= 1} ;
  [%expect {| qstart 1, qend 10, tstart 1, tend 10 |}]

let r qstart qend = {default_record with qstart; qend}

let%expect_test _ =
  printf "%d\n" @@ Btab_record.compare_qstart_qend (r 1 1) (r 1 1) ;
  [%expect {| 0 |}]

let%expect_test _ =
  printf "%d\n" @@ Btab_record.compare_qstart_qend (r 1 2) (r 1 1) ;
  [%expect {| 1 |}]

let%expect_test _ =
  printf "%d\n" @@ Btab_record.compare_qstart_qend (r 1 1) (r 1 2) ;
  [%expect {| -1 |}]

let%expect_test _ =
  printf "%d\n" @@ Btab_record.compare_qstart_qend (r 1 1) (r 0 1) ;
  [%expect {| 1 |}]

let%expect_test _ =
  printf "%d\n" @@ Btab_record.compare_qstart_qend (r 1 1) (r 2 1) ;
  [%expect {| -1 |}]

let%expect_test "basic region detection" =
  let rs =
    [ (* Region 1 *)
      {default_record with query= "A"; qstart= 10; qend= 19}
    ; {default_record with query= "A"; qend= 20; qstart= 25}
    ; (* Region 2 *)
      {default_record with query= "A"; qstart= 27; qend= 30}
    ; {default_record with query= "A"; qstart= 36; qend= 40}
    ; {default_record with query= "A"; qend= 30; qstart= 35}
    ; (* Region 3. has contained stuff. *)
      {default_record with query= "A"; qend= 60; qstart= 70}
    ; {default_record with query= "A"; qstart= 50; qend= 80}
    ; (* Region 4. swapped region 3 order *)
      {default_record with query= "A"; qstart= 500; qend= 800}
    ; {default_record with query= "A"; qend= 600; qstart= 700}
    ; (* Same exact regions, but on query B. *)
      (* Region 1 *)
      {default_record with query= "B"; qstart= 10; qend= 19}
    ; {default_record with query= "B"; qend= 20; qstart= 25}
    ; (* Region 2 *)
      {default_record with query= "B"; qstart= 27; qend= 30}
    ; {default_record with query= "B"; qstart= 36; qend= 40}
    ; {default_record with query= "B"; qend= 30; qstart= 35}
    ; (* Region 3. has contained stuff. *)
      {default_record with query= "B"; qend= 60; qstart= 70}
    ; {default_record with query= "B"; qstart= 50; qend= 80}
    ; (* Region 4. swapped region 3 order. *)
      {default_record with query= "B"; qstart= 500; qend= 800}
    ; {default_record with query= "B"; qend= 600; qstart= 700}
    ; (* A query with a single hit. *)
      {default_record with query= "C"; qend= 1; qstart= 10} ]
  in
  (* Shuffle so we're out of order in the queries. *)
  let random_state = Random.State.make [|0; 1; 2; 3; 4|] in
  (* TODO: assert the permuted list is not the original list. *)
  let permuted = List.permute rs ~random_state in
  (* TODO need equal for the records. *)
  assert (
    let a = List.hd_exn rs in
    let b = List.hd_exn permuted in
    String.(sprintf "%s-%d" a.query a.qstart <> sprintf "%s-%d" b.query b.qstart) ) ;
  List.fold permuted ~init:String.Map.empty ~f:Hit_regions.process_parsed_record
  |> Hit_regions.sort_hits_by_query |> Hit_regions.regions_of_sorted_hits
  |> [%sexp_of: Hit_regions.t] |> print_s ;
  [%expect
    {|
    ((A
      (((start (One_raw 10)) (end_ (One_raw 25)) (index 0) (query A))
       ((start (One_raw 27)) (end_ (One_raw 40)) (index 0) (query A))
       ((start (One_raw 50)) (end_ (One_raw 80)) (index 0) (query A))
       ((start (One_raw 500)) (end_ (One_raw 800)) (index 0) (query A))))
     (B
      (((start (One_raw 10)) (end_ (One_raw 25)) (index 0) (query B))
       ((start (One_raw 27)) (end_ (One_raw 40)) (index 0) (query B))
       ((start (One_raw 50)) (end_ (One_raw 80)) (index 0) (query B))
       ((start (One_raw 500)) (end_ (One_raw 800)) (index 0) (query B))))
     (C (((start (One_raw 1)) (end_ (One_raw 10)) (index 0) (query C))))) |}]

let%expect_test "edges" =
  let rs =
    [ (* Region 1 *)
      {default_record with query= "A"; qstart= 1; qend= 10}
    ; {default_record with query= "A"; qend= 1; qstart= 10} ]
  in
  List.fold rs ~init:String.Map.empty ~f:Hit_regions.process_parsed_record
  |> Hit_regions.sort_hits_by_query |> Hit_regions.regions_of_sorted_hits
  |> [%sexp_of: Hit_regions.t] |> print_s ;
  [%expect
    {| ((A (((start (One_raw 1)) (end_ (One_raw 10)) (index 0) (query A))))) |}]

let%expect_test "edges" =
  let rs =
    [ (* Region 1 *)
      {default_record with query= "A"; qstart= 10; qend= 1}
    ; {default_record with query= "A"; qend= 10; qstart= 1} ]
  in
  List.fold rs ~init:String.Map.empty ~f:Hit_regions.process_parsed_record
  |> Hit_regions.sort_hits_by_query |> Hit_regions.regions_of_sorted_hits
  |> [%sexp_of: Hit_regions.t] |> print_s ;
  [%expect
    {| ((A (((start (One_raw 1)) (end_ (One_raw 10)) (index 0) (query A))))) |}]

let%expect_test "regions canonicalize themselves upon creation" =
  print_s @@ [%sexp_of: Region.t] @@ region_v ~start:10 ~end_:1 ~query:"" () ;
  [%expect {| ((start (One_raw 1)) (end_ (One_raw 10)) (index 0) (query "")) |}]

let%expect_test "regions are strictly positive" =
  print_s @@ [%sexp_of: Region.t Or_error.t]
  @@ Or_error.try_with (fun () -> region_v ~start:(-1) ~end_:10 ~query:"" ()) ;
  [%expect {| (Error "Coord.one_raw_exn failed (-1)") |}] ;
  print_s @@ [%sexp_of: Region.t Or_error.t]
  @@ Or_error.try_with (fun () -> region_v ~start:1 ~end_:(-1) ~query:"" ()) ;
  [%expect {|
    (Error "Coord.one_raw_exn failed (-1)") |}] ;
  print_s @@ [%sexp_of: Region.t Or_error.t]
  @@ Or_error.try_with (fun () -> region_v ~start:(-1) ~end_:(-1) ~query:"" ()) ;
  [%expect {| (Error "Coord.one_raw_exn failed (-1)") |}]

let%expect_test "region length" =
  let p = printf "%d\n" in
  p @@ Region.length @@ region_v ~start:1 ~end_:1 ~query:"" () ;
  p @@ Region.length @@ region_v ~start:1 ~end_:2 ~query:"" () ;
  p @@ Region.length @@ region_v ~start:1 ~end_:10 ~query:"" () ;
  [%expect {|
    1
    2
    10 |}]

let%test_unit _ =
  let result = Region.center @@ region_v ~start:1 ~end_:1 ~query:"" () in
  [%test_result: float] result ~expect:1.0

let%test_unit _ =
  let result = Region.center @@ region_v ~start:1 ~end_:2 ~query:"" () in
  [%test_result: float] result ~expect:1.5

let%test_unit _ =
  let result = Region.center @@ region_v ~start:1 ~end_:3 ~query:"" () in
  [%test_result: float] result ~expect:2.0

let%test_unit "contains: same region" =
  let result =
    Region.contains
      ~this:(region_v ~start:10 ~end_:20 ~query:"" ())
      ~other:(region_v ~start:10 ~end_:20 ~query:"" ())
  in
  [%test_result: bool] result ~expect:true

let%test_unit "contains: fully contained" =
  let result =
    Region.contains
      ~this:(region_v ~start:10 ~end_:20 ~query:"" ())
      ~other:(region_v ~start:11 ~end_:19 ~query:"" ())
  in
  [%test_result: bool] result ~expect:true

let%test_unit "contains: other extends end" =
  let result =
    Region.contains
      ~this:(region_v ~start:10 ~end_:20 ~query:"" ())
      ~other:(region_v ~start:10 ~end_:21 ~query:"" ())
  in
  [%test_result: bool] result ~expect:false

let%test_unit "contains: other extends beginning" =
  let result =
    Region.contains
      ~this:(region_v ~start:10 ~end_:20 ~query:"" ())
      ~other:(region_v ~start:9 ~end_:20 ~query:"" ())
  in
  [%test_result: bool] result ~expect:false

let%test_unit "contains: other is bigger" =
  let result =
    Region.contains
      ~this:(region_v ~start:10 ~end_:20 ~query:"" ())
      ~other:(region_v ~start:9 ~end_:21 ~query:"" ())
  in
  [%test_result: bool] result ~expect:false

let%test_unit "testing for a bug...but the bug was somewhere else" =
  let result =
    Region.contains
      ~this:(region_v ~start:176 ~end_:567 ~query:"" ())
      ~other:(region_v ~start:176 ~end_:569 ~query:"" ())
  in
  [%test_result: bool] result ~expect:false
