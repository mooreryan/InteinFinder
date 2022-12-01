Bad mmseqs config

  $ if [ -d if_out ]; then rm -r if_out; fi
  $ intein_finder bad_mmseqs_config.toml 2> err
  [1]
  $ ../../scripts/redact_log_timestamp err | sexp print
  ERROR
  [DATETIME]
  could
  not
  generate
  config:
  (("config error: mmseqs -> exe"
    "expected 'what' to be executable, but it was not")
   ("config error: mmseqs -> evalue"
    "expected E-value >= 0.0, but got -32.800000")
   ("config error: mmseqs -> num_iterations" "num_iterations >= 1, but got 0")
   ("config error: mmseqs -> sensitivity"
    "expected 1.0 <= sensitivity <= 7.5, but got 0.500000")
   ("config error: mmseqs -> threads" "expected threads >= 1, but got 0"))
