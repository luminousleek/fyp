// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright (c) 2018, Linaro Limited
 */

/*
 * The name of this file must not be modified
 */

#ifndef USER_TA_HEADER_DEFINES_H
#define USER_TA_HEADER_DEFINES_H

#include <trusted_dma_ta.h>

#define TA_UUID				TA_TRUSTED_DMA_UUID

#define TA_FLAGS			TA_FLAG_EXEC_DDR
#define TA_STACK_SIZE			(2 * 1024)
#define TA_DATA_SIZE			(32 * 1024)

#define TA_CURRENT_TA_EXT_PROPERTIES \
    { "gp.ta.description", USER_TA_PROP_TYPE_STRING, \
        "TA that passes data to the PL through an AXI DMA block" }, \
    { "gp.ta.version", USER_TA_PROP_TYPE_U32, &(const uint32_t){ 0x0010 } }

#endif /*USER_TA_HEADER_DEFINES_H*/
