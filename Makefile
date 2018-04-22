.PHONY: test

test:
	rm -r TEST_OUTPUT; ./find_inteins.rb --queries test_files/rnr.faa --outdir TEST_OUTPUT --split-queries --cpus 4 && tree TEST_OUTPUT
