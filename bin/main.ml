open! Core
open Lib

let main : unit -> unit =
 fun () ->
  (* Start with debug. The first thing the [run] function does is set the
     logging how the user wants. This log level will show any errors in the
     config parsing. *)
  Logging.set_up_logging "debug" ;
  match Config.parse_argv () with
  | `Run config ->
      Run.run config
  | `Exit code ->
      exit code

let () = main ()
