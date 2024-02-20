// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright (c) 2018, Linaro Limited
 */

#ifndef __NONCE_SIGN_TA_H__
#define __NONCE_SIGN_TA_H__

/* UUID of the nonce_sign trusted application */
#define TA_NONCE_SIGN_UUID \
	{ 0xa1f65ed6, 0x0ee1, 0x417c, \
		{ 0xb6, 0x76, 0x02, 0x54, 0xd6, 0xa7, 0x15, 0xc8} }


/*
 * out params[0].memref random_buffer
 */
#define TA_NONCE_SIGN_CMD_GEN_NONCE 0

/*
 * in	params[0].value.a key size
 */
#define TA_NONCE_SIGN_CMD_GEN_KEY		1

/*
 * in	params[0].memref  digest
 * out	params[1].memref  signature
 */
#define TA_NONCE_SIGN_CMD_SIGN		2

/*
 * in	params[0].memref  input
 * in	params[1].memref  output
 */
#define TA_NONCE_SIGN_CMD_VERIFY		3


#endif /* __NONCE_SIGN_TA_H */
