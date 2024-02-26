// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright (c) 2018, Linaro Limited
 */

#include <inttypes.h>

#include <tee_internal_api.h>

#include <trusted_dma_ta.h>
#include <pta_trusted_dma.h>

static TEE_TASessionHandle sess = TEE_HANDLE_NULL;
static const TEE_UUID trusted_dma_pta_uuid = PTA_TRUSTED_DMA_UUID;

static TEE_Result cmd_transfer(uint32_t param_types, TEE_Param params[TEE_NUM_PARAMS])
{
  TEE_Result res;
  TEE_Param pta_params[TEE_NUM_PARAMS];
  uint32_t pta_param_types;
  uint32_t return_origin;
  void* dma_base_addr;
  uint32_t is_mm2s;
  char* channel_string;
  const uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_VALUE_INPUT,
						TEE_PARAM_TYPE_NONE);

  if (param_types != exp_pt)
    return TEE_ERROR_BAD_PARAMETERS;

  dma_base_addr = params[0].memref.buffer;
  is_mm2s = params[2].value.a;

  if (is_mm2s) {
    channel_string = "MM2S";
  } else {
    channel_string = "S2MM";
  }

  pta_param_types = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
            TEE_PARAM_TYPE_VALUE_INPUT,
            TEE_PARAM_TYPE_NONE,
            TEE_PARAM_TYPE_NONE);

  // TEE_MemFill(*pta_params, 0, sizeof(pta_params));
  pta_params[0].memref.buffer = dma_base_addr;
  pta_params[1].value.a = is_mm2s;

  DMSG("Initialising DMA at address %p with %s channel", dma_base_addr, channel_string);
  res = TEE_InvokeTACommand(sess, TEE_TIMEOUT_INFINITE, PTA_CMD_TRUSTED_DMA_INIT,
    pta_param_types, pta_params, &return_origin);
  if (res) {
    EMSG("PTA DMA Init(%p, %s): %s", dma_base_addr, channel_string, opteestrerr(res));
  }

  DMSG("Transferring to DMA at address %p with %s channel", dma_base_addr, channel_string);
  res = TEE_InvokeTACommand(sess, TEE_TIMEOUT_INFINITE, PTA_CMD_TRUSTED_DMA_TRANSFER,
    param_types, params, &return_origin);
  if (res) {
    EMSG("PTA DMA Transfer(%p, %s): %s", dma_base_addr, channel_string, opteestrerr(res));
  }

  DMSG("Syncing DMA at address %p with %s channel", dma_base_addr, channel_string);
  res = TEE_InvokeTACommand(sess, TEE_TIMEOUT_INFINITE, PTA_CMD_TRUSTED_DMA_SYNC,
    pta_param_types, pta_params, &return_origin);
  if (res) {
    EMSG("PTA DMA Sync(%p, %s): %s", dma_base_addr, channel_string, opteestrerr(res));
  }

  return res;
}

static TEE_Result cmd_read_dst(uint32_t param_types, TEE_Param params[TEE_NUM_PARAMS])
{
  TEE_Result res;
  uint32_t return_origin;
  const uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_MEMREF_OUTPUT,
						TEE_PARAM_TYPE_VALUE_INPUT,
						TEE_PARAM_TYPE_NONE);

  if (param_types != exp_pt)
    return TEE_ERROR_BAD_PARAMETERS;

  DMSG("Moving %d bytes of memory from %p to %p", params[0].memref.size, params[0].memref.buffer, params[1].memref.buffer);
  TEE_MemMove(params[1].memref.buffer, params[0].memref.buffer, params[0].memref.size);
  return TEE_SUCCESS;
}

TEE_Result TA_CreateEntryPoint(void)
{
	TEE_Result res  = TEE_ERROR_GENERIC;
  DMSG("Opening PTA session...");
  res = TEE_OpenTASession(&trusted_dma_pta_uuid, TEE_TIMEOUT_INFINITE, 0, NULL, &sess, NULL);
  DMSG("TEE_OpenTASession returns res=0x%x", res);
	return res;
}

void TA_DestroyEntryPoint(void)
{
	DMSG("Closing PTA session...");
  TEE_CloseTASession(sess);
}

TEE_Result TA_OpenSessionEntryPoint(uint32_t __unused param_types,
					TEE_Param __unused params[4],
					void __unused **session)
{
	/* Nothing to do */
	return TEE_SUCCESS;
}

void TA_CloseSessionEntryPoint(void __unused *session)
{
  (void)&session;
}

TEE_Result TA_InvokeCommandEntryPoint(void __unused *session, uint32_t cmd,
				      uint32_t param_types,
				      TEE_Param params[TEE_NUM_PARAMS])
{
	switch (cmd) {
  case TA_TRUSTED_DMA_CMD_TRANSFER:
    return cmd_transfer(param_types, params);
	case TA_TRUSTED_DMA_CMD_READ_DST:
		return cmd_read_dst(param_types, params);
	default:
		EMSG("Command ID %#" PRIx32 " is not supported", cmd);
		return TEE_ERROR_NOT_SUPPORTED;
	}
}
