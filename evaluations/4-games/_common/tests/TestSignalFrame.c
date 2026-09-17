#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <xmmintrin.h>

/* The emulator, not the kernel, builds the guest's signal frames, so the
 * psABI contract for handler entry is something it has to get right on its
 * own.  A handler is entered with the stack shape of a call -- RSP points at
 * a return address -- so RSP % 16 == 8, and compilers rely on that when they
 * spill an xmm register with MOVAPS.  A frame placed 8 bytes off instead
 * faults inside any handler that touches SSE.  That reaches a game as a crash
 * far from the cause: Hollow Knight's Boehm GC suspends threads with a signal,
 * so it died only when loading a save allocated enough to trigger a
 * collection.  Check it here, where the answer is unambiguous. */

static int failures;

static void check(const char *what, int ok) {
    if (!ok) {
        fprintf(stderr, "signal-frame-fail:%s\n", what);
        failures++;
    }
}

/* Entry RSP must be 8 mod 16; the prologue then aligns it, so a handler that
 * observes its own RSP after the prologue should see 0 mod 16. */
static void check_alignment(const char *what) {
    uintptr_t rsp;
    __asm__ volatile("mov %%rsp, %0" : "=r"(rsp));
    check(what, (rsp & 15) == 0);
}

static void check_movaps(const char *what) {
    float buf[4] __attribute__((aligned(16)));
    _mm_store_ps(buf, _mm_set1_ps(2.5f)); /* faults if the frame is misaligned */
    check(what, buf[0] == 2.5f && buf[3] == 2.5f);
}

static void plain_handler(int sig) {
    (void) sig;
    check_alignment("plain-alignment");
    check_movaps("plain-movaps");
}

static volatile int nested_depth;

static void siginfo_handler(int sig, siginfo_t *info, void *uc) {
    (void) uc;
    check_alignment("siginfo-alignment");
    check_movaps("siginfo-movaps");
    check("siginfo-signo", info->si_signo == sig);
    if (nested_depth == 0) {
        nested_depth = 1;
        raise(SIGUSR1); /* a second frame stacked on the first */
        nested_depth = 2;
    }
}

/* Clobbering the xmm registers from a handler proves the frame's FXSAVE area
 * is where the sigreturn path expects it, not merely that it is aligned. */
static void clobber_handler(int sig) {
    static const float ones[4] __attribute__((aligned(16))) = {9, 9, 9, 9};
    (void) sig;
    __asm__ volatile("movaps %0, %%xmm0\n\t"
                     "movaps %0, %%xmm6\n\t"
                     "movaps %0, %%xmm15\n\t"
                     :
                     : "m"(ones)
                     : "xmm0", "xmm6", "xmm15");
}

static void install(int sig, void (*fn)(int), int flags) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = fn;
    sa.sa_flags = flags;
    sigaction(sig, &sa, NULL);
}

int main(void) {
    install(SIGUSR2, plain_handler, 0);
    raise(SIGUSR2);

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = siginfo_handler;
    sa.sa_flags = SA_SIGINFO | SA_NODEFER;
    sigaction(SIGUSR1, &sa, NULL);
    raise(SIGUSR1);
    check("nested-unwound", nested_depth == 2);

    float before[4] __attribute__((aligned(16))) = {1, 2, 3, 4};
    float after[4] __attribute__((aligned(16)));
    __m128 live = _mm_load_ps(before);
    install(SIGUSR2, clobber_handler, 0);
    raise(SIGUSR2);
    _mm_store_ps(after, live);
    check("xmm-restored", memcmp(before, after, sizeof(before)) == 0);

    if (failures) {
        return 1;
    }
    printf("signal-frame:alignment=1:nested=1:xmm=1\n");
    return 0;
}
