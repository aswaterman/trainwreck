#ifndef _CACHE_H
#define _CACHE_H

#include "ic_types.h"
#include <map>
#include <vector>
#include <assert.h>
#include <string.h>

template <class word_t>
class ic_memory_t
{
public:

  virtual void tick() = 0;
  virtual bool request_queue_full() = 0;
  virtual bool response_queue_empty() = 0;
  virtual void request(ic_cpu_cache_request_t<word_t> req) = 0;
  virtual void dequeue_response() = 0;
  virtual ic_cpu_cache_response_t<word_t> peek_response() = 0;
};

template <class word_t>
class ic_cache_t : public ic_memory_t<word_t>
{
public:
  ic_cache_t()
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
struct ic_cache_line_data_t
{
  unsigned char data[size];

  ic_cache_line_data_t() { static_assert(size == sizeof(*this)); }
  ic_cache_line_data_t(const ic_cache_line_data_t<size>& cl) { memcpy(data,cl.data,size); }
  bool operator == (const ic_cache_line_data_t<size>& cl) const { return 0 == memcmp(data,cl.data,size); }
  bool operator != (const ic_cache_line_data_t<size>& cl) const { return !(*this == cl); }
};

template <class word_t, int nwords>
struct ic_cache_line_t
{
  word_t data[nwords];
  vaddr_t tag;
  bool dirty;
  bool busy;
  bool valid;

  ic_cache_line_t() : tag(0), dirty(false), valid(false), busy(false) { memset(data,0,sizeof(data)); }
};

template <class word_t, int nwords, int assoc>
struct ic_cache_set_t
{
  ic_cache_line_t<word_t,nwords> lines[assoc];
  unsigned int repl_bits;
  ic_cache_set_t() : repl_bits(0) {}
};

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc>
class ic_blocking_cache_t : public ic_cache_t<word_t>
{
public:
  ic_blocking_cache_t(bool verb);

  void tick();
  bool request_queue_full();
  bool response_queue_empty();
  void request(ic_cpu_cache_request_t<word_t> req);
  ic_cpu_cache_response_t<word_t> peek_response();
  void dequeue_response();

  ic_cpu_cache_response_t<mm_word_t> mm_response;
  ic_cpu_cache_request_t<mm_word_t>  mm_request;
  bool mm_request_ready;

private:
  static const int access_port_width = sizeof(mm_word_t)/sizeof(word_t);
  static const int nwords = (1<<offset_bits)/access_port_width;

  ic_cache_set_t<mm_word_t,nwords,assoc> sets[1<<idx_bits];
  enum state_t { state_ready, state_writeback, state_refill, state_resolve_miss };
  bool verbose;
  int writeback_pos;
  int refill_request_pos;
  int refill_response_pos;
  state_t state;
  ic_cpu_cache_request_t<word_t> req,r_req;
  ic_cpu_cache_response_t<word_t> resp;
};

static inline unsigned int log2i(unsigned int x)
{
  unsigned int r = 0;
  while(x >>= 1)
    r++;
  return r;
}

#endif
