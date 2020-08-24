#!/bin/bash
# -*- sh-basic-offset: 2 -*-
assert() {
  expected="$1"
  input="$2"

  ./bin/tdc "$input" > tmp.s
  cc -o tmp tmp.s
  ./tmp
  actual="$?"

  if [ "$actual" = "$expected" ]; then
      echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

assert 0 "return 0;"
assert 42 "return 42;"
assert 21 "return 5+20-4;"
assert 47 "return 5+6*7;"
assert 15 "return 5*(9-6);"
assert 4 "return (3+5)/2;"
assert 10 "return -10+20;"
assert 10 "return - -10;"
assert 10 "return - - +10;"
assert 10 "return + +10;"

assert 1 "return 1 == 1;"
assert 0 "return 1 == 0;"
assert 0 "return 1 != 1;"
assert 1 "return 1 != 0;"
assert 1 "return 1 < 2;"
assert 0 "return 1 > 2;"
assert 1 "return 1 <= 2;"
assert 0 "return 1 >= 2;"

# local vars
assert 3 "
foo = 1;
bar = 2;
return foo + bar;
"
assert 4 "a = 1; a = a + 3; return a;"

# if-else
assert 1 "if (1 == 1) return 1; return 2;"
assert 2 "if (1 == 0) return 1; return 2;"
assert 2 "if (1 == 0) return 1; else return 2;"

# for
assert 10 "
b = 0;
for (; a <= 10; a = a + 1)
  b = a;
return b;
"

# while
assert 10 "
b = 0;
while (b < 10)
  b = b + 1;
return b;
"

echo OK
