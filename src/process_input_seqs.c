/*
  TODO:

  - Change PANIC_MEM for rstring's to check of rstring_bad()

*/

#include <assert.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <zlib.h>

#include "rlib.h"
#include "kseq_helper.h"
#include "const.h"

int main(int argc, char *argv[])
{
  if (argc != 7) {
    fprintf(stderr,
            "Usage: %s <input_seqs> <outdir> <annotation> <num_mmseqs_splits> "
            "<num_rpsblast_splits> <min_len>\n",
            argv[0]);

    exit(1);
  }


  char* arg_input_seqs = argv[1];
  char* arg_outdir = argv[2];
  char* arg_annotation = argv[3];
  char* arg_num_mmseqs_splits = argv[4];
  char* arg_num_rpsblast_splits = argv[5];
  char* arg_min_len = argv[6];

  char* tmp = NULL;

  rstring* input_seqs_basename = NULL;

  rstring* mmseqs_splits_dir = NULL;
  rstring* rpsblast_splits_dir = NULL;
  rstring* output_single_file = NULL;
  rstring* output_stats = NULL;
  rstring* output_name_map = NULL;

  rstring* new_header = NULL;
  rstring* orig_header = NULL;

  FILE* output_single_file_f = NULL;
  FILE* output_stats_f = NULL;
  FILE* output_name_map_f = NULL;

  FILE** mmseqs_splits = NULL;
  FILE** rpsblast_splits = NULL;

  int ret_val = 0;
  int i = 0;

  long l = 0;
  long min_len = 0;
  long num_mmseqs_splits = 0;
  long num_rpsblast_splits = 0;
  long total_seqs = 0;
  long long_seqs = 0;

  gzFile fp = NULL;
  kseq_t* seq = NULL;

  rstring* rstr = NULL;

  /* Check the outdir for existence/errors */
  rstr = rstring_new(arg_outdir);
  PANIC_MEM(stderr, rstr);

  ret_val = rfile_exist(rstr);
  if (ret_val == RFALSE) {
    /* Make the outdir.  read/write/search permissions for owner and
       group.  read/search permissions for others. */
    errno = 0;
    ret_val = mkdir(arg_outdir, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    PANIC_UNLESS(stderr,
                 ret_val == 0,
                 errno,
                 "Could not make directory '%s': %s",
                 arg_outdir,
                 strerror(errno));

  } else if (ret_val == RERROR) {
    rstring_free(rstr);
    kseq_destroy(seq);
    gzclose(fp);

    fprintf(stderr,
            "Error checking on arg_outdir: '%s'\n",
            arg_outdir);
    exit(1);
  }
  rstring_free(rstr);


  /* Make the mmseqs_splits dir.  Same permissions as above. */
  mmseqs_splits_dir = rstring_format("%s/mmseqs_splits", arg_outdir);
  PANIC_MEM(stderr, mmseqs_splits_dir);
  errno = 0;
  /* Do this tmp thing to avoid this warning: 'null argument where
     non-null required' */
  tmp = rstring_data(mmseqs_splits_dir);
  ret_val = mkdir(tmp, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
  PANIC_UNLESS(stderr,
               ret_val == 0,
               errno,
               "Could not make directory '%s': %s",
               rstring_data(mmseqs_splits_dir),
               strerror(errno));

  /* Make the rpsblast_splits dir.  Same permissions as above. */
  rpsblast_splits_dir = rstring_format("%s/rpsblast_splits", arg_outdir);
  PANIC_MEM(stderr, rpsblast_splits_dir);
  errno = 0;
  /* Do this tmp thing to avoid this warning: 'null argument where
     non-null required' */
  tmp = rstring_data(rpsblast_splits_dir);
  ret_val = mkdir(tmp, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
  PANIC_UNLESS(stderr,
               ret_val == 0,
               errno,
               "Could not make directory '%s': %s",
               rstring_data(rpsblast_splits_dir),
               strerror(errno));

  /* Check the input file for errors. */
  rstr = rstring_new(arg_input_seqs);
  PANIC_MEM(stderr, rstr);

  ret_val = rfile_is_file(rstr);
  if (ret_val == RFALSE) {
    rstring_free(rstr);
    fprintf(stderr, "Error: Either file '%s' does not exist or it isn't a regular file.\n", arg_input_seqs);
    exit(1);
  } else if (ret_val == RERROR) {
    rstring_free(rstr);
    fprintf(stderr, "Error checking on arg_input_seqs: '%s'\n", arg_input_seqs);
    exit(1);
  }

  fp = gzopen(arg_input_seqs, "r");
  PANIC_IF(stderr,
           fp == Z_NULL,
           FILE_ERR,
           "Could not open %s for reading",
           arg_input_seqs);

  seq = kseq_init(fp);

  /* Make all the output file names. */
  input_seqs_basename = rfile_basename(rstr);
  PANIC_MEM(stderr, input_seqs_basename);

  output_single_file =
    rstring_format("%s/%s.intein_finder",
                   arg_outdir,
                   rstring_data(input_seqs_basename));
  PANIC_MEM(stderr, output_single_file);

  output_single_file_f =
    fopen(rstring_data(output_single_file), "w");
  PANIC_MEM(stderr, output_single_file_f);


  output_stats =
    rstring_format("%s/%s.intein_finder.stats",
                   arg_outdir,
                   rstring_data(input_seqs_basename));
  PANIC_MEM(stderr, output_stats);

  output_stats_f =
    fopen(rstring_data(output_stats), "w");
  PANIC_MEM(stderr, output_stats_f);


  output_name_map =
    rstring_format("%s/%s.intein_finder.name_map",
                   arg_outdir,
                   rstring_data(input_seqs_basename));
  PANIC_MEM(stderr, output_name_map);

  output_name_map_f =
    fopen(rstring_data(output_name_map), "w");
  PANIC_MEM(stderr, output_name_map_f);

  rstring_free(rstr);




  /* Check num mmseqs_splits */
  errno = 0;
  num_mmseqs_splits = strtol(arg_num_mmseqs_splits, NULL, 10);
  PANIC_IF(stderr,
           errno == ERANGE,
           errno,
           "Problem parsing num_mmseqs_splits: %s",
           strerror(errno));
  PANIC_IF(stderr,
           num_mmseqs_splits < 1,
           OPT_ERR,
           "Need at least 1 split.");
  PANIC_IF(stderr,
           num_mmseqs_splits > TOO_BIG,
           OPT_ERR,
           "Too many mmseqs_splits!  Use less than %d",
           TOO_BIG);

  /* Check num rpsblast_splits */
  errno = 0;
  num_rpsblast_splits = strtol(arg_num_rpsblast_splits, NULL, 10);
  PANIC_IF(stderr,
           errno == ERANGE,
           errno,
           "Problem parsing num_rpsblast_splits: %s",
           strerror(errno));
  PANIC_IF(stderr,
           num_rpsblast_splits < 1,
           OPT_ERR,
           "Need at least 1 split.");
  PANIC_IF(stderr,
           num_rpsblast_splits > TOO_BIG,
           OPT_ERR,
           "Too many rpsblast_splits!  Use less than %d",
           TOO_BIG);

  /* Check min length */
  errno = 0;
  min_len = strtol(arg_min_len, NULL, 10);
  PANIC_IF(stderr,
           errno == ERANGE,
           errno,
           "Problem parsing min_len: %s",
           strerror(errno));

  /* Make the mmseqs splits outfiles */
  mmseqs_splits = malloc(sizeof(FILE*) * num_mmseqs_splits);
  PANIC_MEM(stderr, mmseqs_splits);

  for (i = 0; i < num_mmseqs_splits; ++i) {
    rstr = rstring_format("%s/%s.intein_finder.split_%d",
                          rstring_data(mmseqs_splits_dir),
                          rstring_data(input_seqs_basename),
                          i);
    PANIC_MEM(stderr, rstr);

    mmseqs_splits[i] = fopen(rstring_data(rstr), "w");
    PANIC_IF(stderr,
             mmseqs_splits[i] == NULL,
             errno,
             "Couldn't open %s for writing: (%s)",
             rstring_data(rstr),
             strerror(errno));

    rstring_free(rstr);
  }

  /* Make the rpsblast splits outfiles */
  rpsblast_splits = malloc(sizeof(FILE*) * num_rpsblast_splits);
  PANIC_MEM(stderr, rpsblast_splits);

  for (i = 0; i < num_rpsblast_splits; ++i) {
    rstr = rstring_format("%s/%s.intein_finder.split_%d",
                          rstring_data(rpsblast_splits_dir),
                          rstring_data(input_seqs_basename),
                          i);
    PANIC_MEM(stderr, rstr);

    rpsblast_splits[i] = fopen(rstring_data(rstr), "w");
    PANIC_IF(stderr,
             rpsblast_splits[i] == NULL,
             errno,
             "Couldn't open %s for writing: (%s)",
             rstring_data(rstr),
             strerror(errno));

    rstring_free(rstr);
  }

  while ((l = kseq_read(seq)) >= 0) {
    /* if (num_seqs % 10000 == 0) { */
    /*   fprintf(stderr, */
    /*           "LOG -- Reading seq %lu\r", */
    /*           num_seqs); */
    /* } */

    if (seq->seq.l >= min_len) {
      if (seq->comment.l) { /* header has comment */
        orig_header = rstring_format("%s %s", seq->name.s, seq->comment.s);
      }
      else {
        orig_header = rstring_new(seq->name.s);
      }
      PANIC_MEM(stderr, orig_header);

      /* We want the new header to have the number of long seqs rather
         than the seq number with respect to the total number of
         seqs. */
      new_header = rstring_format("%s___seq_%lu", arg_annotation, long_seqs + 1);
      PANIC_MEM(stderr, new_header);

      /* Write the name map.*/
      fprintf(output_name_map_f,
              "%s\t%s\n",
              rstring_data(new_header),
              rstring_data(orig_header));

      /* Write seqs to single file. */
      fprintf(output_single_file_f,
              ">%s\n%s\n",
              rstring_data(new_header),
              seq->seq.s);

      /* Write seqs to mmseqs_splits. */
      fprintf(mmseqs_splits[long_seqs % num_mmseqs_splits],
              ">%s\n%s\n",
              rstring_data(new_header),
              seq->seq.s);

      /* Write seqs to rpsblast_splits. */
      fprintf(rpsblast_splits[long_seqs % num_rpsblast_splits],
              ">%s\n%s\n",
              rstring_data(new_header),
              seq->seq.s);

      rstring_free(new_header);
      rstring_free(orig_header);

      ++long_seqs;
    }

    ++total_seqs;
  }

  /* Write stats file. */
  fprintf(output_stats_f,
          "total_seqs\t%lu\n"
          "long_seqs\t%lu\n"
          "short_seqs\t%lu\n",
          total_seqs,
          long_seqs,
          total_seqs - long_seqs);


  kseq_destroy(seq);
  gzclose(fp);

  rstring_free(input_seqs_basename);

  rstring_free(mmseqs_splits_dir);
  rstring_free(rpsblast_splits_dir);

  rstring_free(output_single_file);
  rstring_free(output_stats);
  rstring_free(output_name_map);

  fclose(output_single_file_f);
  fclose(output_stats_f);
  fclose(output_name_map_f);

  for (i = 0; i < num_mmseqs_splits; ++i) {
    fclose(mmseqs_splits[i]);
  }
  free(mmseqs_splits);

  for (i = 0; i < num_rpsblast_splits; ++i) {
    fclose(rpsblast_splits[i]);
  }
  free(rpsblast_splits);

}
