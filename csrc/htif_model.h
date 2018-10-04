#ifndef __HTIF_H
#define __HTIF_H

#include <string.h>

struct packet;
#include <stdint.h>

class htif_t
{
public:
  htif_t(int _fromhost_fd, int _tohost_fd);
  void send_packet(packet* p);
  void tick();

  int fromhost_fd;
  int tohost_fd;
  uint16_t seqno;
  int loading;
  int flushing;
  int terminating;  
  int storing;
  int rd_cr;
  int wr_cr;
  
  int in_val;
  int in_bits;
  int in_rdy;
  
  int out_rdy;
  int out_val;
  int out_bits;

  int num_in_bytes;
  int num_out_bytes;
  int count_num_in;
  int count_num_out;

  uint8_t buf[85]; //buf[15];
  int start;
  int stop;

  uint64_t req_addr;
  unsigned char req_data[16];
};

#endif // __HTIF_H
