// SPDX-License-Identifier: MIT

#include <SDL.h>

#include <stdio.h>
#include <string.h>

static int failures;

static void check(int condition, const char *name) {
    if (condition) {
        printf("PASS: %s\n", name);
    } else {
        fprintf(stderr, "FAIL: %s\n", name);
        ++failures;
    }
}

static int SDLCALL event_filter(void *userdata, SDL_Event *event) {
    int *calls = userdata;
    ++*calls;
    return event->type >= SDL_USEREVENT;
}

static int SDLCALL event_watch(void *userdata, SDL_Event *event) {
    int *calls = userdata;
    ++*calls;
    return event->type >= SDL_USEREVENT;
}

static void SDLCALL log_output(void *userdata, int category,
                               SDL_LogPriority priority, const char *message) {
    int *calls = userdata;
    (void)category;
    (void)priority;
    if (message && strstr(message, "Lorelei callback probe")) {
        ++*calls;
    }
}

static SDL_AssertState SDLCALL assertion_handler(
    const SDL_AssertData *data, void *userdata) {
    int *calls = userdata;
    if (data && data->condition) {
        ++*calls;
    }
    return SDL_ASSERTION_IGNORE;
}

static Uint32 SDLCALL timer_callback(Uint32 interval, void *userdata) {
    volatile int *calls = userdata;
    (void)interval;
    ++*calls;
    return 0;
}

static int SDLCALL thread_entry(void *userdata) {
    int *calls = userdata;
    ++*calls;
    return 73;
}

static void test_events(void) {
    int filter_calls = 0;
    int watch_calls = 0;
    Uint32 event_type = SDL_RegisterEvents(1);
    SDL_Event event;

    check(event_type != (Uint32)-1, "register user event");
    if (event_type == (Uint32)-1) {
        return;
    }

    SDL_AddEventWatch(event_watch, &watch_calls);
    SDL_SetEventFilter(event_filter, &filter_calls);
    SDL_zero(event);
    event.type = event_type;
    check(SDL_PushEvent(&event) == 1, "push filtered and watched event");
    check(filter_calls == 1, "event filter callback");
    check(watch_calls == 1, "event watch callback");
    SDL_SetEventFilter(NULL, NULL);
    SDL_DelEventWatch(event_watch, &watch_calls);
    SDL_FlushEvent(event_type);
}

static void test_log(void) {
    SDL_LogOutputFunction previous = NULL;
    void *previous_userdata = NULL;
    int calls = 0;

    SDL_LogGetOutputFunction(&previous, &previous_userdata);
    SDL_LogSetOutputFunction(log_output, &calls);
    SDL_LogMessage(SDL_LOG_CATEGORY_APPLICATION, SDL_LOG_PRIORITY_INFO,
                   "Lorelei callback probe");
    check(calls == 1, "log output callback");
    SDL_LogSetOutputFunction(previous, previous_userdata);
}

static void test_assertion(void) {
    SDL_AssertionHandler previous;
    void *previous_userdata = NULL;
    int calls = 0;

    previous = SDL_GetAssertionHandler(&previous_userdata);
    SDL_SetAssertionHandler(assertion_handler, &calls);
    SDL_assert_always(0 && "Lorelei callback probe");
    check(calls == 1, "assertion handler callback");
    SDL_SetAssertionHandler(previous, previous_userdata);
    SDL_ResetAssertionReport();
}

static void test_timer(void) {
    volatile int calls = 0;
    SDL_TimerID timer = SDL_AddTimer(10, timer_callback, (void *)&calls);
    int waited_ms = 0;

    check(timer != 0, "create callback timer");
    while (timer && calls == 0 && waited_ms < 1000) {
        SDL_Delay(10);
        waited_ms += 10;
    }
    check(calls == 1, "timer callback");
    if (timer) {
        SDL_RemoveTimer(timer);
    }
}

static void test_thread(void) {
    int calls = 0;
    int status = 0;
    SDL_Thread *thread = SDL_CreateThread(thread_entry, "callback-probe", &calls);

    check(thread != NULL, "create callback thread");
    if (!thread) {
        return;
    }
    SDL_WaitThread(thread, &status);
    check(calls == 1, "thread entry callback");
    check(status == 73, "thread callback return value");
}

static void test_allocator_fdg(void) {
    SDL_malloc_func malloc_function = NULL;
    SDL_calloc_func calloc_function = NULL;
    SDL_realloc_func realloc_function = NULL;
    SDL_free_func free_function = NULL;
    unsigned char *allocation;
    int zeroed = 1;
    int i;

    SDL_GetMemoryFunctions(&malloc_function, &calloc_function,
                           &realloc_function, &free_function);
    check(malloc_function && calloc_function && realloc_function && free_function,
          "allocator getter returned four functions");
    if (!malloc_function || !calloc_function || !realloc_function ||
        !free_function) {
        return;
    }

    allocation = calloc_function(16, 1);
    check(allocation != NULL, "FDG calloc invocation");
    if (allocation) {
        for (i = 0; i < 16; ++i) {
            zeroed &= allocation[i] == 0;
        }
        check(zeroed, "FDG calloc result");
        allocation = realloc_function(allocation, 64);
        check(allocation != NULL, "FDG realloc invocation");
        if (allocation) {
            free_function(allocation);
            check(1, "FDG free invocation");
        }
    }

    allocation = malloc_function(32);
    check(allocation != NULL, "FDG malloc invocation");
    if (allocation) {
        free_function(allocation);
    }
}

int main(void) {
    if (SDL_Init(SDL_INIT_EVENTS | SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    test_events();
    test_log();
    test_assertion();
    test_timer();
    test_thread();
    test_allocator_fdg();
    SDL_Quit();

    if (failures) {
        fprintf(stderr, "%d SDL callback checks failed\n", failures);
        return 1;
    }
    puts("All SDL callback and FDG checks passed");
    return 0;
}
