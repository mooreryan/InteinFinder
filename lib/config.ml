open! Core
open Or_error.Let_syntax
module Sh = Shexp_process

(** Type of config option *)
module type OPT = sig
  type t [@@deriving sexp_of]

  val find : Otoml.t -> t Or_error.t
end

let otoml_get_string_list = Otoml.get_array Otoml.get_string

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

let existing_file_term ~toml_path =
  let open Tiny_toml in
  Value.find toml_path @@ Converter.v Accessor.string existing

let executable_term ~default toml_path =
  let open Tiny_toml in
  Value.find_or ~default toml_path @@ Converter.v Accessor.string executable

let disjoint s1 s2 ~sexp_of =
  let intersection = Set.inter s1 s2 in
  if Set.length intersection = 0 then Or_error.return (s1, s2)
  else
    Or_error.errorf
      "expected nothing shared between pass and maybe, but found %s shared"
    @@ Sexp.to_string_mach
    @@ sexp_of intersection

module type PATH = sig
  val path : string -> string list
end

module Make_evalue (M : PATH) = struct
  [@@@coverage off]

  type t = float [@@deriving sexp_of]

  [@@@coverage on]

  let term =
    let open Tiny_toml in
    Value.find_or ~default:1e-3 (M.path "evalue") Converter.Float.non_negative

  let find toml : t Or_error.t = Tiny_toml.Term.eval term ~config:toml
end

(* module Start_residue' = struct *)
(*   type t = Tier.Map.t [@@deriving sexp_of] *)

(*   let default = *)
(*     let make_default tier residues = *)
(*       let tier = Otoml.string @@ Tier.to_string tier in *)
(*       List.map residues ~f:(fun r -> (r, tier)) *)
(*     in *)
(*     let t1_default = make_default Tier.t1 ["C"; "S"; "A"; "Q"; "P"; "T"] in *)
(*     let t2_default = make_default Tier.t2 ["V"; "G"; "L"; "M"; "N"; "F"] in *)
(*     t1_default @ t2_default *)

(* let toml_path = ["start_residue"] *)

(*   let find : Otoml.t -> t Or_error.t = *)
(*    fun toml -> *)
(*     Tier.Map.of_toml toml ~path:toml_path ~default *)
(*     |> config_error_tag ~toml_path *)
(* end *)

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
    |> non_empty_char_list_of_string_list
    |> [%sexp_of: char list Or_error.t]
    |> print_s ;
    [%expect {| (Ok (a b)) |}] ;
    (* Fails *)
    let toml = Otoml.Parser.from_string {|apple = ["yeah", "b", "Okay"]|} in
    Otoml.find toml (Otoml.get_array Otoml.get_string) ["apple"]
    |> non_empty_char_list_of_string_list
    |> [%sexp_of: char list Or_error.t]
    |> print_s ;
    [%expect
      {|
    (Error
     (("expected string to be a single character but got 'yeah'"
       (Failure "Char.of_string: \"yeah\""))
      ("expected string to be a single character but got 'Okay'"
       (Failure "Char.of_string: \"Okay\"")))) |}]

  let find' toml ~default ~toml_path ~parse =
    Otoml.find_or ~default toml otoml_get_string_list toml_path
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

      let parser result =
        result
        |> non_empty_char_list_of_string_list
        |> Or_error.map ~f:(List.map ~f:Char.uppercase)
        |> Or_error.map ~f:Char.Set.of_list

      let converter = Tiny_toml.Converter.v otoml_get_string_list parser

      let term = Tiny_toml.Value.find_or ~default toml_path converter

      let find config = Tiny_toml.Term.eval term ~config
    end

    module Maybe : OPT with type t = Char.Set.t = struct
      [@@@coverage off]

      type t = Char.Set.t [@@deriving sexp_of]

      [@@@coverage on]

      let toml_path = path "maybe"

      let default = M.maybe_default

      let parser result =
        result
        |> char_list_of_string_list
        |> Or_error.map ~f:(List.map ~f:Char.uppercase)
        |> Or_error.map ~f:Char.Set.of_list

      let converter = Tiny_toml.Converter.v otoml_get_string_list parser

      let term = Tiny_toml.Value.find_or ~default toml_path converter

      let find config = Tiny_toml.Term.eval term ~config
    end

    type t' = {pass: Pass.t; maybe: Maybe.t} [@@deriving sexp_of]

    type t = Tier.Map.t [@@deriving sexp_of]

    let find toml : t Or_error.t =
      let result =
        let%bind pass = Pass.find toml and maybe = Maybe.find toml in
        let%map pass, maybe = disjoint pass maybe ~sexp_of:Char.Set.sexp_of_t in
        Tier.Map.of_passes_maybies_c {passes= pass; maybies= maybe}
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
  (* Uncomment this when you're ready to switch to tiers. *)
  (* module Start_residue = Start_residue' *)

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

    let parser f result =
      result
      |> f
      |> Or_error.map ~f:(List.map ~f:String.uppercase)
      |> Or_error.map ~f:String.Set.of_list

    let path s = ["end_residues"; s]

    module Pass : OPT with type t = String.Set.t = struct
      [@@@coverage off]

      type t = String.Set.t [@@deriving sexp_of]

      [@@@coverage on]

      let toml_path = path "pass"

      let default = ["HN"; "SN"; "GN"; "GQ"; "LD"; "FN"]

      let term =
        let open Tiny_toml in
        Value.find_or ~default toml_path
        @@ Converter.v otoml_get_string_list
        @@ parser non_empty_end_residues_list

      let find config = Tiny_toml.Term.eval term ~config
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

      let term =
        let open Tiny_toml in
        Value.find_or ~default toml_path
        @@ Converter.v otoml_get_string_list
        @@ parser end_residues_list

      let find config = Tiny_toml.Term.eval term ~config
    end

    type t' = {pass: Pass.t; maybe: Maybe.t} [@@deriving sexp_of]

    type t = Tier.Map.t [@@deriving sexp_of]

    let find toml : t Or_error.t =
      let result =
        let%bind pass = Pass.find toml and maybe = Maybe.find toml in
        let%map pass, maybe =
          disjoint pass maybe ~sexp_of:String.Set.sexp_of_t
        in
        Tier.Map.of_passes_maybies_s {passes= pass; maybies= maybe}
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

    let find config =
      Tiny_toml.Term.eval ~config
      @@ executable_term ~default:"makeprofiledb"
      @@ path "exe"
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

    let find config =
      Tiny_toml.Term.eval ~config
      @@ executable_term ~default:"rpsblast+"
      @@ path "exe"
  end

  module Evalue = Make_evalue (struct
    let path = path
  end)

  type t = {exe: Exe.t; evalue: Evalue.t} [@@deriving sexp_of]

  let find toml =
    let%map exe = Exe.find toml and evalue = Evalue.find toml in
    {exe; evalue}
end

module Mafft = struct
  let path s = ["mafft"; s]

  module Exe = struct
    [@@@coverage off]

    type t = string [@@deriving sexp_of]

    [@@@coverage on]

    let find config =
      Tiny_toml.Term.eval ~config
      @@ executable_term ~default:"mafft"
      @@ path "exe"
  end

  type t = {exe: Exe.t} [@@deriving sexp_of]

  let find toml =
    let%map exe = Exe.find toml in
    {exe}
end

module Mmseqs = struct
  let path s = ["mmseqs"; s]

  module Exe = struct
    [@@@coverage off]

    type t = string [@@deriving sexp_of]

    [@@@coverage on]

    let find config =
      Tiny_toml.Term.eval ~config
      @@ executable_term ~default:"mmseqs"
      @@ path "exe"
  end

  module Evalue = Make_evalue (struct
    let path = path
  end)

  module Num_iterations = struct
    [@@@coverage off]

    type t = int [@@deriving sexp_of]

    [@@@coverage on]

    let find config =
      let open Tiny_toml in
      Term.eval ~config
      @@ Value.find_or ~default:2 (path "num_iterations")
      @@ Converter.Int.positive
  end

  module Sensitivity = struct
    [@@@coverage off]

    type t = float [@@deriving sexp_of]

    [@@@coverage on]

    let parser n =
      if Float.(n >= 1.0 && n <= 7.5) then Or_error.return n
      else Or_error.errorf "expected 1.0 <= sensitivity <= 7.5, but got %f" n

    let find config =
      let open Tiny_toml in
      Term.eval ~config
      @@ Value.find_or ~default:5.7 (path "sensitivity")
      @@ Converter.v Accessor.float parser
  end

  type t =
    { exe: Exe.t
    ; evalue: Evalue.t
    ; num_iterations: Num_iterations.t
    ; sensitivity: Sensitivity.t }
  [@@deriving sexp_of]

  let find toml =
    let%map exe = Exe.find toml
    and evalue = Evalue.find toml
    and num_iterations = Num_iterations.find toml
    and sensitivity = Sensitivity.find toml in
    {exe; evalue; num_iterations; sensitivity}
end

let find_inteins_file config =
  Tiny_toml.Term.eval ~config @@ existing_file_term ~toml_path:["inteins"]

let find_queries_file config =
  Tiny_toml.Term.eval ~config @@ existing_file_term ~toml_path:["queries"]

let find_smp_dir config =
  Tiny_toml.Term.eval ~config @@ existing_file_term ~toml_path:["smp_dir"]

let find_out_dir config =
  let open Tiny_toml in
  Term.eval ~config
  @@ Value.find_or ~default:"intein_finder_out" ["out_dir"]
  @@ Converter.v Accessor.string non_existing

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
