/*
   TODO:

   - It will have empty files if you have more splits than the number
     of input sequences.
   - If you pass a directory instead of a file, it hangs.
*/

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <zlib.h>

#include "err_codes.h"
#include "kseq.h"

#define TOO_BIG 10000

KSEQ_INIT(gzFile, gzread)

void kseq_write(FILE* file, kseq_t* seq)
{
  if (seq->qual.l && seq->comment.l) { /* fastq with comment */
    fprintf(file,
            "@%s %s\n"
            "%s\n"
            "+\n"
            "%s\n",
            seq->name.s,
            seq->comment.s,
            seq->seq.s,
            seq->qual.s);
  } else if (seq->qual.l) { /* fastq no comment */
    fprintf(file,
            "@%s\n"
            "%s\n"
            "+\n"
            "%s\n",
            seq->name.s,
            seq->seq.s,
            seq->qual.s);
  } else if (seq->comment.l) { /* fasta with comment */
    fprintf(file,
            ">%s %s\n"
            "%s\n",
            seq->name.s,
            seq->comment.s,
            seq->seq.s);
  } else { /* fasta no comment */
    fprintf(file,
            ">%s\n"
            "%s\n",
            seq->name.s,
            seq->seq.s);
  }
}

int main(int argc, char *argv[])
{
  if (argc != 3) {
    fprintf(stderr,
            "Usage: %s <num splits> <seqs.fa>\n", argv[0]);

    exit(1);
  }

  int i = 0;
  int len = 0;
  int ret_val = 0;

  long l = 0;
  long num_splits = 0;

  unsigned long num_seqs = 0;

  char* arg_num_splits = argv[1];
  char* arg_fname = argv[2];

  char* out_fname = NULL;

  FILE** outfiles = NULL;

  gzFile fp;
  kseq_t* seq;

  errno = 0;
  num_splits = strtol(arg_num_splits, NULL, 10);
  PANIC_IF(stderr,
           errno == ERANGE,
           errno,
           "Problem parsing num_splits: %s",
           strerror(errno));
  PANIC_IF(stderr,
           num_splits < 1,
           OPT_ERR,
           "Need at least 1 split.");
  PANIC_IF(stderr,
           num_splits > TOO_BIG,
           OPT_ERR,
           "Too many splits!  Use less than %d",
           TOO_BIG);


  PANIC_UNLESS_FILE_CAN_BE_READ(stderr, arg_fname);

  fp = gzopen(arg_fname, "r");
  PANIC_IF(stderr,
           fp == Z_NULL,
           FILE_ERR,
           "Could not open %s for reading",
           arg_fname);

  seq = kseq_init(fp);

  /* Set up array with output file handles. */

  len = strnlen(arg_fname, TOO_BIG);
  PANIC_IF(stderr,
           len == TOO_BIG,
           OPT_ERR,
           "File name too long!");

  /*
    len <= for the existing file name part
    .split_ = 7
    max idx of 9999 = 4
    1 for null
  */
  out_fname = malloc(sizeof(char) * (len + 7 + 4 + 1));
  PANIC_MEM(stderr, out_fname);

  outfiles = malloc(sizeof(FILE*) * num_splits);
  PANIC_MEM(stderr, outfiles);

  for (i = 0; i < num_splits; ++i) {
    ret_val = sprintf(out_fname, "%s.split_%d", arg_fname, i);
    PANIC_IF(stderr,
             ret_val < 0,
             STD_ERR,
             "Couldn't create outfile name!");

    errno = 0;
    outfiles[i] = fopen(out_fname, "w");
    PANIC_IF(stderr,
             outfiles[i] == NULL,
             errno,
             "Couldn't open %s for writing: (%s)",
             out_fname,
             strerror(errno));
  }

  free(out_fname);

  while ((l = kseq_read(seq)) >= 0) {
    if (num_seqs % 10000 == 0) {
      fprintf(stderr,
              "LOG -- Reading seq %lu\r",
              num_seqs);
    }

    kseq_write(outfiles[num_seqs % num_splits], seq);

    ++num_seqs;
  }

  kseq_destroy(seq);
  gzclose(fp);

  for (i = 0; i < num_splits; ++i) {
    fclose(outfiles[i]);
  }
  free(outfiles);

  return 0;
}
