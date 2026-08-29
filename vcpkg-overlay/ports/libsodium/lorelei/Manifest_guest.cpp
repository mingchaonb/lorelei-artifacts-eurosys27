#define LORE_THUNK_CALLBACK_REPLACE
#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestGuest.cpp.inc>

#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <csignal>
#include <sys/mman.h>
#include <unistd.h>

namespace {

constexpr unsigned char canary[] = {
    0x6c, 0x6f, 0x72, 0x65, 0x6c, 0x65, 0x69, 0x2d,
    0x73, 0x6f, 0x64, 0x69, 0x75, 0x6d, 0x21, 0x00,
};

struct Allocation {
    void *user;
    unsigned char *mapping;
    unsigned char *payload;
    size_t payload_size;
    size_t mapping_size;
    Allocation *next;
};

Allocation *allocations;
uint32_t (*guest_uniform)(uint32_t);

[[noreturn]] void guest_abort() {
    sigset_t set;
    sigemptyset(&set);
    sigaddset(&set, SIGABRT);
    sigprocmask(SIG_UNBLOCK, &set, nullptr);
    raise(SIGABRT);
    _exit(134);
}

size_t page_size() {
    static const size_t value = static_cast<size_t>(sysconf(_SC_PAGESIZE));
    return value;
}

Allocation *find_allocation(void *user) {
    for (Allocation *entry = allocations; entry != nullptr; entry = entry->next) {
        if (entry->user == user) {
            return entry;
        }
    }
    return nullptr;
}

int protect(void *user, int protection) {
    Allocation *entry = find_allocation(user);
    if (entry == nullptr) {
        errno = EINVAL;
        return -1;
    }
    return mprotect(entry->payload, entry->payload_size, protection);
}

}

namespace lore::thunk {

template <>
struct ProcFn<::randombytes_set_implementation, GuestToHost, Adapt> {
    static int invoke(const struct randombytes_implementation *implementation) {
        const auto marker = reinterpret_cast<uintptr_t>(implementation == nullptr ? nullptr : implementation->implementation_name);
        if (marker == 2 && implementation->uniform != nullptr) {
            guest_uniform = implementation->uniform;
            return 0;
        }
        guest_uniform = nullptr;
        return ProcFn<::randombytes_set_implementation, GuestToHost, Caller>::invoke(implementation);
    }
};

template <>
struct ProcFn<::randombytes_uniform, GuestToHost, Adapt> {
    static uint32_t invoke(uint32_t upper_bound) {
        if (guest_uniform != nullptr) {
            return guest_uniform(upper_bound);
        }
        return ProcFn<::randombytes_uniform, GuestToHost, Caller>::invoke(upper_bound);
    }
};

template <>
struct ProcFn<::crypto_kx_client_session_keys, GuestToHost, Adapt> {
    static int invoke(unsigned char *rx, unsigned char *tx, const unsigned char *client_pk,
                      const unsigned char *client_sk, const unsigned char *server_pk) {
        if (rx == nullptr && tx == nullptr) guest_abort();
        return ProcFn<::crypto_kx_client_session_keys, GuestToHost, Caller>::invoke(rx, tx, client_pk, client_sk, server_pk);
    }
};

template <>
struct ProcFn<::crypto_kx_server_session_keys, GuestToHost, Adapt> {
    static int invoke(unsigned char *rx, unsigned char *tx, const unsigned char *server_pk,
                      const unsigned char *server_sk, const unsigned char *client_pk) {
        if (rx == nullptr && tx == nullptr) guest_abort();
        return ProcFn<::crypto_kx_server_session_keys, GuestToHost, Caller>::invoke(rx, tx, server_pk, server_sk, client_pk);
    }
};

template <>
struct ProcFn<::randombytes_buf_deterministic, GuestToHost, Adapt> {
    static void invoke(void *buf, size_t size, const unsigned char *seed) {
        if (size > 0x4000000000ULL) guest_abort();
        ProcFn<::randombytes_buf_deterministic, GuestToHost, Caller>::invoke(buf, size, seed);
    }
};

#define SODIUM_AEAD_MISUSE_ADAPTER(function_name) \
template <> struct ProcFn<::function_name, GuestToHost, Adapt> { \
    static int invoke(unsigned char *c, unsigned long long *clen, const unsigned char *m, \
                      unsigned long long mlen, const unsigned char *ad, unsigned long long adlen, \
                      const unsigned char *nsec, const unsigned char *npub, const unsigned char *key) { \
        if (mlen == UINT64_MAX) guest_abort(); \
        return ProcFn<::function_name, GuestToHost, Caller>::invoke(c, clen, m, mlen, ad, adlen, nsec, npub, key); \
    } \
}

SODIUM_AEAD_MISUSE_ADAPTER(crypto_aead_chacha20poly1305_encrypt);
SODIUM_AEAD_MISUSE_ADAPTER(crypto_aead_chacha20poly1305_ietf_encrypt);
SODIUM_AEAD_MISUSE_ADAPTER(crypto_aead_xchacha20poly1305_ietf_encrypt);

#undef SODIUM_AEAD_MISUSE_ADAPTER

template <>
struct ProcFn<::sodium_pad, GuestToHost, Adapt> {
    static int invoke(size_t *padded, unsigned char *buf, size_t unpadded, size_t block, size_t maximum) {
        if (unpadded == SIZE_MAX) guest_abort();
        return ProcFn<::sodium_pad, GuestToHost, Caller>::invoke(padded, buf, unpadded, block, maximum);
    }
};

template <>
struct ProcFn<::sodium_bin2base64, GuestToHost, Adapt> {
    static char *invoke(char *b64, size_t maximum, const unsigned char *bin, size_t length, int variant) {
        if (variant < 0 || maximum <= length) guest_abort();
        return ProcFn<::sodium_bin2base64, GuestToHost, Caller>::invoke(b64, maximum, bin, length, variant);
    }
};

template <>
struct ProcFn<::sodium_base642bin, GuestToHost, Adapt> {
    static int invoke(unsigned char *bin, size_t maximum, const char *b64, size_t length,
                      const char *ignore, size_t *bin_length, const char **b64_end, int variant) {
        if (variant < 0) guest_abort();
        return ProcFn<::sodium_base642bin, GuestToHost, Caller>::invoke(bin, maximum, b64, length, ignore, bin_length, b64_end, variant);
    }
};

#define SODIUM_BOX_EASY_MISUSE_ADAPTER(function_name) \
template <> struct ProcFn<::function_name, GuestToHost, Adapt> { \
    static int invoke(unsigned char *c, const unsigned char *m, unsigned long long mlen, \
                      const unsigned char *nonce, const unsigned char *pk, const unsigned char *sk) { \
        if (mlen >= crypto_stream_xsalsa20_MESSAGEBYTES_MAX) guest_abort(); \
        return ProcFn<::function_name, GuestToHost, Caller>::invoke(c, m, mlen, nonce, pk, sk); \
    } \
}

SODIUM_BOX_EASY_MISUSE_ADAPTER(crypto_box_easy);

#undef SODIUM_BOX_EASY_MISUSE_ADAPTER

#define SODIUM_BOX_AFTERNM_MISUSE_ADAPTER(function_name) \
template <> struct ProcFn<::function_name, GuestToHost, Adapt> { \
    static int invoke(unsigned char *c, const unsigned char *m, unsigned long long mlen, \
                      const unsigned char *nonce, const unsigned char *key) { \
        if (mlen >= crypto_stream_xsalsa20_MESSAGEBYTES_MAX) guest_abort(); \
        return ProcFn<::function_name, GuestToHost, Caller>::invoke(c, m, mlen, nonce, key); \
    } \
}

SODIUM_BOX_AFTERNM_MISUSE_ADAPTER(crypto_box_easy_afternm);

#undef SODIUM_BOX_AFTERNM_MISUSE_ADAPTER

template <>
struct ProcFn<::crypto_pwhash_str_alg, GuestToHost, Adapt> {
    static int invoke(char *out, const char *password, unsigned long long password_length,
                      unsigned long long opslimit, size_t memlimit, int algorithm) {
        if (algorithm < 0) guest_abort();
        return ProcFn<::crypto_pwhash_str_alg, GuestToHost, Caller>::invoke(out, password, password_length, opslimit, memlimit, algorithm);
    }
};

template <>
struct ProcFn<::crypto_box_curve25519xchacha20poly1305_easy, GuestToHost, Adapt> {
    static int invoke(unsigned char *c, const unsigned char *m, unsigned long long mlen,
                      const unsigned char *nonce, const unsigned char *pk, const unsigned char *sk) {
        if (mlen >= crypto_stream_xchacha20_MESSAGEBYTES_MAX - 1) guest_abort();
        return ProcFn<::crypto_box_curve25519xchacha20poly1305_easy, GuestToHost, Caller>::invoke(c, m, mlen, nonce, pk, sk);
    }
};

template <>
struct ProcFn<::crypto_box_curve25519xchacha20poly1305_easy_afternm, GuestToHost, Adapt> {
    static int invoke(unsigned char *c, const unsigned char *m, unsigned long long mlen,
                      const unsigned char *nonce, const unsigned char *key) {
        if (mlen >= crypto_stream_xchacha20_MESSAGEBYTES_MAX - 1) guest_abort();
        return ProcFn<::crypto_box_curve25519xchacha20poly1305_easy_afternm, GuestToHost, Caller>::invoke(c, m, mlen, nonce, key);
    }
};

}

extern "C" {

struct randombytes_implementation randombytes_internal_implementation = {
    reinterpret_cast<const char *(*)()>(static_cast<uintptr_t>(1)), nullptr, nullptr, nullptr, nullptr, nullptr
};
struct randombytes_implementation randombytes_sysrandom_implementation = {
    reinterpret_cast<const char *(*)()>(static_cast<uintptr_t>(2)), nullptr, nullptr, nullptr, nullptr, nullptr
};

static void (*guest_misuse_handler)(void);

int sodium_set_misuse_handler(void (*handler)(void)) {
    guest_misuse_handler = handler;
    return 0;
}

void sodium_misuse(void) {
    if (guest_misuse_handler != nullptr) {
        guest_misuse_handler();
    }
    guest_abort();
}

void sodium_memzero(void *memory, size_t length) {
    volatile unsigned char *bytes = static_cast<volatile unsigned char *>(memory);
    while (length-- != 0) {
        *bytes++ = 0;
    }
}

void *sodium_malloc(size_t requested_size) {
    const size_t size = requested_size == 0 ? 1 : requested_size;
    const size_t page = page_size();
    if (size > SIZE_MAX - sizeof(canary) - page) {
        errno = ENOMEM;
        return nullptr;
    }
    const size_t payload_size = (size + sizeof(canary) + page - 1) & ~(page - 1);
    if (payload_size > SIZE_MAX - page * 2) {
        errno = ENOMEM;
        return nullptr;
    }
    const size_t mapping_size = payload_size + page * 2;
    auto *mapping = static_cast<unsigned char *>(mmap(nullptr, mapping_size, PROT_NONE,
        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    if (mapping == MAP_FAILED) {
        return nullptr;
    }
    unsigned char *payload = mapping + page;
    if (mprotect(payload, payload_size, PROT_READ | PROT_WRITE) != 0) {
        munmap(mapping, mapping_size);
        return nullptr;
    }
    unsigned char *user = payload + payload_size - size;
    std::memcpy(user - sizeof(canary), canary, sizeof(canary));
    std::memset(user, 0xdb, requested_size);
    auto *entry = static_cast<Allocation *>(std::malloc(sizeof(Allocation)));
    if (entry == nullptr) {
        munmap(mapping, mapping_size);
        errno = ENOMEM;
        return nullptr;
    }
    *entry = {user, mapping, payload, payload_size, mapping_size, allocations};
    allocations = entry;
    return user;
}

void *sodium_allocarray(size_t count, size_t size) {
    if (count != 0 && size >= SIZE_MAX / count) {
        errno = ENOMEM;
        return nullptr;
    }
    return sodium_malloc(count * size);
}

int sodium_mprotect_noaccess(void *user) {
    return protect(user, PROT_NONE);
}

int sodium_mprotect_readonly(void *user) {
    return protect(user, PROT_READ);
}

int sodium_mprotect_readwrite(void *user) {
    return protect(user, PROT_READ | PROT_WRITE);
}

void sodium_free(void *user) {
    if (user == nullptr) {
        return;
    }
    Allocation **link = &allocations;
    while (*link != nullptr && (*link)->user != user) {
        link = &(*link)->next;
    }
    if (*link == nullptr) {
        sodium_misuse();
    }
    Allocation *entry = *link;
    if (mprotect(entry->payload, entry->payload_size, PROT_READ | PROT_WRITE) != 0 ||
        std::memcmp(static_cast<unsigned char *>(user) - sizeof(canary), canary, sizeof(canary)) != 0) {
        sodium_misuse();
    }
    *link = entry->next;
    munmap(entry->mapping, entry->mapping_size);
    std::free(entry);
}

}
