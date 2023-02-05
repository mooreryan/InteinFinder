open! Core
open Lib
module C = Coord
module Q = Quickcheck

module QG = struct
  include Quickcheck.Generator

  let negative_int = filter Int.quickcheck_generator ~f:(fun i -> i < 0)

  let zero_or_negative_int =
    filter Int.quickcheck_generator ~f:(fun i -> i <= 0)
end

module Test_constructors = struct
  let%test_unit "zero_raw (valid)" =
    Q.test
      QG.small_non_negative_int
      ~examples:[0; 1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match Option.try_with (fun () -> C.zero_raw_exn i) with
        | Some (Zero_raw i') ->
            [%test_result: int] i' ~expect:i
        | None ->
            assert false )

  let%test_unit "zero_raw (invalid)" =
    Q.test
      QG.negative_int
      ~examples:[-1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        assert (Option.is_none @@ Option.try_with (fun () -> C.zero_raw_exn i)) )

  let%test_unit "zero_aln (valid)" =
    Q.test
      QG.small_non_negative_int
      ~examples:[0; 1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match Option.try_with (fun () -> C.zero_aln_exn i) with
        | Some (Zero_aln i') ->
            [%test_result: int] i' ~expect:i
        | None ->
            assert false )

  let%test_unit "zero_aln (invalid)" =
    Q.test
      QG.negative_int
      ~examples:[-1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        assert (Option.is_none @@ Option.try_with (fun () -> C.zero_aln_exn i)) )

  let%test_unit "one_raw (valid)" =
    Q.test
      QG.small_positive_int
      ~examples:[1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match Option.try_with (fun () -> C.one_raw_exn i) with
        | Some (One_raw i') ->
            [%test_result: int] i' ~expect:i
        | None ->
            assert false )

  let%test_unit "one_raw (invalid)" =
    Q.test
      QG.zero_or_negative_int
      ~examples:[-1; 0]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        assert (Option.is_none @@ Option.try_with (fun () -> C.one_raw_exn i)) )

  let%test_unit "one_aln (valid)" =
    Q.test
      QG.small_positive_int
      ~examples:[1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match Option.try_with (fun () -> C.one_aln_exn i) with
        | Some (One_aln i') ->
            [%test_result: int] i' ~expect:i
        | None ->
            assert false )

  let%test_unit "one_aln (invalid)" =
    Q.test
      QG.zero_or_negative_int
      ~examples:[-1; 0]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        assert (Option.is_none @@ Option.try_with (fun () -> C.one_aln_exn i)) )
end

module Test_clamped_constructors = struct
  let%test_unit "zero_raw (valid)" =
    Q.test
      QG.small_non_negative_int
      ~examples:[0; 1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match C.zero_raw_clamped i with
        | Zero_raw i' ->
            [%test_result: int] i' ~expect:i )

  let%test_unit "zero_raw (invalid)" =
    Q.test
      QG.negative_int
      ~examples:[-1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match C.zero_raw_clamped i with
        | Zero_raw i' ->
            [%test_result: int] i' ~expect:C.zero_min )

  let%test_unit "zero_aln (valid)" =
    Q.test
      QG.small_non_negative_int
      ~examples:[0; 1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match C.zero_aln_clamped i with
        | Zero_aln i' ->
            [%test_result: int] i' ~expect:i )

  let%test_unit "zero_aln (invalid)" =
    Q.test
      QG.negative_int
      ~examples:[-1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match C.zero_aln_clamped i with
        | Zero_aln i' ->
            [%test_result: int] i' ~expect:C.zero_min )

  let%test_unit "one_raw (valid)" =
    Q.test
      QG.small_positive_int
      ~examples:[1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match C.one_raw_clamped i with
        | One_raw i' ->
            [%test_result: int] i' ~expect:i )

  let%test_unit "one_raw (invalid)" =
    Q.test
      QG.zero_or_negative_int
      ~examples:[-1; 0]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match C.one_raw_clamped i with
        | One_raw i' ->
            [%test_result: int] i' ~expect:C.one_min )

  let%test_unit "one_aln (valid)" =
    Q.test
      QG.small_positive_int
      ~examples:[1]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match C.one_aln_clamped i with
        | One_aln i' ->
            [%test_result: int] i' ~expect:i )

  let%test_unit "one_aln (invalid)" =
    Q.test
      QG.zero_or_negative_int
      ~examples:[-1; 0]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        match C.one_aln_clamped i with
        | One_aln i' ->
            [%test_result: int] i' ~expect:C.one_min )
end

module Test_conversions = struct
  let zero_clamped_float x = Float.(if of_int x < 0. then 0. else of_int x)

  let one_clamped_float x = Float.(if of_int x < 1. then 1. else of_int x)

  let zero_clamped_int x = Int.(if x < 0 then 0 else x)

  let one_clamped_int x = Int.(if x < 1 then 1 else x)

  let%test_unit "to_float" =
    Q.test
      Int.quickcheck_generator
      ~examples:[-1; 0; 1; 2]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        [%test_result: float]
          (C.to_float (C.zero_raw_clamped i))
          ~expect:(zero_clamped_float i) ;
        [%test_result: float]
          (C.to_float (C.zero_aln_clamped i))
          ~expect:(zero_clamped_float i) ;
        [%test_result: float]
          (C.to_float (C.one_raw_clamped i))
          ~expect:(one_clamped_float i) ;
        [%test_result: float]
          (C.to_float (C.one_aln_clamped i))
          ~expect:(one_clamped_float i) )

  let%test_unit "to_int" =
    Q.test
      Int.quickcheck_generator
      ~examples:[-1; 0; 1; 2]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        [%test_result: int]
          (C.to_int (C.zero_raw_clamped i))
          ~expect:(zero_clamped_int i) ;
        [%test_result: int]
          (C.to_int (C.zero_aln_clamped i))
          ~expect:(zero_clamped_int i) ;
        [%test_result: int]
          (C.to_int (C.one_raw_clamped i))
          ~expect:(one_clamped_int i) ;
        [%test_result: int]
          (C.to_int (C.one_aln_clamped i))
          ~expect:(one_clamped_int i) )

  let%test_unit "to_zero_indexed_int" =
    Q.test
      Int.quickcheck_generator
      ~examples:[-1; 0; 1; 2]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        [%test_result: int]
          (C.to_zero_indexed_int (C.zero_raw_clamped i))
          ~expect:(zero_clamped_int i) ;
        [%test_result: int]
          (C.to_zero_indexed_int (C.zero_aln_clamped i))
          ~expect:(zero_clamped_int i) ;
        [%test_result: int]
          (C.to_zero_indexed_int (C.one_raw_clamped i))
          ~expect:(one_clamped_int i - 1) ;
        [%test_result: int]
          (C.to_zero_indexed_int (C.one_aln_clamped i))
          ~expect:(one_clamped_int i - 1) )

  let%test_unit "to_one_indexed_int" =
    Q.test
      Int.quickcheck_generator
      ~examples:[-1; 0; 1; 2]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        [%test_result: int]
          (C.to_one_indexed_int (C.zero_raw_clamped i))
          ~expect:(zero_clamped_int i + 1) ;
        [%test_result: int]
          (C.to_one_indexed_int (C.zero_aln_clamped i))
          ~expect:(zero_clamped_int i + 1) ;
        [%test_result: int]
          (C.to_one_indexed_int (C.one_raw_clamped i))
          ~expect:(one_clamped_int i) ;
        [%test_result: int]
          (C.to_one_indexed_int (C.one_aln_clamped i))
          ~expect:(one_clamped_int i) )

  let%test_unit "to_one_indexed_int" =
    Q.test
      Int.quickcheck_generator
      ~examples:[-1; 0; 1; 2]
      ~shrinker:Int.quickcheck_shrinker
      ~f:(fun i ->
        [%test_result: string]
          (C.to_one_indexed_string (C.zero_raw_clamped i))
          ~expect:(Int.to_string (zero_clamped_int i + 1)) ;
        [%test_result: string]
          (C.to_one_indexed_string (C.zero_aln_clamped i))
          ~expect:(Int.to_string (zero_clamped_int i + 1)) ;
        [%test_result: string]
          (C.to_one_indexed_string (C.one_raw_clamped i))
          ~expect:(Int.to_string (one_clamped_int i)) ;
        [%test_result: string]
          (C.to_one_indexed_string (C.one_aln_clamped i))
          ~expect:(Int.to_string (one_clamped_int i)) )
end

module Test_equal = struct
  let%test_unit "equal" =
    Q.test QG.small_positive_int ~examples:[1] ~f:(fun i ->
        let zr = C.zero_raw_exn (i - 1) in
        let za = C.zero_aln_exn (i - 1) in
        let or_ = C.one_raw_exn i in
        let oa = C.one_aln_exn i in
        assert (C.(or_ = or_)) ;
        assert (C.(zr = zr)) ;
        assert (C.(oa = oa)) ;
        assert (C.(za = za)) ;
        assert (C.(or_ = zr)) ;
        assert (C.(zr = or_)) ;
        assert (C.(oa = za)) ;
        assert (C.(za = oa)) )

  let%test_unit "comparing" =
    Q.test QG.small_positive_int ~examples:[1] ~f:(fun i ->
        (* Same int means zero-indexed will be "larger". *)
        let zr = C.zero_raw_exn i in
        let za = C.zero_aln_exn i in
        let or_ = C.one_raw_exn i in
        let oa = C.one_aln_exn i in
        (* One-Raw One-Raw *)
        assert (C.(or_ = or_)) ;
        assert (C.(or_ <= or_)) ;
        assert (C.(or_ >= or_)) ;
        assert (not C.(or_ < or_)) ;
        assert (not C.(or_ > or_)) ;
        (* Zero-Raw Zero-Raw *)
        assert (C.(zr = zr)) ;
        assert (C.(zr <= zr)) ;
        assert (C.(zr >= zr)) ;
        assert (not C.(zr < zr)) ;
        assert (not C.(zr > zr)) ;
        (* One-Aln One-Aln *)
        assert (C.(oa = oa)) ;
        assert (C.(oa <= oa)) ;
        assert (C.(oa >= oa)) ;
        assert (not C.(oa < oa)) ;
        assert (not C.(oa > oa)) ;
        (* Zero-aln Zero-aln *)
        assert (C.(za = za)) ;
        assert (C.(za <= za)) ;
        assert (C.(za >= za)) ;
        assert (not C.(za < za)) ;
        assert (not C.(za > za)) ;
        (* One-Raw Zero-Raw *)
        assert (not C.(or_ = zr)) ;
        assert (C.(or_ <= zr)) ;
        assert (not C.(or_ >= zr)) ;
        assert (C.(or_ < zr)) ;
        assert (not C.(or_ > zr)) ;
        (* One-Aln Zero-Aln *)
        assert (not C.(oa = za)) ;
        assert (C.(oa <= za)) ;
        assert (not C.(oa >= za)) ;
        assert (C.(oa < za)) ;
        assert (not C.(oa > za)) ;
        (* Zero-raw One-raw *)
        assert (not C.(zr = or_)) ;
        assert (not C.(zr <= or_)) ;
        assert (C.(zr >= or_)) ;
        assert (not C.(zr < or_)) ;
        assert (C.(zr > or_)) ;
        (* Zero-aln One-aln *)
        assert (not C.(za = oa)) ;
        assert (not C.(za <= oa)) ;
        assert (C.(za >= oa)) ;
        assert (not C.(za < oa)) ;
        assert (C.(za > oa)) ;
        (* Add 2 to get a one-indexed that's bigger than a zero-indexed. *)
        let or_ = C.one_raw_exn (i + 2) in
        let oa = C.one_aln_exn (i + 2) in
        assert (C.(or_ > zr)) ;
        assert (not C.(or_ <= zr)) ;
        assert (C.(oa > za)) ;
        assert (not C.(oa <= za)) )

  let%test_unit "compare" =
    Q.test QG.small_positive_int ~examples:[1] ~f:(fun i ->
        let zr = C.zero_raw_exn (i - 1) in
        let za = C.zero_aln_exn (i - 1) in
        let or_ = C.one_raw_exn i in
        let oa = C.one_aln_exn i in
        [%test_result: int] C.(compare or_ or_) ~expect:0 ;
        [%test_result: int] C.(compare zr zr) ~expect:0 ;
        [%test_result: int] C.(compare oa oa) ~expect:0 ;
        [%test_result: int] C.(compare za za) ~expect:0 ;
        [%test_result: int] C.(compare or_ zr) ~expect:0 ;
        [%test_result: int] C.(compare zr or_) ~expect:0 ;
        [%test_result: int] C.(compare oa za) ~expect:0 ;
        [%test_result: int] C.(compare za oa) ~expect:0 ;
        (* This time, zero indexed coords are the same int value, which means
           the zero-indexed coord is LARGER than the one-indexed. *)
        let zr = C.zero_raw_exn i in
        let za = C.zero_aln_exn i in
        let first_smaller = -1 in
        let second_smaller = 1 in
        [%test_result: int] C.(compare or_ zr) ~expect:first_smaller ;
        [%test_result: int] C.(compare zr or_) ~expect:second_smaller ;
        [%test_result: int] C.(compare oa za) ~expect:first_smaller ;
        [%test_result: int] C.(compare za oa) ~expect:second_smaller )
end

module Test_add = struct
  let%test_unit "adding" =
    Q.test QG.small_positive_int ~examples:[1] ~f:(fun i ->
        let zr = C.zero_raw_exn i in
        let za = C.zero_aln_exn i in
        let or_ = C.one_raw_exn i in
        let oa = C.one_aln_exn i in
        (* add *)
        assert (C.(add zr zr |> to_int) = i + i) ;
        assert (C.(add za za |> to_int) = i + i) ;
        assert (C.(add or_ or_ |> to_int) = i + i) ;
        assert (C.(add oa oa |> to_int) = i + i) ;
        (* add' *)
        assert (C.(add' zr 1 |> to_int) = i + 1) ;
        assert (C.(add' za 1 |> to_int) = i + 1) ;
        assert (C.(add' or_ 1 |> to_int) = i + 1) ;
        assert (C.(add' oa 1 |> to_int) = i + 1) ;
        (* add'' *)
        assert (C.(add'' 1 zr |> to_int) = i + 1) ;
        assert (C.(add'' 1 za |> to_int) = i + 1) ;
        assert (C.(add'' 1 or_ |> to_int) = i + 1) ;
        assert (C.(add'' 1 oa |> to_int) = i + 1) ;
        (* incr *)
        assert (C.(incr zr |> to_int) = i + 1) ;
        assert (C.(incr za |> to_int) = i + 1) ;
        assert (C.(incr or_ |> to_int) = i + 1) ;
        assert (C.(incr oa |> to_int) = i + 1) )
end

module Test_sub = struct
  let to_int' = function None -> None | Some x -> Some (C.to_int x)

  let%test_unit "subtracting bottoms" =
    let zr = C.zero_raw_clamped (-1) in
    let za = C.zero_aln_clamped (-1) in
    let or_ = C.one_raw_clamped (-1) in
    let oa = C.one_aln_clamped (-1) in
    assert (C.(Option.value_exn (sub zr zr) = zr)) ;
    assert (C.(Option.value_exn (sub za za) = za)) ;
    assert (Option.is_none C.(sub or_ or_)) ;
    assert (Option.is_none C.(sub oa oa))

  let%test_unit "subtracting" =
    Q.test QG.small_positive_int ~examples:[1] ~f:(fun i ->
        let zr_smaller = C.zero_raw_exn i in
        let za_smaller = C.zero_aln_exn i in
        let or_smaller = C.one_raw_exn i in
        let oa_smaller = C.one_aln_exn i in
        let zr_bigger = C.zero_raw_exn (i + 1) in
        let za_bigger = C.zero_aln_exn (i + 1) in
        let or_bigger = C.one_raw_exn (i + 1) in
        let oa_bigger = C.one_aln_exn (i + 1) in
        assert (Option.is_none @@ C.(sub zr_smaller zr_bigger)) ;
        assert (
          Option.equal Int.equal C.(sub zr_bigger zr_smaller |> to_int') (Some 1) ) ;
        assert (Option.is_none @@ C.(sub za_smaller za_bigger)) ;
        assert (
          Option.equal Int.equal C.(sub za_bigger za_smaller |> to_int') (Some 1) ) ;
        assert (Option.is_none @@ C.(sub or_smaller or_bigger)) ;
        assert (
          Option.equal Int.equal C.(sub or_bigger or_smaller |> to_int') (Some 1) ) ;
        assert (Option.is_none @@ C.(sub oa_smaller oa_bigger)) ;
        assert (
          Option.equal Int.equal C.(sub oa_bigger oa_smaller |> to_int') (Some 1) ) )

  let%test_unit "subtracting 2" =
    Q.test QG.small_positive_int ~examples:[1] ~f:(fun i ->
        let zr = C.zero_raw_exn (i + 1) in
        let za = C.zero_aln_exn (i + 1) in
        let or_ = C.one_raw_exn (i + 1) in
        let oa = C.one_aln_exn (i + 1) in
        (* sub' *)
        assert (Option.equal Int.equal C.(sub' zr 1 |> to_int') (Some i)) ;
        assert (Option.equal Int.equal C.(sub' za 1 |> to_int') (Some i)) ;
        assert (Option.equal Int.equal C.(sub' or_ 1 |> to_int') (Some i)) ;
        assert (Option.equal Int.equal C.(sub' oa 1 |> to_int') (Some i)) ;
        (* decr *)
        assert (Option.equal Int.equal C.(decr zr |> to_int') (Some i)) ;
        assert (Option.equal Int.equal C.(decr za |> to_int') (Some i)) ;
        assert (Option.equal Int.equal C.(decr or_ |> to_int') (Some i)) ;
        assert (Option.equal Int.equal C.(decr oa |> to_int') (Some i)) )

  let%expect_test "bad decr" =
    Or_error.try_with (fun () -> C.(decr_exn @@ zero_raw_exn 0))
    |> [%sexp_of: C.zero_raw Or_error.t]
    |> print_s ;
    [%expect {| (Error (Failure "decr failed with 0")) |}]
end

module Test_length = struct
  (* one_raw *)
  let%test_unit _ =
    let len = C.length ~start:(C.one_raw_exn 1) ~end_:(C.one_raw_exn 1) () in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len = C.length ~start:(C.one_raw_exn 1) ~end_:(C.one_raw_exn 2) () in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len = C.length ~start:(C.one_raw_exn 2) ~end_:(C.one_raw_exn 1) () in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len = C.length ~start:(C.one_raw_exn 1) ~end_:(C.one_raw_exn 3) () in
    [%test_result: int] len ~expect:3

  let%test_unit _ =
    let len = C.length ~start:(C.one_raw_exn 3) ~end_:(C.one_raw_exn 1) () in
    [%test_result: int] len ~expect:3

  (* one_aln *)
  let%test_unit _ =
    let len = C.length ~start:(C.one_aln_exn 1) ~end_:(C.one_aln_exn 1) () in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len = C.length ~start:(C.one_aln_exn 1) ~end_:(C.one_aln_exn 2) () in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len = C.length ~start:(C.one_aln_exn 2) ~end_:(C.one_aln_exn 1) () in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len = C.length ~start:(C.one_aln_exn 1) ~end_:(C.one_aln_exn 3) () in
    [%test_result: int] len ~expect:3

  let%test_unit _ =
    let len = C.length ~start:(C.one_aln_exn 3) ~end_:(C.one_aln_exn 1) () in
    [%test_result: int] len ~expect:3

  (* zero_raw *)
  let%test_unit _ =
    let len = C.length ~start:(C.zero_raw_exn 1) ~end_:(C.zero_raw_exn 1) () in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len = C.length ~start:(C.zero_raw_exn 1) ~end_:(C.zero_raw_exn 2) () in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len = C.length ~start:(C.zero_raw_exn 2) ~end_:(C.zero_raw_exn 1) () in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len = C.length ~start:(C.zero_raw_exn 1) ~end_:(C.zero_raw_exn 3) () in
    [%test_result: int] len ~expect:3

  let%test_unit _ =
    let len = C.length ~start:(C.zero_raw_exn 3) ~end_:(C.zero_raw_exn 1) () in
    [%test_result: int] len ~expect:3

  (* zero_aln *)
  let%test_unit _ =
    let len = C.length ~start:(C.zero_aln_exn 1) ~end_:(C.zero_aln_exn 1) () in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len = C.length ~start:(C.zero_aln_exn 1) ~end_:(C.zero_aln_exn 2) () in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len = C.length ~start:(C.zero_aln_exn 2) ~end_:(C.zero_aln_exn 1) () in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len = C.length ~start:(C.zero_aln_exn 1) ~end_:(C.zero_aln_exn 3) () in
    [%test_result: int] len ~expect:3

  let%test_unit _ =
    let len = C.length ~start:(C.zero_aln_exn 3) ~end_:(C.zero_aln_exn 1) () in
    [%test_result: int] len ~expect:3

  (* exclusive end *)

  (* TODO: quickcheck *)

  (* one_raw *)
  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_raw_exn 1)
        ~end_:(C.one_raw_exn 1)
        ()
    in
    [%test_result: int] len ~expect:0

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_raw_exn 1)
        ~end_:(C.one_raw_exn 2)
        ()
    in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_raw_exn 2)
        ~end_:(C.one_raw_exn 1)
        ()
    in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_raw_exn 1)
        ~end_:(C.one_raw_exn 3)
        ()
    in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_raw_exn 3)
        ~end_:(C.one_raw_exn 1)
        ()
    in
    [%test_result: int] len ~expect:2

  (* one_aln *)
  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_aln_exn 1)
        ~end_:(C.one_aln_exn 1)
        ()
    in
    [%test_result: int] len ~expect:0

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_aln_exn 1)
        ~end_:(C.one_aln_exn 2)
        ()
    in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_aln_exn 2)
        ~end_:(C.one_aln_exn 1)
        ()
    in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_aln_exn 1)
        ~end_:(C.one_aln_exn 3)
        ()
    in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.one_aln_exn 3)
        ~end_:(C.one_aln_exn 1)
        ()
    in
    [%test_result: int] len ~expect:2

  (* zero_raw *)
  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_raw_exn 1)
        ~end_:(C.zero_raw_exn 1)
        ()
    in
    [%test_result: int] len ~expect:0

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_raw_exn 1)
        ~end_:(C.zero_raw_exn 2)
        ()
    in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_raw_exn 2)
        ~end_:(C.zero_raw_exn 1)
        ()
    in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_raw_exn 1)
        ~end_:(C.zero_raw_exn 3)
        ()
    in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_raw_exn 3)
        ~end_:(C.zero_raw_exn 1)
        ()
    in
    [%test_result: int] len ~expect:2

  (* zero_aln *)
  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_aln_exn 1)
        ~end_:(C.zero_aln_exn 1)
        ()
    in
    [%test_result: int] len ~expect:0

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_aln_exn 1)
        ~end_:(C.zero_aln_exn 2)
        ()
    in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_aln_exn 2)
        ~end_:(C.zero_aln_exn 1)
        ()
    in
    [%test_result: int] len ~expect:1

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_aln_exn 1)
        ~end_:(C.zero_aln_exn 3)
        ()
    in
    [%test_result: int] len ~expect:2

  let%test_unit _ =
    let len =
      C.length
        ~end_is:`exclusive
        ~start:(C.zero_aln_exn 3)
        ~end_:(C.zero_aln_exn 1)
        ()
    in
    [%test_result: int] len ~expect:2
end
