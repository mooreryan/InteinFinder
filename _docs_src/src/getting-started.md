# Getting Started

## Install InteinFinder

The quick start guide assumes you already have InteinFinder installed.  See [installing external dependencies](installing-external-dependencies.md), and [installing precompiled binaries](installing-precompiled-binaries.md) for some quick info about installation.

## Get needed assets

You need a file of inteins and a file of conserved domain models.

InteinFinder comes with these for your convenience.  But expert users may have their own set to use instead.

Here are links to find them on GitHub

- [intein sequences](https://github.com/mooreryan/InteinFinder/tree/main/_assets/intein_sequences)
  - directory containing intein sequence DB
  - In the manuscript, this is referred to as the ISDB (intein sequence database)
- [conserved domain models](https://github.com/mooreryan/InteinFinder/tree/main/_assets/smp)
  - directory containing conserved domain models
  - In the manuscript, this is referred to as the CDMDB (conserved domain model data base)
- [asset bundle](https://github.com/mooreryan/InteinFinder/tree/main/_assets/asset_bundle.tar.gz)
  - Use this link for an archive containing both the intein sequence DB and the conserved domain model DB.
  - It's the same data, but in a form convenient for direct download.

Here is an example for downloading the assets using the bundled archive:

```
$ mkdir InteinFinder_assets
$ cd InteinFinder_assets
$ \curl -L \
  https://github.com/mooreryan/InteinFinder/tree/main/_assets/asset_bundle.tar.gz \
  | tar xz
$ tree
intein_sequences/
└── all_derep.faa
smp/
├── cd00081.smp
├── cd00085.smp
├── cd09643.smp
├── COG1372.smp
├── COG1403.smp
├── COG2356.smp
├── pfam01844.smp
├── pfam04231.smp
├── pfam05204.smp
├── pfam05551.smp
├── pfam07510.smp
├── pfam12639.smp
├── pfam13391.smp
├── pfam13392.smp
├── pfam13395.smp
├── pfam13403.smp
├── pfam14414.smp
├── pfam14527.smp
├── pfam14528.smp
├── pfam14623.smp
├── pfam14890.smp
├── PRK11295.smp
├── PRK15137.smp
├── smart00305.smp
├── smart00306.smp
├── smart00507.smp
├── TIGR01443.smp
├── TIGR01445.smp
└── TIGR02646.smp

0 directories, 29 files
```

## Make a config file

Config files are in [TOML](https://toml.io) format.  Here is an example.

*Note: all paths are relative to the directory in which you run the `InteinFinder` executable.

TODO: does the `~` work in the paths?
TODO: does the folder work with trailing slash?

Let's assume that I have the InteinFinder source directory in the `/home/ryan/projects/InteinFinder` directory, and that I left the `_assets` directory that I mention above in its original place in the source directory.

Assume that in the current directory, I have [this](https://raw.githubusercontent.com/mooreryan/InteinFinder/main/test/cram/assets/rnr_5.faa) fasta file: `rnr_5.faa`.  *Note: If you look at this file, you will see that it is pretty weird.  It has some "special" sequences constructed for use in InteinFinder's end-to-end tests.*

Assume you have saved this file as `config.toml` in the same directory in which you have the `rnr_5.faa` fasta file.

```toml
# Intein target sequences
inteins = "/home/ryan/projects/InteinFinder/_assets/intein_sequences/all_derep.faa"

# Directory of conserved domain models
smp_dir = "/home/ryan/projects/InteinFinder/_assets/smp"

# My query sequences that I want to search
queries = "rnr_5.faa"

# The pipeline's output directory
out_dir = "intein_finder_output"

# The number of threads to use
threads = 4
```

## Run the pipeline

Assuming that the `InteinFinder` binary is somewhere on your [path](http://www.linfo.org/path_env_var.html), then you can run InteinFinder like so:

```
$ InteinFinder config.toml
INFO [2023-01-24 20:12:01] Renaming queries
INFO [2023-01-24 20:12:01] Splitting queries
INFO [2023-01-24 20:12:01] Making profile DB
INFO [2023-01-24 20:12:01] Running rpsblast
INFO [2023-01-24 20:12:01] Running mmseqs
INFO [2023-01-24 20:12:04] Getting query regions
INFO [2023-01-24 20:12:04] Writing putative intein regions
INFO [2023-01-24 20:12:04] Getting queries with intein seq hits
INFO [2023-01-24 20:12:04] Making query_region_hits
INFO [2023-01-24 20:12:04] Reading intein DB into memory
INFO [2023-01-24 20:12:04] Processing regions
INFO [2023-01-24 20:12:27] Writing name map
INFO [2023-01-24 20:12:27] Renaming queries in btab files
INFO [2023-01-24 20:12:27] Summarizing intein DB search
INFO [2023-01-24 20:12:27] Summarizing conserved domain DB search
INFO [2023-01-24 20:12:27] Done!
```

Finally, you will have output that looks something like this.

```
$ tree intein_finder_output/
intein_finder_output/
├── _done
├── logs
│   ├── 1_config.toml
│   ├── 2_pipeline_info.txt
│   └── if_log.2023-01-24_20-12-01.515507.mmseqs_search.txt
├── results
│   ├── 1_putative_intein_regions.tsv
│   ├── 2_intein_hit_checks.tsv
│   └── 3_trimmed_inteins.faa
└── search
    ├── cdm_db
    │   ├── 1_cdm_db_search_out.tsv
    │   └── 2_cdm_db_search_summary.tsv
    └── intein_db
        ├── 1_intein_db_search_out.tsv
        ├── 2_intein_db_search_with_regions.tsv
        └── 3_intein_db_search_summary.tsv

5 directories, 12 files
```

The various output files are described in more detail elsewhere in the manual.