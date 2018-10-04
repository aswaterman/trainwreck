#include "common.h"
#include "mm_types.h"
#include "mm_param.h"
#include "mm_model.h"
#include "mm_model.cc"

#include <DirectC.h>

const int MM_WORD_SIZE = 1 << LG_MM_WORD_SIZE;
typedef mm_cache_line_data_t<MM_WORD_SIZE> mm_word_t;

mm_magic_memory_t<mm_word_t, MM_LATENCY, MM_REFILL_CYCLES>* mm = NULL;

extern "C" {

void mm_init()
{
  mm = new mm_magic_memory_t<mm_word_t, MM_LATENCY, MM_REFILL_CYCLES>;
  mm->mem = new char [MM_SIZE];
  demand(mm->mem, "can't allocate memory");
}

void memory_tick(
  vc_handle mem_req_val,
  vc_handle mem_req_rdy,
  vc_handle mem_req_op,
  vc_handle mem_req_addr,
  vc_handle mem_req_tag,
  vc_handle mem_req_data,

  vc_handle mem_resp_val,
  vc_handle mem_resp_nack,
  vc_handle mem_resp_tag,
  vc_handle mem_resp_data)
{
  if (!mm->request_queue_full())
  {
    static int store_pos = 0;

    if (vc_getScalar(mem_req_val))
    {
      mm_cpu_cache_request_t<mm_word_t> mem_req;

      mem_req.valid = true;
      vc_get2stVector(mem_req_op,(U*)&mem_req.type);
      if (mem_req.type == 3) mem_req.type = op_st;
      mem_req.addr = *vc_2stVectorRef(mem_req_addr)*MM_WORD_SIZE;
      mem_req.tag = *vc_2stVectorRef(mem_req_tag);
      vc_get2stVector(mem_req_data,(U*)&mem_req.data);
      memset(mem_req.bytemask,1,sizeof(mem_req.bytemask));

      mm->request(mem_req);

      if(mem_req.type == op_st)
        store_pos = (store_pos+1)%MM_REFILL_CYCLES;
    }
  }

  mm->tick();

  if(!mm->response_queue_empty())
  {
    mm_cpu_cache_response_t<mm_word_t> resp;

    resp = mm->peek_response();
    mm->dequeue_response();

    vc_putScalar(mem_resp_val, resp.type != op_nack);
    vc_putScalar(mem_resp_nack, resp.type == op_nack);
    vc_put2stVector(mem_resp_tag, (U*)&resp.tag);
    vc_put2stVector(mem_resp_data,(U*)&resp.data);
  }
  else
  {
    vc_putScalar(mem_resp_val,0);
    vc_putScalar(mem_resp_nack,0);
  }

  if (mm->request_queue_full())
    vc_putScalar(mem_req_rdy,0);
  else
    vc_putScalar(mem_req_rdy,1);

}

}
