#include <libpsl.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    const psl_ctx_t *psl = psl_builtin();
    int com = psl && psl_is_public_suffix(psl, "com");
    int co_uk = psl && psl_is_public_suffix(psl, "co.uk");
    int wildcard = psl && psl_is_public_suffix(psl, "foo.ck");
    int exception = psl && !psl_is_public_suffix(psl, "www.ck");
    const char *registrable = psl ? psl_registrable_domain(psl, "www.example.co.uk") : NULL;
    const char *suffix = psl ? psl_unregistrable_domain(psl, "www.example.co.uk") : NULL;
    int ok = com && co_uk && wildcard && exception && registrable && suffix &&
             strcmp(registrable, "example.co.uk") == 0 && strcmp(suffix, "co.uk") == 0;
    printf("com=%d co_uk=%d wildcard=%d exception=%d registrable=%s suffix=%s\n",
           com, co_uk, wildcard, exception, registrable ? registrable : "", suffix ? suffix : "");
    return ok ? 0 : 1;
}
