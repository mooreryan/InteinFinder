open! Core

module Cli = struct
  open Cmdliner

  let ( let+ ) v f = Term.(const f $ v)

  let ( and+ ) v1 v2 = Term.(const (fun x y -> (x, y)) $ v1 $ v2)

  let prog_name = "RemoveInteins"

  type opts = {intein_hit_checks: string; queries: string} [@@deriving sexp_of]

  let intein_hit_checks =
    let doc = "Path to intein_hits_checks file (should exist)" in
    Arg.(
      required
      & pos 0 (some non_dir_file) None
      & info [] ~docv:"HIT_CHECKS" ~doc )

  let queries =
    let doc = "Path to query fasta file (should exist)" in
    Arg.(
      required & pos 1 (some non_dir_file) None & info [] ~docv:"QUERIES" ~doc )

  let opts : opts Term.t =
    let+ intein_hit_checks = intein_hit_checks and+ queries = queries in
    {intein_hit_checks; queries}

  let opts_to_string opts = Sexp.to_string @@ [%sexp_of: opts] opts

  let info =
    let doc = "remove inteins from extein sequences" in
    let man =
      [ `S Manpage.s_description
      ; `P
          "After you run InteinFinder, you can use this program to remove \
           generate a set of extein sequences for any inteins that were \
           identified by the pipeline."
      ; `P
          "Eventually, the functionality provided by this program will be \
           included in the main InteinFinder pipeline, but for now, if you \
           need the intein-free extein sequences, use this program."
      ; `P
          "Note that only query sequences with at least one bonafide intein \
           sequence will be printed, and that only inteins who scored an \
           overall Pass will be removed from said extein sequences.  Keep in \
           mind that the printed sequences may not be completely intein-free, \
           as a query could have multiple inteins, but not all of those \
           predicetd inteins may have scored well enough to be automatically \
           removed.  For now, you will see a warning in cases like these." ]
    in
    Cmd.info
      prog_name
      ~version:Lib.Config.Version.intein_finder_version
      ~doc
      ~man
      ~exits:[]

  let parse_argv () =
    match Cmd.eval_value @@ Cmd.v info opts with
    | Ok (`Ok opts) ->
        opts
    | Ok `Help | Ok `Version ->
        exit 0
    | Error _ ->
        exit 1
end

let main () =
  let open Lib in
  Logging.set_up_logging "debug" ;
  let ({Cli.intein_hit_checks; queries} as opts) = Cli.parse_argv () in
  Logs.debug (fun m -> m "%s" @@ Cli.opts_to_string opts) ;
  Remove_inteins.run ~intein_hit_checks ~queries

let () = main ()
