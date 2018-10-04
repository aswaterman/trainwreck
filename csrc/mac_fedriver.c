#include "mti.h"
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <netdb.h>
#include <pthread.h>
#include <signal.h>
#include <arpa/inet.h>
#include "mac_fedriver.h"

#define MAX_PACKET_SIZE 9000

//#define debug(...)
#define debug fprintf

static int server_sock;

static struct sockaddr_un appserver_addr;

static pthread_t rcv_thread;
static pthread_cond_t rcv_wait_sig;
static pthread_mutex_t rcv_wait_lock;		

static int waiting = 0;
static int rx_length = 0;
static int rx_count = 0;
static char rx_buf[MAX_PACKET_SIZE];

static void *appserver_read_thread(void *buf) {	
	while (1) {
		socklen_t appserver_addr_len = sizeof(appserver_addr);
		rx_length = recvfrom(server_sock, buf, MAX_PACKET_SIZE, 0, (struct sockaddr *)&appserver_addr, &appserver_addr_len);
		
		if (rx_length == -1) {
			debug(stderr, "appserver receive socket error\n");
			pthread_exit(NULL);
		}
		
		waiting = 0;
		
		pthread_mutex_lock(&rcv_wait_lock);
		pthread_cond_wait(&rcv_wait_sig, &rcv_wait_lock);	//simulator thread will
		pthread_mutex_unlock(&rcv_wait_lock);
	}
}

void socket_cleanup(void *sockaddr) {
	if (rcv_thread)
		pthread_kill(rcv_thread, 0);		//kill the receiving thread

	pthread_mutex_destroy(&rcv_wait_lock);
	pthread_cond_destroy(&rcv_wait_sig);

	unlink((char *)sockaddr); 		
	close(server_sock);
}

static int init_socket (void)
{	
  struct sockaddr_un vs_addr;		//verilog simulator address

	server_sock = socket(AF_UNIX, SOCK_DGRAM, 0);
	
	waiting = 1;	

	if (server_sock < 0)
  	{
    		fprintf(stderr, "Can't create a unix domain socket\n");
    		return -1;
  	}

	memset(&vs_addr, 0, sizeof(vs_addr));
	vs_addr.sun_family = AF_UNIX;
  sprintf(vs_addr.sun_path, "/tmp/riscv%d", getuid());
	
	if (unlink(vs_addr.sun_path)==0)	//remove any of existing connections
		fprintf(stderr, "Warning removing existing unix domain socket file %s\n", vs_addr.sun_path);

	if (bind(server_sock, (struct sockaddr *)&vs_addr, sizeof(vs_addr)) < 0) {
                close(server_sock);
                fprintf(stderr, "Can't bind unix domain socket %s\n", vs_addr.sun_path);
                return -1;
        }        
	
	//modelsim callback handler registration
	mti_AddRestartCB(socket_cleanup, vs_addr.sun_path);
	mti_AddQuitCB(socket_cleanup, vs_addr.sun_path);

	//start the receive thread
	pthread_cond_init(&rcv_wait_sig, NULL);
	pthread_mutex_init(&rcv_wait_lock, NULL);

	pthread_create(&rcv_thread, NULL, appserver_read_thread, rx_buf+8);
	
	return 0;
}


DPI_LINK_DECL DPI_DLLESPEC
void init_driver()
{
  init_socket();
}

static int crc32(const char* buffer, int length)
{
  int i, j;
  uint32_t crcreg = 0xFFFFFFFF;
  
  for (j = 0; j < length; ++j)
  {
    unsigned char b = buffer[j];
    for (i = 0; i < 8; ++i)
    {
      if ((crcreg ^ b) & 1)
        crcreg = (crcreg >> 1) ^ 0xEDB88320;
      else
        crcreg >>= 1;
      b >>= 1;
    }
  }

  return crcreg ^ 0xFFFFFFFF;
}

DPI_LINK_DECL DPI_DLLESPEC
void transfer_tx(const tx_request_type *req)
{
  enum tx_state_type {TX_IDLE, START_TX, DATA_TX, TX_DONE};
  static enum tx_state_type tx_state = TX_IDLE;

  static int tx_count = 0;
  static uint8_t tx_buf[MAX_PACKET_SIZE];

	int ret;
	if (tx_state == TX_IDLE) 
	{
		if (req->tx_en == 1)
		{
			tx_state = DATA_TX;
			tx_buf[tx_count++] = req->tx_data;
		}
	}
	else if (tx_state == DATA_TX)
	{
		if (req->tx_en == 1)
		{
			if (tx_count >= 9000)
				debug(stderr,"tx_count >= 8500! something is wrong\n");
			else
				tx_buf[tx_count++] = req->tx_data;
		}
		else
			tx_state = TX_DONE;
	}
	else if (tx_state == TX_DONE)
	{
		if (server_sock <0) 
			debug(stderr, "error trying to send response: server_sock <0\n");
		else   {
			ret = sendto(server_sock, tx_buf+8, tx_count-12, 0, (struct sockaddr*)&appserver_addr, sizeof(appserver_addr));
			debug(stderr, "will send to %s\n",appserver_addr.sun_path); 
			if (ret < 0)		
				perror("sendto");
  		}
		tx_count = 0;
		tx_state = TX_IDLE;
	}
}

const uint8_t preamble[] = { 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5 };


DPI_LINK_DECL DPI_DLLESPEC
void transfer_rx(rx_response_type* resp)
{
  enum rx_state_type {RX_IDLE, DATA_RX, RX_DONE};
  static enum rx_state_type rx_state = RX_IDLE;

	if (rx_state == RX_IDLE) 
	{
		if (waiting==0)
		{			
			//client_sock = poll_socket(rx_buf+8, &nbytes);
			debug(stderr, "Received one packet of size %d\n", rx_length);
			memcpy(rx_buf, preamble, 8); // add preamble

			int minsz = 14+46; // 14 for header, 46 for min packet size
			if (rx_length < minsz)
			{
			    bzero(rx_buf+8+rx_length, (minsz-rx_length));
			    rx_length = minsz;
			}

			int crc = crc32(rx_buf+8, rx_length); // calculate CRC
			memcpy(rx_buf+rx_length+8, &crc, 4);

			rx_length = rx_length + 8 + 4; // preamble + CRC
			rx_count = 0;
			rx_state = DATA_RX;
			waiting = 1;
			
		}
		resp->rxdv = 0;
		resp->rx_data = 0;
	}
	else if (rx_state == DATA_RX) 
	{
		resp->rxdv = 1;
		resp->rx_data = rx_buf[rx_count++];
		if (rx_count == rx_length) {
			rx_state = RX_IDLE;			
			pthread_mutex_lock(&rcv_wait_lock);
			pthread_cond_signal(&rcv_wait_sig);
			pthread_mutex_unlock(&rcv_wait_lock);			
		}
	} 
}


