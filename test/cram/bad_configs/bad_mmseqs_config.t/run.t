Bad mmseqs config

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ InteinFinder bad_mmseqs_config.toml 2> err
  [2]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: mmseqs -> exe"
    "expected 'mmseqs_S8i3cWd93aGj31V' to be executable, but it was not")
   ("config error: mmseqs -> evalue"
    "expected E-value >= 0.0, but got -32.800000")
   ("config error: mmseqs -> num_iterations" "num_iterations >= 1, but got 0")
   ("config error: mmseqs -> sensitivity"
    "expected 1.0 <= sensitivity <= 7.5, but got 0.500000"))
