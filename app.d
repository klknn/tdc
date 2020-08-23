nothrow @nogc:

import tdc.tokenize : tokenize;
import tdc.codegen : genX64;
import tdc.parse : program, Node;
import tdc.stdc.stdio : fprintf, printf, stderr;

extern (C)
int main(int argc, char** argv) {
  if (argc != 2) {
    fprintf(stderr, "invalid number of arguments: %d != 2\n", argc);
    return 1;
  }

  tokenize(argv[1]);
  Node** ast = program(1000);

  // headers
  printf(".intel_syntax noprefix\n");
  printf(".global main\n");
  printf("main:\n");

  // prologue
  // alloc a-z vars
  printf("  push rbp\n");
  printf("  mov rbp, rsp\n");
  printf("  sub rsp, %d\n", 26 * long.sizeof);
  for (long i = 0;  ast[i]; ++i) {
    genX64(ast[i]);
    // pop the last expresion result on top
    printf("  pop rax\n");
  }

  // epilogue
  // return the last expression result in rax
  printf("  mov rsp, rbp\n");
  printf("  pop rbp\n");
  printf("  ret\n");
  return 0;
}
