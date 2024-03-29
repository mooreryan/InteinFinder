# Installing External Dependencies

InteinFinder relies on a few other software packages:

- [MAFFT](https://mafft.cbrc.jp/alignment/software/)
- [MMseqs2](https://github.com/soedinglab/MMseqs2)
- [NCBI BLAST+](https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.12.0/) (specifically, `rpsblast` and `makeprofiledb`)

For detailed instructions on installing these packages, please consult their respective installation pages.

The InteinFinder pipeline's [continuous integration testing](https://github.com/mooreryan/InteinFinder/actions) is done with the following versions:

- MAFFT: v7.490 (2021/Oct/30)
- MMseqs2: 45111b641859ed0ddd875b94d6fd1aef1a675b7e
- makeprofiledb: 2.12.0 (Package: blast 2.12.0)
- rpsblast+: 2.12.0+ (Package: blast 2.12.0)

In other words, InteinFinder is continuously tested with those software versions.

## Using other versions

Other versions will likely work too, but they may give slightly different output, causing the tests to fail if you run them locally.  (E.g., it's possible a different version of BLAST could give slightly different alignment of queries.)

Occasionally, the command line interface of the external dependencies will change (e.g., `mmseqs` has changed a bit in the past).  So, if you discover an error due to that, please [submit a bug report](https://github.com/mooreryan/InteinFinder/issues) (GitHub account required).

For reference, `InteinFinder` pipeline assumes that the command line interface of its external dependencies work something like this:

```
# MAFFT
$ mafft --quiet --auto --thread 1 input.faa

# MMseqs2
$ mmseqs easy-search QUERIES TARGETS OUT TMPDIR \
    --format-mode 2 -s X.X --num-iterations N -e X --threads N

# RPSBLAST
$ makeprofiledb -in DB_IN -out DB_OUT
$ rpsblast -query QUERY -db DB_OUT \
    -num_threads 1 -outfmt 6 -out OUT -evalue X.X
```

Again, occasionally a new release of one of those software dependencies could change the CLI.  If you run into issues related to this, let me know!

## Example installation instructions

Here are some basic instructions for installing the required software on the latest versions of macOS and Ubuntu Linux.

*Note: These instructions are taken from one of the [GitHub actions that builds and tests InteinFinder](https://github.com/mooreryan/InteinFinder/blob/master/.github/workflows/build_and_test.yml), so if it is [passing](https://github.com/mooreryan/InteinFinder/actions/workflows/build_and_test.yml) then these instructions should still work if you have a similar OS.*

*Note: I am not able to test these instructions on Apple Silicon!*

For these instructions, replace the `${LOCAL_PATH}` variable with whatever is appropriate for your environment.

### MAFFT

Here is an example of downloading the source code for MAFFT and compiling it.  MAFFT has pre-compiled binaries available on their site if you would rather use those.

```
$ \curl -L \
  https://mafft.cbrc.jp/alignment/software/mafft-7.490-without-extensions-src.tgz \
  | tar xz \
  && cd mafft-*/core/ && make clean && make && sudo make install
```

Note if you are using macOS, you may have to install developer tools for this to work.  [Here](https://apple.stackexchange.com/a/254381) is an example on Apple StackExchange that may help.

### MMseqs2

Here is how to download pre-compiled MMseqs2 binaries from GitHub.

#### On Ubuntu

```
$ \curl -L \
  https://github.com/soedinglab/MMseqs2/releases/download/13-45111/mmseqs-linux-sse2.tar.gz \
  | tar xz \
  && mv mmseqs/bin/mmseqs "$LOCAL_PATH"
```

#### On macOS

```
$ \curl -L \
  https://github.com/soedinglab/MMseqs2/releases/download/13-45111/mmseqs-osx-universal.tar.gz \
  | tar xz \
  && mv mmseqs/bin/mmseqs "$LOCAL_PATH"
```

### RPSBLAST

Note that in these examples, I'm only bothering to move the `rpsblast` and `makeprofiledb` binaries to a location that is on the path.  (Again, it's taken directly from the CI, which is why it is like this.)

#### On Ubuntu

```
$ \curl -L \
  https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.12.0/ncbi-blast-2.12.0+-x64-linux.tar.gz \
  | tar xz \
  && mv ncbi-blast-2.12.0+/bin/rpsblast "${LOCAL_PATH}/rpsblast+" \
  && mv ncbi-blast-2.12.0+/bin/makeprofiledb "${LOCAL_PATH}/makeprofiledb"
```

#### On macOS

```
$ \curl -L \
  https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.12.0/ncbi-blast-2.12.0+-x64-macosx.tar.gz \
  | tar xz \
  && mv ncbi-blast-2.12.0+/bin/rpsblast "${LOCAL_PATH}/rpsblast+" \
  && mv ncbi-blast-2.12.0+/bin/makeprofiledb "${LOCAL_PATH}/makeprofiledb"
```
