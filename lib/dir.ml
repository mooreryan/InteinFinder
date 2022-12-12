open! Core

[@@@coverage off]

type t =
  { rpsblast_db: string
  ; aln: string
  ; results: string
  ; query_splits: string
  ; logs: string
  ; cdm_db_search: string
  ; intein_db_search: string }
[@@deriving fields]

[@@@coverage on]

let v out_dir =
  { rpsblast_db= out_dir ^/ "rpsblast_db"
  ; aln= out_dir ^/ "alignments"
  ; results= out_dir ^/ "results"
  ; query_splits= out_dir ^/ "query_splits"
  ; logs= out_dir ^/ "logs"
  ; intein_db_search= out_dir ^/ "search" ^/ "intein_db"
  ; cdm_db_search= out_dir ^/ "search" ^/ "cdm_db" }

let mkdirs t =
  let mkdir_p _ _ dir_name = Core_unix.mkdir_p dir_name in
  Fields.Direct.iter
    t
    ~rpsblast_db:mkdir_p
    ~aln:mkdir_p
    ~results:mkdir_p
    ~query_splits:mkdir_p
    ~logs:mkdir_p
    ~cdm_db_search:mkdir_p
    ~intein_db_search:mkdir_p ;
  t
