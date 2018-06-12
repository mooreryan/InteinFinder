#include "kseq_helper.h"

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
