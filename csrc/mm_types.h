#ifndef _TYPES_H
#define _TYPES_H

#include <string.h>

typedef unsigned int vaddr_t;
enum op_type { op_ld, op_st, op_ld1, op_nack };
static const char* op_name[] = {"ld","st"};

template <class word_t>
struct mm_cpu_cache_request_t
{
  bool valid;
  op_type type;
  vaddr_t addr;
  int tag;
  bool bytemask[sizeof(word_t)];
  word_t data;

  mm_cpu_cache_request_t<word_t>()
  {
    memset(this,0,sizeof(*this));
  }
};

template <class word_t>
struct mm_cpu_cache_response_t
{
  bool valid;
  op_type type;
  int tag;
  word_t data;

  mm_cpu_cache_response_t<word_t>()
  {
    memset(this,0,sizeof(*this));
  }
};

#endif
