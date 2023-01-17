open! Core
module Sh = Shexp_process

let non_existing_file_term ~default path =
  let parser s =
    if Sys_unix.file_exists_exn s then
      Or_error.errorf "expected file '%s' not to exist, but it does" s
    else Or_error.return s
  in
  let converter = Tiny_toml.(Converter.v Accessor.string parser) in
  Tiny_toml.Value.find_or ~default path converter

let existing_file_term path =
  let parser s =
    if Sys_unix.file_exists_exn s then Or_error.return s
    else Or_error.errorf "expected file '%s' to exist, but it does not" s
  in
  let converter = Tiny_toml.(Converter.v Accessor.string parser) in
  Tiny_toml.Value.find path converter

let executable_term ~default toml_path =
  let get_exe_path exe =
    let exe_found, path =
      Sh.eval @@ Sh.capture [Sh.Std_io.Stdout] @@ Sh.run_bool "which" [exe]
    in
    if exe_found then Some (String.strip path) else None
  in
  let parser s =
    match get_exe_path s with
    | Some path ->
        Or_error.return path
    | None ->
        Or_error.errorf "expected '%s' to be executable, but it was not" s
  in
  let converter = Tiny_toml.(Converter.v Accessor.string parser) in
  Tiny_toml.Value.find_or ~default toml_path converter

module Checks = struct
  let start_residue_term =
    let default =
      let make_default tier residues =
        let tier = Tier.to_string tier in
        List.map residues ~f:(fun r -> (r, tier))
      in
      let t1_default = make_default Tier.t1 ["C"; "S"; "A"; "Q"; "P"; "T"] in
      let t2_default = make_default Tier.t2 ["V"; "G"; "L"; "M"; "N"; "F"] in
      t1_default @ t2_default
    in
    Tier.Map.tiny_toml_single_residue_term ~default ["start_residue"]

  let end_plus_one_residue_term =
    let default =
      let make_default tier residues =
        let tier = Tier.to_string tier in
        List.map residues ~f:(fun r -> (r, tier))
      in
      make_default Tier.t1 ["S"; "T"; "C"]
    in
    Tier.Map.tiny_toml_single_residue_term ~default ["end_plus_one_residue"]

  let end_residues_term =
    let default =
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
    in
    Tier.Map.tiny_toml_end_residues_term ~default ["end_residues"]

  type t =
    { start_residue: Tier.Map.t
    ; end_residues: Tier.Map.t
    ; end_plus_one_residue: Tier.Map.t }
  [@@deriving sexp_of]

  let term =
    let open Tiny_toml.Term.Let_syntax in
    let%map start_residue = start_residue_term
    and end_residues = end_residues_term
    and end_plus_one_residue = end_plus_one_residue_term in
    {start_residue; end_residues; end_plus_one_residue}
end

module Makeprofiledb = struct
  let path s = ["makeprofiledb"; s]

  type t = {exe: string} [@@deriving sexp_of]

  let exe = executable_term ~default:"makeprofiledb" @@ path "exe"

  let term =
    let open Tiny_toml.Term.Let_syntax in
    let%map exe = exe in
    {exe}
end

module Rpsblast = struct
  let path s = ["rpsblast"; s]

  type t = {exe: string; evalue: float} [@@deriving sexp_of]

  let exe = executable_term ~default:"rpsblast+" @@ path "exe"

  let evalue =
    let open Tiny_toml in
    Value.find_or ~default:1e-3 (path "evalue") Converter.Float.non_negative

  let term =
    let open Tiny_toml.Term.Let_syntax in
    let%map exe = exe and evalue = evalue in
    {exe; evalue}
end

module Mafft = struct
  let path s = ["mafft"; s]

  type t = {exe: string} [@@deriving sexp_of]

  let term =
    let open Tiny_toml.Term.Let_syntax in
    let%map exe = executable_term ~default:"mafft" @@ path "exe" in
    {exe}
end

module Mmseqs = struct
  let path s = ["mmseqs"; s]

  type t = {exe: string; evalue: float; num_iterations: int; sensitivity: float}
  [@@deriving sexp_of]

  let exe = executable_term ~default:"mmseqs" @@ path "exe"

  let evalue =
    let open Tiny_toml in
    Value.find_or ~default:1e-3 (path "evalue") Converter.Float.non_negative

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
end

let inteins_file_term = existing_file_term ["inteins"]

let queries_file_term = existing_file_term ["queries"]

let smp_dir_term = existing_file_term ["smp_dir"]

let out_dir_term =
  non_existing_file_term ~default:"intein_finder_out" ["out_dir"]

let log_level_parse s =
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
        "Log level must be one of 'error', 'warning', 'info', or 'debug'. Got \
         '%s'"
        s

let log_level_term =
  let open Tiny_toml in
  Value.find_or ~default:"info" ["log_level"]
  @@ Converter.v Accessor.string log_level_parse

let clip_region_padding_term =
  let open Tiny_toml in
  Value.find_or ~default:10 ["clip_region_padding"] Converter.Int.non_negative

let min_query_length_term =
  let open Tiny_toml in
  Value.find_or ~default:100 ["min_query_length"] Converter.Int.non_negative

let min_region_length_term =
  let open Tiny_toml in
  Value.find_or ~default:100 ["min_region_length"] Converter.Int.non_negative

let remove_aln_files_term =
  let open Tiny_toml in
  Value.find_or ~default:true ["remove_aln_files"] Converter.bool

let threads_term =
  let open Tiny_toml in
  Value.find_or ~default:1 ["threads"] Converter.Int.positive

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

let term =
  let open Tiny_toml.Term.Let_syntax in
  let%map out_dir = out_dir_term
  and inteins_file = inteins_file_term
  and queries_file = queries_file_term
  and smp_dir = smp_dir_term
  and checks = Checks.term
  and mafft = Mafft.term
  and makeprofiledb = Makeprofiledb.term
  and mmseqs = Mmseqs.term
  and rpsblast = Rpsblast.term
  and log_level = log_level_term
  and clip_region_padding = clip_region_padding_term
  and min_query_length = min_query_length_term
  and min_region_length = min_region_length_term
  and remove_aln_files = remove_aln_files_term
  and threads = threads_term in
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

let find config = Tiny_toml.Term.eval term ~config

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
