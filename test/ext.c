#include <stdio.h>

int ext_foo() {
  printf("this is ext_foo\n");
  return 123;
}

int ext_2() {
  return 2;
}

int ext_double(int a) {
  return a * ext_2();
}

int ext_sum(int a, int b, int c, int d, int e, int f) {
  return a + b + c + d + e + f;
}

int ext_sum7(int a, int b, int c, int d, int e, int f, int g) {
  return a + b + c + d + e + f + g;
}

int ext_sum7_sub8(int a, int b, int c, int d, int e, int f, int g, int h) {
  return ext_sum7(a, b, c, d, e, f, g) - h;
}

int ext_test() {
  return ext_sum7_sub8(1, 2, 3, 4, 5, 6, 7, 8);
}
