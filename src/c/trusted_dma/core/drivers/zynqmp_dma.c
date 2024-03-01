#include <drivers/zynqmp_dma.h>
#include <types_ext.h>
#include <kernel/delay.h>
#include <mm/core_memprot.h>

register_ddr(SRC_PHY_ADDR, DMA_SIZE);
register_phys_mem(MEM_AREA_TEE_RAM, SECURE_MEM_PHY_ADDR, DMA_SIZE);
register_phys_mem_pgdir(MEM_AREA_IO_SEC, TRUSTED_DMA_BASE_ADDR, DMA_SIZE);

uint32_t write_dma(void *virtual_addr, uint32_t offset, uint32_t value)
{
    uint32_t* reg_addr = (uint32_t *) virtual_addr;
    reg_addr[offset>>2] = value;

    return 0;
}

uint32_t read_dma(void *virtual_addr, uint32_t offset)
{
    uint32_t* reg_addr = (uint32_t *) virtual_addr;
    return reg_addr[offset>>2];
}

uint32_t reset_dma(void *dma_virtual_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_CONTROL_REGISTER, RESET_DMA);
  } else {
    return write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, RESET_DMA);
  }
}

uint32_t halt_dma(void *dma_virtual_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_CONTROL_REGISTER, HALT_DMA);
  } else {
    return write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, HALT_DMA);
  }
}

uint32_t enable_all_irq(void *dma_virtual_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_CONTROL_REGISTER, ENABLE_ALL_IRQ);
  } else {
    return write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, ENABLE_ALL_IRQ);
  }
}

uint32_t run_dma(void *dma_virtual_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_CONTROL_REGISTER, RUN_DMA);
  } else {
    return write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, RUN_DMA);
  }
}

uint32_t set_transfer_len(void *dma_virtual_addr, uint32_t length, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_BUFF_LENGTH_REGISTER, length);
  } else {
    return write_dma(dma_virtual_addr, MM2S_TRNSFR_LENGTH_REGISTER, length);
  }
}

uint32_t read_dma_status(void *dma_virtual_addr, enum dma_channel channel) 
{
  if (channel == S2MM_CHANNEL) {
    return read_dma(dma_virtual_addr, S2MM_STATUS_REGISTER);
  } else {
    return read_dma(dma_virtual_addr, MM2S_STATUS_REGISTER);
  }
}

uint32_t set_transfer_mem_addr(void *dma_virtual_addr, enum dma_channel channel)
{
  if (channel == S2MM_CHANNEL) {
    return write_dma(dma_virtual_addr, S2MM_DST_ADDRESS_REGISTER, SECURE_MEM_PHY_ADDR);
  } else {
    return write_dma(dma_virtual_addr, MM2S_SRC_ADDRESS_REGISTER, SRC_PHY_ADDR);
  }
}

TEE_Result dma_init(enum dma_channel channel)
{
  void* dma_virtual_addr = (void *) core_mmu_get_va((paddr_t) TRUSTED_DMA_BASE_ADDR, MEM_AREA_IO_SEC, DMA_SIZE);

  if (!dma_virtual_addr)
    return TEE_ERROR_GENERIC;

  reset_dma(dma_virtual_addr, channel);
  halt_dma(dma_virtual_addr, channel);
  enable_all_irq(dma_virtual_addr, channel);

  return TEE_SUCCESS;
}

TEE_Result dma_sync(enum dma_channel channel)
{
  void* dma_virtual_addr = (void *) core_mmu_get_va((paddr_t) TRUSTED_DMA_BASE_ADDR, MEM_AREA_IO_SEC, DMA_SIZE);
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

TEE_Result dma_transfer(uint32_t length, enum dma_channel channel)
{
  void* dma_virtual_addr = (void *) core_mmu_get_va((paddr_t) TRUSTED_DMA_BASE_ADDR, MEM_AREA_IO_SEC, DMA_SIZE);

  if (!dma_virtual_addr)
    return TEE_ERROR_GENERIC;

  set_transfer_mem_addr(dma_virtual_addr, channel);
  run_dma(dma_virtual_addr, channel);
  set_transfer_len(dma_virtual_addr, length, channel);

  return TEE_SUCCESS;
}
