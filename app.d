nothrow @nogc:

import tdc.tokenize : tokenize, isEof;
import tdc.codegen : genX64;
import tdc.parse : func;
import tdc.stdc.stdio : fprintf, printf, stderr;

extern (C)
int main(int argc, char** argv) {
  // TODO: file input
  if (argc != 2) {
    fprintf(stderr, "invalid number of arguments: %d != 2\n", argc);
    return 1;
  }
  tokenize(argv[1]);
  // header
  printf(".intel_syntax noprefix\n");
  while (!isEof()) {
    genX64(func());
  }
  return 0;
}
