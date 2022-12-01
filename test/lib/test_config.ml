open! Core
open Lib

let%expect_test "Log_level.parse" =
  let open Config in
  print_s @@ [%sexp_of: string Or_error.t] @@ Log_level.parse "eRrOr" ;
  [%expect {| (Ok error) |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ Log_level.parse "wArNiNg" ;
  [%expect {| (Ok warning) |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ Log_level.parse "InFo" ;
  [%expect {| (Ok info) |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ Log_level.parse "DeBuG" ;
  [%expect {| (Ok debug) |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ Log_level.parse "" ;
  [%expect
    {|
    (Error
     "Log level must be one of 'error', 'warning', 'info', or 'debug'. Got ''") |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ Log_level.parse "apple pie" ;
  [%expect
    {|
    (Error
     "Log level must be one of 'error', 'warning', 'info', or 'debug'. Got 'apple pie'") |}]
