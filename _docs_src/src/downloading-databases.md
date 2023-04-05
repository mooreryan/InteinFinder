# Downloading InteinFinder Databases

## Get needed assets

You need a file of inteins and a file of conserved domain models.

InteinFinder comes with these for your convenience.  But expert users may have their own set to use instead.

Here are links to find them on GitHub

- [database bundle](https://github.com/mooreryan/InteinFinder/raw/main/_assets/asset_bundle.tar.gz)
    - Use this link for an archive containing both the intein sequence DB and the conserved domain model DB.
    - It's the same data, but in a form convenient for direct download.
- [intein sequences](https://github.com/mooreryan/InteinFinder/tree/main/_assets/intein_sequences)
    - directory containing intein sequence DB
    - In the manuscript, this is referred to as the ISDB (intein sequence database)
- [conserved domain models](https://github.com/mooreryan/InteinFinder/tree/main/_assets/smp)
    - directory containing conserved domain models
    - In the manuscript, this is referred to as the CDMDB (conserved domain model data base)

Here is an example for downloading the assets using the bundled archive:

```
$ mkdir InteinFinder_db
$ cd InteinFinder_db
$ \curl -L \
  https://github.com/mooreryan/InteinFinder/raw/main/_assets/asset_bundle.tar.gz \
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
