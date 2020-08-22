module tdc.codegen;

@nogc nothrow:

import core.stdc.stdio : printf;
import tdc.parse;

/// Generate x64 asm.
void genX64(Node* node) {
  if (node.kind == NodeKind.integer) {
    printf("  push %ld\n", node.integer);
    return;
  }
  genX64(node.lhs);
  genX64(node.rhs);
  printf("  pop rdi\n");
  printf("  pop rax\n");
  if (node.kind == NodeKind.add) {
    printf("  add rax, rdi\n");
  }
  else if (node.kind == NodeKind.sub) {
    printf("  sub rax, rdi\n");
  }
  else if (node.kind == NodeKind.mul) {
    printf("  imul rax, rdi\n");
  }
  else if (node.kind == NodeKind.div) {
    // extend rax to 128bit rdx:rax (upper:lower bits)
    printf("  cqo\n");
    // rax = rdx:rax / rdi, rdx = rdx:rax % rdi
    printf("  idiv rdi\n");
  }
  else {
    assert(false, "unknown node kind");
  }
  printf("  push rax\n");
}
