# Find Inteins

Want to screen your sweet peptide sequences for Inteins?  If so,
you've come to the right place!

## Output files

## TL;DR

Just open the `INPUT.intein_criteria_check_condensed.txt` file.  Any
sequence/region pair with mostly `Y`'s in the columns probably has an
intein in that region.

### Search info

This file counts up the number of significant hits to the search
databases as well as the best evalue for each search database.

### Intein containing regions

If a sequence is likely to have an intein (e.g., it has significant
homology to something in one of the search databases), we try and
predict the regions on the query that likely contain an intein.
Basically we group overlapping blast hits so that the intein should be
within one of these regions.

### Criteria checking

Columns include:

- `seq` -- The query sequence ID
- `region.id` -- The region ID.  This will match with `region.id` column of `INPUT.intein_containing_regions.txt` file.
- `all` -- [Y/N] Did all the criteria checks pass?
- `region` -- [Y/N] Is the alignment of the intein with the query sequence was contained in the region specified by `INPUT.intein_containing_regions.txt` for this `region.id`?  If this is `N`, then any `Y`'s in the next columns may be spurious.
- `start` -- [Y/N] Was there a `Serine/Ser/S`, `Threonine/Thr/T`, or `Cysteine/Cys/C` at the intein N-terminus?
- `end` -- [Y/N] Was there the dipeptide `Histidine/His/H`-`Asparagine/Asn/N` or `Histidine/His/H`-`Glutamine/Gln/Q` at the intein C-terminus?
- `extein` -- [Y/N] Was there a `Serine/Ser/S`, `Threonine/Thr/T`, or `Cysteine/Cys/C` at the begininning of the C-extein?

There is a condensed and a full file.  The condensed version
aggregates all the alignments from the full file.  It shows one record
per putative intein region per query sequence.  Only queries with
significant hits to inteins or superfamily CDs will appear in these
files.

`INPUT.intein_criteria_check_condensed.txt`

*Note*: This one should always have fewer records than the
`INPUT.intein_containing_regions.txt`.  Pretty sure this is because
the containing regions prediction is done with all search hits (Inbase
sequences plus superfamily members) whereas the criteria check is only
done using the intein sequences from Inbase.

`INPUT.intein_criteria_check_full.txt`

There will be a record for every significant homologous region found
by `mmseqs` when searching the query sequences against the Inbase
intein sequences.

## Things we check

Screens sequences against:

- 585 sequences from inteins.com
- Conserved domains from superfamilies cl22434 (Hint), cl25944 (Intein_splicing) and cl00083 (HNHc).

Also does some fancy aligning to check for these things:

- Ser, Thr or Cys at the intein N-terminus
- The dipeptide His-Asn or His-Gln at the intein C-terminus
- Ser, Thr or Cys following the downstream splice site.

Does not check for:

- The conditions listed in the Intein polymorphisms section of the [Inbase](http://www.inteins.com) website.
- Intein minimum size (though it does check that it spans the putative region)
- Specific intein domains are present and in the correct order
- If the only blast hits are to an endonucleaes

## TODO

- Include the sequences from the superfamily CDs in the alignment step.
