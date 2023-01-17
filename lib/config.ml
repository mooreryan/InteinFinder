open! Core
open Or_error.Let_syntax
module Sh = Shexp_process

let otoml_get_string_list = Otoml.get_array Otoml.get_string

module Non_existing_file = struct
  let parser s =
    if Sys_unix.file_exists_exn s then
      Or_error.errorf "expected file '%s' not to exist, but it does" s
    else Or_error.return s

  let converter = Tiny_toml.(Converter.v Accessor.string parser)

  let term ~default path = Tiny_toml.Value.find_or ~default path converter
end

module Existing_file = struct
  let parser s =
    if Sys_unix.file_exists_exn s then Or_error.return s
    else Or_error.errorf "expected file '%s' to exist, but it does not" s

  let converter = Tiny_toml.(Converter.v Accessor.string parser)

  let term path = Tiny_toml.Value.find path converter
end

module Executable = struct
  let get_exe_path exe =
    let exe_found, path =
      Sh.eval @@ Sh.capture [Sh.Std_io.Stdout] @@ Sh.run_bool "which" [exe]
    in
    if exe_found then Some (String.strip path) else None

  let parser s =
    match get_exe_path s with
    | Some path ->
        Or_error.return path
    | None ->
        Or_error.errorf "expected '%s' to be executable, but it was not" s

  let converter = Tiny_toml.(Converter.v Accessor.string parser)

  let term ~default toml_path =
    Tiny_toml.Value.find_or ~default toml_path converter
end

module type PATH = sig
  val path : string -> string list
end

let evalue_term ~default path =
  let open Tiny_toml in
  Value.find_or ~default path Converter.Float.non_negative

module Checks = struct
  module Start_residue = struct
    let toml_path = ["start_residue"]

    let default : (string * string) list =
      let make_default tier residues =
        let tier = Tier.to_string tier in
        List.map residues ~f:(fun r -> (r, tier))
      in
      let t1_default = make_default Tier.t1 ["C"; "S"; "A"; "Q"; "P"; "T"] in
      let t2_default = make_default Tier.t2 ["V"; "G"; "L"; "M"; "N"; "F"] in
      t1_default @ t2_default

    let find config =
      Tiny_toml.Term.eval ~config
      @@ Tier.Map.tiny_toml_single_residue_term ~default toml_path
  end

  module End_plus_one_residue = struct
    let toml_path = ["end_plus_one_residue"]

    let default : (string * string) list =
      let make_default tier residues =
        let tier = Tier.to_string tier in
        List.map residues ~f:(fun r -> (r, tier))
      in
      make_default Tier.t1 ["S"; "T"; "C"]

    let find config =
      Tiny_toml.Term.eval ~config
      @@ Tier.Map.tiny_toml_single_residue_term ~default toml_path
  end

  module End_residues = struct
    let toml_path = ["end_residues"]

    let default : (string * string) list =
      let make_default tier residues =
        let tier = Tier.to_string tier in
        List.map residues ~f:(fun r -> (r, tier))
      in
      let t1_default =
        make_default Tier.t1 ["HN"; "SN"; "GN"; "GQ"; "LD"; "FN"]
      in
      let t2_default =
        make_default
          Tier.t2
          [ "KN"
          ; "DY"
          ; "SQ"
          ; "HQ"
          ; "NS"
          ; "AN"
          ; "SD"
          ; "TH"
          ; "RD"
          ; "PY"
          ; "YN"
          ; "VH"
          ; "KQ"
          ; "PP"
          ; "NT"
          ; "CN"
          ; "LH" ]
      in
      t1_default @ t2_default

    let find config =
      Tiny_toml.Term.eval ~config
      @@ Tier.Map.tiny_toml_end_residues_term ~default toml_path
  end

  type t =
    { start_residue: Tier.Map.t
    ; end_residues: Tier.Map.t
    ; end_plus_one_residue: Tier.Map.t }
  [@@deriving sexp_of]

  let find toml =
    let%map start_residue = Start_residue.find toml
    and end_residues = End_residues.find toml
    and end_plus_one_residue = End_plus_one_residue.find toml in
    {start_residue; end_residues; end_plus_one_residue}
end

module Makeprofiledb = struct
  let path s = ["makeprofiledb"; s]

  type t = {exe: string} [@@deriving sexp_of]

  let exe = Executable.term ~default:"makeprofiledb" @@ path "exe"

  let term =
    let open Tiny_toml.Term.Let_syntax in
    let%map exe = exe in
    {exe}

  let find config = Tiny_toml.Term.eval term ~config
end

module Rpsblast = struct
  let path s = ["rpsblast"; s]

  type t = {exe: string; evalue: float} [@@deriving sexp_of]

  let exe = Executable.term ~default:"rpsblast+" @@ path "exe"

  let evalue = evalue_term ~default:1e-3 @@ path "evalue"

  let term =
    let open Tiny_toml.Term.Let_syntax in
    let%map exe = exe and evalue = evalue in
    {exe; evalue}

  let find config = Tiny_toml.Term.eval term ~config
end

module Mafft = struct
  let path s = ["mafft"; s]

  type t = {exe: string} [@@deriving sexp_of]

  let term =
    let open Tiny_toml.Term.Let_syntax in
    let%map exe = Executable.term ~default:"mafft" @@ path "exe" in
    {exe}

  let find config = Tiny_toml.Term.eval ~config term
end

module Mmseqs = struct
  let path s = ["mmseqs"; s]

  type t = {exe: string; evalue: float; num_iterations: int; sensitivity: float}
  [@@deriving sexp_of]

  let exe = Executable.term ~default:"mmseqs" @@ path "exe"

  let evalue = evalue_term ~default:1e-3 @@ path "evalue"

  let num_iterations =
    let open Tiny_toml in
    Value.find_or ~default:2 (path "num_iterations") @@ Converter.Int.positive

  let sensitivity =
    let parser n =
      if Float.(n >= 1.0 && n <= 7.5) then Or_error.return n
      else Or_error.errorf "expected 1.0 <= sensitivity <= 7.5, but got %f" n
    in
    let open Tiny_toml in
    Value.find_or ~default:5.7 (path "sensitivity")
    @@ Converter.v Accessor.float parser

  let term =
    let open Tiny_toml.Term.Let_syntax in
    let%map exe = exe
    and evalue = evalue
    and num_iterations = num_iterations
    and sensitivity = sensitivity in
    {exe; evalue; num_iterations; sensitivity}

  let find config = Tiny_toml.Term.eval term ~config
end

let find_inteins_file config =
  Tiny_toml.Term.eval ~config @@ Existing_file.term ["inteins"]

let find_queries_file config =
  Tiny_toml.Term.eval ~config @@ Existing_file.term ["queries"]

let find_smp_dir config =
  Tiny_toml.Term.eval ~config @@ Existing_file.term ["smp_dir"]

let find_out_dir config =
  let open Tiny_toml in
  Term.eval ~config
  @@ Non_existing_file.term ~default:"intein_finder_out" ["out_dir"]

module Log_level = struct
  let parse s =
    match String.lowercase s with
    | "error" ->
        Or_error.return "error"
    | "warning" ->
        Or_error.return "warning"
    | "info" ->
        Or_error.return "info"
    | "debug" ->
        Or_error.return "debug"
    | _ ->
        Or_error.errorf
          "Log level must be one of 'error', 'warning', 'info', or 'debug'. \
           Got '%s'"
          s

  (* Note: will alwas return Ok *)
  let find config =
    let open Tiny_toml in
    Term.eval ~config
    @@ Value.find_or ~default:"info" ["log_level"]
    @@ Converter.v Accessor.string parse
end

let find_clip_region_padding config =
  let open Tiny_toml in
  Term.eval ~config
  @@ Value.find_or
       ~default:10
       ["clip_region_padding"]
       Converter.Int.non_negative

let find_min_query_length config =
  let open Tiny_toml in
  Term.eval ~config
  @@ Value.find_or ~default:100 ["min_query_length"] Converter.Int.non_negative

let find_min_region_length config =
  let open Tiny_toml in
  Term.eval ~config
  @@ Value.find_or ~default:100 ["min_region_length"] Converter.Int.non_negative

let find_remove_aln_files config =
  let open Tiny_toml in
  Term.eval ~config
  @@ Value.find_or ~default:true ["remove_aln_files"] Converter.bool

let find_threads config =
  let open Tiny_toml in
  Term.eval ~config
  @@ Value.find_or ~default:1 ["threads"] Converter.Int.positive

type t =
  { (* Inputs *)
    inteins_file: string
  ; queries_file: string
  ; smp_dir: string
  ; out_dir: string
  ; checks: Checks.t
  ; mafft: Mafft.t
  ; makeprofiledb: Makeprofiledb.t
  ; mmseqs: Mmseqs.t
  ; rpsblast: Rpsblast.t
  ; log_level: string
  ; clip_region_padding: int
  ; min_query_length: int
  ; min_region_length: int
  ; remove_aln_files: bool
  ; threads: int }
[@@deriving sexp_of]

let find toml =
  let%map out_dir = find_out_dir toml
  and inteins_file = find_inteins_file toml
  and queries_file = find_queries_file toml
  and smp_dir = find_smp_dir toml
  and checks = Checks.find toml
  and mafft = Mafft.find toml
  and makeprofiledb = Makeprofiledb.find toml
  and mmseqs = Mmseqs.find toml
  and rpsblast = Rpsblast.find toml
  and log_level = Log_level.find toml
  and clip_region_padding = find_clip_region_padding toml
  and min_query_length = find_min_query_length toml
  and min_region_length = find_min_region_length toml
  and remove_aln_files = find_remove_aln_files toml
  and threads = find_threads toml in
  { inteins_file
  ; queries_file
  ; smp_dir
  ; checks
  ; out_dir
  ; mafft
  ; makeprofiledb
  ; mmseqs
  ; rpsblast
  ; log_level
  ; clip_region_padding
  ; min_query_length
  ; min_region_length
  ; remove_aln_files
  ; threads }

let read_config config_file =
  let toml = Otoml.Parser.from_file config_file in
  match find toml with
  | Ok config ->
      Ok config
  | Error e ->
      Logs.err (fun m ->
          m "could not generate config:\n%s" @@ Error.to_string_hum e ) ;
      Error 2

module Version = struct
  module Sh = Shexp_process

  let newline = Re.compile @@ Re.str "\n"

  let replace_newline s = Re.replace_string ~all:true newline ~by:". " s

  let intein_finder_version =
    (* git describe --always --dirty --abbrev=7 *)
    let base = "1.0.0-SNAPSHOT" in
    let git_hash =
      match%const [%getenv "INTEIN_FINDER_GIT_COMMIT_HASH"] with
      | "" ->
          ""
      | git_hash ->
          [%string " [%{git_hash}]"]
    in
    [%string "%{base}%{git_hash}"]

  let get_version exe arg =
    let sh = Sh.run exe [arg] |> Sh.capture_unit Sh.Std_io.[Stdout; Stderr] in
    let out = Sh.eval sh |> replace_newline in
    [%string "%{exe} version: %{out}"]

  let mafft t = get_version t.mafft.exe "--version"

  let mmseqs t = get_version t.mmseqs.exe "version"

  let rpsblast t = get_version t.rpsblast.exe "-version"

  let makeprofiledb t = get_version t.makeprofiledb.exe "-version"

  let program_version_info t =
    let if_version =
      [%string "InteinFinder version: %{intein_finder_version}."]
    in
    [if_version; mafft t; mmseqs t; rpsblast t; makeprofiledb t]
    |> String.concat ~sep:"\n"
end

(** [write_pipeline_info t dir] writes the versions of all used programs and the
    pipeline config opts as understood by the pipeline to
    [Out_file_name.pipeline_info dir]. *)
let write_pipeline_info t dir =
  let out_file = Out_file_name.pipeline_info dir in
  let versions = Version.program_version_info t in
  let config = Sexp.to_string_hum @@ sexp_of_t t in
  let working_dir = Sys_unix.getcwd () in
  Out_channel.write_all
    out_file
    ~data:
      [%string
        "Program Versions\n\
         ================\n\
         %{versions}\n\n\
         Working Directory\n\
         =================\n\
         %{working_dir}\n\n\
         Config\n\
         ======\n\
         %{config}\n"]

let write_config_file ~config_file ~dir =
  let out_file = Out_file_name.config_file dir in
  Sh.eval @@ Sh.run "cp" [config_file; out_file]

module X = struct
  let s = {|
[magic]
T1 = ["S", "T", "C"]
T2 = ["X"]
|}

  let f s = Otoml.Parser.from_string_result s

  let%expect_test _ =
    let toml = f s in
    ( match toml with
    | Error s ->
        print_endline s
    | Ok toml ->
        Otoml.list_table_keys toml |> [%sexp_of: string list] |> print_s ) ;
    [%expect {| (magic) |}]

  let%expect_test _ =
    let toml = f s in
    ( match toml with
    | Error s ->
        print_endline s
    | Ok toml ->
        let x = Otoml.find_exn toml Otoml.get_table ["magic"] in
        List.iter x ~f:(fun (k, v) ->
            print_endline [%string "%{k} => %{Otoml.Printer.to_string v}"] ) ) ;
    [%expect {|
      T1 => ["S", "T", "C"]
      T2 => ["X"] |}]
end
