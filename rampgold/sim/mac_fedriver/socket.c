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

#include "socket.h"
//#define PORT  (5556+getuid())
#define PORT 5556
#define MAXMSG  9000

#define SOCKET_PATH     "/tmp/riscv"

//#define debug(...)
#define debug fprintf

int server_sock;

struct sockaddr_un	vs_addr;		//verilog simulator address
struct sockaddr_un      appserver_addr;		//appserver address
socklen_t appserver_addr_len;

pthread_t rcv_thread;
pthread_cond_t rcv_wait_sig;
pthread_mutex_t rcv_wait_lock;		

extern int waiting;
extern int  rx_length;			
extern char rx_buf[MAX_PACKET_SIZE];

void *appserver_read_thread(void *buf) {	
	while (1) {
		appserver_addr_len = sizeof(appserver_addr);
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

int init_socket (void) {	
	char port_name[12]; 

	snprintf(port_name, 11, "%d", PORT);
	server_sock = socket(AF_UNIX, SOCK_DGRAM, 0);
	
	waiting = 1;	

	if (server_sock < 0)
  	{
    		fprintf(stderr, "Can't create a unix domain socket\n");
    		return -1;
  	}

	memset(&vs_addr, 0, sizeof(vs_addr));
	vs_addr.sun_family = AF_UNIX;
        
	strcpy(vs_addr.sun_path, SOCKET_PATH);
	strcat(vs_addr.sun_path, port_name);
	
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

#if 0 
static int server_sock;
static int count=0;
static fd_set active_fd_set, read_fd_set;

int init_socket(void)
{
  struct sockaddr_in servername;

  server_sock = socket(PF_INET, SOCK_STREAM, 0);

  if (server_sock < 0)
  {
    perror("socket");
    return -1;
  }

  servername.sin_family = AF_INET;
  servername.sin_port = htons(PORT);
  servername.sin_addr.s_addr = htonl(INADDR_ANY);

  if (bind(server_sock, (struct sockaddr *)&servername, sizeof(servername)) < 0)
  {
    perror("bind");
    return -1;
  }

  if (listen(server_sock, 1) < 0)
  {
    perror("listen");
    return -1;
  }

  /* Initialize the set of active sockets.  */
  FD_ZERO(&active_fd_set);
  FD_SET(server_sock, &active_fd_set);

  debug(stderr, "init_socket! server_sock=%d\n", server_sock);

  return 0;
}

int poll_socket(char* msg, int* nbytes)
{
  struct timeval timeout;
  int nready;
  int client_sock;
  int sock = -1;

  count++;

  timeout.tv_sec = 0;
  timeout.tv_usec = 1;

  /* Block until input arrives on one or more active sockets.  */
  read_fd_set = active_fd_set;
  nready = select(FD_SETSIZE, &read_fd_set, NULL, NULL, &timeout);

  if (nready < 0)
  {
    perror("select");
    return -1;
  }

  for (client_sock=0; client_sock<FD_SETSIZE; client_sock++)
  {
    if (FD_ISSET(client_sock, &read_fd_set))
    {
      if (client_sock == server_sock)
      {
        struct sockaddr_in clientname;
        socklen_t size;

        size = sizeof(clientname);
        client_sock = accept(server_sock, (struct sockaddr *)&clientname, &size);
        debug(stderr, "count=%d server_sock=%d client_sock=%d\n", count, server_sock, client_sock);

        if (client_sock < 0)
        {
          perror("accept");
          return -1;
        }

        *nbytes = read(client_sock, msg, MAXMSG);
	if (*nbytes == -1)
		perror("read:");
        FD_SET(client_sock, &active_fd_set);
        sock = client_sock;
        break;
      }
      else
      {
        debug(stderr, "inside! client_sock=%d\n", client_sock);
        *nbytes = read(client_sock, msg, MAXMSG);

        if (*nbytes == 0)
        {
          FD_CLR(client_sock, &active_fd_set);
          close(client_sock);
        }
        else
        {
          sock = client_sock;
        }
        break;
      }
    }
  }
  return sock;
}
#endif
