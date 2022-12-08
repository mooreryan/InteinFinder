open! Core
open Lib

let ok_or_exit result = match result with Ok x -> x | Error code -> exit code

let main : unit -> unit =
 fun () ->
  (* Start with debug. The first thing the [run] function does is set the
     logging how the user wants. This log level will show any errors in the
     config parsing. *)
  Logging.set_up_logging "debug" ;
  let {Cli.config_file} = ok_or_exit @@ Cli.parse_argv () in
  let config = ok_or_exit @@ Config.read_config config_file in
  Run.run config config_file

let () = main ()
