#include <kernel/pseudo_ta.h>
#include <drivers/zynqmp_dma.h>
#include <pta_trusted_dma.h>
#include <tee_api_defines.h>
#include <tee_api_types.h>
#include <trace.h>

#define PTA_NAME "trusted_dma.pta"

static TEE_Result pta_cmd_trusted_dma_init(uint32_t param_types, TEE_Param params [TEE_NUM_PARAMS])
{
  void* dma_base_addr;
  enum dma_channel channel;
  const uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_VALUE_INPUT,
						TEE_PARAM_TYPE_NONE,
						TEE_PARAM_TYPE_NONE);

  if (param_types != exp_pt)
    return TEE_ERROR_BAD_PARAMETERS;

  dma_base_addr = params[0].memref.buffer;
  channel = (params[1].value.a == 1) ? MM2S_CHANNEL : S2MM_CHANNEL;

  return dma_init(dma_base_addr, channel);
}

static TEE_Result pta_cmd_trusted_dma_sync(uint32_t param_types, TEE_Param params [TEE_NUM_PARAMS])
{
  void* dma_base_addr;
  enum dma_channel channel;
  const uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_VALUE_INPUT,
						TEE_PARAM_TYPE_NONE,
						TEE_PARAM_TYPE_NONE);

  if (param_types != exp_pt)
    return TEE_ERROR_BAD_PARAMETERS;

  dma_base_addr = params[0].memref.buffer;
  channel = (params[1].value.a == 1) ? MM2S_CHANNEL : S2MM_CHANNEL;

  return dma_sync(dma_base_addr, channel);
}

static TEE_Result pta_cmd_trusted_dma_transfer(uint32_t param_types, TEE_Param params [TEE_NUM_PARAMS])
{
  void* dma_base_addr;
  void* transfer_mem_addr;
  uint32_t transfer_length;
  enum dma_channel channel;
  const uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_VALUE_INPUT,
						TEE_PARAM_TYPE_NONE);

  if (param_types != exp_pt)
    return TEE_ERROR_BAD_PARAMETERS;

  dma_base_addr = params[0].memref.buffer;
  transfer_mem_addr = params[1].memref.buffer;
  transfer_length = params[1].memref.size;
  channel = (params[2].value.a == 1) ? MM2S_CHANNEL : S2MM_CHANNEL;

  return dma_transfer(dma_base_addr, transfer_mem_addr, transfer_length, channel);
}

TEE_Result invoke_command(void *session __unused, uint32_t cmd_id,
				      uint32_t param_types,
				      TEE_Param params[TEE_NUM_PARAMS])
{
	switch (cmd_id) {
  case PTA_CMD_TRUSTED_DMA_INIT:
    return pta_cmd_trusted_dma_init(param_types, params);
	case PTA_CMD_TRUSTED_DMA_SYNC:
		return pta_cmd_trusted_dma_sync(param_types, params);
	case PTA_CMD_TRUSTED_DMA_TRANSFER:
		return pta_cmd_trusted_dma_transfer(param_types, params);
	default:
		EMSG("Command ID %#" PRIx32 " is not supported", cmd_id);
		return TEE_ERROR_NOT_SUPPORTED;
	}
}

pseudo_ta_register(.uuid = PTA_TRUSTED_DMA_UUID, .name = PTA_NAME,
    .flags = PTA_DEFAULT_FLAGS,
    .invoke_command_entry_point = invoke_command);
