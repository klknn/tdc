#!/bin/bash
# -*- sh-basic-offset: 2 -*-

gcc -c test/ext.c

assert() {
  expected="$1"
  input="$2"
  echo "$input"

  ./bin/tdc "$input" > tmp.s || exit 1
  cc -o tmp tmp.s ext.o || exit 1
  ./tmp
  actual="$?"

  if [ "$actual" = "$expected" ]; then
      echo "=> $actual OK!"
  else
    echo "=> $expected expected, but got $actual"
    exit 1
  fi
}

# test pointer ops
assert 3 "
int main() {
  int x;
  int* y;
  x = 3;
  y = &x;
  return *y;
}
"

# multi deref
assert 3 "
int main() {
  int x;
  int* y;
  int** z;
  x = 3;
  y = &x;
  z = &y;
  return **z;
}
"

# deref assign
assert 3 "
int main() {
  int x;
  int* y;
  x = 1;
  y = &x;
  *y = 3;
  return x;
}
"

# test func def
assert 246 "
int foo() { return 123; }
int main() { int a; a = 123; return foo() + a; }
"
assert 3 "
int foo(int a) { return a; }
int main() { return foo(3); }
"

assert 3 "
int foo(int a, int b) { return a - b; }
int main() { return foo(5, 2); }
"

assert 3 "
int foo(int* a) { return *a; }
int main() { int x; x = 3; return foo(&x); }
"


# all args on reg
assert 6 "
int foo(int a, int b, int c, int d, int e, int f) {
  return a + b + c + d + e + f;
}
int main() { return foo(1, 1, 1, 1, 1, 1); }
"
x
assert 4 "
int foo(int a, int b, int c, int d, int e, int f, int g) {
  return a + b + c + d + e + f - g;
}
int main() { return foo(1, 1, 1, 1, 1, 2, 3); }
"

assert 5 "
int foo(int a, int b, int c, int d, int e, int f, int g, int h) {
  return a + b + c + d + e + f + g - h;
}
int main() { return foo(1, 1, 1, 1, 1, 1, 1, 2); }
"



# test recursion
assert 13 "
int fib(int a) { if (a <= 1) return a; return fib(a-2) + fib(a-1); }
int main() { return fib(7); }
"

# external function call
assert 246 "int main() { int a; a = 123; return ext_double(a); }"
assert 6 "int main() { return ext_sum(1, 1, 1, 1, 1, 1); }"
assert 8 "int main() { return ext_sum7(1, 1, 1, 1, 1, 1, 2); }"
assert 5 "int main() { return ext_sum7_sub8(1, 1, 1, 1, 1, 1, 2, 3); }"
assert 123 "int main() { return ext_foo(); }"
assert 124 "int main() { int a; a = 1; return a + ext_foo(); }"

# arithmetics
assert 0 "int main() { return 0; }"
assert 42 "int main() { return 42; }"
assert 21 "int main() { return 5+20-4; }"
assert 47 "int main() { return 5+6*7; }"
assert 15 "int main() { return 5*(9-6); }"
assert 4 "int main() { return (3+5)/2; }"
assert 10 "int main() { return -10+20; }"
assert 10 "int main() { return - -10; }"
assert 10 "int main() { return - - +10; }"
assert 10 "int main() { return + +10; }"

# bool ops
assert 0 "int main() { return !123; }"
assert 0 "int main() { return !1; }"
assert 1 "int main() { return !0; }"
assert 0 "int main() { return 0 && exit(1); }"
assert 0 "int main() { return 0 && 0; }"
assert 0 "int main() { return 0 && 1; }"
assert 0 "int main() { return 1 && 0; }"
assert 1 "int main() { return 1 && 1; }"
assert 1 "int main() { return 1 || exit(1); }"
assert 0 "int main() { return 0 || 0; }"
assert 1 "int main() { return 0 || 1; }"
assert 1 "int main() { return 1 || 0; }"
assert 1 "int main() { return 1 || 1; }"
assert 0 "int main() { return 0 ^ 0; }"
assert 1 "int main() { return 0 ^ 1; }"
assert 1 "int main() { return 1 ^ 0; }"
assert 0 "int main() { return 1 ^ 1; }"
assert 0 "int main() { return 1 & 0; }"
assert 1 "int main() { return 1 | 0; }"
assert 1 "int main() { return 1 == 1; }"
assert 0 "int main() { return 1 == 0; }"
assert 0 "int main() { return 1 != 1; }"
assert 1 "int main() { return 1 != 0; }"
assert 1 "int main() { return 1 < 2; }"
assert 0 "int main() { return 1 > 2; }"
assert 1 "int main() { return 1 <= 2; }"
assert 0 "int main() { return 1 >= 2; }"

# local vars
assert 1 "
int main() {
  int foo;
  int bar;
  foo = 1;
  bar = 2;
  return bar - foo;
}"
assert 4 "int main() { int a; a = 1; a = a + 3; return a; }"

# if-else
assert 1 "int main() { if (1 == 1) return 1; return 2; }"
assert 2 "int main() { if (1 == 0) return 1; return 2; }"
assert 2 "int main() { if (1 == 0) return 1; else return 2; }"

# for
assert 10 "
int main() {
  int a;
  int b;
  a = 0;
  b = 0;
  for (; a <= 10; a = a + 1)
    b = a;
  return b;
}"

# while
assert 10 "
int main() {
  int a;
  int b;
  a = 0;
  b = 0;
  while (b < 10) {
    b = b + 1;
    a = b;
  }
  return a;
}"

echo OK
