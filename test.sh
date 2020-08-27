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

# test func def
assert 246 "
foo() { return 123; }
main() { a = 123; return foo() + a; }
"
assert 3 "
foo(a) { return a; }
main() { return foo(3); }
"

assert 3 "
foo(a, b) { return a - b; }
main() { return foo(5, 2); }
"

# all args on reg
assert 6 "
foo(a, b, c, d, e, f) { return a + b + c + d + e + f; }
main() { return foo(1, 1, 1, 1, 1, 1); }
"

# TODO: 7th args on stack
assert 4 "
foo(a, b, c, d, e, f, g) { return a + b + c + d + e + f - g; }
main() { return foo(1, 1, 1, 1, 1, 2, 3); }
"

assert 5 "
foo(a, b, c, d, e, f, g, h) { return a + b + c + d + e + f + g - h; }
main() { return foo(1, 1, 1, 1, 1, 1, 1, 2); }
"



# test recursion
assert 13 "
fib(a) { if (a <= 1) return a; return fib(a-2) + fib(a-1); }
main() { return fib(7); }
"

assert 246 "main() { a = 123; return ext_double(a); }"
assert 6 "main() { return ext_sum(1, 1, 1, 1, 1, 1); }"
assert 8 "main() { return ext_sum7(1, 1, 1, 1, 1, 1, 2); }"
assert 5 "main() { return ext_sum7_sub8(1, 1, 1, 1, 1, 1, 2, 3); }"
assert 123 "main() { return ext_foo(); }"
assert 124 "main() { a = 1; return a + ext_foo(); }"

assert 0 "main() { return 0; }"
assert 42 "main() { return 42; }"
assert 21 "main() { return 5+20-4; }"
assert 47 "main() { return 5+6*7; }"
assert 15 "main() { return 5*(9-6); }"
assert 4 "main() { return (3+5)/2; }"
assert 10 "main() { return -10+20; }"
assert 10 "main() { return - -10; }"
assert 10 "main() { return - - +10; }"
assert 10 "main() { return + +10; }"

assert 1 "main() { return 1 == 1; }"
assert 0 "main() { return 1 == 0; }"
assert 0 "main() { return 1 != 1; }"
assert 1 "main() { return 1 != 0; }"
assert 1 "main() { return 1 < 2; }"
assert 0 "main() { return 1 > 2; }"
assert 1 "main() { return 1 <= 2; }"
assert 0 "main() { return 1 >= 2; }"

# local vars
assert 3 "
main() {
  foo = 1;
  bar = 2;
  return foo + bar;
}"
assert 4 "main() { a = 1; a = a + 3; return a; }"

# if-else
assert 1 "main() { if (1 == 1) return 1; return 2; }"
assert 2 "main() { if (1 == 0) return 1; return 2; }"
assert 2 "main() { if (1 == 0) return 1; else return 2; }"

# for
assert 10 "
main() {
  a = 0;
  b = 0;
  for (; a <= 10; a = a + 1)
    b = a;
  return b;
}"

# while
assert 10 "
main() {
  a = 0;
  b = 0;
  while (b < 10) {
    b = b + 1;
    a = b;
  }
  return a;
}"

echo OK
