#include <tommath.h>
#include <stdint.h>
#include <stdio.h>

static unsigned callback_calls;
static uint64_t callback_state = UINT64_C(0x9e3779b97f4a7c15);

static mp_err deterministic_random(void *output, size_t size)
{
   unsigned char *bytes = output;
   size_t i;

   ++callback_calls;
   for (i = 0; i < size; ++i) {
      callback_state ^= callback_state << 7;
      callback_state ^= callback_state >> 9;
      bytes[i] = (unsigned char)callback_state;
   }
   return MP_OKAY;
}

int main(void)
{
   mp_int a, b, product;
   char hexadecimal[256];
   int result = 1;

   if (mp_init(&a) != MP_OKAY)
      return 2;
   if (mp_init(&b) != MP_OKAY) {
      mp_clear(&a);
      return 2;
   }
   if (mp_init(&product) != MP_OKAY) {
      mp_clear(&a);
      mp_clear(&b);
      return 2;
   }

   mp_rand_source(deterministic_random);
   if (mp_rand(&a, 4) != MP_OKAY || mp_rand(&b, 3) != MP_OKAY)
      goto done;
   if (mp_mul(&a, &b, &product) != MP_OKAY)
      goto done;
   if (mp_to_radix(&product, hexadecimal, sizeof(hexadecimal), NULL, 16) != MP_OKAY)
      goto done;
   if (callback_calls != 2 || mp_cmp_d(&product, 0u) != MP_GT)
      goto done;

   printf("callback_calls=%u product=%s\n", callback_calls, hexadecimal);
   result = 0;

done:
   mp_rand_source(NULL);
   mp_clear(&a);
   mp_clear(&b);
   mp_clear(&product);
   return result;
}
