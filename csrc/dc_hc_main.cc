#include "dc_hc_types.h"
#include "dc_hc_param.h"
#include "dc_hc_model.h"
#include "dc_hc_model.cc"

#include <DirectC.h>

const int WORD_SIZE = 1 << LG_WORD_SIZE;
const int MM_WORD_SIZE = 1 << LG_MM_WORD_SIZE;
const int assoc = 1 << LG_ASSOC;
const int nmshr = 1 << LG_NMSHR;
const int nsecondary = 1 << LG_NSECONDARY;
const int offset_bits = LG_CL_SIZE;
const int idx_bits = LG_NSETS;

typedef dc_cache_line_data_t<WORD_SIZE> word_t;
typedef dc_cache_line_data_t<MM_WORD_SIZE> mm_word_t;

const int line_size = sizeof(word_t) << offset_bits;
const int cache_size = line_size*assoc << idx_bits;

dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>* dcache = NULL;

extern "C" {

void dc_init()
{
  dcache = new dc_hellacache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc,nmshr,nsecondary>(0);
}

void dc_tick
(
  vc_handle cache_cpu_ready,
  vc_handle cache_cpu_valid,
  vc_handle cache_cpu_tag,
  vc_handle cache_cpu_data,

  vc_handle cpu_cache_valid,
  vc_handle cpu_cache_opcode,
  vc_handle cpu_cache_addr,
  vc_handle cpu_cache_data,
  vc_handle cpu_cache_bytemask,
  vc_handle cpu_cache_tag,

  vc_handle cache_mem_valid,
  vc_handle cache_mem_store,
  vc_handle cache_mem_addr,
  vc_handle cache_mem_tag,
  vc_handle cache_mem_data,

  vc_handle mem_cache_valid,
  vc_handle mem_cache_ready,
  vc_handle mem_cache_tag,
  vc_handle mem_cache_data
)
{
  dcache->mm_response.valid = vc_getScalar(mem_cache_valid);
  dcache->mm_response.tag = *vc_2stVectorRef(mem_cache_tag);
  vc_get2stVector(mem_cache_data,(U*)&dcache->mm_response.data);
  dcache->mm_request_ready = vc_getScalar(mem_cache_ready);
  
  if (!dcache->request_queue_full())
  {
    if (vc_getScalar(cpu_cache_valid))
    {
      dc_cpu_cache_request_t<word_t> cache_req;

      cache_req.valid = true;
      unsigned int opcode = vc_toInteger(cpu_cache_opcode);
      switch (opcode)
      {
        case 0: cache_req.type = op_ld;
                break;
        case 1: cache_req.type = op_st;
                break;
        case 2: cache_req.type = op_amo_or;
                break;
        case 3: cache_req.type = op_amo_and;
                break;
        case 4: cache_req.type = op_amo_add;
                break;
      }
      
      cache_req.addr = *vc_2stVectorRef(cpu_cache_addr)*WORD_SIZE;
      cache_req.tag = *vc_2stVectorRef(cpu_cache_tag);
      vc_get2stVector(cpu_cache_data,(U*)&cache_req.data);

      unsigned int bytemask = vc_toInteger(cpu_cache_bytemask);
      int bytemask_bits = 0;
      for(int i = 0; i < WORD_SIZE; i++)
      {
        if (bytemask & (1 << i))
        {
          cache_req.bytemask[i] = true;
          bytemask_bits++;
        }
      }

      if (cache_req.type == op_st)
        DEBUG("DCache store to address  == %08x, bytemask = %08x, data = %08x\n", cache_req.addr, bytemask, *((unsigned int *)&cache_req.data));
      else
        DEBUG("DCache load from address == %08x\n", cache_req.addr);
        
      dcache->request(cache_req);
    }
  }  
  
  dcache->tick();
  
  dc_cpu_cache_response_t<word_t> resp;
  
  // check for responses from cache
  if(!dcache->response_queue_empty())
  {
    resp = dcache->peek_response();
    dcache->dequeue_response();
    
    vc_putScalar(cache_cpu_valid, 1);
    vc_put2stVector(cache_cpu_tag, (U*)&resp.tag);
    vc_put2stVector(cache_cpu_data,(U*)&resp.data);
  }
  else
  {
    vc_putScalar(cache_cpu_valid, 0);
  }
  
  if (dcache->request_queue_full())
    vc_putScalar(cache_cpu_ready,0);
  else
    vc_putScalar(cache_cpu_ready,1);
  
  // connect L2 request signals
  
  dcache->mm_request.addr /= MM_WORD_SIZE;
  vc_putScalar(cache_mem_valid, dcache->mm_request.valid);
  vc_putScalar(cache_mem_store, (dcache->mm_request.type == op_st));
  vc_put2stVector(cache_mem_addr,(U*)&dcache->mm_request.addr);  
  vc_put2stVector(cache_mem_tag, (U*)&dcache->mm_request.tag);
  vc_put2stVector(cache_mem_data,(U*)&dcache->mm_request.data);
}

}
