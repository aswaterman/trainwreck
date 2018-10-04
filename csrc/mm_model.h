#ifndef _CACHE_H
#define _CACHE_H

#include "mm_types.h"
#include <map>
#include <vector>
#include <assert.h>
#include <string.h>

template <class word_t>
class mm_memory_t
{
public:

  virtual void tick() = 0;
  virtual bool request_queue_full() = 0;
  virtual bool response_queue_empty() = 0;
  virtual void request(mm_cpu_cache_request_t<word_t> req) = 0;
  virtual void dequeue_response() = 0;
  virtual mm_cpu_cache_response_t<word_t> peek_response() = 0;
};

template <class word_t>
class mm_cache_t : public mm_memory_t<word_t>
{
public:
  mm_cache_t()
  {
    memset(&num_stores,0,(char*)&linesize-(char*)&num_stores);
  }

  int num_stores;
  int num_store_hits;
  int num_loads;
  int num_load_hits;
  int num_writebacks;
  int num_hits_under_miss;
  int num_misses_under_miss;
  int num_secondary_misses;
  int num_cycles_blocked;
  int num_cycles_blocked_amo;
  int num_cycles_blocked_nomshr;
  int num_cycles_blocked_nosecondary;
  int num_cycles_blocked_finishing;
  int num_cycles_blocked_refill;
  int num_cycles_blocked_writeback;
  int num_cycles_blocked_load;
  int num_cycles_blocked_meta_busy;
  int num_cycles_idle;
  int num_cycles;
  int num_cycles_mem_busy;

  int log_num_stores;
  int log_num_store_hits;
  int log_num_loads;
  int log_num_load_hits;
  int log_num_writebacks;
  int log_num_hits_under_miss;
  int log_num_misses_under_miss;
  int log_num_secondary_misses;
  int log_num_cycles_blocked;
  int log_num_cycles_blocked_amo;
  int log_num_cycles_blocked_nomshr;
  int log_num_cycles_blocked_nosecondary;
  int log_num_cycles_blocked_finishing;
  int log_num_cycles_blocked_refill;
  int log_num_cycles_blocked_writeback;
  int log_num_cycles_blocked_load;
  int log_num_cycles_blocked_meta_busy;
  int log_num_cycles_idle;
  int log_num_cycles;
  int log_num_cycles_mem_busy;

  int linesize;
};

#define static_assert(x) switch (x) case 0: case (x):

template <int size>
struct mm_cache_line_data_t
{
  unsigned char data[size];

  mm_cache_line_data_t() { static_assert(size == sizeof(*this)); }
  mm_cache_line_data_t(const mm_cache_line_data_t<size>& cl) { memcpy(data,cl.data,size); }
  bool operator == (const mm_cache_line_data_t<size>& cl) const { return 0 == memcmp(data,cl.data,size); }
  bool operator != (const mm_cache_line_data_t<size>& cl) const { return !(*this == cl); }
};

template <class word_t, int latency, int numwords>
class mm_magic_memory_t : public mm_cache_t<word_t>
{
public:
  mm_magic_memory_t();

  void tick();
  bool request_queue_full();
  bool response_queue_empty();
  void request(mm_cpu_cache_request_t<word_t> req);
  mm_cpu_cache_response_t<word_t> peek_response();
  void dequeue_response();

  word_t get_word(vaddr_t addr);
  void set_word(vaddr_t addr, word_t word, bool bytemask[sizeof(word_t)]);
  void set_memaddr(char *addr);

  char *mem;

private:
  mm_cpu_cache_request_t<word_t> req;
  mm_cpu_cache_response_t<word_t> resp[latency];
};

static inline unsigned int log2i(unsigned int x)
{
  unsigned int r = 0;
  while(x >>= 1)
    r++;
  return r;
}

#endif
