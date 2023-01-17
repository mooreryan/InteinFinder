open! Core
open Lib

let%expect_test "log_level_parse" =
  let open Config in
  print_s @@ [%sexp_of: string Or_error.t] @@ log_level_parse "eRrOr" ;
  [%expect {| (Ok error) |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ log_level_parse "wArNiNg" ;
  [%expect {| (Ok warning) |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ log_level_parse "InFo" ;
  [%expect {| (Ok info) |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ log_level_parse "DeBuG" ;
  [%expect {| (Ok debug) |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ log_level_parse "" ;
  [%expect
    {|
    (Error
     "Log level must be one of 'error', 'warning', 'info', or 'debug'. Got ''") |}] ;
  print_s @@ [%sexp_of: string Or_error.t] @@ log_level_parse "apple pie" ;
  [%expect
    {|
    (Error
     "Log level must be one of 'error', 'warning', 'info', or 'debug'. Got 'apple pie'") |}]
