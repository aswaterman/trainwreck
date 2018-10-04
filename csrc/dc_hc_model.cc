#include "dc_hc_model.h"
#include <stdexcept>
#include <stdlib.h>

#define CALC_ADDR(tag,idx,off) ((vaddr_t)((((((tag) << idx_bits)+(idx)) << offset_bits)+(off))*sizeof(word_t)))

inline bool or_reduce(bool* a, int n)
{
  bool x = false;
  for(int i = 0; i < n; i++)
    x |= a[i];
  return x;
}

inline bool and_reduce(bool* a, int n)
{
  bool x = true;
  for(int i = 0; i < n; i++)
    x &= a[i];
  return x;
}

inline int priority_encode(bool* a, int n)
{
  for(int i = 0; i < n; i++)
    if(a[i])
      return i;
  abort();
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::dc_hellacache_t(bool verb)
{
  static_assert(sizeof(mm_word_t) % sizeof(word_t) == 0);
  
  verbose = verb;
 
  req.valid = false;
  r_req.valid = false;
  resp.valid = false; 
  r_tag_check_valid = false;
  r_cpu_response_valid = false;
  r_mm_request_valid = false;  
  mm_response.valid = false;
  mm_request_ready = false;
  r_cpu_request_amo_type = op_ld;
  r_amo_replay_type = op_ld;
  
  r_amo_replay = false;
  r_cpu_request_amo = false;
  dc_cache_t<word_t>::linesize = sizeof(word_t) << offset_bits;
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
bool dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::request_queue_full()
{
  return req.valid;
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
bool dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::response_queue_empty()
{
  return !resp.valid;
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
void dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::request(dc_cpu_cache_request_t<word_t> r)
{
  if(request_queue_full())
    throw std::runtime_error("attempted to request() while request_queue_full()!");
  
  req = r;
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
dc_cpu_cache_response_t<word_t> dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::peek_response()
{
  return resp;
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
void dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::dequeue_response()
{
  if(response_queue_empty())
    throw std::runtime_error("attempted to get_response() while response_queue_empty!");
 
  resp.valid = false; 
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
dc_mshr_out_t<mshr_type,nmshr> dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::mshr_access(dc_mshr_in_t<word_t,assoc> in)
{
  // combinational read of MSHR file
  dc_mshr_out_t<mshr_type,nmshr> out;
  out.dealloc = false;
  out.secondary_miss = false;
  
  // increment counters and do state transitions if the last request to L2 was successful
  if (mm_request_ready && r_mm_request_valid && or_reduce(r_mm_request,nmshr))
  {
    for(int i = 0; i < nmshr; i++)
    {
      if (r_mm_request[i])
      {
        switch(mshr[i].state)
        {
          case mshr_type::state_writeback:            
              if (mshr[i].request_pos == (1<<offset_bits)/access_port_width-1)              
                mshr[i].state = mshr_type::state_refill;
              mshr[i].request_pos = (mshr[i].request_pos + 1) & ((1<<offset_bits)/access_port_width-1);
            break;
          case mshr_type::state_refill:
//               if (mshr[i].request_pos == (1<<offset_bits)/access_port_width-1)
//               if (mshr[i].request_pos == 1)                
                mshr[i].state = mshr_type::state_wait_for_refill;
//               else
//                 mshr[i].request_pos++;              
/*              mshr[i].request_pos = (mshr[i].request_pos + 1) & ((1<<offset_bits)/access_port_width-1);*/
            break;
        }
      }
    }
  }

  for(int i = 0; i < nmshr; i++)
  {
//     if(mshr[i].valid && mshr[i].idx == in.lookup_idx)    
//       out.conflict[i] = in.request_valid;
//     else
//       out.conflict[i] = false;
          
    out.hit[i] = in.request_valid && mshr[i].valid && mshr[i].idx == in.lookup_idx && mshr[i].tag == in.lookup_tag;
    if(out.hit[i])
    {
      out.secondary_pos = mshr[i].secondary_pos;
      out.secondary_miss = in.request_valid && mshr[i].secondary_pos != nsecondary && mshr[i].state != mshr_type::state_finish;
    }
    
    out.free[i] = !or_reduce(out.free,i) && !mshr[i].valid;
    
    out.finish[i] = !or_reduce(out.finish,i) && mshr[i].valid && !in.mm_response_valid && mshr[i].state == mshr_type::state_finish;

    if(out.finish[i] && (mshr[i].secondary[mshr[i].finish_pos].type != op_amo_or)
                     && (mshr[i].secondary[mshr[i].finish_pos].type != op_amo_and)
                     && (mshr[i].secondary[mshr[i].finish_pos].type != op_amo_add))
    {
//      printf("out.finish[%d] == true : mshr[%d].finish_pos == %d : mshr[%d].secondary[mshr[%d].finish_pos+1].valid == %s\n", i, i, mshr[i].finish_pos, i, i, mshr[i].secondary[mshr[i].finish_pos+1].valid ? "true" : "false");
      out.dealloc = mshr[i].finish_pos == nsecondary-1 || !mshr[i].secondary[mshr[i].finish_pos+1].valid;
    }  

    out.mm_request[i] = !or_reduce(out.mm_request,i) && mshr[i].valid && (mshr[i].state == mshr_type::state_writeback || mshr[i].state == mshr_type::state_refill);
    r_mm_request[i] = out.mm_request[i];
  }
  
  int raddr = 0; // XXX
  for(int i = 0; i < nmshr; i++)
    if(out.mm_request[i])
      raddr = i;
  for(int i = 0; i < nmshr; i++)
    if(out.finish[i])
      raddr = i;
  if(in.mm_response_valid)
    raddr = in.mm_response_tag;
  out.rdata = mshr[raddr];
  
  // update MSHRs (this happens on the subsequent rising edge)
//   bool request_pos_inc = false;
  bool alloc_mshr = false;
  if(in.mm_response_valid)
    ;
  else if(or_reduce(out.finish,nmshr))
    ;
//   else if(in.mm_can_request && or_reduce(out.mm_request,nmshr))
//     request_pos_inc = true;
  else if(or_reduce(out.mm_request,nmshr))
    ;
  else if(in.request_valid)
  {
    if(in.cache_hit)
      ;
/*    else if(!out.conflict && or_reduce(out.free,nmshr))*/
    else if(!or_reduce(out.hit, nmshr) && or_reduce(out.free,nmshr) && in.repl_way_valid)
      alloc_mshr = true;
    else if (!or_reduce(out.hit, nmshr) && or_reduce(out.free,nmshr))
        printf("DCache: Couldn't allocate MSHR - all destination ways are busy\n");
  }
  
  for(int i = 0; i < nmshr; i++)
  {
    switch(mshr[i].state)
    {
//       case mshr_type::state_writeback:
//         if(out.mm_request[i] && request_pos_inc && mshr[i].request_pos == (1<<offset_bits)/access_port_width-1)
//           mshr[i].state = mshr_type::state_refill;
//         break;
//       case mshr_type::state_refill:
//         if(out.mm_request[i] && request_pos_inc && mshr[i].request_pos == (1<<offset_bits)/access_port_width-1)
//           mshr[i].state = mshr_type::state_wait_for_refill;
//         break;
      case mshr_type::state_wait_for_refill:
        if(in.mm_response_valid && i == in.mm_response_tag && mshr[i].response_pos == (1<<offset_bits)/access_port_width-1)
          mshr[i].state = mshr_type::state_finish;
        break;
      case mshr_type::state_finish:
        if(out.dealloc && out.finish[i])
          mshr[i].valid = false;
        break;
    }
    
    if(in.mm_response_valid && i == in.mm_response_tag)
      mshr[i].response_pos = (mshr[i].response_pos + 1) & ((1<<offset_bits)/access_port_width-1);
    
    if(out.finish[i])
      if ((mshr[i].secondary[mshr[i].finish_pos].type == op_amo_or) ||
          (mshr[i].secondary[mshr[i].finish_pos].type == op_amo_and) ||     
          (mshr[i].secondary[mshr[i].finish_pos].type == op_amo_add))  
        mshr[i].secondary[mshr[i].finish_pos].type = op_st;
      else
      {
        mshr[i].finish_pos = mshr[i].finish_pos + 1;
        if (mshr[i].finish_pos == nsecondary)
          mshr[i].finish_pos = 0;
      }

//        mshr[i].finish_pos = (mshr[i].finish_pos + 1) & ((1<<offset_bits)-1);
    
//     if(out.mm_request[i] && request_pos_inc)
//       mshr[i].request_pos = (mshr[i].request_pos + 1) & ((1<<offset_bits)/access_port_width-1);
      
    if(alloc_mshr && out.free[i])
    {
      mshr[i].valid = true;
      mshr[i].dirty = false;
      mshr[i].idx = in.lookup_idx;
      mshr[i].tag = in.lookup_tag;
      mshr[i].dirty_tag = in.dirty_tag;
      mshr[i].repl_bits = in.repl_bits;
      mshr[i].request_pos = 0;
      mshr[i].response_pos = 0;
      mshr[i].finish_pos = 0;
      mshr[i].secondary_pos = 0;
    
      for(int j = 0; j < nsecondary; j++)
        mshr[i].secondary[j].valid = false;
    
      mshr[i].state = in.repl_way_clean ? mshr_type::state_refill : mshr_type::state_writeback;
      
      for(int j = 0; j < assoc; j++)
        mshr[i].way_en[j] = (j == in.repl_way);      
    
      if(verbose)
        printf("MSHR[%x] allocated: addr=%08x, way=%x (%s)\n",i,CALC_ADDR(in.lookup_tag,in.lookup_idx,0),in.repl_way,in.repl_way_clean?"clean":"dirty");
    }
    
    if(alloc_mshr && out.free[i] || (out.hit[i] && out.secondary_miss))
    {
      int secondary_id = alloc_mshr ? 0 : out.secondary_pos;
     
      mshr[i].dirty |= in.type != op_ld; 
      mshr[i].secondary[secondary_id].offset = in.offset;
      mshr[i].secondary[secondary_id].cpu_tag = in.request_tag;
      mshr[i].secondary[secondary_id].type = in.type;
      mshr[i].secondary[secondary_id].store_data = in.store_data;
      for(int j = 0; j < sizeof(word_t); j++)
        mshr[i].secondary[secondary_id].bytemask[j] = in.store_bytemask[j];
      mshr[i].secondary[secondary_id].valid = true;
      
      if (verbose)
        printf("Allocated secondary miss %d to MSHR %d\n", mshr[i].secondary_pos, i);
      
      mshr[i].secondary_pos++;
    }
  }
  
  return out;
}
  
template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
dc_cache_out_t<mm_word_t,assoc> dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::cache_access(dc_cache_in_t<mm_word_t,assoc> cache_in)
{
  dc_cache_out_t<mm_word_t,assoc> out;
  
  if(cache_in.repl_w_en)
    sets[cache_in.access_idx].repl_bits = cache_in.repl_bits;
  
  // metadata read/write port
  for(int i = 0; i < assoc; i++)
  {
    if(cache_in.way_en[i] && cache_in.dirty_w_en)
      sets[cache_in.access_idx].lines[i].dirty = cache_in.dirty_w_data;
    if(cache_in.way_en[i] && cache_in.tag_valid_w_en)
    {
      sets[cache_in.access_idx].lines[i].valid = cache_in.valid_w_data;
      sets[cache_in.access_idx].lines[i].busy  = cache_in.valid_w_busy;
      sets[cache_in.access_idx].lines[i].tag   = cache_in.tag_w_data;      
    }
  }
  // TODO: this should actually have its own read enable signal (i.e. repl_read_en)
  
  if(cache_in.meta_read_en)
    out.repl_bits = sets[cache_in.meta_read_idx].repl_bits;
  for(int i = 0; i < assoc; i++)
  {
    if(cache_in.meta_read_en)
    {
      out.busy[i] = sets[cache_in.meta_read_idx].lines[i].busy;
      out.valid[i] = sets[cache_in.meta_read_idx].lines[i].valid;
      out.dirty[i] = sets[cache_in.meta_read_idx].lines[i].dirty;
      out.tag[i] = sets[cache_in.meta_read_idx].lines[i].tag;
    }
  }
  
  mm_word_t cache_read_data;
  for(int i = 0; i < assoc; i++)
  {
    if(cache_in.way_en[i] && cache_in.data_w_en)
    {
      // byte-masked write to cache line
      char* dst = (char*)&sets[cache_in.access_idx].lines[i].data[cache_in.access_offset/access_port_width];
      const char* src = (const char*)&cache_in.data_w_data;
      for(int j = 0; j < access_port_width*sizeof(word_t); j++)
        if(cache_in.data_w_bytemask[j])
          dst[j] = src[j];

      if(verbose)
      {
        int start,end;
        for(start = 0; !cache_in.data_w_bytemask[start] && start < access_port_width*sizeof(word_t); start++);
        for(end = access_port_width*sizeof(word_t)-1; !cache_in.data_w_bytemask[end] && end >= 0; end--);
//        printf("start == %d : end == %d\n", start, end);
        if(start <= end)
        {
       //   printf("cache[%x] <= 0x",CALC_ADDR(/*write_tag*/0,cache_in.access_idx,cache_in.access_offset/access_port_width*access_port_width)+start);
          printf("cache[%x] <= 0x",CALC_ADDR(/*write_tag*/0,cache_in.access_idx,cache_in.access_offset*access_port_width)+start);
          for(int j = end; j >= start; j--)
            cache_in.data_w_bytemask[j] ? printf("%02x",(unsigned char)dst[j]) : printf("XX");
          printf("\n");
        }
      }
    }
    if(cache_in.way_en[i] && cache_in.data_read_en)
      out.read_data = sets[cache_in.access_idx].lines[i].data[cache_in.access_offset/access_port_width];
    assert(!(cache_in.data_read_en && cache_in.data_w_en));
  }
  
  return out;
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
dc_repl_out_t dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::replacement_policy(dc_repl_in_t<assoc> in)
{
  dc_repl_out_t out;
//   out.repl_way = rand() % assoc;
//   for(int i = 0; i < assoc; i++)
//     if(!in.dirty[i])
//       out.repl_way = i;
//   for(int i = 0; i < assoc; i++)
//     if(!in.valid[i] & !in.busy[i])
//       out.repl_way = i;

  out.repl_way_valid = false;
  out.repl_way = 0;
  out.repl_bits = 0;
  if (in.request_valid)
  {
    unsigned int next = (in.repl_bits + 1) % assoc;
    if (!in.busy[next])
    {
      out.repl_way_valid = true;
      out.repl_way = in.repl_bits;
      out.repl_bits = next;
    }
  }

  return out;
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
void dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::tick()
{
  int word_offset_bits = log2i(sizeof(word_t));

  bool amo_replay=false;
  int amo_replay_offset=0;

  // software interface from L2

  // HW ports from L2
  bool mm_response_valid = mm_response.valid;
  mm_word_t mm_response_data = mm_response.data;
  vaddr_t mm_response_tag = mm_response.tag;
  
  // combinational signals from CPU
  int tag_check_idx = (req.addr >> (word_offset_bits+offset_bits)) & ((1<<idx_bits)-1);
  int tag_check_tag =  req.addr >> (word_offset_bits+offset_bits+idx_bits);
  
  // signals delayed a cycle from CPU
  bool cpu_request_valid = r_req.valid;
  bool cpu_request_st  = r_req.type == op_st;
  bool cpu_request_amo = r_req.valid & ((r_req.type == op_amo_or) || (r_req.type == op_amo_and) || (r_req.type == op_amo_add));
  int cpu_request_amo_offset = 0;

  op_type cpu_request_type = r_req.type;
  vaddr_t cpu_request_addr = r_req.addr;
  word_t cpu_request_data = r_req.data;
  bool* cpu_request_bytemask = r_req.bytemask;
  int cpu_request_tag = r_req.tag;

//   if (verbose)
//   {
//     printf("cpu_request_valid == %s : cpu_request_type == %s : cpu_request_addr = %08x\n", cpu_request_valid ? "true" : "false", op_name[cpu_request_type], cpu_request_addr);
//   }
  
  // verify that request is a legal AMO
  // if access port width > 32 bits
  // bytemask must have 4 high bits
  // aligned along a 32 bit boundary
  if (cpu_request_amo)
  {
    bool invalid_amo = false;
    int bits = 0;

    for (int i=0;i<sizeof(word_t);i++)
    {
      if (cpu_request_bytemask[i])
      {
        if (bits == 0)
        {
          if (i % 4)
            invalid_amo = true;
          else
            cpu_request_amo_offset = i >> 2;
        }
        bits++;
      }
    }

    if (bits != 4)
      invalid_amo = true;
    if (invalid_amo)    
      throw std::runtime_error("Invalid AMO - improper number or alignment of bits in bytemask!");    
  }


  // HW ports to CPU
  bool cpu_request_ack = false;
  // assume cpu_can_respond is always true.

  dc_cache_t<word_t>::num_cycles_mem_busy += r_mm_request_valid && ~mm_request_ready;
  
  // HW ports to L2
  bool mm_response_ack = false;  
  bool mm_request_valid = false;
  vaddr_t mm_request_addr;
  mm_word_t mm_request_data;
  bool mm_request_store;
  int mm_request_tag;
  
  // address breakdown
  int lookup_offset = (cpu_request_addr >> word_offset_bits) & ((1<<offset_bits)-1);
  int lookup_idx = (cpu_request_addr >> (word_offset_bits+offset_bits)) & ((1<<idx_bits)-1);
  int lookup_tag =  cpu_request_addr >> (word_offset_bits+offset_bits+idx_bits);
  
  // cache tag check
  bool dc_cache_tag_match[assoc];
  bool cache_hit = false;
  for(int i = 0; i < assoc; i++)
    cache_hit |= dc_cache_tag_match[i] = r_cache_valid_out[i] && r_cache_tag_out[i] == lookup_tag;
  cache_hit &= cpu_request_valid && r_tag_check_valid;
  
  dc_repl_in_t<assoc> repl_in;
  repl_in.request_valid = r_tag_check_valid;
  repl_in.repl_bits = r_cache_repl_bits;
  for(int i = 0; i < assoc; i++)
    repl_in.valid[i] = r_cache_valid_out[i];
  for(int i = 0; i < assoc; i++)
    repl_in.dirty[i] = r_cache_dirty_out[i];
  for(int i = 0; i < assoc; i++)
    repl_in.busy[i] = r_cache_busy_out[i];
  
  dc_repl_out_t repl_out = replacement_policy(repl_in);
  //int repl_way = rand() % assoc;
  bool repl_way_valid = repl_out.repl_way_valid;
  int repl_way = repl_out.repl_way;
  
  dc_mshr_in_t<word_t,assoc> mshr_in;
  mshr_in.request_valid = cpu_request_valid && r_tag_check_valid;
  mshr_in.lookup_idx = lookup_idx;
  mshr_in.lookup_tag = lookup_tag;

  mshr_in.request_tag = cpu_request_tag;
  mshr_in.offset = lookup_offset;
//   mshr_in.store = cpu_request_st;
  mshr_in.type = r_req.type;
  mshr_in.store_data = cpu_request_data;  
  for(int i = 0; i < sizeof(word_t); i++)
    mshr_in.store_bytemask[i] = cpu_request_bytemask[i];
  
  mshr_in.cache_hit = cache_hit;
  mshr_in.repl_bits = repl_out.repl_bits;
  mshr_in.repl_way = repl_out.repl_way;
  mshr_in.repl_way_valid = repl_out.repl_way_valid;
  mshr_in.repl_way_clean =  !r_cache_valid_out[repl_out.repl_way] || !r_cache_dirty_out[repl_out.repl_way];
  mshr_in.dirty_tag = r_cache_tag_out[repl_out.repl_way];
  mshr_in.mm_response_valid = mm_response_valid;
  mshr_in.mm_response_tag = mm_response_tag;
  
  dc_mshr_out_t<mshr_type,nmshr> mshr_out = mshr_access(mshr_in);
  mshr_type mshr_rdata0 = mshr_out.rdata;
  
  if(cache_hit && or_reduce(mshr_out.hit,nmshr))
    throw std::runtime_error("WTF? Hit in both tag array and MSHR file!");
  
  //int write_tag; // not a HW signal; for debug
  dc_cache_in_t<mm_word_t,assoc> cache_in;
//  cache_in.repl_bits = mshr_rdata0.repl_bits;
  cache_in.repl_bits = repl_out.repl_bits;
  cache_in.access_idx; // XXX
  cache_in.data_read_en = false;
  for(int i = 0; i < assoc; i++)
    cache_in.way_en[assoc] = false;
  cache_in.dirty_w_en = false;
  cache_in.dirty_w_data; // XXX
  cache_in.tag_valid_w_en = false;
  cache_in.valid_w_data; // XXX
  cache_in.valid_w_busy; // XXX
  cache_in.repl_w_en = false;
  cache_in.tag_w_data; // XXX
  cache_in.data_w_en = false;
  cache_in.access_offset; // XXX
  cache_in.data_w_data; // XXX
  for(int i = 0; i < sizeof(mm_word_t); i++)
    cache_in.data_w_bytemask[i] = false;
  
  bool cpu_hit_done = false;
  bool alloc_mshr = false;

  //
  // cache access port
  //
  // we must preferentially handle a response from the memory system.
  // otherwise, resolve any MSHR accesses.
  // otherwise, if there's a CPU request hit, resolve it.
  // otherwise, if there's a CPU request miss, allocate an MSHR.
  // otherwise, send a request to the L2.
  //
  if(mm_response_valid)
  {
    if(verbose)
    {
      printf("Resolving MSHR[%x] refill to addr %x\n",mm_response_tag,CALC_ADDR(mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.response_pos*access_port_width));
    }
    
    cache_in.access_idx = mshr_rdata0.idx;
    for(int i = 0; i < assoc; i++)
      cache_in.way_en[i] = mshr_rdata0.way_en[i];
    cache_in.data_w_en = true;
    cache_in.access_offset = mshr_rdata0.response_pos * access_port_width;
    cache_in.data_w_data = mm_response_data;
    for(int i = 0; i < access_port_width*sizeof(word_t); i++)
      cache_in.data_w_bytemask[i] = true;

    mm_response_ack = true;
    
  }
  // replay MSHR miss queue
  else if(or_reduce(mshr_out.finish,nmshr))
  {
    if(verbose)
    {
      if(mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_st)
      {
//        printf("Resolving MSHR[%x] store %x => [%x] (%x,%x,%x)\n",priority_encode(mshr_out.finish,nmshr),adapter<unsigned int,word_t>::convert(mshr_rdata0.secondary[mshr_rdata0.finish_pos].store_data),CALC_ADDR(mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.secondary[mshr_rdata0.finish_pos].offset),mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.secondary[mshr_rdata0.finish_pos].offset);
        printf("Resolving MSHR[%x] store ", priority_encode(mshr_out.finish,nmshr));
        for (int i=0;i<sizeof(word_t) >> 2;i++)
          printf("%08x", ((unsigned int *)&mshr_rdata0.secondary[mshr_rdata0.finish_pos].store_data)[i]);
        printf(" => [%x] (%x,%x,%x)\n",CALC_ADDR(mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.secondary[mshr_rdata0.finish_pos].offset),mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.secondary[mshr_rdata0.finish_pos].offset);
      }
      else if (mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_ld)
        printf("Resolving MSHR[%x] load to addr %x (%x,%x,%x)\n",priority_encode(mshr_out.finish,nmshr),CALC_ADDR(mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.secondary[mshr_rdata0.finish_pos].offset),mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.secondary[mshr_rdata0.finish_pos].offset);
      else 
        printf("Resolving MSHR[%x] AMO to addr %x (%x,%x,%x)\n",priority_encode(mshr_out.finish,nmshr),CALC_ADDR(mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.secondary[mshr_rdata0.finish_pos].offset),mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.secondary[mshr_rdata0.finish_pos].offset);       
    }

    amo_replay = (mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_amo_or) ||
                      (mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_amo_and) || 
                      (mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_amo_add);

    if (amo_replay)
    {
      while (!mshr_rdata0.secondary[mshr_rdata0.finish_pos].bytemask[amo_replay_offset])
        amo_replay_offset++;
      amo_replay_offset = amo_replay_offset >> 2;
    }

    cache_in.access_idx = mshr_rdata0.idx;
    int way, ways = 0;
    
    for(int i = 0; i < assoc; i++)
    {
      cache_in.way_en[i] = mshr_rdata0.way_en[i];
      if (mshr_rdata0.way_en[i])
      {
        way = i;
        ways++;
      }
    }    

    if (ways != 1)
      printf("ERROR: more than one way simultaneously active? ways = %d\n", ways);
    
    cache_in.data_w_en = mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_st;
    cache_in.dirty_w_en = mshr_out.dealloc;
    cache_in.dirty_w_data = mshr_rdata0.dirty;
    if (mshr_out.dealloc && verbose)
    {
      printf("Marking index %d way %d not busy\n", cache_in.access_idx, way);
    }
    
    cache_in.tag_valid_w_en = mshr_out.dealloc;
    cache_in.tag_w_data = mshr_rdata0.tag;
    cache_in.valid_w_data = true;
    cache_in.valid_w_busy = false;
    cache_in.repl_bits = mshr_rdata0.repl_bits;
    
    cache_in.data_read_en = !(mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_st);
    cache_in.access_offset = mshr_rdata0.secondary[mshr_rdata0.finish_pos].offset;

    word_t store_data = mshr_rdata0.secondary[mshr_rdata0.finish_pos].store_data;
    if (r_amo_replay)
    {
      int amo_data = ((int *)&store_data)[r_amo_replay_offset];
      switch (r_amo_replay_type)
      {
        case op_amo_add : amo_data += r_amo_replay_data; break;
        case op_amo_and : amo_data &= r_amo_replay_data; break;
        case op_amo_or  : amo_data |= r_amo_replay_data; break;
      }
      ((int *)&store_data)[r_amo_replay_offset] = amo_data;
      r_amo_replay = false;
    }
    
    ((word_t*)&cache_in.data_w_data)[cache_in.access_offset % access_port_width] = store_data;
    for(int i = 0; i < sizeof(word_t); i++)
     cache_in.data_w_bytemask[i + (cache_in.access_offset % access_port_width)*sizeof(word_t)] = mshr_rdata0.secondary[mshr_rdata0.finish_pos].bytemask[i];
  }
//   else if(mm_can_request && or_reduce(mshr_out.mm_request,nmshr))
  // issue request to L2 (writeback or read a cache line)
  else if(or_reduce(mshr_out.mm_request,nmshr))
  {
    mm_request_valid = true;
    mm_request_store = (mshr_rdata0.state == mshr_type::state_writeback);
    mm_request_addr = CALC_ADDR(mm_request_store ? mshr_rdata0.dirty_tag : mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.request_pos*access_port_width);
    mm_request_tag = priority_encode(mshr_out.mm_request,nmshr);

    if(verbose)
      if (mm_request_store)
        printf("Writing back addr %x (MSHR[%x])\n",CALC_ADDR(mshr_rdata0.dirty_tag,mshr_rdata0.idx,mshr_rdata0.request_pos*access_port_width),priority_encode(mshr_out.mm_request,nmshr));
      else
        printf("Load from memory addr %x (MSHR[%x])\n", CALC_ADDR(mshr_rdata0.tag,mshr_rdata0.idx,mshr_rdata0.request_pos*access_port_width),priority_encode(mshr_out.mm_request,nmshr));
    
    cache_in.data_read_en = mm_request_store;
    cache_in.access_idx = mshr_rdata0.idx;
    cache_in.access_offset = mshr_rdata0.request_pos*access_port_width;
    for(int j = 0; j < assoc; j++)
      cache_in.way_en[j] = mshr_rdata0.way_en[j];

  }
  // handle a request from CPU
  else if(cpu_request_valid && r_tag_check_valid)
  {    
    if(cache_hit)
    {
      if(verbose)      
      {
        if ((cpu_request_type != op_ld) && (cpu_request_type != op_st))
          printf("Resolving %s hit to addr %x (%x,%x,%x)\n",op_name[cpu_request_type], cpu_request_addr,lookup_tag,lookup_idx,lookup_offset);
        else
          printf("Resolving %s hit to addr %x (%x,%x,%x)\n",cpu_request_st ? "store" : "load",cpu_request_addr,lookup_tag,lookup_idx,lookup_offset);
      }
      
      cache_in.data_read_en = !cpu_request_st;
      cache_in.access_idx = lookup_idx;
      cache_in.access_offset = lookup_offset;
    
      for(int i = 0; i < assoc; i++)
        cache_in.way_en[i] = dc_cache_tag_match[i];
      cache_in.data_w_en = cpu_request_st;

      bool dirty = false;
      vaddr_t tag = 0;
      for(int i = 0; i < assoc; i++)
      {
        dirty |= r_cache_dirty_out[i] && dc_cache_tag_match[i];
        if(dc_cache_tag_match[i]) tag |= r_cache_tag_out[i];
      }
      
      cache_in.dirty_w_en = !dirty && cpu_request_st;      
      cache_in.dirty_w_data = true;
      
      word_t store_data = cpu_request_data;
      if (r_cpu_request_amo)
      {
        int amo_data = ((int *)&store_data)[r_cpu_request_amo_offset];
        switch (r_cpu_request_amo_type)
        {
          case op_amo_add : amo_data += r_cpu_request_amo_data; break;
          case op_amo_and : amo_data &= r_cpu_request_amo_data; break;
          case op_amo_or  : amo_data |= r_cpu_request_amo_data; break;
        }
        ((int *)&store_data)[r_cpu_request_amo_offset] = amo_data;
        r_cpu_request_amo = false;
      }

     ((word_t*)&cache_in.data_w_data)[cache_in.access_offset % access_port_width] = store_data;
      for(int i = 0; i < sizeof(word_t); i++)
        cache_in.data_w_bytemask[i + (cache_in.access_offset % access_port_width)*sizeof(word_t)] = cpu_request_bytemask[i];
      
      cpu_hit_done = true;
    }
    // allocate MSHR on a cache miss
//     else if(!mshr_out.conflict && or_reduce(mshr_out.free,nmshr)) // !conflict implies !mshr_hit
    else if (!or_reduce(mshr_out.hit, nmshr) && or_reduce(mshr_out.free,nmshr) && repl_out.repl_way_valid)
    {
      alloc_mshr = true;
      cache_in.access_idx = lookup_idx;
      for(int i = 0; i < assoc; i++)
        cache_in.way_en[i] = (i == repl_way);
            
      cache_in.tag_valid_w_en = true;
      cache_in.valid_w_data = false;
      cache_in.valid_w_busy = true;
      cache_in.repl_w_en = true;
      
      if (verbose)
        printf("Allocated MSHR : index = %d target way = %d\n", lookup_idx, repl_way);
      
      cache_in.dirty_w_en = true;
      cache_in.dirty_w_data = false;
    }
    // otherwise it should be a secondary miss
  } 
  
  assert(cpu_hit_done + alloc_mshr + mshr_out.secondary_miss <= 1);
  cpu_request_ack = (cpu_hit_done && !cpu_request_amo) || alloc_mshr || mshr_out.secondary_miss;
  cache_in.meta_read_idx = !cpu_request_ack && cpu_request_valid ? lookup_idx : tag_check_idx;
  cache_in.meta_read_en = !(cache_in.dirty_w_en || cache_in.tag_valid_w_en);
  
  dc_cache_out_t<mm_word_t,assoc> cache_out = cache_access(cache_in);
  r_cache_repl_bits = cache_out.repl_bits;
  for(int i = 0; i < assoc; i++)
  {
    r_cache_valid_out[i] = cache_out.valid[i];
    r_cache_busy_out[i] = cache_out.busy[i];
    r_cache_dirty_out[i] = cache_out.dirty[i];
    r_cache_tag_out[i] = cache_out.tag[i];
  }
  
  r_cpu_response_valid = (or_reduce(mshr_out.finish,nmshr) && (mshr_rdata0.secondary[mshr_rdata0.finish_pos].type != op_st)) || (cpu_hit_done && !cpu_request_st);
  r_cpu_response_data = ((word_t*)&cache_out.read_data)[cache_in.access_offset % access_port_width];
  r_cpu_response_tag = or_reduce(mshr_out.finish,nmshr) && !(mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_st) ? mshr_rdata0.secondary[mshr_rdata0.finish_pos].cpu_tag : cpu_request_tag;

  if (amo_replay)
  {
    r_amo_replay_data = ((int *)&r_cpu_response_data)[amo_replay_offset];
    r_amo_replay_type = mshr_rdata0.secondary[mshr_rdata0.finish_pos].type;
    r_amo_replay_offset = amo_replay_offset;
    r_amo_replay = amo_replay;    
  }

  if (cpu_hit_done && cpu_request_amo)
  {
    r_cpu_request_amo_data = ((int *)&r_cpu_response_data)[cpu_request_amo_offset];
    r_cpu_request_amo_type = cpu_request_type;
    r_cpu_request_amo_offset = cpu_request_amo_offset;
    r_cpu_request_amo = cpu_request_amo;
    r_req.type = op_st;
  }
//   r_cpu_request_amo = cpu_request_amo;

  // cpu response port
  resp.valid = r_cpu_response_valid;
  resp.type = op_ld;
  resp.tag = r_cpu_response_tag;
  resp.data = r_cpu_response_data;

//  r_cpu_response_valid = or_reduce(mshr_out.finish,nmshr) && !(mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_st) || cpu_hit_done && !cpu_request_st;
//  r_cpu_response_data = ((word_t*)&cache_out.read_data)[cache_in.access_offset % access_port_width];
//  r_cpu_response_tag = or_reduce(mshr_out.finish,nmshr) && !(mshr_rdata0.secondary[mshr_rdata0.finish_pos].type == op_st) ? mshr_rdata0.secondary[mshr_rdata0.finish_pos].cpu_tag : cpu_request_tag;
  
  // performance counters
  dc_cache_t<word_t>::num_stores +=  cpu_request_st && (alloc_mshr || mshr_out.secondary_miss || cpu_hit_done);
  dc_cache_t<word_t>::num_loads  += !cpu_request_st && (alloc_mshr || mshr_out.secondary_miss || cpu_hit_done);
  dc_cache_t<word_t>::num_store_hits +=  cpu_request_st && cpu_hit_done;
  dc_cache_t<word_t>::num_load_hits  += !cpu_request_st && cpu_hit_done;
  dc_cache_t<word_t>::num_writebacks += cpu_request_valid && r_tag_check_valid && alloc_mshr && !mshr_in.repl_way_clean;
  dc_cache_t<word_t>::num_hits_under_miss += cpu_hit_done && !and_reduce(mshr_out.free,nmshr);
  dc_cache_t<word_t>::num_misses_under_miss += (alloc_mshr || mshr_out.secondary_miss) && !and_reduce(mshr_out.free,nmshr);
  dc_cache_t<word_t>::num_secondary_misses += mshr_out.secondary_miss;
  dc_cache_t<word_t>::num_cycles_idle += !req.valid;
  dc_cache_t<word_t>::num_cycles++;

//   dc_cache_t<word_t>::num_cycles_blocked += req.valid && !cpu_request_ack;
//   dc_cache_t<word_t>::num_cycles_blocked_nomshr += req.valid && !cpu_request_ack && !cache_hit && !or_reduce(mshr_out.free,nmshr);
//   dc_cache_t<word_t>::num_cycles_blocked_nosecondary += req.valid && !cpu_request_ack && !cache_hit && or_reduce(mshr_out.hit,nmshr) && mshr_out.secondary_pos == nsecondary;
//   dc_cache_t<word_t>::num_cycles_blocked_finishing += req.valid && !cpu_request_ack && or_reduce(mshr_out.finish,nmshr);
//   dc_cache_t<word_t>::num_cycles_blocked_refill += req.valid && !cpu_request_ack && mm_response_valid;
//   dc_cache_t<word_t>::num_cycles_idle += !req.valid;
  
  // interface back to CPU
//  if (verbose)
//  {
//     printf("cache_in.meta_read_en == %s\n", cache_in.meta_read_en ? "true" : "false");
//     printf("cpu_request_ack == %s\n", cpu_request_ack ? "true" : "false");
//  }
    
  
  if(cpu_request_ack)
  {
    r_req.valid = false;
  }
  
  if((cpu_request_ack || !r_req.valid) && cache_in.meta_read_en)
  {
    r_req = req;
    req.valid = false;
  }
  
  dc_cache_t<word_t>::num_cycles_blocked += req.valid;
  dc_cache_t<word_t>::num_cycles_blocked_amo += req.valid && cpu_hit_done && cpu_request_amo;
  dc_cache_t<word_t>::num_cycles_blocked_nomshr += req.valid && !cache_hit && !or_reduce(mshr_out.free,nmshr);
  dc_cache_t<word_t>::num_cycles_blocked_nosecondary += req.valid && !cache_hit && or_reduce(mshr_out.hit,nmshr) && mshr_out.secondary_pos == nsecondary;
  dc_cache_t<word_t>::num_cycles_blocked_finishing += req.valid && or_reduce(mshr_out.finish,nmshr);
  dc_cache_t<word_t>::num_cycles_blocked_refill += req.valid && mm_response_valid;
  dc_cache_t<word_t>::num_cycles_blocked_writeback += req.valid && mm_request_valid && mm_request_store;
  dc_cache_t<word_t>::num_cycles_blocked_load += req.valid && mm_request_valid && !mm_request_store;
  dc_cache_t<word_t>::num_cycles_blocked_meta_busy += req.valid && (!r_tag_check_valid || !cache_in.meta_read_en);

  if (verbose && req.valid)
  {
    printf("DCache blocked: ");
    if (!r_tag_check_valid || !cache_in.meta_read_en)
      printf("Metadata RAM busy  ");
    if (cpu_hit_done && cpu_request_amo)
      printf("Handling AMO  ");
    if (!cache_hit && !or_reduce(mshr_out.free,nmshr))
      printf("No free MSHR  ");
    if (!cache_hit && or_reduce(mshr_out.hit,nmshr) && mshr_out.secondary_pos == nsecondary)
      printf("Secondary miss storage full  ");
    if (or_reduce(mshr_out.finish,nmshr))
      printf("Doing replay  ");
    if (mm_response_valid)
      printf("Handling cache refill  ");
    if (mm_request_valid && mm_request_store)
      printf("Writing back cache line to L2  ");
    if (mm_request_valid && !mm_request_store)
      printf("Requesting cache line from L2  ");

    printf("\n");
  }  

  r_tag_check_valid = cache_in.meta_read_en;
  
  // interface down to L2
  mm_request.valid = false;
  if(mm_request_valid)
  {
    mm_request.valid = true;
    mm_request.type = mm_request_store ? op_st : op_ld;
    mm_request.data = cache_out.read_data;
    for(int i = 0; i < sizeof(mm_word_t); i++)
      mm_request.bytemask[i] = true;
    mm_request.addr = mm_request_addr;
    mm_request.tag = mm_request_tag;

    uint32_t* p = (uint32_t*)&mm_request.data;

    if (verbose)
    {
      printf("dc_tick() : mm_request ready=%d type=%d addr=%08x tag=%d\n", mm_request_ready, mm_request.type, mm_request.addr, mm_request.tag);
      printf("dc_tick() : mm_request data=%08x%08x%08x%08x\n", p[3],p[2],p[1],p[0]);
    }
  }

  r_mm_request_valid = mm_request_valid;
  r_mm_request_store = mm_request_store;
  r_mm_request_addr = mm_request_addr;
  r_mm_request_tag = mm_request_tag;
  r_mm_request_data = cache_out.read_data;
  
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
void dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::print_stats_total()
{
  int sm = dc_cache_t<word_t>::num_secondary_misses;
  int st = dc_cache_t<word_t>::num_stores;
  int stm = dc_cache_t<word_t>::num_stores-dc_cache_t<word_t>::num_store_hits;
  int ld = dc_cache_t<word_t>::num_loads;
  int ldm = dc_cache_t<word_t>::num_loads-dc_cache_t<word_t>::num_load_hits;
  int wb = dc_cache_t<word_t>::num_writebacks;
  int ls = dc_cache_t<word_t>::linesize;
  int cycle = dc_cache_t<word_t>::num_cycles;
//   int mem_busy = dc_cache_t<word_t>::num_cycles_mem_busy;
  int blocked = dc_cache_t<word_t>::num_cycles_blocked;
  int l2wb = dc_cache_t<word_t>::num_cycles_blocked_writeback;
  int l2ld = dc_cache_t<word_t>::num_cycles_blocked_load;
  int mb = dc_cache_t<word_t>::num_cycles_blocked_meta_busy;
  
  printf("\nFinished after %d cycles.\n",cycle);
  printf("Cache was idle for %10d cycles (%3.1f%%).\n",dc_cache_t<word_t>::num_cycles_idle,dc_cache_t<word_t>::num_cycles_idle/double(cycle)*100);
  printf("\n");
  printf("Cache was blocked for %10d cycles (%3.1f%% of cycles).\n",dc_cache_t<word_t>::num_cycles_blocked,dc_cache_t<word_t>::num_cycles_blocked/double(cycle)*100);
  printf("   MSHR file full     %10d cycles (%3.1f%% of cycles blocked)\n",dc_cache_t<word_t>::num_cycles_blocked_nomshr,dc_cache_t<word_t>::num_cycles_blocked_nomshr/double(blocked)*100);
  printf("   2ndary misses full %10d cycles (%3.1f%% of cycles blocked)\n",dc_cache_t<word_t>::num_cycles_blocked_nosecondary,dc_cache_t<word_t>::num_cycles_blocked_nosecondary/double(blocked)*100);
  printf("   Resolving misses   %10d cycles (%3.1f%% of cycles blocked)\n",dc_cache_t<word_t>::num_cycles_blocked_finishing,dc_cache_t<word_t>::num_cycles_blocked_finishing/double(blocked)*100);
  printf("   Refilling          %10d cycles (%3.1f%% of cycles blocked)\n",dc_cache_t<word_t>::num_cycles_blocked_refill,dc_cache_t<word_t>::num_cycles_blocked_refill/double(blocked)*100);
  printf("   L2 writeback       %10d cycles (%3.1f%% of cycles blocked)\n",l2wb,l2wb/double(blocked)*100);
  printf("   Metadata RAM busy  %10d cycles (%3.1f%% of cycles blocked)\n",mb,mb/double(blocked)*100);
  printf("   L2 load            %10d cycles (%3.1f%% of cycles blocked)\n",l2ld,l2ld/double(blocked)*100);
  printf("\n");
  printf("%10d stores,   %10d misses (%3.1f%% of stores)\n",st,stm,double(stm)/st*100);
  printf("%10d loads,    %10d misses (%3.1f%% of loads)\n",ld,ldm,double(ldm)/ld*100);
  printf("%10d accesses, %10d misses (%3.1f%% of accesses)\n",st+ld,stm+ldm,double(stm+ldm)/(st+ld)*100);
  printf("%10d hits under miss\n",dc_cache_t<word_t>::num_hits_under_miss);
  printf("%10d primary misses under miss\n",ldm+stm-sm);
  printf("%10d secondary misses under miss\n",sm);
  printf("%10d writebacks (%.1f%% of L1<->Mem traffic)\n",wb,wb/double(wb+stm+ldm)*100);
  printf("%.2f MB CPU<->L1,  %.2f MB L1<->Mem\n",(st+ld)*sizeof(word_t)/double(1<<20),(stm+ldm-sm+wb)*ls/double(1<<20));
  
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
void dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::print_stats_log()
{
  int sm = dc_cache_t<word_t>::num_secondary_misses - dc_cache_t<word_t>::log_num_secondary_misses;
  int st = dc_cache_t<word_t>::num_stores - dc_cache_t<word_t>::log_num_stores;
  int stm = (dc_cache_t<word_t>::num_stores - dc_cache_t<word_t>::log_num_stores) - (dc_cache_t<word_t>::num_store_hits - dc_cache_t<word_t>::log_num_store_hits);
  int ld = dc_cache_t<word_t>::num_loads - dc_cache_t<word_t>::log_num_loads;
  int ldm = (dc_cache_t<word_t>::num_loads - dc_cache_t<word_t>::log_num_loads) - (dc_cache_t<word_t>::num_load_hits - dc_cache_t<word_t>::log_num_load_hits);
  int wb = dc_cache_t<word_t>::num_writebacks - dc_cache_t<word_t>::log_num_writebacks;
  int ls = dc_cache_t<word_t>::linesize;
  int cycle = dc_cache_t<word_t>::num_cycles - dc_cache_t<word_t>::log_num_cycles;
  int idle = dc_cache_t<word_t>::num_cycles_idle - dc_cache_t<word_t>::log_num_cycles_idle;
  int blocked = dc_cache_t<word_t>::num_cycles_blocked - dc_cache_t<word_t>::log_num_cycles_blocked;
  int nomshr = dc_cache_t<word_t>::num_cycles_blocked_nomshr - dc_cache_t<word_t>::log_num_cycles_blocked_nomshr;
  int nosecondary = dc_cache_t<word_t>::num_cycles_blocked_nosecondary - dc_cache_t<word_t>::log_num_cycles_blocked_nosecondary;
  int finishing = dc_cache_t<word_t>::num_cycles_blocked_finishing - dc_cache_t<word_t>::log_num_cycles_blocked_finishing;
  int refill = dc_cache_t<word_t>::num_cycles_blocked_refill - dc_cache_t<word_t>::log_num_cycles_blocked_refill;
  int hum = dc_cache_t<word_t>::num_hits_under_miss - dc_cache_t<word_t>::log_num_hits_under_miss;
  int l2wb = dc_cache_t<word_t>::num_cycles_blocked_writeback - dc_cache_t<word_t>::log_num_cycles_blocked_writeback;
  int l2ld = dc_cache_t<word_t>::num_cycles_blocked_load - dc_cache_t<word_t>::log_num_cycles_blocked_load;
  int mb = dc_cache_t<word_t>::num_cycles_blocked_meta_busy - dc_cache_t<word_t>::log_num_cycles_blocked_meta_busy;
//   int mem_busy = dc_cache_t<word_t>::num_cycles_mem_busy - dc_cache_t<word_t>::log_num_cycles_mem_busy;
  
  printf("\nLogged %d cycles.\n",cycle);
  printf("Cache was idle for %10d cycles (%3.1f%%).\n",idle,idle/double(cycle)*100);
  printf("\n");
  printf("Cache was blocked for %10d cycles (%3.1f%% of cycles).\n",blocked,blocked/double(cycle)*100);
  printf("   MSHR file full     %10d cycles (%3.1f%% of cycles blocked)\n",nomshr,nomshr/double(blocked)*100);
  printf("   2ndary misses full %10d cycles (%3.1f%% of cycles blocked)\n",nosecondary,nosecondary/double(blocked)*100);
  printf("   Replaying misses   %10d cycles (%3.1f%% of cycles blocked)\n",finishing,finishing/double(blocked)*100);
  printf("   Refilling          %10d cycles (%3.1f%% of cycles blocked)\n",refill,refill/double(blocked)*100);
  printf("   L2 writeback       %10d cycles (%3.1f%% of cycles blocked)\n",l2wb,l2wb/double(blocked)*100);
  printf("   Metadata RAM busy  %10d cycles (%3.1f%% of cycles blocked)\n",mb,mb/double(blocked)*100);  
  printf("   L2 load            %10d cycles (%3.1f%% of cycles blocked)\n",l2ld,l2ld/double(blocked)*100);
  printf("\n");
  printf("%10d stores,   %10d misses (%3.1f%% of stores)\n",st,stm,double(stm)/st*100);
  printf("%10d loads,    %10d misses (%3.1f%% of loads)\n",ld,ldm,double(ldm)/ld*100);
  printf("%10d accesses, %10d misses (%3.1f%% of accesses)\n",st+ld,stm+ldm,double(stm+ldm)/(st+ld)*100);
  printf("%10d hits under miss\n",hum);
  printf("%10d primary misses under miss\n",ldm+stm-sm);
  printf("%10d secondary misses under miss\n",sm);
  printf("%10d writebacks (%.1f%% of L1<->Mem traffic)\n",wb,wb/double(wb+stm+ldm)*100);
  printf("%.2f MB CPU<->L1,  %.2f MB L1<->Mem\n",(st+ld)*sizeof(word_t)/double(1<<20),(stm+ldm-sm+wb)*ls/double(1<<20));
  
}

template <class word_t, class mm_word_t, int offset_bits, int idx_bits, int assoc, int nmshr, int nsecondary>
void dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>::reset_stats_log()
{
  dc_cache_t<word_t>::log_num_stores = dc_cache_t<word_t>::num_stores;
  dc_cache_t<word_t>::log_num_loads  = dc_cache_t<word_t>::num_loads;
  dc_cache_t<word_t>::log_num_store_hits =  dc_cache_t<word_t>::num_store_hits;
  dc_cache_t<word_t>::log_num_load_hits  = dc_cache_t<word_t>::num_load_hits;
  dc_cache_t<word_t>::log_num_writebacks = dc_cache_t<word_t>::num_writebacks;
  dc_cache_t<word_t>::log_num_hits_under_miss = dc_cache_t<word_t>::num_hits_under_miss;
  dc_cache_t<word_t>::log_num_misses_under_miss = dc_cache_t<word_t>::num_misses_under_miss;
  dc_cache_t<word_t>::log_num_secondary_misses = dc_cache_t<word_t>::num_secondary_misses;
  dc_cache_t<word_t>::log_num_cycles_blocked = dc_cache_t<word_t>::num_cycles_blocked;
  dc_cache_t<word_t>::log_num_cycles_blocked_amo = dc_cache_t<word_t>::num_cycles_blocked_amo;
  dc_cache_t<word_t>::log_num_cycles_blocked_nomshr = dc_cache_t<word_t>::num_cycles_blocked_nomshr;
  dc_cache_t<word_t>::log_num_cycles_blocked_nosecondary = dc_cache_t<word_t>::num_cycles_blocked_nosecondary;
  dc_cache_t<word_t>::log_num_cycles_blocked_finishing = dc_cache_t<word_t>::num_cycles_blocked_finishing;
  dc_cache_t<word_t>::log_num_cycles_blocked_refill = dc_cache_t<word_t>::num_cycles_blocked_refill;
  dc_cache_t<word_t>::log_num_cycles_blocked_writeback = dc_cache_t<word_t>::num_cycles_blocked_writeback;
  dc_cache_t<word_t>::log_num_cycles_blocked_load = dc_cache_t<word_t>::num_cycles_blocked_load;
  dc_cache_t<word_t>::log_num_cycles_idle = dc_cache_t<word_t>::num_cycles_idle;
  dc_cache_t<word_t>::log_num_cycles = dc_cache_t<word_t>::num_cycles;
  dc_cache_t<word_t>::log_num_cycles_mem_busy = dc_cache_t<word_t>::num_cycles_mem_busy;
  dc_cache_t<word_t>::log_num_cycles_blocked_meta_busy = dc_cache_t<word_t>::num_cycles_blocked_meta_busy;
}
