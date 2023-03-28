---
main: true
---

# InteinFinder

[![Build and Test](https://github.com/mooreryan/InteinFinder/actions/workflows/build_and_test.yml/badge.svg?branch=main)](https://github.com/mooreryan/InteinFinder/actions/workflows/build_and_test.yml) [![code on GitHub](https://img.shields.io/badge/code-GitHub-blue)](https://github.com/mooreryan/InteinFinder) [![GitHub issues](https://img.shields.io/github/issues/mooreryan/InteinFinder)](https://github.com/mooreryan/InteinFinder/issues) [![Coverage Status](https://coveralls.io/repos/github/mooreryan/InteinFinder/badge.svg?branch=main)](https://coveralls.io/github/mooreryan/InteinFinder?branch=main)

InteinFinder: automated intein detection from large protein datasets

InteinFinder is an automated pipeline for identifying, cataloging, and removing inteins from peptide sequences.  InteinFinder accurately screens proteins for inteins and is scalable to large peptide sequence datasets.

## Background

Inteins are mobile genetic elements found within the coding regions of genes.  The protein equivalent of introns, they are transcribed and translated along with their flanking protein fragments (exteins) before splicing out from the precursor protein.  They are found throughout the tree of life, including viruses and bacteriophages.  Whereas inteins were previously thought to be parasitic genetic elements providing no benefit to the host organism, recent studies suggest that inteins may impact host ecology by acting as environmental “sensors” exhibiting post-translational control on extein sequences.  This property and others make inteins useful tools for biotechnology applications in molecular biology and protein engineering.  As inteins are mobile, their presence confounds evolutionary and ecological studies of protein coding genes, especially those used in viral ecology, necessitating their removal prior to phylogenetic and other analyses.

Given the increased interest in inteins, more studies are focusing on identifying inteins within a set of genomes or other large datasets.  The process of screening peptide sequences for the presence of inteins has not been consolidated into a single pipeline.  To address this, we developed InteinFinder, an automated pipeline for identifying, cataloging, and removing inteins from peptide sequences.  InteinFinder accurately screens proteins for inteins and is scalable to large peptide sequence datasets.

## License

### Software

[![license MIT or Apache
2.0](https://img.shields.io/badge/license-MIT%20or%20Apache%202.0-blue)](https://github.com/mooreryan/InteinFinder)

Copyright (c) 2018 - 2023 Ryan M. Moore

Licensed under the Apache License, Version 2.0 or the MIT license, at your option. This program may not be copied, modified, or distributed except according to those terms.

### Documentation

<a rel="license" href="http://creativecommons.org/licenses/by/4.0/">
<img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by/4.0/88x31.png" />
</a>

Copyright (c) 2022 - 2023 Ryan M. Moore.

This documentation is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by/4.0/">Creative Commons Attribution 4.0 International License</a>.
