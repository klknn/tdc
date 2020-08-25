nothrow @nogc:

import tdc.tokenize : tokenize;
import tdc.codegen : genX64;
import tdc.parse : program, Program, Node;
import tdc.stdc.stdio : fprintf, printf, stderr;

extern (C)
int main(int argc, char** argv) {
  if (argc != 2) {
    fprintf(stderr, "invalid number of arguments: %d != 2\n", argc);
    return 1;
  }

  tokenize(argv[1]);
  Program p = program();

  // headers
  printf(".intel_syntax noprefix\n");
  printf(".global main\n");
  printf("main:\n");

  // alloc local variables
  printf("  push rbp\n");
  printf("  mov rbp, rsp\n");
  printf("  sub rsp, %d\n", p.localsLength * long.sizeof);
  for (Node* node = p.node;  node; node = node.next) {
    genX64(node);
    // pop the last expresion result on top
    printf("  pop rax\n");
  }
  return 0;
}
