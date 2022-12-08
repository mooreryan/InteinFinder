open! Core
open Cmdliner

let prog_name = "InteinFinder"

type opts = {config_file: string} [@@deriving sexp_of]

let make_opts config_file = {config_file}

let config_term =
  let doc = "Path to config toml" in
  Arg.(required & pos 0 (some non_dir_file) None & info [] ~docv:"CONFIG" ~doc)

let term = Term.(const make_opts $ config_term)

let info =
  let doc = "automated intein detection from large protein datasets" in
  let man =
    [ `S Manpage.s_description
    ; `P
        "InteinFinder is an automated pipeline for identifying, cataloging, \
         and removing inteins from peptide sequences.  It accurately screens \
         proteins for inteins and is scalable to large peptide sequence \
         datasets."
    ; `S Manpage.s_bugs
    ; `P
        "Please report any bugs or issues on GitHub. \
         (https://github.com/mooreryan/InteinFinder/issues)"
    ; `S Manpage.s_see_also
    ; `P
        "For full documentation, please see the GitHub page. \
         (https://github.com/mooreryan/InteinFinder)"
    ; `S Manpage.s_authors
    ; `P "Ryan M. Moore <https://orcid.org/0000-0003-3337-8184>" ]
  in
  let version = Lib.Config.Version.intein_finder_version in
  Cmd.info prog_name ~version ~doc ~man ~exits:[]

let parse_argv () =
  match Cmd.eval_value @@ Cmd.v info term with
  | Ok (`Ok opts) ->
      Ok opts
  | Ok `Help | Ok `Version ->
      Error 0
  | Error _ ->
      Error 1
