# Installing InteinFinder from source files

*Note: If you are not already an OCaml programmer, I recommend that you download one of the [precompiled binaries](./installing-precompiled-binaries.md) or use the [Docker image](./installing-with-docker.md) instead.  It is never fun to set up a development environment in a language you are not familiar with!*

If you want to compile InteinFinder from source, you need to have a working OCaml development setup.

Additionally, you will need to install [GNU Make](https://www.gnu.org/software/make/) and the [external dependencies](./installing-external-dependencies.md) that InteinFinder relies on.

## Set up OCaml development environment

Instructions to set up an OCaml development environment can be found [here](https://ocaml.org/learn/tutorials/up_and_running.html) or [here](https://dev.realworldocaml.org/install.html).

## Get the code

Use git to clone the git repository.

```
$ git clone https://github.com/mooreryan/intein_finder.git
```

or download a release from [here](https://github.com/mooreryan/intein_finder/releases).

## Install OCaml dependencies

```
cd intein_finder
opam install . --deps-only --with-doc --with-test
```

## Build, install, & run tests

```
$ opam exec -- make build_release && opam exec -- make install_release
```

If you want to run the tests, you can with

```
$ opam exec -- make install_release
```

Note that if you have different versions of the [external dependencies](TODO), then the tests may fail for trivial reasons (like alignments being slightly different between MAFFT versions).

## Sanity check

If all went well, this should give you the path to the `intein_finder` executable file.

```
$ which intein_finder
```
