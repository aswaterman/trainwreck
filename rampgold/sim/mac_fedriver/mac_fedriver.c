#include "mac_fedriver.h"
#include "socket.h"
#include <stdio.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <sys/un.h>

// #define debug(...)
#define debug fprintf

extern int server_sock;
extern struct sockaddr_un appserver_addr;
extern socklen_t appserver_addr_len;
int waiting = 0;

#define CRCPOLY 0xEDB88320
#define INITXOR 0xFFFFFFFF
#define FINALXOR 0xFFFFFFFF


enum tx_state_type {TX_IDLE, START_TX, DATA_TX, TX_DONE};
typedef enum tx_state_type tx_state_t;
tx_state_t tx_state;

enum rx_state_type {RX_IDLE, DATA_RX, RX_DONE};
typedef enum rx_state_type rx_state_t;
rx_state_t rx_state;

DPI_LINK_DECL DPI_DLLESPEC
void init_driver()
{
  init_socket();
  tx_state = TX_IDLE;
  rx_state = RX_IDLE;
}

/**
 * Computes the CRC32 of the buffer of the given length
 */
int crc32(char *buffer, int length) {
    int i, j;
    uint32_t crcreg = INITXOR;
    
    for (j = 0; j < length; ++j) {
        unsigned char b = buffer[j];
        for (i = 0; i < 8; ++i) {
            if ((crcreg ^ b) & 1) {
                crcreg = (crcreg >> 1) ^ CRCPOLY;
            } else {
                crcreg >>= 1;
            }
            b >>= 1;
        }
    }

    return crcreg ^ FINALXOR;
}

int tx_count = 0;
uint8_t tx_buf[MAX_PACKET_SIZE];

DPI_LINK_DECL DPI_DLLESPEC
void transfer_tx(const tx_request_type *req)
{
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
//		waiting = 0;
		tx_count = 0;
		tx_state = TX_IDLE;
	}
}

int rx_count = 0;
char rx_buf[MAX_PACKET_SIZE];
int rx_length = 0;

const uint8_t preamble[] = { 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5 };

extern pthread_cond_t rcv_wait_sig;
extern pthread_mutex_t rcv_wait_lock;		


DPI_LINK_DECL DPI_DLLESPEC
void transfer_rx(rx_response_type* resp)
{
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


