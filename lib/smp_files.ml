open! Core

[@@@coverage off]

type t = string list [@@deriving sexp_of]

[@@@coverage on]

let paths_exn dir = Utils.ls_dir dir
