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

for function, arguments in (
    ("breakdown_test_2", "int arg1, int arg2"),
    ("breakdown_test_6", "int arg1, int arg2, int arg3, int arg4, int arg5, int arg6"),
):
    text = replace_once(
        text,
        f"""invoke({arguments}) {{
    // prolog
    int ret;
    void *args[] = {{
""",
        f"""invoke({arguments}) {{
    // prolog
    breakdown_marker(1);
    int ret;
    void *args[] = {{
""",
        f"{function} caller entry",
    )

    text = replace_once(
        text,
        f"""    // forward
    // center
    ProcFn<{function}, GuestToHost, Exec>::invoke(args, &ret, nullptr);
""",
        f"""    // forward
    // center
    breakdown_marker(2);
    ProcFn<{function}, GuestToHost, Exec>::invoke(args, &ret, nullptr);
""",
        f"{function} dispatch",
    )

path.write_text(text)
