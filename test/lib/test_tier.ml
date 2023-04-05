open! Core
open Lib

let bad_first_letter =
  let not_cap_t c = Char.(c <> 'T') in
  Quickcheck.Generator.filter Char.gen_alpha ~f:not_cap_t

let bad_tier =
  let open Quickcheck.Generator.Let_syntax in
  let%bind c = bad_first_letter in
  let%map rest = String.quickcheck_generator in
  Char.to_string c ^ rest

let good_tier =
  let open Quickcheck.Generator.Let_syntax in
  let%map i = Quickcheck.Generator.small_positive_int in
  [%string "T%{i#Int}"]

let%test_unit "good tiers are okay" =
  let f s =
    let actual = Tier.to_string @@ Tier.create_exn s in
    assert (String.(s = actual))
  in
  let examples = ["T1"; "T101"] in
  Quickcheck.test good_tier ~sexp_of:String.sexp_of_t ~f ~examples

let%test_unit "bad tiers give errors" =
  let f s = assert (Or_error.is_error @@ Tier.create s) in
  let examples = [""; "t"; "T"; "t1"; "A1"; "TT"; "T0"; "T-1"; "T1.2"] in
  Quickcheck.test bad_tier ~sexp_of:String.sexp_of_t ~f ~examples

let%expect_test "T0 gives special error message" =
  print_s @@ [%sexp_of: Tier.t Or_error.t] @@ Tier.create "T0" ;
  [%expect {| (Error "Tier number must be >= 1.  Got 0.") |}]

module Test_tier_list = struct
  let tl ints =
    List.map ints ~f:(fun i -> Tier.create_exn [%string "T%{i#Int}"])

  let%expect_test "empty list is okay" =
    print_s
    @@ [%sexp_of: Tier.Valid_list.t Or_error.t]
    @@ Tier.Valid_list.create [] ;
    [%expect {| (Ok ()) |}]

  let%expect_test "good" =
    print_s
    @@ [%sexp_of: Tier.Valid_list.t Or_error.t]
    @@ Tier.Valid_list.create
    @@ tl [1] ;
    [%expect {| (Ok (1)) |}] ;
    print_s
    @@ [%sexp_of: Tier.Valid_list.t Or_error.t]
    @@ Tier.Valid_list.create
    @@ tl [1; 2] ;
    [%expect {| (Ok (1 2)) |}] ;
    print_s
    @@ [%sexp_of: Tier.Valid_list.t Or_error.t]
    @@ Tier.Valid_list.create
    @@ tl [1; 3; 2] ;
    [%expect {| (Ok (1 2 3)) |}] ;
    print_s
    @@ [%sexp_of: Tier.Valid_list.t Or_error.t]
    @@ Tier.Valid_list.create
    @@ tl [1; 3; 2; 4] ;
    [%expect {| (Ok (1 2 3 4)) |}]

  let%expect_test "bad" =
    print_s
    @@ [%sexp_of: Tier.Valid_list.t Or_error.t]
    @@ Tier.Valid_list.create
    @@ tl [1; 3] ;
    [%expect
      {| (Error "Expected tiers to start at one and increase by one, but got: (1 3)") |}] ;
    print_s
    @@ [%sexp_of: Tier.Valid_list.t Or_error.t]
    @@ Tier.Valid_list.create
    @@ tl [2; 3] ;
    [%expect
      {| (Error "Expected tiers to start at one and increase by one, but got: (2 3)") |}] ;
    print_s
    @@ [%sexp_of: Tier.Valid_list.t Or_error.t]
    @@ Tier.Valid_list.create
    @@ tl [1; 2; 3; 5] ;
    [%expect
      {|
      (Error
       "Expected tiers to start at one and increase by one, but got: (1 2 3 5)") |}] ;
    print_s
    @@ [%sexp_of: Tier.Valid_list.t Or_error.t]
    @@ Tier.Valid_list.create
    @@ tl [1; 3; 2; 5] ;
    [%expect
      {|
      (Error
       "Expected tiers to start at one and increase by one, but got: (1 2 3 5)") |}]
end
