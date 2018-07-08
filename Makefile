CC = gcc
CFLAGS = -Wall -g
LDFLAGS = -lz

BIN = bin
SRC = src
VENDOR = vendor
TEST_FILES = test_files
TEST_OUTDIR = TEST_OUTPUT

THREADS_ALIGNMENT = 16
THREADS_SEARCH = 16

OBJS := $(SRC)/kseq_helper.o

SRC_RLIB = vendor/ruby_like_c/src

ifeq ($(OPTIMIZE),)
OPTIMIZE = 3
endif

# MMseqs2 needs a certain binary option depending on the node you're
# on.
ifeq ($(MMSEQS),)
MMSEQS = "mmseqs"
endif


.PHONY: test
.PHONY: test_small
.PHONY: test_small2
.PHONY: all

all: split_seqs

test: split_seqs simple_headers process_input_seqs
	rm -r $(TEST_OUTDIR); ./intein_finder --mmseqs $(MMSEQS) --use-length-in-refinement --queries test_files/rnr.faa --outdir $(TEST_OUTDIR) --split-queries --cpus-alignment $(THREADS_ALIGNMENT) --cpus-search $(THREADS_SEARCH) && tree $(TEST_OUTDIR) && diff TEST_OUTPUT/results/intein_regions_refined_condensed.txt test_files/test_expected.txt

test_small: split_seqs
	rm -r $(TEST_OUTDIR); ./intein_finder --mmseqs $(MMSEQS) --use-length-in-refinement --evalue-rpsblast 1e-10 --evalue-mmseqs 1e-10 --evalue-region-refinement 1e-10 --mmseqs-sensitivity 1 --mmseqs-iterations 1 --queries test_files/rnr_seq_4.faa --outdir $(TEST_OUTDIR) --split-queries --cpus-alignment $(THREADS_ALIGNMENT) --cpus-search $(THREADS_SEARCH) && tree $(TEST_OUTDIR) && diff $(TEST_OUTDIR)/results/intein_regions_refined_condensed.txt test_files/test_small_expected.txt

# test_small2: split_seqs
# 	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/small_2.faa --outdir $(TEST_OUTDIR) --cpus $(THREADS) && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/* && diff $(TEST_OUTDIR)/results/intein_regions_refined_condensed.txt test_files/test_small2_expected.txt

# test_long_and_short: split_seqs
# 	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/long_and_short.faa --outdir $(TEST_OUTDIR) --cpus $(THREADS) && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/*

# test_no_inteins: split_seqs
# 	rm -r $(TEST_OUTDIR); ./intein_finder --use-length-in-refinement --mmseqs-sensitivity 5.7 --mmseqs-iterations 2 --queries test_files/no_inteins.faa --outdir $(TEST_OUTDIR) --cpus $(THREADS) && tree $(TEST_OUTDIR) && head $(TEST_OUTDIR)/results/*

split_seqs: $(OBJS)
	$(CC) $(CFLAGS) -I$(SRC_RLIB) -o $(BIN)/$@ -O$(OPTIMIZE) $(SRC)/$@.c $^ $(LDFLAGS)

test_split_seqs: split_seqs
	rm $(TEST_FILES)/split_seqs_in.fa.split_?; valgrind --leak-check=full $(BIN)/split_seqs 2 $(TEST_FILES)/split_seqs_in.fa && diff $(TEST_FILES)/split_seqs_in.fa.split_0 $(TEST_FILES)/split_seqs_split_0_expected.txt && diff $(TEST_FILES)/split_seqs_in.fa.split_1 $(TEST_FILES)/split_seqs_split_1_expected.txt

simple_headers: $(OBJS)
	$(CC) $(CFLAGS) -I$(SRC_RLIB) -o $(BIN)/$@ -O$(OPTIMIZE) $(SRC)/$@.c $^ $(LDFLAGS)

test_simple_headers: simple_headers
	rm $(TEST_FILES)/*.simple_headers.*; valgrind --leak-check=full $(BIN)/simple_headers APPLE $(TEST_FILES)/simple_headers_in.fa && diff $(TEST_FILES)/simple_headers_in.simple_headers.fa $(TEST_FILES)/simple_headers_expected.fa && diff $(TEST_FILES)/simple_headers_in.simple_headers.name_map.txt $(TEST_FILES)/simple_headers_name_map_expected.txt

# START HERE: fix the options to use the named ones
test_homology_search: simple_headers split_seqs
	rm test_files/snazzy_proteins.simple_headers.faa.split_*; rm -r QWFP/; time ruby bin/homology_search.rb --inteins-db assets/intein_sequences/all_derep.faa --seqs test_files/snazzy_proteins.faa --outdir QWFP --mmseqs-threads 8 --mmseqs-iterations 1 --rpsblast-instances 8 --num-splits 2 && tree QWFP

process_input_seqs: $(OBJS)
	$(CC) $(CFLAGS) -I$(SRC_RLIB) -o $(BIN)/$@ -O$(OPTIMIZE) $(SRC)/$@.c $^ $(LDFLAGS)

test_process_input_seqs: process_input_seqs
	rm -r $(TEST_FILES)/PROCESS_INPUT_SEQS_TEST_OUTDIR; valgrind --leak-check=full $(BIN)/process_input_seqs spec/test_files/input/process_input_seqs_input.fa $(TEST_FILES)/PROCESS_INPUT_SEQS_TEST_OUTDIR snazzy_lala 2 8
