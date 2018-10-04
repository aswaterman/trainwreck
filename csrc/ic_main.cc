#include "ic_types.h"
#include "ic_param.h"
#include "ic_model.h"
#include "ic_model.cc"

#include <DirectC.h>

const int WORD_SIZE = 1 << LG_WORD_SIZE;
const int MM_WORD_SIZE = 1 << LG_MM_WORD_SIZE;
const int assoc = 1 << LG_ASSOC;
const int offset_bits = LG_CL_SIZE;
const int idx_bits = LG_NSETS;

typedef ic_cache_line_data_t<WORD_SIZE> word_t;
typedef ic_cache_line_data_t<MM_WORD_SIZE> mm_word_t;

const int line_size = sizeof(word_t) << offset_bits;
const int cache_size = line_size*assoc << idx_bits;

ic_blocking_cache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc>* icache = NULL;

extern "C" {

void ic_init()
{
  icache = new ic_blocking_cache_t<word_t,mm_word_t,offset_bits,idx_bits,assoc>(0);
}

void ic_tick
(
  vc_handle cache_cpu_ready,
  vc_handle cache_cpu_valid,
  vc_handle cache_cpu_data,

  vc_handle cpu_cache_valid,
  vc_handle cpu_cache_addr,

  vc_handle cache_mem_valid,
  vc_handle cache_mem_addr,

  vc_handle mem_cache_valid,
  vc_handle mem_cache_ready,
  vc_handle mem_cache_data
)
{
  icache->mm_response.valid = vc_getScalar(mem_cache_valid);
  icache->mm_response.tag = 0;
  vc_get2stVector(mem_cache_data,(U*)&icache->mm_response.data);
  icache->mm_request_ready = vc_getScalar(mem_cache_ready);

  if (vc_getScalar(cpu_cache_valid))
  {
    ic_cpu_cache_request_t<word_t> cache_req;

    cache_req.valid = true;
    cache_req.type = op_ld;
    cache_req.addr = *vc_2stVectorRef(cpu_cache_addr)*WORD_SIZE;
    cache_req.tag = 0;

    icache->request(cache_req);
  }

  icache->tick();

  if(!icache->response_queue_empty())
  {
    ic_cpu_cache_response_t<word_t> resp;

    resp = icache->peek_response();
    icache->dequeue_response();

    vc_putScalar(cache_cpu_valid, 1);
    vc_put2stVector(cache_cpu_data,(U*)&resp.data);
  }
  else
  {
    vc_putScalar(cache_cpu_valid, 0);
  }

  if (icache->request_queue_full())
  {
    vc_putScalar(cache_cpu_ready, 0);
  }
  else
  {
    vc_putScalar(cache_cpu_ready, 1);
  }

  icache->mm_request.addr /= MM_WORD_SIZE;
  vc_putScalar(cache_mem_valid, icache->mm_request.valid);
  vc_put2stVector(cache_mem_addr,(U*)&icache->mm_request.addr);
}

}
