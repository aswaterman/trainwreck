#ifndef _HELLACACHE_H
#define _HELLACACHE_H

#include "dc_hc_types.h"
#include <map>
#include <vector>
#include <assert.h>
#include <string.h>

template <class word_t>
class dc_memory_t
{
public:

  virtual void tick() = 0;
  virtual bool request_queue_full() = 0;
  virtual bool response_queue_empty() = 0;
  virtual void request(dc_cpu_cache_request_t<word_t> req) = 0;
  virtual void dequeue_response() = 0;
  virtual dc_cpu_cache_response_t<word_t> peek_response() = 0;
};

template <class word_t>
class dc_cache_t : public dc_memory_t<word_t>
{
public:
  dc_cache_t()
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
struct dc_cache_line_data_t
{
  unsigned char data[size];

  dc_cache_line_data_t() { static_assert(size == sizeof(*this)); }
  dc_cache_line_data_t(const dc_cache_line_data_t<size>& cl) { memcpy(data,cl.data,size); }
  bool operator == (const dc_cache_line_data_t<size>& cl) const { return 0 == memcmp(data,cl.data,size); }
  bool operator != (const dc_cache_line_data_t<size>& cl) const { return !(*this == cl); }
};

template <class word_t, int nwords>
struct dc_cache_line_t
{
  word_t data[nwords];
  vaddr_t tag;
  bool dirty;
  bool busy;
  bool valid;

  dc_cache_line_t() : tag(0), dirty(false), valid(false), busy(false) { memset(data,0,sizeof(data)); }
};

template <class word_t, int nwords, int assoc>
struct dc_cache_set_t
{
  dc_cache_line_t<word_t,nwords> lines[assoc];
  unsigned int repl_bits;
  dc_cache_set_t() : repl_bits(0) {}
};

#define mshr_type dc_mshr_t<word_t,assoc,nsecondary>

template <class word_t>
struct dc_mshr_secondary_t
{
  bool valid;
  op_type type;
  word_t store_data;
  bool bytemask[sizeof(word_t)];
  int offset;
  int cpu_tag;
  
  dc_mshr_secondary_t() : valid(false) {}
};

template <class mm_word_t, int assoc>
struct dc_cache_in_t
{
  bool way_en[assoc];
  vaddr_t access_idx;
  vaddr_t access_offset;
  
  bool dirty_w_en;
  bool dirty_w_data;

  bool tag_valid_w_en;
  bool valid_w_data;
  bool valid_w_busy;
  vaddr_t tag_w_data;
  
  bool repl_w_en;
  unsigned int repl_bits;
  
  bool data_w_en;
  mm_word_t data_w_data;
  bool data_w_bytemask[sizeof(mm_word_t)];
  
  bool meta_read_en;
  vaddr_t meta_read_idx;
  
  bool data_read_en;
};

template <class mm_word_t, int assoc>
struct dc_cache_out_t
{
  unsigned int repl_bits;
  bool valid[assoc];
  bool busy[assoc];
  bool dirty[assoc];
  vaddr_t tag[assoc];
  mm_word_t read_data;
};

template <class word_t, int assoc>
struct dc_mshr_in_t
{
  bool request_valid;
  vaddr_t lookup_idx;
  vaddr_t lookup_tag;
  
  int request_tag;
  vaddr_t offset;
  op_type type;
  word_t store_data;
  bool store_bytemask[sizeof(word_t)];

  bool cache_hit;
  unsigned int repl_bits;
  bool repl_way_valid;
  int repl_way;
  bool repl_way_clean;
  vaddr_t dirty_tag;
  
  bool mm_response_valid;
  int mm_response_tag;
};

template <class my_mshr_type, int nmshr>
struct dc_mshr_out_t
{
  bool dealloc;
  bool secondary_miss;
  int secondary_pos;
  bool finish[nmshr];
  bool hit[nmshr];
  bool free[nmshr];
  bool mm_request[nmshr];
  my_mshr_type rdata;
};

template <class word_t, int assoc, int nsecondary>
struct dc_mshr_t
{
  vaddr_t tag;
  vaddr_t idx;
  vaddr_t dirty_tag;
  bool valid;
  bool dirty;
  
  dc_mshr_secondary_t<word_t> secondary[nsecondary];
  int secondary_pos;
  
  // refill state
  enum state_t { state_writeback, state_refill, state_wait_for_refill, state_finish };
  state_t state;
  int response_pos;
  int request_pos;
  int finish_pos;
  bool way_en[assoc];
  unsigned int repl_bits;
  
  dc_mshr_t() : valid(false) {}
};

template <int assoc>
struct dc_repl_in_t
{
  bool request_valid;
  unsigned int repl_bits;
  bool valid[assoc];
  bool busy[assoc];
  bool dirty[assoc];
};

struct dc_repl_out_t
{
  bool repl_way_valid;
  unsigned int repl_way;
  unsigned int repl_bits;
};

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
class dc_hellacache_t : public dc_cache_t<word_t>
{
public:
  dc_hellacache_t(bool verbose);

  bool request_queue_full();
  bool response_queue_empty();
  void request(dc_cpu_cache_request_t<word_t> req);
  dc_cpu_cache_response_t<word_t> peek_response();
  void dequeue_response();
  void tick();
  void print_stats_log(); 
  void print_stats_total();
  void reset_stats_log();

  dc_cpu_cache_response_t<mm_word_t> mm_response;
  dc_cpu_cache_request_t<mm_word_t>  mm_request;
  bool mm_request_ready;

private:
  dc_mshr_out_t<mshr_type,nmshr> mshr_access(dc_mshr_in_t<word_t,assoc> in);
  dc_cache_out_t<mm_word_t,assoc> cache_access(dc_cache_in_t<mm_word_t,assoc> cache_in);
  dc_repl_out_t replacement_policy(dc_repl_in_t<assoc> in);
  
  static const int access_port_width = sizeof(mm_word_t)/sizeof(word_t);
  static const int nwords = (1<<offset_bits)/access_port_width;
  bool verbose;

  unsigned int r_cache_repl_bits;
  bool r_cache_valid_out[assoc];
  bool r_cache_busy_out[assoc];  
  bool r_cache_dirty_out[assoc];
  vaddr_t r_cache_tag_out[assoc];
  bool r_tag_check_valid;
  
  bool r_cpu_response_valid;
  int r_cpu_response_tag;
  word_t r_cpu_response_data;

  bool r_mm_request_valid;
  vaddr_t r_mm_request_addr;
  mm_word_t r_mm_request_data;
  bool r_mm_request_store;
  int r_mm_request_tag;
  bool r_mm_request[nmshr];  

  int r_amo_replay_data;
  op_type r_amo_replay_type;
  int r_amo_replay_offset;
  bool r_amo_replay;

  int r_cpu_request_amo_data;
  op_type r_cpu_request_amo_type;
  int r_cpu_request_amo_offset;
  bool r_cpu_request_amo;

  mshr_type mshr[nmshr];  
  dc_cache_set_t<mm_word_t,nwords,assoc> sets[1<<idx_bits];
  
  dc_cpu_cache_request_t<word_t> req,r_req;
  dc_cpu_cache_response_t<word_t> resp;
};

static inline unsigned int log2i(unsigned int x)
{
  unsigned int r = 0;
  while(x >>= 1)
    r++;
  return r;
}

#endif
