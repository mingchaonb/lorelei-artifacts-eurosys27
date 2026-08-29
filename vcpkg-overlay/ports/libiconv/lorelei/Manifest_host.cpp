#define LORE_THUNK_CALLBACK_REPLACE
#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestHost.cpp.inc>

namespace lore::thunk {

    /// IconvCtlCallbackContext - Callback state for the two dynamically typed iconvctl payloads.
    struct IconvCtlCallbackContext {
        CallbackContext ucHook;
        CallbackContext wcHook;
        CallbackContext mbToUcFallback;
        CallbackContext ucToMbFallback;
        CallbackContext mbToWcFallback;
        CallbackContext wcToMbFallback;
    };

    template <>
    struct ProcFn<::libiconvctl, GuestToHost, Adapt> {
        static int invoke(libiconv_t cd, int request, void *argument) {
            IconvCtlCallbackContext context;

            if (request == ICONV_SET_HOOKS && argument) {
                auto hooks = *static_cast<const iconv_hooks *>(argument);
                context.ucHook.init<true>(
                    reinterpret_cast<void *&>(hooks.uc_hook),
                    allocCallbackTrampoline<
                        ProcCb<iconv_unicode_char_hook, HostToGuest, Entry>::invoke>);
                context.wcHook.init<true>(
                    reinterpret_cast<void *&>(hooks.wc_hook),
                    allocCallbackTrampoline<
                        ProcCb<iconv_wide_char_hook, HostToGuest, Entry>::invoke>);
                return ProcFn<::libiconvctl, GuestToHost, Caller>::invoke(cd, request, &hooks);
            }

            if (request == ICONV_SET_FALLBACKS && argument) {
                auto fallbacks = *static_cast<const iconv_fallbacks *>(argument);
                context.mbToUcFallback.init<true>(
                    reinterpret_cast<void *&>(fallbacks.mb_to_uc_fallback),
                    allocCallbackTrampoline<
                        ProcCb<iconv_unicode_mb_to_uc_fallback, HostToGuest, Entry>::invoke>);
                context.ucToMbFallback.init<true>(
                    reinterpret_cast<void *&>(fallbacks.uc_to_mb_fallback),
                    allocCallbackTrampoline<
                        ProcCb<iconv_unicode_uc_to_mb_fallback, HostToGuest, Entry>::invoke>);
                context.mbToWcFallback.init<true>(
                    reinterpret_cast<void *&>(fallbacks.mb_to_wc_fallback),
                    allocCallbackTrampoline<
                        ProcCb<iconv_wchar_mb_to_wc_fallback, HostToGuest, Entry>::invoke>);
                context.wcToMbFallback.init<true>(
                    reinterpret_cast<void *&>(fallbacks.wc_to_mb_fallback),
                    allocCallbackTrampoline<
                        ProcCb<iconv_wchar_wc_to_mb_fallback, HostToGuest, Entry>::invoke>);
                return ProcFn<::libiconvctl, GuestToHost, Caller>::invoke(cd, request, &fallbacks);
            }

            return ProcFn<::libiconvctl, GuestToHost, Caller>::invoke(cd, request, argument);
        }
    };

}
