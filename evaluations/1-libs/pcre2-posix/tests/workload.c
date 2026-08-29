#include <pcre2posix.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    regex_t regex;
    regmatch_t matches[2];
    int compile_rc = regcomp(&regex, "lore(lei)", REG_EXTENDED | REG_ICASE);
    int match_rc = compile_rc ? compile_rc : regexec(&regex, "xxLOREleiyy", 2, matches, 0);
    int no_match = compile_rc ? compile_rc : regexec(&regex, "hecate", 0, NULL, 0);
    if (!compile_rc) regfree(&regex);
    regex_t invalid;
    int invalid_rc = regcomp(&invalid, "(", REG_EXTENDED);
    char error[128] = {0};
    size_t error_len = regerror(invalid_rc, &invalid, error, sizeof(error));
    int ok = compile_rc == 0 && match_rc == 0 && matches[0].rm_so == 2 && matches[0].rm_eo == 9 &&
             matches[1].rm_so == 6 && matches[1].rm_eo == 9 && no_match == REG_NOMATCH &&
             invalid_rc != 0 && error_len > 1 && error[0] != 0;
    printf("match=%d whole=%ld:%ld capture=%ld:%ld nomatch=%d invalid=%d error=%d\n", match_rc,
           (long)matches[0].rm_so, (long)matches[0].rm_eo, (long)matches[1].rm_so, (long)matches[1].rm_eo,
           no_match == REG_NOMATCH, invalid_rc != 0, error[0] != 0);
    return ok ? 0 : 1;
}
