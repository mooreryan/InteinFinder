# Config Files

There are a lot of options that you can specify when running InteinFinder.  The config file is how you specify those options.

InteinFinder config files are written in [TOML](https://toml.io), which is (supposed to) prioritize ease of reading and writing.  Hopefully you agree :)

## Example

Here is an example with all the available options given with their default values.  Note that you can break arrays across multiple lines if you want to!

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


[start_residue]
pass  = ["C", "S", "A", "Q", "P", "T"]
maybe = ["V", "G", "L", "M", "N", "F"]

[end_residues]
pass  = ["HN", "SN", "GN", "GQ", "LD", "FN"]
maybe = ["KN", "DY", "SQ", "HQ", "NS", "AN", 
         "SD", "TH", "RD", "PY", "YN", "VH", 
		 "KQ", "PP", "NT", "CN", "LH"]

[end_plus_one_residue]
pass  = ["S", "T", "C"]
maybe = []

[makeprofiledb]
exe = "makeprofiledb"

[mafft]
exe = mafft
max_concurrent_jobs = 1

[mmseqs]
exe = mmseqs
evalue = 1e-3
num_iterations = 2
sensitivity = 5.7
threads = 1

[rpsblast]
exe = "rpsblast+"
evalue = 1e-3
num_splits = 1
```

## Details

Let's go into detail on each set of options.

*Note: I will try to keep this in sync with the code, but if you notice it is not, then please [file an issue](TODO)!*

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

Both these options are required.

### InteinFinder DB location

- `inteins`
    - Path to the file containing the intein DB you want to search against
	- In most cases, you will use the file [included](TODO) with InteinFinder, but you can always use your own.
- `smp_dir`
    - Path to the directory containing `SMP` files to search against
	- This is the file format that rpsblast uses ([link](TODO)).
	- In most cases, you will use the file [included](TODO) with InteinFinder, but you can always use your own.

Both these options are required.

### General pipeline options

These options are all optional.  That means if you leave them out of your config file, they will be assigned to their default values.

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

## Key intein residues

You can customize the key intein residues that InteinFinder pipeline will check for.  The defaults are based on a combination of literature support and frequency in known/annotated inteins, so you often won't be adjusting them.  However, you have the power if you need to!

TODO: probably change `maybe` to `pass` and `pass` to `strict_pass`.

You control the key residues with a TOML [table](https://toml.io/en/v1.0.0#table).

All of these tables are optional.

### Start residues

The header to control start residues is `[start_residue]`.  There are two options: `pass` and `maybe`.

- `pass`
    - An array of residues considered for a "strict" pass
	- default value: `["C", "S", "A", "Q", "P", "T"]`
- `maybe`
    - An array of residues considered for a regular pass
	- default value: `["V", "G", "L", "M", "N", "F"]`

This is what the default would look like in a TOML file.

```toml
[start_residue]
pass  = ["C", "S", "A", "Q", "P", "T"]
maybe = ["V", "G", "L", "M", "N", "F"]
```

Of course, if you want the default, simply leave out the entire table!

### End residues

Control the final two residues with `[end_residues]`.  Again, two options: `pass` and `maybe`.

- `pass`
    - An array of residues considered for a "strict" pass
	- default value: `["HN", "SN", "GN", "GQ", "LD", "FN"]`
- `maybe`
    - An array of residues considered for a regular pass
	- default value: `["KN", "DY", "SQ", "HQ", "NS", "AN", "SD", "TH", "RD", "PY", "YN", "VH", "KQ", "PP", "NT", "CN", "LH"]`

This is what the default would look like in a TOML file.

```toml
[end_residues]
pass  = ["HN", "SN", "GN", "GQ", "LD", "FN"]
maybe = ["KN", "DY", "SQ", "HQ", "NS", "AN", 
         "SD", "TH", "RD", "PY", "YN", "VH", 
		 "KQ", "PP", "NT", "CN", "LH"]
```

The whitespace is just there to make it look nicer.  You can put it on the same line if you want!

Same as above, if you want the default, simply leave out the entire table!

### End plus one residue

This is the C-terminal extein residue check.  It's called "end plus one" just for clarity, as in one residue past the end of the intein.

Control the residues considered for pass and strict pass with `[end_plus_one_residues]` table.  Again, two options: `pass` and `maybe`.

- `pass`
    - An array of residues considered for a "strict" pass
	- default value: `["S", "T", "C"]`
- `maybe`
    - An array of residues considered for a regular pass
	- default value: `[]`
	- Hang on...what does an empty array mean for a default value?
	    - It means that there are only strict passes and failures by default for the C-terminal intein residue check.
        - Also, it means not providing a value here is the same as the default value.

Here's an example of how it would look in your config file.

```toml
[end_plus_one_residue]
pass  = ["S", "T", "C"]
maybe = []
```
Like the last couple of options, if you want the default, simply leave out the entire table!

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
	    - Note that this default value assumes that the program is on you [PATH](TODO)

### MAFFT

[MAFFT](TODO) is used to do the alignments when refining putative intein regions.

- `exe`
    - The name of the executable program
	- Also, you could pass in a path to the program (TODO add a test for this)
    - default value: `mafft`
	    - Note that this default value assumes that the program is on you [PATH](TODO)
- `max_concurrent_jobs`
    - Controls how many `mafft` jobs to run in parallel
	- A reasonable value would be the number of cores/threads your machine has.
	- Often it will match the threads for `mmseqs` and `num_splits` for `rpsblast`.
	- default value: `1`

### MMseqs2

[MMseqs2](TODO) is used to search queries against intein sequences

- `exe`
    - The name of the executable program
	- Also, you could pass in a path to the program (TODO add a test for this)
    - default value: `mmseqs`
	    - Note that this default value assumes that the program is on you [PATH](TODO)
- `evalue`
    - default value: `1e-3`
- `num_iterations`
    - default value: `2`
- `sensitivity`
    - default value: `5.7`
- `threads`
	- Often it will match the `num_splits` for `mmseqs` and `max_concurrent_jobs` for `mafft`.
    - default value: `1`


### RPSBLAST

- `exe`
    - The name of the executable program
	- Also, you could pass in a path to the program (TODO add a test for this)
    - default value: `rpsblast+`
	    - Note that this default value assumes that the program is on you [PATH](TODO)
		- There is a good chance that you will change this to `rpsblast`.
		    - On my system, it's called `rpsblast+`, but I'm not sure which is more common.
- `evalue`
    - default value: `1e-3`
- `num_splits`
    - This controls how many times to split the query file
	- Set this value to however many cores/threads you want to use.
	- Often it will match the `threads` for `mmseqs` and `max_concurrent_jobs` for `mafft`.
    - default value: `1`
