#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int64_t ext_foo() {
  printf("this is ext_foo\n");
  return 123;
}

int64_t ext_2() {
  return 2;
}

int64_t ext_double(int64_t a) {
  return a * ext_2();
}

int64_t ext_sum(int64_t a, int64_t b, int64_t c, int64_t d, int64_t e, int64_t f) {
  return a + b + c + d + e + f;
}

int64_t ext_sum7(int64_t a, int64_t b, int64_t c, int64_t d, int64_t e, int64_t f, int64_t g) {
  return a + b + c + d + e + f + g;
}

int64_t ext_sum7_sub8(int64_t a, int64_t b, int64_t c, int64_t d, int64_t e, int64_t f, int64_t g, int64_t h) {
  return ext_sum7(a, b, c, d, e, f, g) - h;
}

int64_t ext_test() {
  return ext_sum7_sub8(1, 2, 3, 4, 5, 6, 7, 8);
}

void ext_alloc4(int32_t** p, int32_t a0, int32_t a1, int32_t a2, int32_t a3) {
  *p = malloc(4 * sizeof(int32_t));
  (*p)[0] = a0;
  (*p)[1] = a1;
  (*p)[2] = a2;
  (*p)[3] = a3;
}
