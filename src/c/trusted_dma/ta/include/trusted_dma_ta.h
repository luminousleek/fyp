// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright (c) 2018, Linaro Limited
 */

#ifndef __TRUSTED_DMA_TA_H__
#define __TRUSTED_DMA_TA_H__

/* UUID of the trusted DMA trusted application */
#define PTA_TRUSTED_DMA_UUID \
	{ 0xe1429e6f, 0xd436, 0x4c53, \
		{ 0xbe, 0x3b, 0x9e, 0x15, 0x36, 0x50, 0xe6, 0x1f} }


#define TA_TRUSTED_DMA_UUID \
	{ 0x3d8c6025, 0x55ad, 0x4c7e, \
		{ 0xb0, 0x61, 0x93, 0x3a, 0xf9, 0x5c, 0xd0, 0xdd} }


/*
 * in params[0].value transfer length
 * in params[1].value 1 if MM2S channel, 0 if S2MM channel
 */
#define TA_TRUSTED_DMA_CMD_TRANSFER 0

/*
 * out params[0].memref ns_output_buf
 */
#define TA_TRUSTED_DMA_CMD_READ_DST 1

static const char *opteestrerr(unsigned err)
{
    switch (err) {
    case 0x00000000:
        return "TEEC_SUCCESS";
    case 0xF0100003:
        return "TEEC_ERROR_STORAGE_NOT_AVAILABLE";
    case 0xFFFF0000:
        return "TEEC_ERROR_GENERIC";
    case 0xFFFF0001:
        return "TEEC_ERROR_ACCESS_DENIED";
    case 0xFFFF0002:
        return "TEEC_ERROR_CANCEL";
    case 0xFFFF0003:
        return "TEEC_ERROR_ACCESS_CONFLICT";
    case 0xFFFF0004:
        return "TEEC_ERROR_EXCESS_DATA";
    case 0xFFFF0005:
        return "TEEC_ERROR_BAD_FORMAT";
    case 0xFFFF0006:
        return "TEEC_ERROR_BAD_PARAMETERS";
    case 0xFFFF0007:
        return "TEEC_ERROR_BAD_STATE";
    case 0xFFFF0008:
        return "TEEC_ERROR_ITEM_NOT_FOUND";
    case 0xFFFF0009:
        return "TEEC_ERROR_NOT_IMPLEMENTED";
    case 0xFFFF000A:
        return "TEEC_ERROR_NOT_SUPPORTED";
    case 0xFFFF000B:
        return "TEEC_ERROR_NO_DATA";
    case 0xFFFF000C:
        return "TEEC_ERROR_OUT_OF_MEMORY";
    case 0xFFFF000D:
        return "TEEC_ERROR_BUSY";
    case 0xFFFF000E:
        return "TEEC_ERROR_COMMUNICATION";
    case 0xFFFF000F:
        return "TEEC_ERROR_SECURITY";
    case 0xFFFF0010:
        return "TEEC_ERROR_SHORT_BUFFER";
    case 0xFFFF0011:
        return "TEEC_ERROR_EXTERNAL_CANCEL";
    case 0xFFFF3024:
        return "TEEC_ERROR_TARGET_DEAD";
    case 0xFFFF3041:
        return "TEEC_ERROR_STORAGE_NO_SPACE";
    case 0x00000001:
        return "TEEC_ORIGIN_API";
    case 0x00000002:
        return "TEEC_ORIGIN_COMMS";
    case 0x00000003:
        return "TEEC_ORIGIN_TEE";
    case 0x00000004:
        return "TEEC_ORIGIN_TRUSTED_APP";
    default:
        return "(unknown)";
    }
}

#endif /* __TRUSTED_DMA_TA_H */
