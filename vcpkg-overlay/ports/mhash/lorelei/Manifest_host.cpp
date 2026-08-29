#define LORE_THUNK_CALLBACK_REPLACE
#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestHost.cpp.inc>

namespace lore::thunk {

template <>
struct ProcFn<::mhash_init, GuestToHost, Adapt> {
    static MHASH invoke(hashid type) {
        return ProcFn<::mhash_init, GuestToHost, Caller>::invoke(type);
    }
};

template <>
struct ProcFn<::mhash, GuestToHost, Adapt> {
    static mutils_boolean invoke(MHASH thread, const void *plaintext,
                                 mutils_word32 size) {
        return ProcFn<::mhash, GuestToHost, Caller>::invoke(thread, plaintext,
                                                            size);
    }
};

template <>
struct ProcFn<::mhash_deinit, GuestToHost, Adapt> {
    static void invoke(MHASH thread, void *result) {
        ProcFn<::mhash_deinit, GuestToHost, Caller>::invoke(thread, result);
    }
};

template <>
struct ProcFn<::mhash_end, GuestToHost, Adapt> {
    static void *invoke(MHASH thread) {
        return ProcFn<::mhash_end, GuestToHost, Caller>::invoke(thread);
    }
};

template <>
struct ProcFn<::mhash_hmac_init, GuestToHost, Adapt> {
    static MHASH invoke(hashid type, void *key, mutils_word32 keysize,
                        mutils_word32 block) {
        return ProcFn<::mhash_hmac_init, GuestToHost, Caller>::invoke(
            type, key, keysize, block);
    }
};

template <>
struct ProcFn<::mhash_hmac_end, GuestToHost, Adapt> {
    static void *invoke(MHASH thread) {
        return ProcFn<::mhash_hmac_end, GuestToHost, Caller>::invoke(thread);
    }
};

template <>
struct ProcFn<::mhash_save_state_mem, GuestToHost, Adapt> {
    static mutils_boolean invoke(MHASH thread, void *mem,
                                 mutils_word32 *mem_size) {
        return ProcFn<::mhash_save_state_mem, GuestToHost, Caller>::invoke(
            thread, mem, mem_size);
    }
};

template <>
struct ProcFn<::mhash_restore_state_mem, GuestToHost, Adapt> {
    static MHASH invoke(void *mem) {
        return ProcFn<::mhash_restore_state_mem, GuestToHost, Caller>::invoke(
            mem);
    }
};

}
