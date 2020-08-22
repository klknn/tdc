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
  switch (node.kind) {
    // arithmetic ops
    case NodeKind.add:
      printf("  add rax, rdi\n");
      break;
    case NodeKind.sub:
      printf("  sub rax, rdi\n");
      break;
    case NodeKind.mul:
      printf("  imul rax, rdi\n");
      break;
    case NodeKind.div:
      // extend rax to 128bit rdx:rax (upper:lower bits)
      printf("  cqo\n");
      // rax = rdx:rax / rdi, rdx = rdx:rax % rdi
      printf("  idiv rdi\n");
      break;

    // logical ops
    case NodeKind.eq:
    case NodeKind.neq:
    case NodeKind.lt:
    case NodeKind.leq:
      printf("  cmp rax, rdi\n");
      switch (node.kind) {
        case NodeKind.eq:
          // al = rax == rdi ? 1 : 0
          printf("  sete al\n");
          break;
        case NodeKind.neq:
          // al = rax == rdi ? 0 : 1
          printf("  setne al\n");
          break;
        case NodeKind.lt:
          // al = rax < rdi ? 1 : 0
          printf("  setl al\n");
          break;
        case NodeKind.leq:
          // al = rax <= rdi ? 1 : 0
          printf("  setle al\n");
          break;
        default:
          assert(false, "unknown node kind");
      }
      // move a byte with zero extend because al is a 8-bit register
      printf("  movzb rax, al\n");
      break;
    default:
      assert(false, "unknown node kind");
  }
  printf("  push rax\n");
}
