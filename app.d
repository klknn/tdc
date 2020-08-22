nothrow @nogc:

import core.stdc.stdio : fprintf, printf, stderr;

import tdc.tokenize : tokenize;
import tdc.parse : expr, Node;
import tdc.codegen : genX64;

extern (C)
int main(int argc, char** argv) {
  if (argc != 2) {
    fprintf(stderr, "invalid number of arguments: %d != 2\n", argc);
    return 1;
  }

  tokenize(argv[1]);
  Node* node = expr();

  // headers
  printf(".intel_syntax noprefix\n");
  printf(".global main\n");
  printf("main:\n");

  genX64(node);

  printf("  pop rax\n");
  printf("  ret\n");
  return 0;
}
