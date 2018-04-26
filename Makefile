.PHONY: test test_small

test:
	rm -r TEST_OUTPUT_FULL; ./find_inteins.rb --use-length-in-refinement --queries test_files/rnr.faa --outdir TEST_OUTPUT_FULL --split-queries --cpus 32 && tree TEST_OUTPUT_FULL

test_small:
	rm -r TEST_OUTPUT_SMALL; ./find_inteins.rb --use-length-in-refinement --evalue-rpsblast 1e-10 --evalue-mmseqs 1e-10 --evalue-region-refinement 1e-10 --mmseqs-sensitivity 1 --mmseqs-iterations 1 --queries test_files/rnr_seq_4.faa --outdir TEST_OUTPUT_SMALL --split-queries --cpus 32 && tree TEST_OUTPUT_SMALL && head TEST_OUTPUT_SMALL/rnr*

test_small_2:
	rm -r TEST_OUTPUT_SMALL_2; ./find_inteins.rb --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/rnr_seq_4.faa --outdir TEST_OUTPUT_SMALL_2 --split-queries --cpus 32 && tree TEST_OUTPUT_SMALL_2 && head TEST_OUTPUT_SMALL_2/rnr*
