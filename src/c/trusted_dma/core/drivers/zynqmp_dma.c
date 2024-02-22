#include <drivers/zynqmp_dma.h>
#include <kernel/delay.h>
#include <mm/core_memprot.h>
#include <util.h>

uint32_t write_dma(uintptr_t *virtual_addr, uint32_t offset, uint32_t value)
{
    virtual_addr[offset>>2] = value;

    return 0;
}

uint32_t read_dma(uintptr_t *virtual_addr, uint32_t offset)
{
    return virtual_addr[offset>>2];
}

uint32_t reset_dma(uintptr_t *dma_virtual_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_CONTROL_REGISTER, RESET_DMA);
  } else {
    return write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, RESET_DMA);
  }
}

uint32_t halt_dma(uintptr_t *dma_virtual_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_CONTROL_REGISTER, HALT_DMA);
  } else {
    return write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, HALT_DMA);
  }
}

uint32_t enable_all_irq(uintptr_t *dma_virtual_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_CONTROL_REGISTER, ENABLE_ALL_IRQ);
  } else {
    return write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, ENABLE_ALL_IRQ);
  }
}

uint32_t run_dma(uintptr_t *dma_virtual_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_CONTROL_REGISTER, RUN_DMA);
  } else {
    return write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, RUN_DMA);
  }
}

uint32_t set_transfer_len(uintptr_t *dma_virtual_addr, uint32_t length, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_BUFF_LENGTH_REGISTER, length);
  } else {
    return write_dma(dma_virtual_addr, MM2S_TRNSFR_LENGTH_REGISTER, length);
  }
}

uint32_t read_dma_status(uintptr_t *dma_virtual_addr, enum dma_channel channel) {
  if (channel == S2MM_CHANNEL) {
    return read_dma(dma_virtual_addr, S2MM_STATUS_REGISTER);
  } else {
    return read_dma(dma_virtual_addr, MM2S_STATUS_REGISTER);
  }
}

uint32_t set_transfer_mem_addr(uintptr_t *dma_virtual_addr, uint32_t phy_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_DST_ADDRESS_REGISTER, dst_phy_addr);
  } else {
    return write_dma(dma_virtual_addr, MM2S_SRC_ADDRESS_REGISTER, src_phy_addr);
  }
}

TEE_Result dma_init(uintptr_t dma_base_addr, enum dma_channel channel)
{
  register_phys_mem_pgdir(MEM_AREA_IO_SEC, dma_base_addr, DMA_SIZE);
  uintptr_t dma_virtual_addr = core_mmu_get_va(dma_base_addr, MEM_AREA_IO_SEC, DMA_SIZE);

  if (!dma_virtual_addr)
    return TEE_ERROR_GENERIC;

  reset_dma(dma_virtual_addr, channel);
  halt_dma(dma_virtual_addr, channel);
  enable_all_irq(dma_virtual_addr, channel);

  return TEE_SUCCESS;
}

TEE_Result dma_sync(uintptr_t dma_base_addr, enum dma_channel channel)
{
  uintptr_t dma_virtual_addr = core_mmu_get_va(dma_base_addr, MEM_AREA_IO_SEC, DMA_SIZE);
  uint64_t tref = timeout_init_us(DMA_DONE_TIMEOUT_USEC);
  uint32_t status = 0;

  if (!dma_virtual_addr)
    return TEE_ERROR_GENERIC;
  
  while (!timeout_elapsed(tref)) {
    status = read_dma_status(dma_virtual_addr, channel);
    if ((status & IOC_IRQ_FLAG) && (status & IDLE_FLAG)) {
      return TEE_SUCCESS;
    }
  }

  return TEE_ERROR_GENERIC;
}

TEE_Result dma_transfer(uintptr_t dma_base_addr, uint32_t transfer_mem_addr, uint32_t length, 
                        enum dma_channel channel)
{
  uintptr_t dma_virtual_addr = core_mmu_get_va(dma_base_addr, MEM_AREA_IO_SEC, DMA_SIZE);

  if (!dma_virtual_addr)
    return TEE_ERROR_GENERIC;

  set_transfer_mem_addr(dma_virtual_addr, transfer_mem_addr, channel);
  run_dma(dma_virtual_addr, channel);
  set_transfer_len(dma_virtual_addr, length, channel);

  return TEE_SUCCESS;
}
