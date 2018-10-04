Ethernet DMA architecture:

CPU functional pipelines, timing model control (plus CPU reset) and mac address ram are all on a duplex 32-bit ring (separated rx and tx) right now. TX is a token ring, while the Ethernet TX block serves as the master node. Clocked at 100 MHz, the ring is fast enough to support a PCIe x1 link.

Each unit on the debug ring has its own 8-bit pipeline ID (PID) and a 16-bit sequence number.

There are three predefined PIDs currently:

255 – Broadcast PID (can be used to start several DMA engines in different pipelines using one packet) 
254 – MAC address RAM
253- Timing model controller and CPU reset (threads_total, threads_active and reset pipelines)

Sequence number is for reliable transmission.  Appserver should have watchdogs for each pipeline, because they use different sequence numbers. If Appserver did not receive a valid ack packet for the current sequence number, it should resend the request with the same sequence number. The hardware will execute the request if it hasn't service the request. Otherwise, it will return an ACK with the current sequence number without committing any change. Note that the command packet (DMA command packet) is 'atomic' in hardware, so corrupted command packet won't affect the system state. When an ack is received, appserver should increment the sequence number *ONLY* by 1. Appserver always starts sending the first packet with a non-zero sequence number. The hardware may also send an NACK packet back to the appserver, indicating a corrupted packet has been received and resend is required.

Appserver may send new requests to other pipelines without receiving the ack/nack packet from the current pipeline. This will improve the frontend link bandwidth utilization. Broadcast packet (PID=255) may also be considered for starting DMA engines in multiple pipelines simultaneously. However, there is only one 4K-byte TX buffer for all pipelines. Except the mac address configuration ack packet,   any byte of an ack/nack packet above byte 16 (padding after L/T) will be written to the TX buffer before sending to the wires.  Appserver is responsible for not overflowing the TX buffer, since it knows how many bytes each pipeline will return.  

General packet format for both RX and TX:

0-5  : DST MAC 
6-11 : SRC MAC                        -----------> Ethernet Header
12-13: L/T        (16'h8888)
--------------------------------
14-15: padding(all 1)/rx payload (word) if < 60 
16   : packet type 
17   : pid   
18-19: seq #  (nonzero)              ------------>RAMP Gold header
---------------------------------
20 - : payload (32-bit aligned)      ------------>payload

Initialization sequence:

1.Initialize mac address by sending a broadcast Ethernet packet to the MAC address RAM (PID = 254)
Packet format in bytes:

0-5   :  DST MAC (48'hFFFFFFFFFFFF)
6-11  :  SRC MAC (Appserver MAC)
12-13 : L/T        (16'h8888)
14    : padding
15    : 03  (<60 byte packet)
16    : packet type (8'h 3  rstPacketType)
17    : pid   (pid = 8'd254)
18-19 : seq #  (nonzero)
20- 25: Appserver's MAC 
26-31 : Board MAC address
	
Hardware responds an Ack or Nack packet with 0-byte payload. Once the board is configured it will no longer accept any broadcast packet. 

2. Configure the timing model (we may change this if we have multiple pipelines)
Send timing packet (packet type = 8'h2) to PID = 253. 
single 32-bit word payload (from byte 20) :
         20:  threads total 
	 21:  threads active
         22:  start (1) or stop (0) timing model 
         23:  padding  (maybe no need to send at all. I'll check my hardware during simulation)

Hardware responds ack or nack without payload

3.Reset all CPU pipelines by toggling cpurst.
Send reset packet (packet type = 8'h3) to PID = 253 without payload. Threads active and total    will be restored to the maximum (64). Timing model state will be set to 'stop'.
Hardware responds ack or nack without payload.

Read/Write using DMA.
First, send a data packet (packet type = 8'h0) to a pipeline to fill the DMA buffer. 
Data packet payload format (32-bit word address)
0 : inst 0 
1 : data 0
2 : inst 1
3 : data 1
4 : inst  2
5 : data 2 

Hardware responds ack or nack without payload.

Then, send or broadcast a command packet (packet type = 8'h1) to that pipeline to setup and start the DMA engine.
Command packet payload format:
0 (low 16-bit) : Response count in 32-bit words
0 (high 16-bit): Number of threads will be started
1 : dma address reg 0
2 : dma control reg 0   (bit[25:20] is threadid,  bit[19:10] is ctrl_reg.buf_addr,  bit[9:0] is ctrl_reg.count,  bit layout is the same as before)
3 : dma address reg 1
4 : dma control reg 1
.....

The first word (32 bits) in the payload indicates how many words  the ack packet will contain. The commit of DMA command is atomic. If the packet is corrupted or a retry packet (with the old sequence number), none of the start DMA commands will be executed. However, appserver is responsible for setting the 'response count' and '# of threads started' correctly. Otherwise, it will lock up the pipeline forever. 
