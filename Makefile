.PHONY: test test_small

test:
	rm -r TEST_OUTPUT; ./find_inteins.rb --queries test_files/rnr.faa --outdir TEST_OUTPUT --split-queries --cpus 32 && tree TEST_OUTPUT

test_small:
	rm -r TEST_OUTPUT; ./find_inteins.rb --mmseqs-sensitivity 1 --mmseqs-iterations 1 --queries test_files/rnr_seq_4.faa --outdir TEST_OUTPUT --split-queries --cpus 32 && tree TEST_OUTPUT && head TEST_OUTPUT/rnr*
