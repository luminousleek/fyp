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
#define PKT_LENGTH                  123
#define DST_LENGTH                  33

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
  // aes-128-cbc-sha
  virtual_src_key_addr[0]= 0xA92180D1;
	virtual_src_key_addr[1]= 0x93D7948F;
	virtual_src_key_addr[2]= 0x62B38E57;
	virtual_src_key_addr[3]= 0xC1E0BDE7;

  // aes-128-cbc-sha256
	// virtual_src_key_addr[0]= 0xA820FD5C;
	// virtual_src_key_addr[1]= 0xFDC68007;
	// virtual_src_key_addr[2]= 0x00E8376E;
	// virtual_src_key_addr[3]= 0xEBA05222;

	// dtls packet
  // plaintext: have yourself a merry little Christmas let your heart be light
  virtual_src_ct_addr[0]= 0x47208A78;
  virtual_src_ct_addr[1]= 0xD4F4195E;
  virtual_src_ct_addr[2]= 0x801E7588;
  virtual_src_ct_addr[3]= 0x00450008;

  virtual_src_ct_addr[4]= 0x7EAF6D00;
  virtual_src_ct_addr[5]= 0x11400000;
  virtual_src_ct_addr[6]= 0x007FFFCC;
  virtual_src_ct_addr[7]= 0x007F0100;

  virtual_src_ct_addr[8]= 0x58D50100;
  virtual_src_ct_addr[9]= 0x5900D859;
  virtual_src_ct_addr[10]= 0xFE176CFE;
  virtual_src_ct_addr[11]= 0x000100FD;

  virtual_src_ct_addr[12]= 0x00000000;
  virtual_src_ct_addr[13]= 0xE2440002;
  virtual_src_ct_addr[14]= 0x2519CE46;
  virtual_src_ct_addr[15]= 0xD645C4E3;

  virtual_src_ct_addr[16]= 0x145DAC1C;
  virtual_src_ct_addr[17]= 0xED81DD41;
  virtual_src_ct_addr[18]= 0x1F3B8D7C;
  virtual_src_ct_addr[19]= 0x131FD579;

  virtual_src_ct_addr[20]= 0x2D7F79E7;
  virtual_src_ct_addr[21]= 0xF5276422;
  virtual_src_ct_addr[22]= 0x4DAA7008;
  virtual_src_ct_addr[23]= 0x34648AC3;

  virtual_src_ct_addr[24]= 0x96C8E94E;
  virtual_src_ct_addr[25]= 0x4711DAA8;
  virtual_src_ct_addr[26]= 0xDA940A1B;
  virtual_src_ct_addr[27]= 0xFCD2849B;

  virtual_src_ct_addr[28]= 0x7B7651D9;
  virtual_src_ct_addr[29]= 0xB9C860F0;
  virtual_src_ct_addr[30]= 0x00B62892;

  // plaintext: have yourself a merry little Christmas let your heart be light
	// virtual_src_ct_addr[0]= 0x47208A78;
  // virtual_src_ct_addr[1]= 0xD4F4195E;
  // virtual_src_ct_addr[2]= 0x801E7588;
  // virtual_src_ct_addr[3]= 0x00450008;

  // virtual_src_ct_addr[4]= 0x4E018900;
  // virtual_src_ct_addr[5]= 0x11400000;
  // virtual_src_ct_addr[6]= 0x007F147B;
  // virtual_src_ct_addr[7]= 0x007F0100;

  // virtual_src_ct_addr[8]= 0xEBEC0100;
  // virtual_src_ct_addr[9]= 0x7500D859;
  // virtual_src_ct_addr[10]= 0xFE1788FE;
  // virtual_src_ct_addr[11]= 0x000100FD;

  // virtual_src_ct_addr[12]= 0x00000000;
  // virtual_src_ct_addr[13]= 0xE0600001;
  // virtual_src_ct_addr[14]= 0x0006DE99;
  // virtual_src_ct_addr[15]= 0x6BC1345B;

  // virtual_src_ct_addr[16]= 0x5106C24B;
  // virtual_src_ct_addr[17]= 0xE1D140BB;
  // virtual_src_ct_addr[18]= 0x7E19BCB0;
  // virtual_src_ct_addr[19]= 0xF870C216;

  // virtual_src_ct_addr[20]= 0x1AD9E330;
  // virtual_src_ct_addr[21]= 0x986F9B5D;
  // virtual_src_ct_addr[22]= 0x698CE94B;
  // virtual_src_ct_addr[23]= 0xCB0ED730;

  // virtual_src_ct_addr[24]= 0x9D940329;
  // virtual_src_ct_addr[25]= 0xFBC76C9F;
  // virtual_src_ct_addr[26]= 0xB8325A4D;
  // virtual_src_ct_addr[27]= 0xFDFD9B39;

  // virtual_src_ct_addr[28]= 0xC81ABCBA;
  // virtual_src_ct_addr[29]= 0x3371B01C;
  // virtual_src_ct_addr[30]= 0x6253B8E3;
  // virtual_src_ct_addr[31]= 0x6E99DFDC;

  // virtual_src_ct_addr[32]= 0x84F3B025;
  // virtual_src_ct_addr[33]= 0xD752D278;
  // virtual_src_ct_addr[34]= 0xFD7BC6BF;
  // virtual_src_ct_addr[35]= 0x25946E8B;

  // virtual_src_ct_addr[36]= 0x29180F3B;
  // virtual_src_ct_addr[37]= 0x0010D311;

	printf("Clearing the destination register block...\n");
    memset(virtual_dst_addr, 0, DST_LENGTH);

  printf("Key memory block data:      ");
	  print_mem(virtual_src_key_addr, KEY_LENGTH);

  printf("CT memory block data:      ");
	  print_mem(virtual_src_ct_addr, PKT_LENGTH);

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

  printf("Writing MM2S transfer length of KEY_LENGTH bytes for key and PKT_LENGTH bytes for packet...\n");
    write_dma(dma_ct_virtual_addr, MM2S_TRNSFR_LENGTH_REGISTER, PKT_LENGTH);
    write_dma(dma_key_virtual_addr, MM2S_TRNSFR_LENGTH_REGISTER, KEY_LENGTH);
    dma_mm2s_status(dma_ct_virtual_addr);
    dma_mm2s_status(dma_key_virtual_addr);

  printf("Writing S2MM transfer length of DST_LENGTH bytes...\n");
    write_dma(dma_ct_virtual_addr, S2MM_BUFF_LENGTH_REGISTER, DST_LENGTH);
    dma_s2mm_status(dma_ct_virtual_addr);

  // printf("Waiting for MM2S synchronization...\n");
  // printf("key MM2S sync\n");
  //   dma_mm2s_sync(dma_key_virtual_addr);
  // printf("pkt MM2S sync\n");
  //   dma_mm2s_sync(dma_ct_virtual_addr);

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
