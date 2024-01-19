Bonafide inteins are removed from exteins.

  $ RemoveInteins intein_hit_checks.tsv queries.faa 2> err
  >a
  abccddeeefffgggghhhhiiiii
  >b
  abXccXXddXXeeeXXXfffggggXXXXhhhhiiiii
  $ ../../scripts/redact_log_timestamp err
  DEBUG [DATETIME] ((intein_hit_checks intein_hit_checks.tsv)(queries queries.faa))
  INFO [DATETIME] Reading intein hit checks
  Reading: 0.0M
  Reading: 0.0M

Hit checks should be the correct file

  $ RemoveInteins queries.faa intein_hit_checks.tsv 2> err
  [2]
  $ grep 'Uncaught exception' -A2 err
  Reading: 0.0M
    
    ("Intein hit checks had the wrong header. Did you provide 2_intein_hit_checks.tsv?"

Has a help screen

  $ RemoveInteins --help > /dev/null

Has a version

  $ RemoveInteins --version | ../../scripts/redact_git_hash /dev/stdin
  1.0.0-SNAPSHOT
