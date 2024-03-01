// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright (c) 2018, Linaro Limited
 */

#include <err.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>

/* OP-TEE TEE client API (built by optee_client) */
#include <tee_client_api.h>

/* For the UUID (found in the TA's h-file(s)) */
#include <trusted_dma_ta.h>

#define TRUSTED_DMA_BASE_ADDR 0xA0000000
#define SECURE_MEM_PHY_ADDR   0x30000000
#define SRC_PHY_ADDR          0x40000000
#define DST_PHY_ADDR          0x50000000

static void teec_err(TEEC_Result res, uint32_t eo, const char *str)
{
	errx(1, "%s: %#" PRIx32 " (error origin %#" PRIx32 ")", str, res, eo);
}

int main(int argc, char *argv[])
{
	TEEC_Result res;
	uint32_t eo;
	TEEC_Context ctx;
	TEEC_Session sess;
	TEEC_Operation op;
	const char payload[] = "hello world! this went through the trusted dma";
  uint32_t transfer_length = sizeof(payload);
  char* result;
	size_t n;
	const TEEC_UUID uuid = TA_TRUSTED_DMA_UUID;

	res = TEEC_InitializeContext(NULL, &ctx);
	if (res)
		errx(1, "TEEC_InitializeContext(NULL, x): %#" PRIx32, res);

	res = TEEC_OpenSession(&ctx, &sess, &uuid, TEEC_LOGIN_PUBLIC, NULL,
			       NULL, &eo);
	if (res)
		teec_err(res, eo, "TEEC_OpenSession(TEEC_LOGIN_PUBLIC)");

  result = (char *) malloc(sizeof(char) * (transfer_length));
  memset(result, 0, transfer_length);

  printf("Opening a character device file of the ZynqMP's DDR memory...\n");
	int ddr_memory = open("/dev/mem", O_RDWR | O_SYNC);

  printf("Memory map the MM2S source address for register block.\n");
    unsigned int *virtual_src_addr  = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, ddr_memory, SRC_PHY_ADDR);
  printf("Memory map the S2MM source address for register block.\n");
    unsigned int *virtual_dst_addr  = mmap(NULL, 65535, PROT_READ | PROT_WRITE, MAP_SHARED, ddr_memory, DST_PHY_ADDR);

  printf("Copy payload to virtual source address.\n");
  memcpy(virtual_src_addr, payload, transfer_length);

	memset(&op, 0, sizeof(op));
  
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_VALUE_INPUT, 
          TEEC_VALUE_INPUT,
					TEEC_NONE,
          TEEC_NONE);
  op.params[0].value.a = transfer_length;
  op.params[1].value.a = 1;

  printf("Transferring to MM2S channel.\n");
	res = TEEC_InvokeCommand(&sess, TA_TRUSTED_DMA_CMD_TRANSFER, &op, &eo);
	if (res)
		teec_err(res, eo, "TEEC_InvokeCommand(TA_TRUSTED_DMA_CMD_TRANSFER)");

	memset(&op, 0, sizeof(op));
  
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_VALUE_INPUT, 
          TEEC_VALUE_INPUT,
					TEEC_NONE,
          TEEC_NONE);
  op.params[0].value.a = transfer_length;
  op.params[1].value.a = 0;

  printf("Transferring to S2MM channel.\n");
  res = TEEC_InvokeCommand(&sess, TA_TRUSTED_DMA_CMD_TRANSFER, &op, &eo);
	if (res)
		teec_err(res, eo, "TEEC_InvokeCommand(TA_TRUSTED_DMA_CMD_TRANSFER)");

  memset(&op, 0, sizeof(op));
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_VALUE_INPUT, 
          TEEC_NONE,
					TEEC_NONE,
          TEEC_NONE);

  op.params[0].value.a = transfer_length;

  printf("Reading secure memory\n");
  res = TEEC_InvokeCommand(&sess, TA_TRUSTED_DMA_CMD_READ_DST, &op, &eo);
	if (res)
		teec_err(res, eo, "TEEC_InvokeCommand(TA_TRUSTED_DMA_CMD_READ_DST)");

	printf("Result: ");
	for (n = 0; n < transfer_length; n++)
		printf("%02x ", ((uint8_t *) virtual_dst_addr)[n]);
	printf("\n");
  printf("%s", virtual_dst_addr);

	return 0;
}
