#ifndef ERR_CODES_H
#define ERR_CODES_H


/* These are need for the macros to work */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* NOTE when calling kseq_init, kseq calls ks_init which does NOT
   check the calloc calls. */

#define SUCCESS    0

#define ARG_ERR    2
#define FILE_ERR   3
#define KSEQ_ERR   5
#define MEM_ERR    6
#define STD_ERR    1
#define THREAD_ERR 4
#define OPT_ERR    7

#define FILE_ERR_MSG "could not open '%s' for %s"
#define KSEQ_ERR_MSG "could not init kseq on '%s'"
#define MEM_ERR_MSG  "memory error while allocating"
#define STD_ERR_MSG  "an error occured"

#define PANIC_IF(iostream, test, err_type, msg, ...)    \
  do {                                                  \
    if (test) {                                         \
      fprintf(iostream,                                 \
              "FATAL -- %s:%d -- " msg "\n",            \
              __FILE__,                                 \
              __LINE__,                                 \
              ##__VA_ARGS__);                           \
      exit(err_type);                                   \
    }                                                   \
  } while (0)

#define PANIC_UNLESS(iostream, test, err_type, msg, ...)        \
  do {                                                          \
    if (!(test)) {                                              \
      fprintf(iostream,                                         \
              "FATAL -- %s:%d -- " msg "\n",                    \
              __FILE__,                                         \
              __LINE__,                                         \
              ##__VA_ARGS__);                                   \
      exit(err_type);                                           \
    }                                                           \
  } while (0)

#define PANIC_MEM(iostream, var)                                \
  do {                                                          \
    if (var == NULL) {                                          \
      fprintf(iostream,                                         \
              "FATAL -- %s:%d -- " MEM_ERR_MSG " " #var " \n",  \
              __FILE__,                                         \
              __LINE__);                                        \
      exit(MEM_ERR);                                            \
    }                                                           \
  } while (0)

#define PANIC_UNLESS_FILE_CAN_BE_READ(iostream, fname)                  \
  do {                                                                  \
    int err_codes_fd = open(fname, O_RDONLY);                           \
    PANIC_IF(iostream,                                                  \
             err_codes_fd == -1,                                        \
             errno,                                                     \
             "Could not read file '%s': %s",                            \
             fname,                                                     \
             strerror(errno));                                          \
    PANIC_UNLESS(iostream,                                              \
                 close(err_codes_fd) == 0,                              \
                 errno,                                                 \
                 "Could not close fd (%d) associated with file "        \
                 "'%s': %s",                                            \
                 err_codes_fd,                                          \
                 fname,                                                 \
                 strerror(errno));                                      \
  } while (0)

#define PANIC_IF_FILE_CAN_BE_READ(iostream, fname)                      \
  do {                                                                  \
    int err_codes_fd = open(fname, O_RDONLY);                           \
    PANIC_UNLESS(iostream,                                              \
                 err_codes_fd == -1,                                    \
                 STD_ERR,                                               \
                 "The file '%s' already exists",                        \
                 fname);                                                \
    if (err_codes_fd != -1) {                                           \
      PANIC_UNLESS(iostream,                                            \
                   close(err_codes_fd) == 0,                            \
                   errno,                                               \
                   "Could not close fd (%d) associated with file "      \
                   "'%s': %s",                                          \
                   err_codes_fd,                                        \
                   fname,                                               \
                   strerror(errno));                                    \
    }                                                                   \
  } while (0)

#endif
