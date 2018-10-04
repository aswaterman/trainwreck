#include "htif-modelsim.h"
#include <stdint.h>
#include <unistd.h>
#include <stdexcept>
#include <stddef.h>
#include <fcntl.h>
#include <stdio.h>

//#define debug(...)
#define debug(...) fprintf(stderr,__VA_ARGS__)

const size_t RTL_MAX_DATA_SIZE = 8;

struct rtl_packet_t
{
  uint16_t cmd;
  uint16_t seqno;
  uint32_t data_size;
  uint64_t addr;
  uint8_t  data[RTL_MAX_DATA_SIZE];
};

static int fromhost_fd = -1;
static int tohost_fd = -1;
static int can_recv = 1;

DPI_LINK_DECL DPI_DLLESPEC
void
fromhost_getbyte(
    svBit* valid,
    svBitVecVal* bits)
{
  static rtl_packet_t fromhost_buf;
  static int fromhost_pos = 0;
  static int fromhost_bytes = 0;

  if(fromhost_bytes == fromhost_pos)
  {
    if(!can_recv)
    {
      *valid = 0;
      return;
    }
    fromhost_bytes = read(fromhost_fd, &fromhost_buf, sizeof(fromhost_buf));
    fromhost_pos = 0;
    can_recv = 0;

    debug("got %d bytes\n",fromhost_bytes);
    for(int i = 0; i < fromhost_bytes; i++)
      debug("%x ",((unsigned char*)&fromhost_buf)[i]);
    debug("\n");

    if(fromhost_bytes != 16 && fromhost_bytes != 24)
      throw std::logic_error("bad packet size!");
  }

  *valid = 1;
  *bits = ((char*)&fromhost_buf)[fromhost_pos++];
}

DPI_LINK_DECL DPI_DLLESPEC
void
htif_init(
    const char* thost,
    const char* fhost)
{
  tohost_fd = open(thost,O_WRONLY);
  fromhost_fd = open(fhost,O_RDONLY);

  if(tohost_fd == -1 || fromhost_fd == -1)
    throw std::logic_error("error opening pipe!");
}

DPI_LINK_DECL DPI_DLLESPEC
void
tohost_putbyte(
    const svBitVecVal* bits)
{
  static rtl_packet_t tohost_buf;
  static int tohost_bytes = 0;

  ((char*)&tohost_buf)[tohost_bytes++] = *bits;

  if(tohost_bytes >= offsetof(rtl_packet_t,data))
  {
    if(tohost_buf.data_size != 0 && tohost_buf.data_size != 8)
      throw std::logic_error("sending a bad packet!");

    if(tohost_bytes - offsetof(rtl_packet_t,data) == tohost_buf.data_size)
    {
      debug("sending %d bytes\n",tohost_bytes);
      for(int i = 0; i < tohost_bytes; i++)
        debug("%x ",((unsigned char*)&tohost_buf)[i]);
      debug("\n");

      if(write(tohost_fd, &tohost_buf, tohost_bytes) != tohost_bytes)
        throw std::logic_error("error sending packet!");
      tohost_bytes = 0;
      can_recv = 1;
    }
  }
}
