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
#define LORE_THUNK_NEXT_LIBRARY \"../libz_HTL.so\"

#include <stdint.h>

static inline void breakdown_marker(uint32_t operation)
{
    register uint32_t eax __asm__(\"eax\") = operation;
    register uint32_t ebx __asm__(\"ebx\") = 0xa001;

    __asm__ volatile(\"ud2\" : \"+a\"(eax), \"+b\"(ebx) : : \"memory\");
}
""",
    "LORE_THUNK_BUILD definition",
)

text = replace_once(
    text,
    """const char * ProcFn<::zlibVersion, GuestToHost, Caller>::
invoke() {
    // prolog
    const char *ret;
""",
    """const char * ProcFn<::zlibVersion, GuestToHost, Caller>::
invoke() {
    // prolog
    breakdown_marker(1);
    const char *ret;
""",
    "zlibVersion caller entry",
)

text = replace_once(
    text,
    """    // forward
    // center
    ProcFn<zlibVersion, GuestToHost, Exec>::invoke(args, &ret, nullptr);
""",
    """    // forward
    // center
    breakdown_marker(2);
    ProcFn<zlibVersion, GuestToHost, Exec>::invoke(args, &ret, nullptr);
""",
    "zlibVersion dispatch",
)

path.write_text(text)
