open! Core
open Or_error.Let_syntax
module Sh = Shexp_process

(** Type of config option *)
module type OPT = sig
  type t [@@deriving sexp_of]

  val find : Otoml.t -> t Or_error.t
end

let existing s =
  if Sys_unix.file_exists_exn s then Or_error.return s
  else Or_error.errorf "expected file '%s' to exist, but it does not" s

let non_existing s =
  if Sys_unix.file_exists_exn s then
    Or_error.errorf "expected file '%s' not to exist, but it does" s
  else Or_error.return s

let get_exe_path exe =
  let exe_found, path =
    Sh.eval @@ Sh.capture [Sh.Std_io.Stdout] @@ Sh.run_bool "which" [exe]
  in
  if exe_found then Some (String.strip path) else None

let executable s =
  match get_exe_path s with
  | Some path ->
      Or_error.return path
  | None ->
      Or_error.errorf "expected '%s' to be executable, but it was not" s

(** Wrapper for [Or_error.tag] that makes more uniform error tags for config
    problems. *)
let config_error_tag oe ~toml_path =
  let msg = String.concat toml_path ~sep:" -> " in
  let tag = "config error: " ^ msg in
  Or_error.tag oe ~tag

let otoml_find_oe toml accessor path =
  Or_error.try_with (fun () -> Otoml.find_exn toml accessor path)

(* Find existing file, no default. *)
let find_existing_file toml ~toml_path =
  let%bind file_name = otoml_find_oe toml Otoml.get_string toml_path in
  existing file_name |> config_error_tag ~toml_path

let find_executable_file_with_default toml ~toml_path ~default =
  (* This is the toml config path. *)
  Otoml.find_or ~default toml Otoml.get_string toml_path
  |> executable
  |> config_error_tag ~toml_path

let find_int_with_default_and_parse toml ~toml_path ~default ~parse =
  Otoml.find_or ~default toml Otoml.get_integer toml_path
  |> parse
  |> config_error_tag ~toml_path

let disjoint s1 s2 ~sexp_of =
  let intersection = Set.inter s1 s2 in
  if Set.length intersection = 0 then Or_error.return (s1, s2)
  else
    Or_error.errorf
      "expected nothing shared between pass and maybe, but found %s shared"
    @@ Sexp.to_string_mach @@ sexp_of intersection

module type PATH = sig
  val path : string -> string list
end

module Make_evalue (M : PATH) = struct
  [@@@coverage off]

  type t = float [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = M.path "evalue"

  let default = 1e-3

  let parse n =
    if Float.(n >= 0.0) then Or_error.return n
    else Or_error.errorf "expected E-value >= 0.0, but got %f" n

  let find toml : t Or_error.t =
    Otoml.find_or ~default toml Otoml.get_float toml_path
    |> parse
    |> config_error_tag ~toml_path
end

module Single_residue_check = struct
  module type MAKE = sig
    val top : string

    val pass_default : string list

    val maybe_default : string list
  end

  let char_list_of_string_list l =
    List.map l ~f:(fun s ->
        Or_error.try_with (fun () -> Char.of_string s)
        |> Or_error.tag
             ~tag:
               [%string
                 "expected string to be a single character but got '%{s}'"] )
    |> Or_error.all

  let non_empty_char_list_of_string_list = function
    | [] ->
        Or_error.error_string "expected a non-empty list, but got an empty list"
    | residues ->
        char_list_of_string_list residues

  let%expect_test "non_empty_char_list_of_string_list" =
    (* Works *)
    let toml = Otoml.Parser.from_string {|apple = ["a", "b"]|} in
    Otoml.find toml (Otoml.get_array Otoml.get_string) ["apple"]
    |> non_empty_char_list_of_string_list |> [%sexp_of: char list Or_error.t]
    |> print_s ;
    [%expect {| (Ok (a b)) |}] ;
    (* Fails *)
    let toml = Otoml.Parser.from_string {|apple = ["yeah", "b", "Okay"]|} in
    Otoml.find toml (Otoml.get_array Otoml.get_string) ["apple"]
    |> non_empty_char_list_of_string_list |> [%sexp_of: char list Or_error.t]
    |> print_s ;
    [%expect
      {|
    (Error
     (("expected string to be a single character but got 'yeah'"
       (Failure "Char.of_string: \"yeah\""))
      ("expected string to be a single character but got 'Okay'"
       (Failure "Char.of_string: \"Okay\"")))) |}]

  let find' toml ~default ~toml_path ~parse =
    Otoml.find_or ~default toml (Otoml.get_array Otoml.get_string) toml_path
    |> parse
    |> Or_error.map ~f:(List.map ~f:Char.uppercase)
    |> Or_error.map ~f:Char.Set.of_list
    |> config_error_tag ~toml_path

  module Make (M : MAKE) = struct
    let path s = [M.top; s]

    module Pass : OPT with type t = Char.Set.t = struct
      [@@@coverage off]

      type t = Char.Set.t [@@deriving sexp_of]

      [@@@coverage on]

      let toml_path = path "pass"

      let default = M.pass_default

      let find toml =
        find' toml ~default ~toml_path ~parse:non_empty_char_list_of_string_list
    end

    module Maybe : OPT with type t = Char.Set.t = struct
      [@@@coverage off]

      type t = Char.Set.t [@@deriving sexp_of]

      [@@@coverage on]

      let toml_path = path "maybe"

      let default = M.maybe_default

      let find toml =
        find' toml ~default ~toml_path ~parse:char_list_of_string_list
    end

    type t = {pass: Pass.t; maybe: Maybe.t} [@@deriving sexp_of]

    let find toml =
      let result =
        let%bind pass = Pass.find toml and maybe = Maybe.find toml in
        let%map pass, maybe = disjoint pass maybe ~sexp_of:Char.Set.sexp_of_t in
        {pass; maybe}
      in
      config_error_tag result ~toml_path:[M.top]
  end
end

module Checks = struct
  module Start_residue = Single_residue_check.Make (struct
    let top = "start_residue"

    let pass_default = ["C"; "S"; "A"; "Q"; "P"; "T"]

    let maybe_default = ["V"; "G"; "L"; "M"; "N"; "F"]
  end)

  module End_plus_one_residue = Single_residue_check.Make (struct
    let top = "end_plus_one_residue"

    let pass_default = ["S"; "T"; "C"]

    let maybe_default = []
  end)

  module End_residues = struct
    let end_residues_list l =
      List.map l ~f:(fun s ->
          if String.length s = 2 then Or_error.return s
          else Or_error.errorf "expected two end residues but got '%s'" s )
      |> Or_error.all

    let non_empty_end_residues_list = function
      | [] ->
          Or_error.error_string
            "expected a non-empty list, but got an empty list"
      | l ->
          end_residues_list l

    let find' toml ~default ~toml_path ~parse =
      Otoml.find_or ~default toml (Otoml.get_array Otoml.get_string) toml_path
      |> parse
      |> Or_error.map ~f:(List.map ~f:String.uppercase)
      |> Or_error.map ~f:String.Set.of_list
      |> config_error_tag ~toml_path

    let path s = ["end_residues"; s]

    module Pass : OPT with type t = String.Set.t = struct
      [@@@coverage off]

      type t = String.Set.t [@@deriving sexp_of]

      [@@@coverage on]

      let toml_path = path "pass"

      let default = ["HN"; "SN"; "GN"; "GQ"; "LD"; "FN"]

      let find toml =
        find' toml ~default ~toml_path ~parse:non_empty_end_residues_list
    end

    module Maybe : OPT with type t = String.Set.t = struct
      [@@@coverage off]

      type t = String.Set.t [@@deriving sexp_of]

      [@@@coverage on]

      let toml_path = path "maybe"

      let default =
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

      let find toml = find' toml ~default ~toml_path ~parse:end_residues_list
    end

    type t = {pass: Pass.t; maybe: Maybe.t} [@@deriving sexp_of]

    let find toml =
      let result =
        let%bind pass = Pass.find toml and maybe = Maybe.find toml in
        let%map pass, maybe =
          disjoint pass maybe ~sexp_of:String.Set.sexp_of_t
        in
        {pass; maybe}
      in
      config_error_tag result ~toml_path:["end_residues"]
  end

  type t =
    { start_residue: Start_residue.t
    ; end_residues: End_residues.t
    ; end_plus_one_residue: End_plus_one_residue.t }
  [@@deriving sexp_of]

  let find toml =
    let%map start_residue = Start_residue.find toml
    and end_residues = End_residues.find toml
    and end_plus_one_residue = End_plus_one_residue.find toml in
    {start_residue; end_residues; end_plus_one_residue}
end

module Makeprofiledb = struct
  let path s = ["makeprofiledb"; s]

  module Exe = struct
    [@@@coverage off]

    type t = string [@@deriving sexp_of]

    [@@@coverage on]

    let toml_path = path "exe"

    let default = "makeprofiledb"

    let find toml = find_executable_file_with_default toml ~toml_path ~default
  end

  type t = {exe: Exe.t} [@@deriving sexp_of]

  let find toml =
    let%map exe = Exe.find toml in
    {exe}
end

module Rpsblast = struct
  let path s = ["rpsblast"; s]

  module Exe = struct
    [@@@coverage off]

    type t = string [@@deriving sexp_of]

    [@@@coverage on]

    let toml_path = path "exe"

    let default = "rpsblast+"

    let find toml = find_executable_file_with_default toml ~toml_path ~default
  end

  module Evalue = Make_evalue (struct
    let path = path
  end)

  module Num_splits = struct
    [@@@coverage off]

    type t = int [@@deriving sexp_of]

    [@@@coverage on]

    let toml_path = path "num_splits"

    let default = 1

    let parse n =
      if n >= 1 then Or_error.return n
      else Or_error.errorf "expected num_split >= 1, but got %d" n

    let find toml =
      find_int_with_default_and_parse toml ~toml_path ~default ~parse
  end

  type t = {exe: Exe.t; evalue: Evalue.t; num_splits: Num_splits.t}
  [@@deriving sexp_of]

  let find toml =
    let%map exe = Exe.find toml
    and evalue = Evalue.find toml
    and num_splits = Num_splits.find toml in
    {exe; evalue; num_splits}
end

module Mafft = struct
  let path s = ["mafft"; s]

  module Exe = struct
    [@@@coverage off]

    type t = string [@@deriving sexp_of]

    [@@@coverage on]

    let toml_path = path "exe"

    let default = "mafft"

    let find toml = find_executable_file_with_default toml ~toml_path ~default
  end

  module Max_concurrent_jobs = struct
    [@@@coverage off]

    type t = int [@@deriving sexp_of]

    [@@@coverage on]

    let toml_path = path "max_concurrent_jobs"

    let default = 1

    let parse n =
      if n >= 1 then Or_error.return n
      else Or_error.errorf "expected threads >= 1, but got %d" n

    let find toml =
      find_int_with_default_and_parse toml ~toml_path ~default ~parse
  end

  type t = {exe: Exe.t; max_concurrent_jobs: Max_concurrent_jobs.t}
  [@@deriving sexp_of]

  let find toml =
    let%map exe = Exe.find toml
    and max_concurrent_jobs = Max_concurrent_jobs.find toml in
    {exe; max_concurrent_jobs}
end

module Mmseqs = struct
  let path s = ["mmseqs"; s]

  module Exe = struct
    [@@@coverage off]

    type t = string [@@deriving sexp_of]

    [@@@coverage on]

    let toml_path = path "exe"

    let default = "mmseqs"

    let find toml = find_executable_file_with_default toml ~toml_path ~default
  end

  module Evalue = Make_evalue (struct
    let path = path
  end)

  module Num_iterations = struct
    [@@@coverage off]

    type t = int [@@deriving sexp_of]

    [@@@coverage on]

    let toml_path = path "num_iterations"

    let default = 2

    let parse n =
      if n >= 1 then Or_error.return n
      else Or_error.errorf "num_iterations >= 1, but got %d" n

    let find toml =
      find_int_with_default_and_parse toml ~toml_path ~default ~parse
  end

  module Sensitivity = struct
    [@@@coverage off]

    type t = float [@@deriving sexp_of]

    [@@@coverage on]

    let toml_path = path "sensitivity"

    let default = 5.7

    let parse n =
      if Float.(n >= 1.0 && n <= 7.5) then Or_error.return n
      else Or_error.errorf "expected 1.0 <= sensitivity <= 7.5, but got %f" n

    let find toml : t Or_error.t =
      Otoml.find_or ~default toml Otoml.get_float toml_path
      |> parse
      |> config_error_tag ~toml_path
  end

  module Threads = struct
    [@@@coverage off]

    type t = int [@@deriving sexp_of]

    [@@@coverage on]

    let toml_path = path "threads"

    let default = 1

    let parse n =
      if n >= 1 then Or_error.return n
      else Or_error.errorf "expected threads >= 1, but got %d" n

    let find toml =
      find_int_with_default_and_parse toml ~toml_path ~default ~parse
  end

  type t =
    { exe: Exe.t
    ; evalue: Evalue.t
    ; num_iterations: Num_iterations.t
    ; sensitivity: Sensitivity.t
    ; threads: Threads.t }
  [@@deriving sexp_of]

  let find toml =
    let%map exe = Exe.find toml
    and evalue = Evalue.find toml
    and num_iterations = Num_iterations.find toml
    and sensitivity = Sensitivity.find toml
    and threads = Threads.find toml in
    {exe; evalue; num_iterations; sensitivity; threads}
end

module Inteins_file = struct
  [@@@coverage off]

  type t = string [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = ["inteins"]

  let find toml = find_existing_file toml ~toml_path
end

module Queries_file = struct
  [@@@coverage off]

  type t = string [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = ["queries"]

  let find toml = find_existing_file toml ~toml_path
end

module Smp_dir = struct
  [@@@coverage off]

  type t = string [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = ["smp_dir"]

  let find toml : t Or_error.t = find_existing_file toml ~toml_path
end

module Out_dir = struct
  [@@@coverage off]

  type t = string [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = ["out_dir"]

  let default = "intein_finder_out"

  let find toml =
    Otoml.find_or ~default toml Otoml.get_string toml_path
    |> non_existing
    |> config_error_tag ~toml_path
end

module Log_level = struct
  (* NOTE: ideally take the log level variant...but would need sexp for it. *)

  [@@@coverage off]

  type t = string [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = ["log_level"]

  let default = "info"

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
  let find toml =
    Otoml.find_or ~default toml Otoml.get_string toml_path |> parse
end

module Clip_region_padding = struct
  [@@@coverage off]

  type t = int [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = ["clip_region_padding"]

  let default = 10

  let parse n =
    if n >= 0 then Or_error.return n
    else Or_error.errorf "expected clip_region_padding >= 0, but got %d" n

  let find toml =
    find_int_with_default_and_parse toml ~toml_path ~default ~parse
end

module Min_query_length = struct
  [@@@coverage off]

  type t = int [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = ["min_query_length"]

  let default = 100

  let parse n =
    if n >= 0 then Or_error.return n
    else Or_error.errorf "expected min_query_length >= 0, but got %d" n

  let find toml =
    find_int_with_default_and_parse toml ~toml_path ~default ~parse
end

module Min_region_length = struct
  [@@@coverage off]

  type t = int [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = ["min_region_length"]

  let default = 100

  let parse n =
    if n >= 0 then Or_error.return n
    else Or_error.errorf "expected min_region_length >= 0, but got %d" n

  let find toml =
    find_int_with_default_and_parse toml ~toml_path ~default ~parse
end

module Remove_aln_files = struct
  [@@@coverage off]

  type t = bool [@@deriving sexp_of]

  [@@@coverage on]

  let toml_path = ["remove_aln_files"]

  let default = true

  let find toml =
    Otoml.find_or ~default toml Otoml.get_boolean toml_path |> Or_error.return
end

type t =
  { (* Inputs *)
    inteins_file: Inteins_file.t
  ; queries_file: Queries_file.t
  ; smp_dir: Smp_dir.t
  ; out_dir: Out_dir.t
  ; checks: Checks.t
  ; mafft: Mafft.t
  ; makeprofiledb: Makeprofiledb.t
  ; mmseqs: Mmseqs.t
  ; rpsblast: Rpsblast.t
  ; log_level: Log_level.t
  ; clip_region_padding: Clip_region_padding.t
  ; min_query_length: Min_query_length.t
  ; min_region_length: Min_region_length.t
  ; remove_aln_files: Remove_aln_files.t }
[@@deriving sexp_of]

let find toml =
  let%map out_dir = Out_dir.find toml
  and inteins_file = Inteins_file.find toml
  and queries_file = Queries_file.find toml
  and smp_dir = Smp_dir.find toml
  and checks = Checks.find toml
  and mafft = Mafft.find toml
  and makeprofiledb = Makeprofiledb.find toml
  and mmseqs = Mmseqs.find toml
  and rpsblast = Rpsblast.find toml
  and log_level = Log_level.find toml
  and clip_region_padding = Clip_region_padding.find toml
  and min_query_length = Min_query_length.find toml
  and min_region_length = Min_region_length.find toml
  and remove_aln_files = Remove_aln_files.find toml in
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
  ; remove_aln_files }

let parse_argv () =
  let config_file = Caml.Sys.argv.(1) in
  let toml = Otoml.Parser.from_file config_file in
  match find toml with
  | Ok config ->
      `Run (config, config_file)
  | Error e ->
      Logs.err (fun m ->
          m "could not generate config: %s" @@ Error.to_string_mach e ) ;
      `Exit 1

module Version = struct
  module Sh = Shexp_process

  let newline = Re.compile @@ Re.str "\n"

  let replace_newline s = Re.replace_string ~all:true newline ~by:". " s

  let intein_finder_version =
    (* git describe --always --dirty --abbrev=7 *)
    let base = "1.0.0-SNAPSHOT" in
    match%const [%getenv "INTEIN_FINDER_GIT_COMMIT_HASH"] with
    | "" ->
        base
    | git_hash ->
        [%string "%{base} (%{git_hash})"]

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
    [dir/1_pipeline_info.txt]. *)
let write_pipeline_info t dir =
  let out_file = dir ^/ "1_pipeline_info.txt" in
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
  let out_file = dir ^/ "0_config.toml" in
  Sh.eval @@ Sh.run "cp" [config_file; out_file]
