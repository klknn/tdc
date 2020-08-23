module tdc.codegen;

// Registers in x64
// - rax: function return value
// - rbs: base pointer, start of function stack frame
// - rsp: stack pointer
//     pop r%% = mov r%%, [rsp]; add rsp, 8
//     push r%% = sub rsp, 8; mov [rsp], r%%
// - rdi:
// - rdx:

@nogc nothrow:

import tdc.parse : Node, NodeKind;
import tdc.stdc.stdio : printf;

/// Push the given function local variable from rbp to stack top (rsp)
void pushLocalVarAddress(Node* node) {
  assert(node.kind == NodeKind.localVar);
  // copy a base pointer (rbp, top of function frame) to rax
  printf("  mov rax, rbp\n");
  // move rax to offset from top
  printf("  sub rax, %d\n", node.offset);
  // push rax to stack top
  printf("  push rax\n");
}

/// Generate x64 asm in node and put a result in stack top
void genX64(Node* node) {
  NodeKind k = node.kind;

  if (k == NodeKind.integer) {
    printf("  push %ld\n", node.integer);
    return;
  }
  if (k == NodeKind.localVar) {
    pushLocalVarAddress(node);
    printf("  pop rax\n");
    // rax = *rax
    printf("  mov rax, [rax]\n");
    // return the deref value
    printf("  push rax\n");
    return;
  }
  if (k == NodeKind.assign) {
    pushLocalVarAddress(node.lhs);
    genX64(node.rhs);
    // rdi = rhs
    printf("  pop rdi\n");
    // rax = &lhs
    printf("  pop rax\n");
    // *rax = rdi
    printf("  mov [rax], rdi\n");
    // return rhs
    printf("  push rdi\n");
    return;
  }

  // gen binary ops
  genX64(node.lhs);
  genX64(node.rhs);
  printf("  pop rdi\n");
  printf("  pop rax\n");

  // arithmetic ops
  // return value will be stored in rax
  if (k == NodeKind.add) {
    printf("  add rax, rdi\n");
  }
  else if (k == NodeKind.sub) {
    printf("  sub rax, rdi\n");
  }
  else if (k == NodeKind.mul) {
    printf("  imul rax, rdi\n");
  }
  else if (k == NodeKind.div) {
    // extend rax to 128bit rdx:rax (upper:lower bits)
    printf("  cqo\n");
    // rax = rdx:rax / rdi, rdx = rdx:rax % rdi
    printf("  idiv rdi\n");
  }
  // logical ops
  else if (k == NodeKind.eq ||
           k == NodeKind.neq ||
           k == NodeKind.lt ||
           k == NodeKind.leq) {
    printf("  cmp rax, rdi\n");
    if (k == NodeKind.eq) {
      // al = rax == rdi ? 1 : 0
      printf("  sete al\n");
    }
    else if (k == NodeKind.neq) {
      // al = rax == rdi ? 0 : 1
      printf("  setne al\n");
    }
    else if (k == NodeKind.lt) {
      // al = rax < rdi ? 1 : 0
      printf("  setl al\n");
    }
    else if (k == NodeKind.leq) {
      // al = rax <= rdi ? 1 : 0
      printf("  setle al\n");
    }
    else {
      assert(false, "unknown logical node kind");
    }
    // move a byte with zero extend because al is a 8-bit register
    printf("  movzb rax, al\n");
  }
  else {
      assert(false, "unknown node kind");
  }
  // return rax
  printf("  push rax\n");
}
