#include "mm_model.h"
#include <stdexcept>

template<class word_t, int latency, int numwords>
mm_magic_memory_t<word_t,latency,numwords>::mm_magic_memory_t()
{
  req.valid = false;
  for(int i = 0; i < latency; i++)
    resp[i].valid = false;
}

template<class word_t, int latency, int numwords>
bool mm_magic_memory_t<word_t,latency,numwords>::request_queue_full()
{
  return req.valid;
}

template<class word_t, int latency, int numwords>
bool mm_magic_memory_t<word_t,latency,numwords>::response_queue_empty()
{
  return !resp[0].valid;
}

template<class word_t, int latency, int numwords>
void mm_magic_memory_t<word_t,latency,numwords>::request(mm_cpu_cache_request_t<word_t> r)
{
  if(request_queue_full())
    throw std::runtime_error("attempted to request() while blocked!");
  req = r;

  if(r.valid && r.type == op_st)
    set_word(r.addr,r.data,r.bytemask);
}

template<class word_t, int latency, int numwords>
mm_cpu_cache_response_t<word_t> mm_magic_memory_t<word_t,latency,numwords>::peek_response()
{
  return resp[0];
}

template<class word_t, int latency, int numwords>
void mm_magic_memory_t<word_t,latency,numwords>::dequeue_response()
{
  if(response_queue_empty())
    throw std::runtime_error("attempted to get_response() while response_queue_empty!");

  resp[0].valid = false;
}

template<class word_t, int latency, int numwords>
void mm_magic_memory_t<word_t,latency,numwords>::tick()
{
  for(int i = 0; i < latency-1; i++)
    resp[i] = resp[i+1];

  resp[latency-1].valid = false;

  if (req.valid)
  {
    if (req.type == op_ld)
    {
      //if(rand() % 10 == 0)
      //{
      //  resp[latency-1].valid = true;
      //  resp[latency-1].type = op_nack;
      //  resp[latency-1].tag = req.tag;
      //  req.valid = false;
      //  return;
      //}

      bool can_accept = true;
      for(int i = latency - numwords; i < latency; i++)
        can_accept = can_accept && !resp[i].valid;
      if(can_accept)
      {
        for (int i = 0; i < numwords; i++)
        {
          resp[latency - numwords + i].valid = true;
          resp[latency - numwords + i].type  = req.type;
          resp[latency - numwords + i].tag   = req.tag;
          resp[latency - numwords + i].data  = req.type == op_ld ? get_word(req.addr+(i*sizeof(word_t))) : word_t();
          unsigned int* ptr = (unsigned int*)&get_word(req.addr+i*sizeof(word_t));
          //printf("mm_tick() : addr=%08x : data=%08x%08x%08x%08x\n", req.addr+(i*sizeof(word_t)), ptr[3], ptr[2], ptr[1], ptr[0]);
        }
        mm_cache_t<word_t>::num_loads  += req.type == op_ld;
        mm_cache_t<word_t>::num_load_hits  += req.type == op_ld;
        req.valid = false;
      }
    }
    else if (req.type == op_st)
    {
      mm_cache_t<word_t>::num_stores += req.type == op_st;
      mm_cache_t<word_t>::num_store_hits += req.type == op_st;
      req.valid = false;
    }
    else if (req.type == op_ld1)
    {
      bool can_accept = !resp[latency-1].valid;
      if(can_accept)
      {
        resp[latency-1].valid = true;
        resp[latency-1].type  = req.type;
        resp[latency-1].tag   = req.tag;
        resp[latency-1].data  = req.type == op_ld1 ? get_word(req.addr) : word_t();

        mm_cache_t<word_t>::num_loads  += req.type == op_ld1;
        mm_cache_t<word_t>::num_load_hits  += req.type == op_ld1;
        req.valid = false;
      }
    }
  }
}

template<class word_t, int latency, int numwords>
word_t mm_magic_memory_t<word_t,latency,numwords>::get_word(vaddr_t addr)
{
  if(addr % sizeof(word_t))
    throw std::runtime_error("unaligned memory address!");

  if(addr > MM_SIZE)
  {
    printf("get_word addr=%08x\n", addr);
    throw std::runtime_error("out of bounds!");
  }

  word_t retval;
  memcpy(retval.data, &mem[addr], sizeof(word_t));

  return retval;
}

template<class word_t, int latency, int numwords>
void mm_magic_memory_t<word_t,latency,numwords>::set_word(vaddr_t addr, word_t word, bool bytemask[sizeof(word_t)])
{
  if(addr % sizeof(word_t))
    throw std::runtime_error("unaligned memory address!");

  if(addr > MM_SIZE)
  {
    printf("set_word addr=%08x\n", addr);
    throw std::runtime_error("out of bounds!");
  }

  char* dst = &mem[addr];
  const char* src = (const char*)&word;
  for(int i = 0; i < sizeof(word_t); i++)
    if(bytemask[i])
      dst[i] = src[i];
}

template<class word_t, int latency, int numwords>
void mm_magic_memory_t<word_t,latency,numwords>::set_memaddr(char *addr)
{
  mem = addr;
}
