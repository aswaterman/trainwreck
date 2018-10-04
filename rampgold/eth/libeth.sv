//---------------------------------------------------------------------------   
// File:        libeth.v
// Author:      Zhangxi Tan
// Description: Data structure for ethernet and the token ring
//------------------------------------------------------------------------------  

`ifndef SYNP94
package libeth;
//import libconf::*;
`endif

typedef enum bit [2:0] {tx_start_empty, tx_start, slot_start, slot_data, tx_none} tx_ring_slot_type;        //MAC: tx_start indicates updating the TX header

typedef struct packed { 
  bit [15:0]          seqnum;   //sequence number
  bit [7:0]           pid;      //pipeline id
  bit [7:0]           ptype;    //packet type
}eth_ring_header_type;

typedef struct packed {
  tx_ring_slot_type      stype;    //slot type
  union packed {      
     eth_ring_header_type header;
     bit [31:0]          data;     //data[0] indicates if it's a corrupted request
  }msg; 
}eth_tx_ring_data_type;

//tx packet format:
//0-5  : DST MAC
//6-11 : SRC MAC
//12-13: L/T
//14-15: padding 
//16   : packet type
//17   : pipeline id
//18-19: seq #
//20-  : data payload

const bit [7:0] BCASTPID = 8'd255;
const bit [7:0] MACPID   = 8'd254;
const bit [7:0] TMPID    = 8'd253;


typedef enum bit [1:0] {rx_start, rx_data, rx_end, rx_none} rx_pipe_slot_type;

const bit [15:0] protocolTypeRAMP = 16'h8888;

const bit [7:0] dataPacketType = 8'h00;
const bit [7:0] cmdPacketType  = 8'h01;
const bit [7:0] tmPacketType   = 8'h02;
const bit [7:0] rstPacketType  = 8'h03;
//const bit [7:0] macPacketType  = 8'd253;        //update mac and send ack
const bit [7:0] ackPacketType  = 8'd254;
const bit [7:0] nackPacketType = 8'd255;
//const bit [7:0] i2cPacketType  = 8'h04;   

typedef struct packed {
   rx_pipe_slot_type     stype;
   union packed {
     eth_ring_header_type  header;
     bit [31:0]            data;      //EOF in MAC: the last bit indicates good/bad frame. 
   }msg;
}eth_rx_pipe_data_type;

//rx packet format
//0-5 : DST MAC
//6-11: SRC MAC
//12-13: L/T
//14-15: padding 
//16: packet type
//17: pipeline id
//18-19: seq #
//20-: data payload (32-bit aligned)

//data/cmd packet payload (32-bit word address)
//0 : inst 0/{#active threads[31:16], tx byte count[15:0]}
//1 : data 0/addr0
//2 : inst 1/cmd0
//3 : data 1/addr1
//4 : inst 2/cmd1


function automatic bit isRetransmit(bit [15:0] seqnum_old, bit[15:0] seqnum_new);     //cwnd == 1
  bit  ret;
  
  ret = (seqnum_new  == seqnum_old) ? '1 : '0; 
  
  return ret; 
endfunction

`ifndef SYNP94
endpackage
`endif
