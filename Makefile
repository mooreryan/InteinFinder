TEST_OUTDIR = TEST_OUTPUT

.PHONY: test test_small test_small2

test:
	rm -r $(TEST_OUTDIR); ./find_inteins.rb --use-length-in-refinement --queries test_files/rnr.faa --outdir $(TEST_OUTDIR) --split-queries --cpus 32 && tree $(TEST_OUTDIR)

test_small:
	rm -r $(TEST_OUTDIR); ./find_inteins.rb --use-length-in-refinement --evalue-rpsblast 1e-10 --evalue-mmseqs 1e-10 --evalue-region-refinement 1e-10 --mmseqs-sensitivity 1 --mmseqs-iterations 1 --queries test_files/rnr_seq_4.faa --outdir $(TEST_OUTDIR) --split-queries --cpus 32 && tree $(TEST_OUTDIR) && diff $(TEST_OUTDIR)/results/intein_regions_refined_condensed.txt test_files/test_small_expected.txt

test_small2:
	rm -r $(TEST_OUTDIR); ./find_inteins.rb --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/small_2.faa --outdir $(TEST_OUTDIR) --cpus 32 && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/*
