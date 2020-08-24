nothrow @nogc:

import tdc.tokenize : tokenize;
import tdc.codegen : genX64;
import tdc.parse : program, Program;
import tdc.stdc.stdio : fprintf, printf, stderr;

extern (C)
int main(int argc, char** argv) {
  if (argc != 2) {
    fprintf(stderr, "invalid number of arguments: %d != 2\n", argc);
    return 1;
  }

  tokenize(argv[1]);
  Program p = program(1000);

  // headers
  printf(".intel_syntax noprefix\n");
  printf(".global main\n");
  printf("main:\n");

  // prologue
  // alloc a-z vars
  printf("  push rbp\n");
  printf("  mov rbp, rsp\n");
  printf("  sub rsp, %d\n", p.localsLength * long.sizeof);
  for (long i = 0;  p.nodes[i]; ++i) {
    genX64(p.nodes[i]);
    // pop the last expresion result on top
    printf("  pop rax\n");
  }
  return 0;
}
