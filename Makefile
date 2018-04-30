TEST_OUTDIR = TEST_OUTPUT

.PHONY: test test_small test_small2

test:
	rm -r $(TEST_OUTDIR); ./intein_finder --ignore-regions-less-than 0 --use-length-in-refinement --queries test_files/rnr.faa --outdir $(TEST_OUTDIR) --split-queries --cpus 32 && tree $(TEST_OUTDIR) && diff TEST_OUTPUT/results/intein_regions_refined_condensed.txt test_files/test_expected.txt

test_small:
	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --evalue-rpsblast 1e-10 --evalue-mmseqs 1e-10 --evalue-region-refinement 1e-10 --mmseqs-sensitivity 1 --mmseqs-iterations 1 --queries test_files/rnr_seq_4.faa --outdir $(TEST_OUTDIR) --split-queries --cpus 32 && tree $(TEST_OUTDIR) && diff $(TEST_OUTDIR)/results/intein_regions_refined_condensed.txt test_files/test_small_expected.txt

test_small2:
	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/small_2.faa --outdir $(TEST_OUTDIR) --cpus 32 && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/* && diff $(TEST_OUTDIR)/results/intein_regions_refined_condensed.txt test_files/test_small2_expected.txt

test_long_and_short:
	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/long_and_short.faa --outdir $(TEST_OUTDIR) --cpus 32 && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/*

test_no_inteins:
	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/no_inteins.faa --outdir $(TEST_OUTDIR) --cpus 32 && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/*
