#include "common.h"
#include "htif_model.h"

#include <unistd.h>
#include <stdio.h>
#include <stdexcept>

enum
{
  APP_CMD_READ_MEM,
  APP_CMD_WRITE_MEM,
  APP_CMD_READ_CONTROL_REG,
  APP_CMD_WRITE_CONTROL_REG,
  APP_CMD_START,
  APP_CMD_STOP,
  APP_CMD_ACK,
  APP_CMD_NACK
};

#define APP_DATA_ALIGN 16
#define APP_MAX_DATA_SIZE 16
#define APP_REAL_REG_SIZE 4
#define APP_MAX_REG_SIZE 8
#define MEMSZ 0x80000000


struct packet
{
  uint16_t cmd;
  uint16_t seqno;
  uint32_t data_size;
  uint64_t addr;
  uint8_t  data[APP_MAX_DATA_SIZE];
};

class packet_error : public std::runtime_error
{
public:
  packet_error(const std::string& s) : std::runtime_error(s) {}
};

class io_error : public packet_error
{
public:
  io_error(const std::string& s) : packet_error(s) {}
};

htif_t::htif_t(int _fromhost_fd, int _tohost_fd)
 : fromhost_fd(_fromhost_fd)
 , tohost_fd(_tohost_fd)
 , seqno(1)
 , loading(0)
 , flushing(0)
 , terminating(0)
 , storing(0)
 , rd_cr(0)
 , wr_cr(0)
 , start(0)
 , stop(0)
 , in_val(0)
 , in_bits(0)
 , out_rdy(0)
{
}

void htif_t::send_packet(packet* p)
{
  while(1) try
  {
    int bytes = write(tohost_fd,p,offsetof(packet,data)+p->data_size);
    if(bytes == -1 || (size_t)bytes != offsetof(packet,data)+p->data_size)
      throw io_error("write failed");
    return;
  }
  catch(io_error e)
  {
    fprintf(stderr,"warning: %s\n",e.what());
  }
}

void htif_t::tick()
{
  int i;
  if (terminating)
  {
     if (count_num_in < num_in_bytes)
     {
        if (in_rdy)
        {
         in_bits = buf[count_num_in];
         count_num_in++;
         in_val=1;
         return;
        }
       else
       {
         return;
       }
    }
    else 
    {
        in_val=0;
        out_rdy = 1;
    
          if (count_num_out == num_out_bytes)
           {
            packet ackpacket = {APP_CMD_ACK,seqno,0,0};
            send_packet(&ackpacket);
            seqno++;
            stop=1;
            num_out_bytes = 0;
            num_in_bytes = 0;
            count_num_in = 0;
            count_num_out = 0;
            terminating=0;
            out_rdy=0;

            return; 
           }
           else
           {
               if (out_val)
               { 
                 buf[count_num_out]=out_bits;
                 count_num_out++;
                 return;
               }
          
              else
              {
               return;
              }
           }
     }
 }  


/*  if (terminating)
  {
    if (count_num_in == num_in_bytes) 
    {  
      in_val = 0;
      out_rdy = 1;

      stop = 1;

      packet ackpacket = {APP_CMD_ACK,seqno,0,0};
      send_packet(&ackpacket);
      seqno++;

      terminating = 0;
      num_out_bytes=0;
      num_in_bytes =0;
      count_num_in=0;
      count_num_out=0;
      out_rdy = 0;

      return;
    }   
    else 
    {
      if (in_rdy) 
      {
        in_bits = buf[count_num_in];
        count_num_in++;
        in_val = 1;
        return;
      }
      return;
    }
  }
 */


  if (loading)
  {
    if (count_num_in < num_in_bytes)
    {
      if (in_rdy)
      {
        in_bits = buf[count_num_in];
        count_num_in++;
        in_val=1;
        return;
      }
      else
      {
        return;
      }
    }
    else 
    {  
      in_val=0;
      out_rdy = 1;
      if (count_num_out == num_out_bytes)
      {
        packet ackpacket = {APP_CMD_ACK,seqno,0,0};  
        for (i = 0; i < APP_MAX_DATA_SIZE; i++)
        {
          req_data[i] = (buf[2+i*2] & 0xf) | ((buf[2+i*2+1] & 0xf) << 4);
        }

        ackpacket.data_size = sizeof(req_data); 
        memcpy(ackpacket.data,req_data,APP_MAX_DATA_SIZE);
        send_packet(&ackpacket);
        seqno++;
        loading = 0;
        out_rdy = 0;
      }          
      else
      {
        if (out_val) 
        {
          buf[count_num_out] = out_bits;
          count_num_out++;
          return;
        }
        else
        {
          return;
        }
      }
    }
  }

  if (storing)
  {
     if (count_num_in < num_in_bytes)
     {
        if (in_rdy)
        {
         in_bits = buf[count_num_in];
         count_num_in++;
         in_val=1;
         return;
        }
       else
       {
         return;
       }
    }
    else 
    {
        in_val=0;
        out_rdy = 1;
    
          if (count_num_out == num_out_bytes)
           {
            packet ackpacket = {APP_CMD_ACK,seqno,0,0};
            send_packet(&ackpacket);
            seqno++;
            num_out_bytes = 0;
            num_in_bytes = 0;
            count_num_in = 0;
            count_num_out = 0;
            storing=0;
            out_rdy=0; 
           }
           else
           {
               if (out_val)
               { 
                 buf[count_num_out]=out_bits;
                 count_num_out++;
                 return;
               }
          
              else
              {
               return;
              }
           }
     }
 }  

  if (rd_cr) 
  {
     if (count_num_in < num_in_bytes) 
     {
       if (in_rdy)
       {
         in_bits = buf[count_num_in];
         count_num_in++;
         in_val=1;
         return;
       }
       else
       {
         return;
       }
     }
     else 
     {
        in_val=0;
        out_rdy = 1;
        if (count_num_out == num_out_bytes)
         {
           packet ackpacket = {APP_CMD_ACK,seqno,0,0};  //this has to be changed cause i have to send buf...
        
           for (i = APP_REAL_REG_SIZE; i<16; i++)
           {
           req_data[i]=0;
           }

           for (i = 0; i< APP_REAL_REG_SIZE ; i++)
           {
            req_data[i] = ((buf[2+i*2] & 0xf)<<0) | ((buf[2+i*2+1]&0xf)<<4);
           }
           ackpacket.data_size = APP_MAX_REG_SIZE;
           memcpy(ackpacket.data,req_data,APP_MAX_REG_SIZE);
           send_packet(&ackpacket);
           seqno++;
           rd_cr = 0;
           out_rdy = 0;
         }
          
       else
       {
          if (out_val) 
          {
              buf[count_num_out] = out_bits;
              count_num_out++;
              return;
          }
          else
          {
             return;
          }
       }
     }
   }


  if (wr_cr || flushing)
  {
     if (count_num_in <  num_in_bytes)
     {
        if (in_rdy)
        {
           in_bits = buf[count_num_in];
           count_num_in++;
           in_val = 1;
           return;
        }
        else 
        {
          return;
        }
     }
    else 
    {
           in_val = 0;
           out_rdy = 1;
           if (count_num_out == num_out_bytes)
            {
             packet ackpacket = {APP_CMD_ACK,seqno,0,0};
             send_packet(&ackpacket);
             seqno++;
             if (flushing) {
                 start = 1;
             }
             flushing = 0;
             wr_cr = 0;
           
             num_out_bytes=0;
             num_in_bytes =0;
             count_num_in=0;
             count_num_out=0;
             out_rdy = 0;
           } 
           else 
           {  
            if (out_val)
            {
              buf[count_num_out]=out_bits;
              count_num_out++;
              return;
            }
         
            else 
            {
             return;
            }
          }
    }
}

  packet p;
  int bytes = read(fromhost_fd,&p,sizeof(p));

  if (bytes == -1)
  {
    return;
  }

  if (p.seqno != seqno)
  {
    printf("nack p.seqno=%d seqno=%d p.cmd=%d p.addr=%016lx!\n", p.seqno, seqno, p.cmd, p.addr);
    return;
  }

  switch (p.cmd)
  {
  case APP_CMD_START:
    count_num_in=0;
    count_num_out=0; 
    buf[0]=4;
    buf[1]=0;
    req_addr = p.addr;

    for (i=2; i< 10; i++)
    {
      buf[i] = (req_addr >> ((i-2)*4)) & 0xf;
    } 
 
/*    for (i=2; i<10; i++)
    {
      buf[i] = 0;
    }
*/
    in_bits = (4>>0) & 0xf; 

    num_in_bytes = 10;
    num_out_bytes = 2;
    flushing = 1;
    if (in_rdy) 
    {
    in_val = 1;
    out_rdy = 1; 
    count_num_in++;
    }
    break;

  case APP_CMD_STOP:
    count_num_in=0;
    count_num_out=0; 
    num_in_bytes = 2;
    num_out_bytes = 2;
    terminating = 1;
    buf[0] = (5 >> 0) & 0xf;
    buf[1] = (5 >> 4) & 0xf;
    in_bits = 5;
    if (in_rdy) 
    {
      in_val = 1;
      out_rdy = 1;
      count_num_in++;
    }
   break;

  case APP_CMD_READ_MEM:
    demand(p.addr % APP_DATA_ALIGN == 0, "misaligned address");
    demand(p.data_size % APP_DATA_ALIGN == 0, "misaligned data");
    demand(p.data_size <= APP_MAX_DATA_SIZE, "long read data");
    demand(p.addr <= MEMSZ && p.addr+p.data_size <= MEMSZ, "out of bounds");
    count_num_in=0;
    count_num_out=0; 
    req_addr = p.addr;
    for (i=0;i<2;i++)
    {
      buf[i]=0;
    }

    for (i=2; i< 10; i++)
    {
      buf[i] = (req_addr >> ((i-2)*4)) & 0xf;
    } 
    in_bits=0;
    out_rdy=0;
    num_in_bytes=10;
    num_out_bytes=34;

    if (in_rdy) 
    {
     in_val=1;
    count_num_in++;
    }  

    loading = 1;
    break;
    
  case APP_CMD_WRITE_MEM:
    demand(p.addr % APP_DATA_ALIGN == 0, "misaligned address");
    demand(p.data_size % APP_DATA_ALIGN == 0, "misaligned data");
    demand(p.data_size <= bytes - offsetof(packet,data), "short packet");
    demand(p.addr <= MEMSZ && p.addr+p.data_size <= MEMSZ, "out of bounds");
    count_num_in=0;
    count_num_out=0; 
    req_addr = p.addr;
    memcpy(req_data,p.data,APP_MAX_DATA_SIZE);
  
    buf[0]=1;
    buf[1]=0;
 
    for (i=2; i< 10; i++)
    {
      buf[i] = (req_addr >> ((i-2)*4)) & 0xf;
    } 
    
    for (i=10; i<42; i++)
    {
      buf[i]=(req_data[(i-10)/2]>>(((i-10)%2)*4)) & 0xf;
    }

    in_bits = 1;
    out_rdy = 0;
    num_in_bytes = 42;
    num_out_bytes = 2;
    
    if (in_rdy) 
    {
    in_val = 1;
    count_num_in++;
    }
    storing = 1;
    break;

  case APP_CMD_READ_CONTROL_REG:
    demand((p.addr >> 16 == 2) || (p.addr & 0xff) == 16,"bad control reg");
    demand(p.data_size == APP_MAX_REG_SIZE,"bad control reg size");
    count_num_in=0;
    count_num_out=0;
  //  printf("we received the rd_cr cmd\n"); 
  
    buf[0]=2;
    buf[1]=0;
    req_addr=p.addr;    
    for (i=2; i< 10; i++)
    {
      buf[i] = (req_addr >> ((i-2)*4)) & 0xf;
    } 
/* 
    for (i=2; i<4; i++)
    {
      buf[i] = (16 >> ((i-2)*4)) & 0xf;
    }
    for (i=4; i<10; i++)
    {
      buf[i] = 0;
    }
*/
    in_bits = 2;
    out_rdy = 0;
    num_in_bytes = 10;
    num_out_bytes = 10;
    if (in_rdy) 
    { 
    in_val = 1;
    count_num_in++ ;
    }
    rd_cr = 1;
  //  printf("we are reading control reg\n");
    break;

  case APP_CMD_WRITE_CONTROL_REG:
    demand((p.addr >> 16 == 2) || (p.addr & 0xff)  ==  17,"bad control reg");
    demand(p.data_size == APP_MAX_REG_SIZE,"bad control reg size");
    count_num_in=0;
    count_num_out=0; 
//    req_data = *(uint64_t*)p.data;
    memcpy(req_data,p.data,APP_MAX_REG_SIZE);
    buf[0]=3;
    buf[1]=0;
    req_addr = p.addr;
    for (i=2; i< 10; i++)
    {
      buf[i] = (req_addr >> ((i-2)*4)) & 0xf;
    } 
 
  /* for (i=2; i<4; i++)
    {
      buf[i] = (17>>((i-2)*4)) & 0xf;
    }
    for (i=4; i<10; i++)
    {
      buf[i] = 0;
    }
*/
    for (i=10; i<18; i++)
    {
       buf[i]=(req_data[(i-10)/2]>>(((i-10)%2)*4)) & 0xf;
    }
    in_bits = 3;
     out_rdy = 0;
    num_in_bytes = 18;
    num_out_bytes = 2;
    if (in_rdy) 
    {
    in_val = 1;
    count_num_in++;
    }
    wr_cr=1;
    break;
  }
}
