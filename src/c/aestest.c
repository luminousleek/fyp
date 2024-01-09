/*
 * Copyright (c) 2012 Xilinx, Inc.  All rights reserved.
 *
 * Xilinx, Inc.
 * XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" AS A
 * COURTESY TO YOU.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
 * ONE POSSIBLE   IMPLEMENTATION OF THIS FEATURE, APPLICATION OR
 * STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION
 * IS FREE FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE
 * FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION.
 * XILINX EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO
 * THE ADEQUACY OF THE IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO
 * ANY WARRANTIES OR REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE
 * FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <termios.h>
#include <sys/mman.h>

#define MM2S_CONTROL_REGISTER       0x00
#define MM2S_STATUS_REGISTER        0x04
#define MM2S_SRC_ADDRESS_REGISTER   0x18
#define MM2S_TRNSFR_LENGTH_REGISTER 0x28

#define S2MM_CONTROL_REGISTER       0x30
#define S2MM_STATUS_REGISTER        0x34
#define S2MM_DST_ADDRESS_REGISTER   0x48
#define S2MM_BUFF_LENGTH_REGISTER   0x58

#define IOC_IRQ_FLAG                1<<12
#define IDLE_FLAG                   1<<1

#define STATUS_HALTED               0x00000001
#define STATUS_IDLE                 0x00000002
#define STATUS_SG_INCLDED           0x00000008
#define STATUS_DMA_INTERNAL_ERR     0x00000010
#define STATUS_DMA_SLAVE_ERR        0x00000020
#define STATUS_DMA_DECODE_ERR       0x00000040
#define STATUS_SG_INTERNAL_ERR      0x00000100
#define STATUS_SG_SLAVE_ERR         0x00000200
#define STATUS_SG_DECODE_ERR        0x00000400
#define STATUS_IOC_IRQ              0x00001000
#define STATUS_DELAY_IRQ            0x00002000
#define STATUS_ERR_IRQ              0x00004000

#define HALT_DMA                    0x00000000
#define RUN_DMA                     0x00000001
#define RESET_DMA                   0x00000004
#define ENABLE_IOC_IRQ              0x00001000
#define ENABLE_DELAY_IRQ            0x00002000
#define ENABLE_ERR_IRQ              0x00004000
#define ENABLE_ALL_IRQ              0x00007000

#define KEY_LENGTH                  16
#define CT_LENGTH                   80
#define DST_LENGTH                  65

#define CT_DMA_PHY_ADDR             0x40400000
#define KEY_DMA_PHY_ADDR            0x40410000
#define SRC_KEY_PHY_ADDR            0x0e000000
#define SRC_CT_PHY_ADDR             0x0e100000
#define DST_PHY_ADDR                0x0f000000

unsigned int write_dma(unsigned int *virtual_addr, int offset, unsigned int value)
{
    virtual_addr[offset>>2] = value;

    return 0;
}

unsigned int read_dma(unsigned int *virtual_addr, int offset)
{
    return virtual_addr[offset>>2];
}

void dma_s2mm_status(unsigned int *virtual_addr)
{
    unsigned int status = read_dma(virtual_addr, S2MM_STATUS_REGISTER);

    printf("Stream to memory-mapped status (0x%08x@0x%02x):", status, S2MM_STATUS_REGISTER);

    if (status & STATUS_HALTED) {
		printf(" Halted.\n");
	} else {
		printf(" Running.\n");
	}

    if (status & STATUS_IDLE) {
		printf(" Idle.\n");
	}

    if (status & STATUS_SG_INCLDED) {
		printf(" SG is included.\n");
	}

    if (status & STATUS_DMA_INTERNAL_ERR) {
		printf(" DMA internal error.\n");
	}

    if (status & STATUS_DMA_SLAVE_ERR) {
		printf(" DMA slave error.\n");
	}

    if (status & STATUS_DMA_DECODE_ERR) {
		printf(" DMA decode error.\n");
	}

    if (status & STATUS_SG_INTERNAL_ERR) {
		printf(" SG internal error.\n");
	}

    if (status & STATUS_SG_SLAVE_ERR) {
		printf(" SG slave error.\n");
	}

    if (status & STATUS_SG_DECODE_ERR) {
		printf(" SG decode error.\n");
	}

    if (status & STATUS_IOC_IRQ) {
		printf(" IOC interrupt occurred.\n");
	}

    if (status & STATUS_DELAY_IRQ) {
		printf(" Interrupt on delay occurred.\n");
	}

    if (status & STATUS_ERR_IRQ) {
		printf(" Error interrupt occurred.\n");
	}
}

void dma_mm2s_status(unsigned int *virtual_addr)
{
    unsigned int status = read_dma(virtual_addr, MM2S_STATUS_REGISTER);

    printf("Memory-mapped to stream status (0x%08x@0x%02x):", status, MM2S_STATUS_REGISTER);

    if (status & STATUS_HALTED) {
		printf(" Halted.\n");
	} else {
		printf(" Running.\n");
	}

    if (status & STATUS_IDLE) {
		printf(" Idle.\n");
	}

    if (status & STATUS_SG_INCLDED) {
		printf(" SG is included.\n");
	}

    if (status & STATUS_DMA_INTERNAL_ERR) {
		printf(" DMA internal error.\n");
	}

    if (status & STATUS_DMA_SLAVE_ERR) {
		printf(" DMA slave error.\n");
	}

    if (status & STATUS_DMA_DECODE_ERR) {
		printf(" DMA decode error.\n");
	}

    if (status & STATUS_SG_INTERNAL_ERR) {
		printf(" SG internal error.\n");
	}

    if (status & STATUS_SG_SLAVE_ERR) {
		printf(" SG slave error.\n");
	}

    if (status & STATUS_SG_DECODE_ERR) {
		printf(" SG decode error.\n");
	}

    if (status & STATUS_IOC_IRQ) {
		printf(" IOC interrupt occurred.\n");
	}

    if (status & STATUS_DELAY_IRQ) {
		printf(" Interrupt on delay occurred.\n");
	}

    if (status & STATUS_ERR_IRQ) {
		printf(" Error interrupt occurred.\n");
	}
}

int dma_mm2s_sync(unsigned int *virtual_addr)
{
    unsigned int mm2s_status =  read_dma(virtual_addr, MM2S_STATUS_REGISTER);

	// sit in this while loop as long as the status does not read back 0x00001002 (4098)
	// 0x00001002 = IOC interrupt has occured and DMA is idle
	while(!(mm2s_status & IOC_IRQ_FLAG) || !(mm2s_status & IDLE_FLAG))
	{
        // dma_s2mm_status(virtual_addr);
        dma_mm2s_status(virtual_addr);

        mm2s_status =  read_dma(virtual_addr, MM2S_STATUS_REGISTER);
    }

	return 0;
}

int dma_s2mm_sync(unsigned int *virtual_addr)
{
    unsigned int s2mm_status = read_dma(virtual_addr, S2MM_STATUS_REGISTER);

	// sit in this while loop as long as the status does not read back 0x00001002 (4098)
	// 0x00001002 = IOC interrupt has occured and DMA is idle
	while(!(s2mm_status & IOC_IRQ_FLAG) || !(s2mm_status & IDLE_FLAG))
	{
        dma_s2mm_status(virtual_addr);
        // dma_mm2s_status(virtual_addr);

        s2mm_status = read_dma(virtual_addr, S2MM_STATUS_REGISTER);
    }

	return 0;
}

void print_mem(void *virtual_address, int byte_count)
{
	char *data_ptr = virtual_address;

	for(int i=0;i<byte_count;i++){
		printf("%02X", data_ptr[i]);

		// print a space every 4 bytes (0 indexed)
		if(i%4==3){
			printf(" ");
		}
	}

	printf("\n");
}

//void load_mem(void *virtual_address, int byte_count, unsigned int data)
//{
//	char *data_ptr = data;
//
//	for(int i=0;i<byte_count;i++){
//		data_ptr[i] = data;
//	}
//
//	memset(virtual_address, *data_ptr, byte_count);
//}

int main()
{
    printf("Hello World! - Running DMA transfer test application.\n");

	printf("Opening a character device file of the Arty's DDR memeory...\n");
	int ddr_memory = open("/dev/mem", O_RDWR | O_SYNC);

	printf("Memory map the address of the DMA AXI IP for CT via its AXI lite control interface register block.\n");
    unsigned int *dma_ct_virtual_addr = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, ddr_memory, CT_DMA_PHY_ADDR);

  printf("Memory map the address of the DMA AXI IP for key via its AXI lite control interface register block.\n");
    unsigned int *dma_key_virtual_addr = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, ddr_memory, KEY_DMA_PHY_ADDR);

	printf("Memory map the MM2S source address for key register block.\n");
    unsigned int *virtual_src_key_addr  = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, ddr_memory, SRC_KEY_PHY_ADDR);

  printf("Memory map the MM2S source address for ct register block.\n");
    unsigned int *virtual_src_ct_addr  = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, ddr_memory, SRC_CT_PHY_ADDR);

	printf("Memory map the S2MM destination address register block.\n");
    unsigned int *virtual_dst_addr = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, ddr_memory, DST_PHY_ADDR);

	printf("Writing packet data to source register block...\n");
	
	// key data
	virtual_src_key_addr[0]= 0xA92180D1;
	virtual_src_key_addr[1]= 0x93D7948F;
	virtual_src_key_addr[2]= 0x62B38E57;
	virtual_src_key_addr[3]= 0xC1E0BDE7;

	// ct packet
  // iv: 02 2c b3 0d ad 12 19 df 1d c9 ca 9d 63 a9 8c f2
  // plaintext: have yourself a merry little Christmas let your heart be light
	virtual_src_ct_addr[0]= 0x0DB32C02;
	virtual_src_ct_addr[1]= 0xDF1912AD;
	virtual_src_ct_addr[2]= 0x9DCAC91D;
	virtual_src_ct_addr[3]= 0xF28CA963;

	virtual_src_ct_addr[4]= 0x63D49459;
	virtual_src_ct_addr[5]= 0x06EDD8A4;
	virtual_src_ct_addr[6]= 0xF514DF25;
	virtual_src_ct_addr[7]= 0x8FF53E19;

	virtual_src_ct_addr[8]= 0x073277E8;
	virtual_src_ct_addr[9]= 0xE0127793;
	virtual_src_ct_addr[10]= 0x405606E3;
	virtual_src_ct_addr[11]= 0xC667F0C4;

	virtual_src_ct_addr[12]= 0x7709F875;
	virtual_src_ct_addr[13]= 0xB0F8F991;
	virtual_src_ct_addr[14]= 0xB7B3BBB4;
	virtual_src_ct_addr[15]= 0xA5902BB8;

	virtual_src_ct_addr[16]= 0xDA6FE762;
  virtual_src_ct_addr[17]= 0x27308C93;
  virtual_src_ct_addr[18]= 0x81BA4A09;
  virtual_src_ct_addr[19]= 0x5EE854E8;

	printf("Clearing the destination register block...\n");
    memset(virtual_dst_addr, 0, DST_LENGTH);

  printf("Key memory block data:      ");
	  print_mem(virtual_src_key_addr, KEY_LENGTH);

  printf("CT memory block data:      ");
	  print_mem(virtual_src_ct_addr, CT_LENGTH);

  printf("Destination memory block data: ");
	  print_mem(virtual_dst_addr, DST_LENGTH);

  printf("Reset the DMA.\n");
    write_dma(dma_ct_virtual_addr, S2MM_CONTROL_REGISTER, RESET_DMA);
    write_dma(dma_ct_virtual_addr, MM2S_CONTROL_REGISTER, RESET_DMA);
    write_dma(dma_key_virtual_addr, MM2S_CONTROL_REGISTER, RESET_DMA);
    dma_s2mm_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);

	printf("Halt the DMA.\n");
    write_dma(dma_ct_virtual_addr, S2MM_CONTROL_REGISTER, HALT_DMA);
    write_dma(dma_ct_virtual_addr, MM2S_CONTROL_REGISTER, HALT_DMA);
    write_dma(dma_key_virtual_addr, MM2S_CONTROL_REGISTER, HALT_DMA);
    dma_s2mm_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);

	printf("Enable all interrupts.\n");
    write_dma(dma_ct_virtual_addr, S2MM_CONTROL_REGISTER, ENABLE_ALL_IRQ);
    write_dma(dma_ct_virtual_addr, MM2S_CONTROL_REGISTER, ENABLE_ALL_IRQ);
    write_dma(dma_key_virtual_addr, MM2S_CONTROL_REGISTER, ENABLE_ALL_IRQ);
    dma_s2mm_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);

  printf("Writing source address of the data from MM2S in DDR...\n");
    write_dma(dma_ct_virtual_addr, MM2S_SRC_ADDRESS_REGISTER, SRC_CT_PHY_ADDR);
    write_dma(dma_key_virtual_addr, MM2S_SRC_ADDRESS_REGISTER, SRC_KEY_PHY_ADDR);
    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);

  printf("Writing the destination address for the data from S2MM in DDR...\n");
    write_dma(dma_ct_virtual_addr, S2MM_DST_ADDRESS_REGISTER, DST_PHY_ADDR);
    dma_s2mm_status(dma_ct_virtual_addr);

	printf("Run the MM2S channel.\n");
    write_dma(dma_ct_virtual_addr, MM2S_CONTROL_REGISTER, RUN_DMA);
    write_dma(dma_key_virtual_addr, MM2S_CONTROL_REGISTER, RUN_DMA);
    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);

	printf("Run the S2MM channel.\n");
    write_dma(dma_ct_virtual_addr, S2MM_CONTROL_REGISTER, RUN_DMA);
    dma_s2mm_status(dma_ct_virtual_addr);

  printf("Writing MM2S transfer length of KEY_LENGTH bytes for key and CT_LENGTH bytes for CT...\n");
    write_dma(dma_ct_virtual_addr, MM2S_TRNSFR_LENGTH_REGISTER, CT_LENGTH);
    write_dma(dma_key_virtual_addr, MM2S_TRNSFR_LENGTH_REGISTER, KEY_LENGTH);
    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);

  printf("Writing S2MM transfer length of DST_LENGTH bytes...\n");
    write_dma(dma_ct_virtual_addr, S2MM_BUFF_LENGTH_REGISTER, DST_LENGTH);
    dma_s2mm_status(dma_ct_virtual_addr);

  printf("Waiting for MM2S synchronization...\n");
    dma_mm2s_sync(dma_ct_virtual_addr);
    dma_mm2s_sync(dma_key_virtual_addr);

  printf("Waiting for S2MM sychronization...\n");
    dma_s2mm_sync(dma_ct_virtual_addr);

    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);
    dma_s2mm_status(dma_ct_virtual_addr);

  printf("Destination memory block: ");
	  print_mem(virtual_dst_addr, DST_LENGTH);

	printf("\n");

  printf("plaintext: %s\n", (char *) virtual_dst_addr);

  printf("Halt the DMA.\n");
    write_dma(dma_ct_virtual_addr, S2MM_CONTROL_REGISTER, HALT_DMA);
    write_dma(dma_ct_virtual_addr, MM2S_CONTROL_REGISTER, HALT_DMA);
    write_dma(dma_key_virtual_addr, MM2S_CONTROL_REGISTER, HALT_DMA);
    dma_s2mm_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);

  printf("Reset the DMA.\n");
    write_dma(dma_ct_virtual_addr, S2MM_CONTROL_REGISTER, RESET_DMA);
    write_dma(dma_ct_virtual_addr, MM2S_CONTROL_REGISTER, RESET_DMA);
    write_dma(dma_key_virtual_addr, MM2S_CONTROL_REGISTER, RESET_DMA);
    dma_s2mm_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);

    return 0;
}
