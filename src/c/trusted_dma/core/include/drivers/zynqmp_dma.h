#include <tee_api_types.h>

#ifndef __DRIVERS_ZYNQMP_DMA_H_
#define __DRIVERS_ZYNQMP_DMA_H_

enum dma_channel {
  S2MM_CHANNEL = 0,
  MM2S_CHANNEL = 1
};

/* DMA registers */
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

#define DMA_SIZE                    0x10000
#define DMA_DONE_TIMEOUT_USEC       3000000

TEE_Result dma_init(uintptr_t dma_base_addr, enum dma_channel channel);
TEE_Result dma_sync(uintptr_t dma_base_addr, enum dma_channel channel);
TEE_Result dma_transfer(uintptr_t dma_base_addr, uint32_t transfer_mem_addr, uint32_t length, 
                        enum dma_channel channel);

#endif