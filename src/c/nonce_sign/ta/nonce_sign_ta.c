// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright (c) 2018, Linaro Limited
 */

#include <inttypes.h>

#include <tee_internal_api.h>

#include <nonce_sign_ta.h>

struct nonce_sign {
	TEE_ObjectHandle key;
};

static TEE_Result cmd_gen_nonce(struct nonce_sign *state, uint32_t pt,
            TEE_Param params[TEE_NUM_PARAMS])
{
  void *random_buf = NULL;
  size_t random_buf_len;
  const uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_OUTPUT,
						TEE_PARAM_TYPE_NONE,
						TEE_PARAM_TYPE_NONE,
						TEE_PARAM_TYPE_NONE);

  if (pt != exp_pt)
		return TEE_ERROR_BAD_PARAMETERS;

  random_buf_len = params[0].memref.size;
  random_buf = TEE_Malloc(random_buf_len, 0);
	if (!random_buf)
		return TEE_ERROR_OUT_OF_MEMORY;
	IMSG("Generating random data over %u bytes.", random_buf_len);

  TEE_GenerateRandom(random_buf, random_buf_len);
  TEE_MemMove(params[0].memref.buffer, random_buf, random_buf_len);
	TEE_Free(random_buf);

  return TEE_SUCCESS;
}

static TEE_Result cmd_gen_key(struct nonce_sign *state, uint32_t pt,
			      TEE_Param params[TEE_NUM_PARAMS])
{
	TEE_Result res;
	uint32_t key_size;
	TEE_ObjectHandle key;
	const uint32_t key_type = TEE_TYPE_RSA_KEYPAIR;
	const uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_VALUE_INPUT,
						TEE_PARAM_TYPE_NONE,
						TEE_PARAM_TYPE_NONE,
						TEE_PARAM_TYPE_NONE);

  
	if (pt != exp_pt)
		return TEE_ERROR_BAD_PARAMETERS;

	key_size = params[0].value.a;

	res = TEE_AllocateTransientObject(key_type, key_size, &key);
	if (res) {
		EMSG("TEE_AllocateTransientObject(%#" PRIx32 ", %" PRId32 "): %#" PRIx32, key_type, key_size, res);
		return res;
	}

	res = TEE_GenerateKey(key, key_size, NULL, 0);
	if (res) {
		EMSG("TEE_GenerateKey(%" PRId32 "): %#" PRIx32,
		     key_size, res);
		TEE_FreeTransientObject(key);
		return res;
	}

	TEE_FreeTransientObject(state->key);
	state->key = key;
	return TEE_SUCCESS;
}

static TEE_Result cmd_sign(struct nonce_sign *state, uint32_t pt,
        TEE_Param params[TEE_NUM_PARAMS])
{
  TEE_Result res;
  const void *inbuf;
  uint32_t inbuf_len;
  void *outbuf;
  uint32_t outbuf_len;
  TEE_OperationHandle op;
  TEE_ObjectInfo key_info;
  const uint32_t alg = TEE_ALG_RSASSA_PKCS1_V1_5_SHA256;
  const uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_MEMREF_OUTPUT,
						TEE_PARAM_TYPE_NONE,
						TEE_PARAM_TYPE_NONE);

  IMSG("cmd_sign: Checking params");
	if (pt != exp_pt) {
		return TEE_ERROR_BAD_PARAMETERS;
  }
	if (!state->key)
		return TEE_ERROR_BAD_STATE;

  IMSG("cmd_sign: Getting key");
  res = TEE_GetObjectInfo1(state->key, &key_info);
	if (res) {
		EMSG("TEE_GetObjectInfo1: %#" PRIx32, res);
		return res;
	}

  inbuf = params[0].memref.buffer;
	inbuf_len = params[0].memref.size;
	outbuf = params[1].memref.buffer;
	outbuf_len = params[1].memref.size;
  IMSG("digest size: %d, signature size: %d, key_size: %d", inbuf_len, outbuf_len, key_info.keySize);

  IMSG("cmd_sign: Allocating operation");
	res = TEE_AllocateOperation(&op, alg, TEE_MODE_SIGN,
				    key_info.keySize);
	if (res) {
		EMSG("TEE_AllocateOperation(TEE_MODE_SIGN, %#" PRIx32 ", %" PRId32 "): %#" PRIx32, alg, key_info.keySize, res);
		return res;
	}

  IMSG("cmd_sign: Setting operation key");
  res = TEE_SetOperationKey(op, state->key);
	if (res) {
		EMSG("TEE_SetOperationKey: %#" PRIx32, res);
		goto out;
	}

  IMSG("cmd_sign: Signing");
  res = TEE_AsymmetricSignDigest(op, NULL, 0, inbuf, inbuf_len, outbuf,
            &outbuf_len);
  if (res) {
		EMSG("TEE_AsymmetricSignDigest(%" PRId32 ", %" PRId32 "): %#" PRIx32, inbuf_len, params[1].memref.size, res);
	}
	params[1].memref.size = outbuf_len;

out:
  // TEE_Free(sig_buf);
	TEE_FreeOperation(op);
	return res;
}

static TEE_Result cmd_verify(struct nonce_sign *state, uint32_t pt,
        TEE_Param params[TEE_NUM_PARAMS])
{
  TEE_Result res;
  const void *digestbuf;
  uint32_t digestbuf_len;
  void *sigbuf;
  uint32_t sigbuf_len;
  TEE_OperationHandle op;
  TEE_ObjectInfo key_info;
  const uint32_t alg = TEE_ALG_RSASSA_PKCS1_V1_5_SHA256;
  const uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_MEMREF_INPUT,
						TEE_PARAM_TYPE_NONE,
						TEE_PARAM_TYPE_NONE);

  IMSG("cmd_verify: Checking params");
	if (pt != exp_pt) {
		return TEE_ERROR_BAD_PARAMETERS;
  }
	if (!state->key)
		return TEE_ERROR_BAD_STATE;

  IMSG("cmd_verify: Getting key");
  res = TEE_GetObjectInfo1(state->key, &key_info);
	if (res) {
		EMSG("TEE_GetObjectInfo1: %#" PRIx32, res);
		return res;
	}

  digestbuf = params[0].memref.buffer;
  digestbuf_len = params[0].memref.size;
	sigbuf = params[1].memref.buffer;
	sigbuf_len = params[1].memref.size;

  IMSG("cmd_verify: Allocating operation");
	res = TEE_AllocateOperation(&op, alg, TEE_MODE_VERIFY,
				    key_info.keySize);
	if (res) {
		EMSG("TEE_AllocateOperation(TEE_MODE_SIGN, %#" PRIx32 ", %" PRId32 "): %#" PRIx32, alg, key_info.keySize, res);
		return res;
	}

  IMSG("cmd_verify: Setting operation key");
  res = TEE_SetOperationKey(op, state->key);
	if (res) {
		EMSG("TEE_SetOperationKey: %#" PRIx32, res);
		goto out;
	}

  IMSG("cmd_verify: Verifying");
  res = TEE_AsymmetricVerifyDigest(op, NULL, 0, digestbuf, digestbuf_len, sigbuf,
            sigbuf_len);
  if (res) {
		EMSG("TEE_AsymmetricVerifyDigest(%" PRId32 ", %" PRId32 "): %#" PRIx32, digestbuf_len, params[1].memref.size, res);
	}
	params[1].memref.size = sigbuf_len;

out:
	TEE_FreeOperation(op);
	return res;
}

TEE_Result TA_CreateEntryPoint(void)
{
	/* Nothing to do */
	return TEE_SUCCESS;
}

void TA_DestroyEntryPoint(void)
{
	/* Nothing to do */
}

TEE_Result TA_OpenSessionEntryPoint(uint32_t __unused param_types,
					TEE_Param __unused params[4],
					void **session)
{
	struct nonce_sign *state;

	/*
	 * Allocate and init state for the session.
	 */
	state = TEE_Malloc(sizeof(*state), 0);
	if (!state)
		return TEE_ERROR_OUT_OF_MEMORY;

	state->key = TEE_HANDLE_NULL;

	*session = state;

	return TEE_SUCCESS;
}

void TA_CloseSessionEntryPoint(void *session)
{
	struct nonce_sign *state = session;

	TEE_FreeTransientObject(state->key);
	TEE_Free(state);
}

TEE_Result TA_InvokeCommandEntryPoint(void *session, uint32_t cmd,
				      uint32_t param_types,
				      TEE_Param params[TEE_NUM_PARAMS])
{
	switch (cmd) {
  case TA_NONCE_SIGN_CMD_GEN_NONCE:
    return cmd_gen_nonce(session, param_types, params);
	case TA_NONCE_SIGN_CMD_GEN_KEY:
		return cmd_gen_key(session, param_types, params);
	case TA_NONCE_SIGN_CMD_SIGN:
		return cmd_sign(session, param_types, params);
  case TA_NONCE_SIGN_CMD_VERIFY:
    return cmd_verify(session, param_types, params);
	default:
		EMSG("Command ID %#" PRIx32 " is not supported", cmd);
		return TEE_ERROR_NOT_SUPPORTED;
	}
}
