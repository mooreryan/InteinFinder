CC = gcc
CFLAGS = -Wall -g
LDFLAGS = -lz

BIN = bin
SRC = src
TEST_FILES = test_files
TEST_OUTDIR = TEST_OUTPUT

ifeq ($(OPTIMIZE),)
OPTIMIZE = 3
endif

.PHONY: test
.PHONY: test_small
.PHONY: test_small2
.PHONY: all

all: split_seqs

test: split_seqs
	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --queries test_files/rnr.faa --outdir $(TEST_OUTDIR) --split-queries --cpus 32 && tree $(TEST_OUTDIR) && diff TEST_OUTPUT/results/intein_regions_refined_condensed.txt test_files/test_expected.txt

test_small: split_seqs
	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --evalue-rpsblast 1e-10 --evalue-mmseqs 1e-10 --evalue-region-refinement 1e-10 --mmseqs-sensitivity 1 --mmseqs-iterations 1 --queries test_files/rnr_seq_4.faa --outdir $(TEST_OUTDIR) --split-queries --cpus 32 && tree $(TEST_OUTDIR) && diff $(TEST_OUTDIR)/results/intein_regions_refined_condensed.txt test_files/test_small_expected.txt

test_small2: split_seqs
	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/small_2.faa --outdir $(TEST_OUTDIR) --cpus 32 && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/* && diff $(TEST_OUTDIR)/results/intein_regions_refined_condensed.txt test_files/test_small2_expected.txt

test_long_and_short: split_seqs
	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/long_and_short.faa --outdir $(TEST_OUTDIR) --cpus 32 && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/*

test_no_inteins: split_seqs
	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/no_inteins.faa --outdir $(TEST_OUTDIR) --cpus 32 && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/*

split_seqs:
	$(CC) $(CFLAGS) -fopt-info-optimized -O$(OPTIMIZE) $(SRC)/$@.c $(LDFLAGS) -o $(BIN)/$@

test_split_seqs: split_seqs
	rm $(TEST_FILES)/split_seqs_in.fa.split_?; valgrind --leak-check=full $(BIN)/split_seqs 2 $(TEST_FILES)/split_seqs_in.fa && diff $(TEST_FILES)/split_seqs_in.fa.split_0 $(TEST_FILES)/split_seqs_split_0_expected.txt && diff $(TEST_FILES)/split_seqs_in.fa.split_1 $(TEST_FILES)/split_seqs_split_1_expected.txt
