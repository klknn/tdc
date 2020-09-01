#include <stdint.h>

typedef struct _S {
  int64_t i;
  struct _S* s;
} S;

int64_t foo(int64_t a, S* s) {
  return a + s->i;
}

int main() {
  S s;
  s.i = 123;
  return foo(1, &s);
}
