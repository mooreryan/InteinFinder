open! Core

module T = struct
  [@@@coverage off]

  type t = int [@@deriving sexp_of, compare, hash]

  [@@@coverage on]
end

include T
include Comparable.Make_plain (T)

let of_zero_indexed_int i = i

let to_zero_indexed_int i = i

let to_one_indexed_int i = i + 1

let to_one_indexed_string t = Int.to_string @@ to_one_indexed_int t

let zero () = 0

let assert_positive_or_zero t =
  let i = to_zero_indexed_int t in
  if i < 0 then Or_error.errorf "Expected index >= 0, but got %d" i
  else Or_error.return ()

let%expect_test "assert_positive_or_zero" =
  print_s @@ [%sexp_of: unit Or_error.t] @@ assert_positive_or_zero
  @@ of_zero_indexed_int (-1) ;
  [%expect {| (Error "Expected index >= 0, but got -1") |}] ;
  print_s @@ [%sexp_of: unit Or_error.t] @@ assert_positive_or_zero
  @@ of_zero_indexed_int 0 ;
  [%expect {| (Ok ()) |}] ;
  print_s @@ [%sexp_of: unit Or_error.t] @@ assert_positive_or_zero
  @@ of_zero_indexed_int 1 ;
  [%expect {| (Ok ()) |}]
