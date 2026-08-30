#!/usr/bin/env python3

import pathlib
import sys


def replace_once(text: str, old: str, new: str, description: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one {description}, found {count}")
    return text.replace(old, new, 1)


path = pathlib.Path(sys.argv[1])
text = path.read_text()

text = replace_once(
    text,
    "#define LORE_THUNK_BUILD\n",
    """#define LORE_THUNK_BUILD
#define LORE_THUNK_NEXT_LIBRARY "../libbreakdown_test_HTL.so"

#include <stdint.h>

static inline void breakdown_marker(uint32_t operation)
{
    register uint32_t eax __asm__("eax") = operation;
    register uint32_t ebx __asm__("ebx") = 0xa001;

    __asm__ volatile("ud2" : "+a"(eax), "+b"(ebx) : : "memory");
}
""",
    "LORE_THUNK_BUILD definition",
)

text = replace_once(
    text,
    """invoke(int arg1, int arg2, int arg3) {
    // prolog
    int ret;
    void *args[] = {
""",
    """invoke(int arg1, int arg2, int arg3) {
    // prolog
    breakdown_marker(1);
    int ret;
    void *args[] = {
""",
    "breakdown_test caller entry",
)

text = replace_once(
    text,
    """    // forward
    // center
    ProcFn<breakdown_test, GuestToHost, Exec>::invoke(args, &ret, nullptr);
""",
    """    // forward
    // center
    breakdown_marker(2);
    ProcFn<breakdown_test, GuestToHost, Exec>::invoke(args, &ret, nullptr);
""",
    "breakdown_test dispatch",
)

path.write_text(text)
