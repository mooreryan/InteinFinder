(lang dune 3.5)

(generate_opam_files true)

(name intein_finder)

(version 1.0.0-SNAPSHOT)

(maintainers "Ryan M. Moore")

(authors "Ryan M. Moore")

(homepage "https://github.com/mooreryan/InteinFinder")

(source
 (github mooreryan/InteinFinder))

(documentation "https://mooreryan.github.io/InteinFinder/")

(bug_reports "https://github.com/mooreryan/InteinFinder/issues")

(package
 (name intein_finder)
 (synopsis "TODO")
 (depends
  (ocaml
   (= "4.14.0"))
  (async
   (and
    (>= "v0.15.0")
    (< "v0.16.0")))
  (async_unix
   (and
    (>= "v0.15.0")
    (< "v0.16.0")))
  (bio_io
   (and
    (>= "0.6.0")
    (< "0.7.0")))
  (core
   (and
    (>= "v0.15.0")
    (< "v0.16.0")))
  (core_unix
   (and
    (>= "v0.15.0")
    (< "v0.16.0")))
  (expect_test_helpers_core
   (and
    :with-test
    (>= "v0.15.0")
    (< "v0.16.0")))
  (logs
   (and
    (>= "0.7.0")
    (< "0.8.0")))
  (fmt
   (and
    (>= "0.9.0")
    (< "0.10.0")))
  (ocamlformat
   (= "0.24.1"))
  (otoml
   (and
    (>= "1.0.0")
    (< "1.1.0")))
  (ppx_const
   (and
    (>= "2.0")
    (< "2.1")))
  (ppx_getenv
   (and
    (>= "2.1")
    (< "2.2")))
  (ppx_jane
   (and
    (>= "v0.15.0")
    (< "v0.16.0")))
  (re
   (and
    (>= "1.10")
    (< "1.11")))
  (sexp
   (and
    :with-test
    (>= "v0.15.0")
    (< "v0.16.0")))
  (shexp
   (and
    (>= "v0.15.0")
    (< "v0.16.0")))))