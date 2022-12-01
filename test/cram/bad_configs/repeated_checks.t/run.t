Repeated checks

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder repeated_checks.toml 2> err
  [1]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: start_residue"
    "expected nothing shared between pass and maybe, but found (A) shared")
   ("config error: end_residues"
    "expected nothing shared between pass and maybe, but found (AA) shared")
   ("config error: end_plus_one_residue"
    "expected nothing shared between pass and maybe, but found (A B) shared"))
