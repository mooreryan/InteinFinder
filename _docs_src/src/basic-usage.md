# Basic Usage

This tutorial covers basic usage of InteinFinder.

- Making a simple config file
- Running the software
- Checking the output
- Generating intein free extein sequences

## Download the data

The data used in this tutorial is available on GitHub, with [this](https://raw.githubusercontent.com/mooreryan/InteinFinder/main/_examples/basic_usage.tar.gz) direct link.

It contains the query sequences, config file, and database assets used in this example.

Here is an example of how to download the data.  Note, you can skip the `tree` command that is shown.  It is simply to display the data for this example.

```
$ mkdir tutorials && cd tutorials
$ \curl -L \
  https://raw.githubusercontent.com/mooreryan/InteinFinder/main/_examples/basic_usage.tar.gz \
  | tar xz
$ cd basic_usage
$ tree --charset=ascii
.
|-- cddb
|   |-- cd00081.smp
|   |-- cd00085.smp
|   |-- cd09643.smp
|   |-- COG1372.smp
|   |-- COG1403.smp
|   |-- COG2356.smp
|   |-- pfam01844.smp
|   |-- pfam04231.smp
|   |-- pfam05204.smp
|   |-- pfam05551.smp
|   |-- pfam07510.smp
|   |-- pfam12639.smp
|   |-- pfam13391.smp
|   |-- pfam13392.smp
|   |-- pfam13395.smp
|   |-- pfam13403.smp
|   |-- pfam14414.smp
|   |-- pfam14527.smp
|   |-- pfam14528.smp
|   |-- pfam14623.smp
|   |-- pfam14890.smp
|   |-- PRK11295.smp
|   |-- PRK15137.smp
|   |-- smart00305.smp
|   |-- smart00306.smp
|   |-- smart00507.smp
|   |-- TIGR01443.smp
|   |-- TIGR01445.smp
|   `-- TIGR02646.smp
|-- config.toml
|-- isdb
|   `-- all_derep.faa
|-- queries.faa
`-- README.md

2 directories, 33 files
```

## Make the config file

Assuming that you have [installed](installing-precompiled-binaries.md) InteinFinder and all its [dependencies](installing-external-dependencies.md), the next thing you need to do is to make a config file.

Let's make the config file together now.  We use [TOML](https://toml.io) files to configure InteinFinder.

### A note about relative paths

For this tutorial, I am assuming that you will be in the current directory when you run the InteinFinder program.

This matters when specifying the location of the files.  In the tutorial, we will be using file paths relative to *this* directory.  Because we use relative file paths, we must run InteinFinder in this directory, or it will not be able to find the files.

If you want to avoid this restriction, you must use absolute file paths (e.g., `/home/ryan/downloads/config.toml`).  Doing this will allow you to run the `InteinFinder` executable from any directory.

### Queries

First, you need to specify the queries file.  You can use relative paths.  It will look like this:

For this example, we will use a couple of sequences from UniProt as the query sequences.  The file is called `queries.faa`.

```toml
queries = "queries.faa"
```

The key is `queries` and the values is the name of the file.  In this case, it is a relative path to the file `queries.faa` located in this directory.  Note that the value is a string, and so it has double quotes (`"`) around it.

### Output directory

Next, you need to specify the output directory.  For that, you use the key `out_dir`.

```toml
out_dir = "if_out"
```

The above line tells InteinFinder that you want its output to go in a directory called `if_out`.  Again, it is a relative path, so the output file will be in the current directory.

### Target databases

InteinFinder needs two databases to run.  One is a FASTA file containing known intein sequences, and the other is a directory of SMP files containing conserved domains commonly associated with inteins.  While you can provide your own, for this tutorial, we will use those included in the InteinFinder git repository.  Note that in the manuscript, these are called the intein sequence database (ISDB), and the conserved domain database (CDDB).

The intein sequences are in `isdb/all_derep.faa` and the SMP files are in `cddb`.  They are included in the tar file you downloaded earlier.

Here is what it will look like:

```toml
inteins = "isdb/all_derep.faa"
smp_dir = "cddb/smp"
```

Remember that these file paths are relative to the directory that we are currently in.

### Put it together

And that is all the required key/value pairs for the config file.  You can see the whole config file saved as `config.toml` in this directory:

```toml
queries = "queries.faa"
out_dir = "if_out"

inteins = "isdb/all_derep.faa"
smp_dir = "cddb/smp"
```

## Run the pipeline

Technically, there are two parts to the pipeline.

- identifying inteins in the dataset (`InteinFinder` program)
- removing inteins from query sequences (`RemoveInteins` program)

Eventually, these two steps will be merged into a single executable program, but for now they are separate.

I'm going to assume that you have successfully installed it, and it is on your path.  Also, I'm assuming that you are running InteinFinder in this directory.

### InteinFinder

`InteinFinder` is the main program.  It identifies intein regions on your query sequences and, for any "bonafide" inteins, it will give you the intein sequences.

Let's run it now.

```
$ InteinFinder config.toml
INFO [2023-03-27 23:49:50] Renaming queries
INFO [2023-03-27 23:49:50] Splitting queries
INFO [2023-03-27 23:49:50] Making profile DB
INFO [2023-03-27 23:49:50] Running rpsblast
INFO [2023-03-27 23:49:50] Running mmseqs
INFO [2023-03-27 23:49:53] Getting query regions
INFO [2023-03-27 23:49:53] Writing putative intein regions
INFO [2023-03-27 23:49:53] Getting queries with intein seq hits
INFO [2023-03-27 23:49:53] Making query_region_hits
INFO [2023-03-27 23:49:53] Reading intein DB into memory
INFO [2023-03-27 23:49:53] Processing regions
INFO [2023-03-27 23:49:54] Writing name map
INFO [2023-03-27 23:49:54] Renaming queries in btab files
INFO [2023-03-27 23:49:54] Summarizing intein DB search
INFO [2023-03-27 23:49:54] Summarizing conserved domain DB search
INFO [2023-03-27 23:49:54] Done!
```

There you go!  Let's check out the output...

```
$ tree if_out/
if_out/
├── _done
├── logs
│   ├── 1_config.toml
│   ├── 2_pipeline_info.txt
│   └── if_log.2023-03-27_23-49-50.674508.mmseqs_search.txt
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

For more info about the output files, see the [docs](intein-finder-output.md).

### RemoveInteins

Sometimes, you want to process your query sequences to remove any inteins.  As of today (2023-03-28), this requires a separate program that is included with the InteinFinder distribution called `RemoveInteins`.  (Eventually, it will be merged in to the main `InteinFinder` program.)

Here is the usage synopsis of the program:

```
RemoveInteins [OPTION]... HIT_CHECKS QUERIES
```

It takes the hit checks file output and the queries input from the `InteinFinder` run.

Let's run it now.

```
$ RemoveInteins \
    if_out/results/2_intein_hit_checks.tsv \
    queries.faa > \
    if_out/results/4_intein_free_queries.faa

DEBUG [2023-03-28 11:59:10] ((intein_hit_checks if_out/results/2_intein_hit_checks.tsv)(queries queries.faa))
INFO [2023-03-28 11:59:10] Reading intein hit checks
INFO [2023-03-28 11:59:10] Reading the query sequences
```

Alright, let's look at the output once more:

```
$ tree if_out
if_out/
├── _done
├── logs
│   ├── 1_config.toml
│   ├── 2_pipeline_info.txt
│   └── if_log.2023-03-28_11-46-22.139065.mmseqs_search.txt
├── results
│   ├── 1_putative_intein_regions.tsv
│   ├── 2_intein_hit_checks.tsv
│   ├── 3_trimmed_inteins.faa
│   └── 4_intein_free_queries.faa
└── search
    ├── cdm_db
    │   ├── 1_cdm_db_search_out.tsv
    │   └── 2_cdm_db_search_summary.tsv
    └── intein_db
        ├── 1_intein_db_search_out.tsv
        ├── 2_intein_db_search_with_regions.tsv
        └── 3_intein_db_search_summary.tsv

5 directories, 13 files
```

As you see, there is one additional file, `4_intein_free_queries.faa`, that contains intein-free query sequences.

Note that only query sequences with at least one bonafide intein sequence will be printed, and that only inteins who scored an overall Pass will be removed from said extein sequences. Keep in mind that the printed sequences may not be completely intein-free, as a query could have multiple inteins, but not all of those predicetd inteins may have scored well enough to be automatically removed. For now, you will see a warning in cases like these.

## Wrap up

In this tutorial, we went over the basics of using InteinFinder, including writing a config file using mostly default options, and generating a set of intein-free sequences with the `RemoveInteins` program.
