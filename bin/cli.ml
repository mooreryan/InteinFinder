open! Core
open Cmdliner

let prog_name = "InteinFinder"

[@@@coverage off]

type opts = {config_file: string} [@@deriving sexp_of]

[@@@coverage on]

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
    ; `S Manpage.s_examples
    ; `P "=== CLI Usage"
    ; `Pre "  \\$ InteinFinder config.toml"
    ; `P "=== Example Config File"
    ; `P
        "The required options are 'queries', 'out_dir', 'inteins', and \
         'smp_dir'.  All other fields are optional.  If you leave an optional \
         field blank, its default value will be used."
    ; `P
        "Here is an example config file.  All optional values are shown with \
         their default values."
    ; `Pre
        {|```
# General I/O
queries = "path/to/queries.faa"
out_dir = "path/to/output_directory"

# InteinFinder DB location
inteins = "path/to/intein_db.faa"
smp_dir = "path/to/smp_directory"

# All options below this line are optional!

# General pipeline options
log_level = "info"
clip_region_padding = 10
min_query_length = 100
min_region_length = 100
remove_aln_files = true
threads = 1

[makeprofiledb]
exe = "makeprofiledb"

[mafft]
exe = mafft

[mmseqs]
exe = mmseqs
evalue = 1e-3
num_iterations = 2
sensitivity = 5.7

[rpsblast]
exe = "rpsblast+"
evalue = 1e-3

[start_residue]
# Tier 1
C = "T1"
S = "T1"
A = "T1"
Q = "T1"
P = "T1"
T = "T1"

# Tier 2
V = "T2"
G = "T2"
L = "T2"
M = "T2"
N = "T2"
F = "T2"

[end_residues]
# Tier 1
HN = "T1"
SN = "T1"
GN = "T1"
GQ = "T1"
LD = "T1"
FN = "T1"

# Tier 2
KN = "T2"
DY = "T2"
SQ = "T2"
HQ = "T2"
NS = "T2"
AN = "T2"
SD = "T2"
TH = "T2"
RD = "T2"
PY = "T2"
YN = "T2"
VH = "T2"
KQ = "T2"
PP = "T2"
NT = "T2"
CN = "T2"
LH = "T2"

[end_plus_one_residue]
S = "T1"
T = "T1"
C = "T1"
```|}
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
