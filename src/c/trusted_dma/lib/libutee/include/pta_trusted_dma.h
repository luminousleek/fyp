

#ifndef __PTA_TRUSTED_DMA_H
#define __PTA_TRUSTED_DMA_H

/*
 * identifier of the pta
 */

#define PTA_TRUSTED_DMA_UUID \
	{ 0xe1429e6f, 0xd436, 0x4c53, \
		{ 0xbe, 0x3b, 0x9e, 0x15, 0x36, 0x50, 0xe6, 0x1f} }

/*
 * commands
 */
#define PTA_CMD_TRUSTED_DMA_INIT     0x0100
#define PTA_CMD_TRUSTED_DMA_TRANSFER 0x0101
#define PTA_CMD_TRUSTED_DMA_SYNC     0x0102

#endif /*__PTA_TRUSTED_DMA_H*/
