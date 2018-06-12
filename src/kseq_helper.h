#ifndef KSEQ_HELPER_H
#define KSEQ_HELPER_H

#include <stdio.h>
#include <zlib.h>

#include "kseq.h"

KSEQ_INIT(gzFile, gzread)

void kseq_write(FILE* file, kseq_t* seq);

#endif
