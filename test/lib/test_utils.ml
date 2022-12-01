open! Core
open Lib
open Expect_test_helpers_base

let assert_file_exists name = assert (Sys_unix.file_exists_exn name)

let refute_file_exists name = assert (not (Sys_unix.file_exists_exn name))

let%test_unit "remove_if_file_empty" =
  Utils.with_temp_file (fun name ->
      Out_channel.write_all name ~data:"yo" ;
      Utils.remove_file_if_empty name ;
      assert_file_exists name ;
      (* Now truncate the file and try again. *)
      Core_unix.truncate name ~len:(Int64.of_int 0) ;
      Utils.remove_file_if_empty name ;
      refute_file_exists name )

let%expect_test "assert_all_files_exist" =
  let files = ["apple.txt"; "pie.txt"] in
  require_does_raise [%here] (fun () -> Utils.assert_all_files_exist files) ;
  [%expect
    {|
    ("Expected 'apple.txt' to exist, but it does not"
     "Expected 'pie.txt' to exist, but it does not") |}]

let%expect_test "assert_all_files_exist" =
  Utils.with_temp_file (fun name ->
      let files = [name; "pie.txt"] in
      require_does_raise [%here] (fun () -> Utils.assert_all_files_exist files) ) ;
  [%expect {| "Expected 'pie.txt' to exist, but it does not" |}]

let%test_unit "assert_all_files_exist" =
  Utils.with_temp_file (fun name ->
      let files = [name] in
      Utils.assert_all_files_exist files )
