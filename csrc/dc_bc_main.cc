#include "dc_bc_types.h"
#include "dc_bc_param.h"
#include "dc_bc_model.h"
#include "dc_bc_model.cc"

#include <DirectC.h>

const int WORD_SIZE = 1 << LG_WORD_SIZE;
const int MM_WORD_SIZE = 1 << LG_MM_WORD_SIZE;
const int assoc = 1 << LG_ASSOC;
const int offset_bits = LG_CL_SIZE;
const int idx_bits = LG_NSETS;

typedef dc_cache_line_data_t<WORD_SIZE> word_t;
typedef dc_cache_line_data_t<MM_WORD_SIZE> mm_word_t;

const int line_size = sizeof(word_t) << offset_bits;
const int cache_size = line_size*assoc << idx_bits;

dc_blocking_cache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc>* dcache = NULL;

extern "C" {

void dc_init()
{
  dcache = new dc_blocking_cache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc>(1);
}

void dc_tick
(
  vc_handle cache_cpu_ready,
  vc_handle cache_cpu_valid,
  vc_handle cache_cpu_data,

  vc_handle cpu_cache_valid,
  vc_handle cpu_cache_store,
  vc_handle cpu_cache_addr,
  vc_handle cpu_cache_data,

  vc_handle cache_mem_valid,
  vc_handle cache_mem_store,
  vc_handle cache_mem_addr,
  vc_handle cache_mem_data,

  vc_handle mem_cache_valid,
  vc_handle mem_cache_ready,
  vc_handle mem_cache_data
)
{
  dcache->mm_response.valid = vc_getScalar(mem_cache_valid);
  dcache->mm_response.tag = 0;
  vc_get2stVector(mem_cache_data,(U*)&dcache->mm_response.data);
  dcache->mm_request_ready = vc_getScalar(mem_cache_ready);

  if (!dcache->request_queue_full())
  {
    if (vc_getScalar(cpu_cache_valid))
    {
      dc_cpu_cache_request_t<word_t> cache_req;

      cache_req.valid = true;
      if (vc_getScalar(cpu_cache_store)) cache_req.type = op_st;
      else cache_req.type = op_ld;
      cache_req.addr = *vc_2stVectorRef(cpu_cache_addr)*WORD_SIZE;
      vc_get2stVector(cpu_cache_data,(U*)&cache_req.data);
      cache_req.tag = 0;

      dcache->request(cache_req);
    }
  }

  dcache->tick();

  if(!dcache->response_queue_empty())
  {
  dc_cpu_cache_response_t<word_t> resp;

    resp = dcache->peek_response();
    dcache->dequeue_response();

    vc_putScalar(cache_cpu_valid, 1);
    vc_put2stVector(cache_cpu_data,(U*)&resp.data);
  }
  else
  {
    vc_putScalar(cache_cpu_valid, 0);
  }

  if (dcache->request_queue_full())
  {
    vc_putScalar(cache_cpu_ready, 0);
  }
  else
  {
    vc_putScalar(cache_cpu_ready, 1);
  }

  dcache->mm_request.addr /= MM_WORD_SIZE;
  vc_putScalar(cache_mem_valid, dcache->mm_request.valid);
  vc_putScalar(cache_mem_store, (dcache->mm_request.type == op_st));
  vc_put2stVector(cache_mem_addr,(U*)&dcache->mm_request.addr);
  vc_put2stVector(cache_mem_data,(U*)&dcache->mm_request.data);
}

}
