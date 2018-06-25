#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <zlib.h>

#include "kseq_helper.h"
#include "const.h"

#include "rlib.h"

/* This just assumes it's a fasta */

int main(int argc, char *argv[])
{
  if (argc != 3) {
    fprintf(stderr,
            "Usage: %s <annotation> <seqs.fa>\n", argv[0]);

    exit(1);
  }

  char* arg_annotation = argv[1];
  char* arg_fname = argv[2];

  rstring* annotation = rstring_new(arg_annotation);
  PANIC_MEM(stderr, annotation);

  rstring* fname = rstring_new(arg_fname);
  PANIC_MEM(stderr, fname);

  rstring* ext = rfile_extname(fname);
  PANIC_MEM(stderr, ext);

  rstring* base = rfile_basename2(fname, ext);
  PANIC_MEM(stderr, base);

  rstring* dir = rfile_dirname(fname);
  PANIC_MEM(stderr, dir);

  rstring* out_fasta =
    rstring_format("%s/%s.simple_headers%s",
                   rstring_data(dir),
                   rstring_data(base),
                   rstring_data(ext));
  PANIC_MEM(stderr, out_fasta);

  rstring* out_name_map =
    rstring_format("%s/%s.simple_headers.name_map.txt",
                   rstring_data(dir),
                   rstring_data(base));
  PANIC_MEM(stderr, out_name_map);

  FILE* out_fasta_f = fopen(rstring_data(out_fasta), "w");
  PANIC_MEM(stderr, out_fasta_f);

  FILE* out_name_map_f = fopen(rstring_data(out_name_map), "w");
  PANIC_MEM(stderr, out_name_map_f);

  rstring_free(dir);
  rstring_free(base);
  rstring_free(ext);


  rstring* new_header = NULL;
  rstring* old_header = NULL;

  long l = 0;
  unsigned long num_seqs = 0;

  gzFile fp;
  kseq_t* seq;

  PANIC_UNLESS_FILE_CAN_BE_READ(stderr, arg_fname);

  fp = gzopen(arg_fname, "r");
  PANIC_IF(stderr,
           fp == Z_NULL,
           FILE_ERR,
           "Could not open %s for reading",
           arg_fname);

  seq = kseq_init(fp);

  while ((l = kseq_read(seq)) >= 0) {
    if (++num_seqs % 10000 == 0) {
      fprintf(stderr,
              "LOG -- Reading seq %lu\r",
              num_seqs);
    }

    if (seq->comment.l) { /* header has comment */
      old_header = rstring_format("%s %s", seq->name.s, seq->comment.s);
    }
    else {
      old_header = rstring_new(seq->name.s);
    }
    PANIC_MEM(stderr, old_header);

    new_header = rstring_format("%s___seq_%lu", arg_annotation, num_seqs);
    PANIC_MEM(stderr, new_header);

    fprintf(out_name_map_f,
            "%s\t%s\n",
            rstring_data(new_header),
            rstring_data(old_header));

    fprintf(out_fasta_f,
            ">%s\n%s\n",
            rstring_data(new_header),
            seq->seq.s);

    rstring_free(new_header);
    rstring_free(old_header);
  }

  kseq_destroy(seq);
  gzclose(fp);

  fclose(out_fasta_f);
  fclose(out_name_map_f);

  rstring_free(annotation);
  rstring_free(fname);
  rstring_free(out_fasta);
  rstring_free(out_name_map);

  return 0;
}
