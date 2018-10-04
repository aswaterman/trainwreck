#include "htif_model.h"
#include "htif_model.cc"

#include <DirectC.h>

htif_t* htif = NULL;

extern "C" {

void htif_init
(
  vc_handle fromhost,
  vc_handle tohost
)
{
  htif = new htif_t(*vc_2stVectorRef(fromhost), *vc_2stVectorRef(tohost));
}

void htif_tick
(
  vc_handle htif_start,
  vc_handle htif_stop,

  vc_handle in_val,
  vc_handle in_bits,
  vc_handle in_rdy,

  vc_handle out_rdy,
  vc_handle out_val,
  vc_handle out_bits
)
{

  htif->in_rdy = vc_getScalar(in_rdy);
  htif->out_val = vc_getScalar(out_val);
  vc_get2stVector(out_bits,(U*)&htif->out_bits);

  htif->tick();

  vc_putScalar(htif_start, htif->start);
  vc_putScalar(htif_stop, htif->stop);

  vc_putScalar(in_val, htif->in_val);
  vc_put2stVector(in_bits, (U*)&htif->in_bits);
  vc_putScalar(out_rdy, htif->out_rdy);

}

}
