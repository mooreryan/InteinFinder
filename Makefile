.PHONY: test test_small

test:
	rm -r TEST_OUTPUT; ./find_inteins.rb --queries test_files/rnr.faa --outdir TEST_OUTPUT --split-queries --cpus 4 && tree TEST_OUTPUT

test_small:
	rm -r TEST_OUTPUT; ./find_inteins.rb --queries test_files/rnr_seq_4.faa --outdir TEST_OUTPUT --cpus 8 && tree TEST_OUTPUT
