open! Core
module Sh = Shexp_process

module Out = struct
  [@@@coverage off]

  type t = {out: string; log: string} [@@deriving fields, sexp_of]

  [@@@coverage on]

  let v ~out ~log = {out; log}
end

let prefix = "intein_finder__mmseqs"

let suffix = "intein_finder__mmseqs"

let run ~(config : Config.Mmseqs.t) ~queries ~targets ~out_dir ~log_base
    ~threads =
  let out = Out_file_name.intein_db_search_out out_dir in
  let log = Utils.log_name ~log_base ~desc:"mmseqs_search" in
  let sensitivity = Utils.float_to_string_hum config.sensitivity in
  let num_iterations = Int.to_string config.num_iterations in
  let evalue = Utils.float_to_string_hum config.evalue in
  let threads = Int.to_string threads in
  Sh.eval
  @@ Sh.outputs_to ~append:() log
  @@ Sh.with_temp_dir ~prefix ~suffix (fun tmpdir ->
         Sh.run
           config.exe
           [ "easy-search"
           ; queries
           ; targets
           ; out
           ; tmpdir
           ; "--format-mode"
           ; "2"
           ; "-s"
           ; sensitivity
           ; "--num-iterations"
           ; num_iterations
           ; "-e"
           ; evalue
           ; "--threads"
           ; threads ] ) ;
  Out.v ~out ~log
