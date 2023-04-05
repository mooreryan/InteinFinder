# Config Files

There are a lot of options that you can specify when running InteinFinder.  The config file is how you specify those options.

InteinFinder config files are written in [TOML](https://toml.io), which is (supposed to) prioritize ease of reading and writing.  Hopefully you agree :)

## Example

Here is an example with all the available options given with their default values.

Note:

- Most of these are optional!
- Double quote your strings
- You can break arrays across multiple lines if you want to!
- Any line starting with a `#` is a comment.
  - That means that they are ignored.
  - You can use them for your own clarification, or whatever you need.
- For file paths, you must not use `~` as an abbreviation for your home directory, it will not work.

```toml
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
```

## Details

Let's go into detail on each set of options.

*Note: I will try to keep this in sync with the code, but if you notice it is not, then please [file an issue](https://github.com/mooreryan/InteinFinder/issues/new)!*

### A note about paths

For any option that takes a path to a file or directory (`inteins`, `queries`, `smp_dir`, and `out_dir`), you can use a relative path if you want.  But keep in mind that it will be relative to the location in which you run InteinFinder, *not the location in which the config file resides*.

If that is confusing, you may want to stick to absolute paths.

### General I/O

- `queries`
    - Path to the file containing the query peptide sequences that you want to check for inteins
- `out_dir`
    - Path to the output directory in which InteinFinder will dump its output
	- Will be created if it does not exist
	- Pipeline will fail if it does exist

Both these options are **required**.

### InteinFinder DB location

- `inteins`
    - Path to the file containing the intein DB you want to search against
	- In most cases, you will use the file [included](https://github.com/mooreryan/InteinFinder/blob/main/_assets/intein_sequences/all_derep.faa) with InteinFinder, but you can always use your own.
- `smp_dir`
    - Path to the directory containing `SMP` files to search against
	- This is the file format that rpsblast uses ([link](todo.md)).
	- In most cases, you will use the files [included](https://github.com/mooreryan/InteinFinder/tree/main/_assets/smp) with InteinFinder, but you can always use your own.

Both these options are **required**.

### General pipeline options

These config pairs are all **optional**.  That means if you leave them out of your config file, they will be assigned to their default values.

- `clip_region_padding`
    - The "padding" added to each side of the hit region to "clip" from the query sequence and include in the alignment files
	- A value of `10` means add ten residues to each side of the clipping region.
	- (You probably don't want to mess with this.)
    - default value: `10`
- `log_level`
    - Options from least verbose to most verbose: `error`, `warning`, `info`, and `debug`
    - default value: `"info"`
- `min_query_length`
    - Ignore all queries sequences whose length is less than this value.
    - default value: `100`
- `min_region_length`
    - Don't try to refine any hit regions whose length is less than this value.
	- It sounds like you might lose cool info with this option, but you really won't.
	    - The shortest intein included in InteinFinder's DB is greater than 100 AAs in length.
		- That means that any hit regions shorter than this can *never* pass all the checks anyway.
		- But don't worry, they still show up in the putative intein regions file!
    - default value: `100`
- `remove_aln_files`
    - Set to `true` (or leave it out) if you want to remove the alignment files.
	- Set to `false` if you want to keep the alignment files.
	    - While this sounds cool, in practice it's not so fun, as it can dump a TON of files.
		- Generally, you might use this option if:
		    - you have a small number queries
			- you really want to look at the aligments
			- you found something weird and need to figure out what is going on
			- you found a bug and submitted a bug report, but Ryan (aka me) asked you for the intermediate alignment files :)
    - default value: `true`
- `threads`
    - Number of threads/cores/CPUs to use for the parts of the pipeline that can run in parallel
        - For MMseqs2, this is the `threads` option.
		- For RPSBLAST, it is the number of concurrent search jobs that are run
		- For running alignments, it controls how many alignment jobs are run concurrently.
	- A reasonable value is close to the number of cores your machine has.
    - default value: `1`

### Key intein residues

You can customize the key intein residues that InteinFinder pipeline will check for.  The defaults are based on a combination of literature support and frequency in known/annotated inteins, so you may not need to adjust them.  However, you have the power if you need to!

All of these tables are **optional**.  Be careful though:  if you specify one of the following options, then you need to *fully specify* that option.

Here is an incorrect example....You want to change start residue `G` from tier 2 to tier 1, but you want all other residues to be the same.  The following **will NOT** do that.

```
[start_residue]
G = "T1"
```

Why will that not work?  Because you are saying for start residue, `G` is a tier 1 pass and all other residues that you didn't specify should be considered as `Fail`.

#### Tiers

InteinFinder uses the concept of tiers in its scoring scheme.  You can find an explanation of that [here](todo.md) or in the [manuscript](todo.md).

- Pass tiers
  - To specify tier 1 pass, you use `"T1"`
  - To specify tier 2 pass, you use `"T2"`
  - Etc.
- Fail
  - Any residue not explicitly listed as one of the pass tiers is considered a `Fail`

#### Start residue

- The table to control start residue tiers is `[start_residue]`.
- The start residue is the first amino acid of the predicted intein.
- Defaults:
  - Tier 1 pass: C, S, A, Q, P, T
  - Tier 2 pass: V, G, L, M, N, F
  - Fail: any other residue
- If you want the default, simply leave out the entire table!

#### End residues

- Control the final two residues with `[end_residues]`.
- The end residues are the final two amino acids of the predicted intein.
- Defaults:
  - Tier 1 pass: HN, SN, GN, GQ, LD, FN
  - Tier 2 pass: KN, DY, SQ, HQ, NS, AN, SD, TH, RD, PY, YN, VH, KQ, PP, NT, CN, LH
  - Fail: any other AA pair
- If you want the default, simply leave out the entire table!

#### End plus one residue

- This is the C-terminal extein residue check.
  - It's called "end plus one" just for clarity, as in one residue past the end of the intein.
- Control the residues considered for pass and strict pass with `[end_plus_one_residues]` table
- Like the last couple of options, if you want the default, simply leave out the entire table!
- Defaults:
  - Tier 1 pass: S, T, C
  - Fail: any other AA pair

## External program options

Now we should talk about how to set certain options in the external programs that the InteinFinder pipeline uses.

The options for each program are specified using a table.

### makeprofiledb

The `makeprofiledb` program is used to make the database used for the `rpsblast` search.  It is why you need to specify the `smp_dir`.

There is only one option for this table:

- `exe`
    - The name of the executable program
	- Also, you could pass in a path to the program (TODO add a test for this)
    - default value: `makeprofiledb`
	    - Note that this default value assumes that the program is on your [PATH](http://www.linfo.org/path_env_var.html)

### MAFFT

[MAFFT](https://mafft.cbrc.jp/alignment/software/) is used to do the alignments when refining putative intein regions.

- `exe`
    - The name of the executable program
	- Also, you could pass in a path to the program (TODO add a test for this)
    - default value: `mafft`
	    - Note that this default value assumes that the program is on your path

### MMseqs2

[MMseqs2](https://github.com/soedinglab/MMseqs2) is used to search queries against intein sequences

- `exe`
    - The name of the executable program
	- Also, you could pass in a path to the program (TODO add a test for this)
    - default value: `mmseqs`
	    - Note that this default value assumes that the program is on your path
- `evalue`
    - default value: `1e-3`
- `num_iterations`
    - default value: `2`
- `sensitivity`
    - default value: `5.7`

### RPSBLAST

- `exe`
    - The name of the executable program
	- Also, you could pass in a path to the program (TODO add a test for this)
    - default value: `rpsblast+`
	    - Note that this default value assumes that the program is on you [PATH](todo.md)
		- There is a good chance that you will change this to `rpsblast`.
		    - On my system, it's called `rpsblast+`, but I'm not sure which is more common.
- `evalue`
    - default value: `1e-3`
