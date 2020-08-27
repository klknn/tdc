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

long numIfBlock;
long numForBlock;
long numForCall;

/// Put the local variable address (offset from top) in rax
void raxLocalVarAddress(const(Node)* node) {
  assert(node.kind == NodeKind.localVar);
  // copy a base pointer (rbp, top of function frame) to rax
  printf("  mov rax, rbp\n");
  // move rax to offset from top
  printf("  sub rax, %d\n", node.var.offset);
}

/// Set arg to the given register and return the next arg.
const(Node)* setArg(const(Node)* arg, const(char)* reg) {
  if (arg == null) return arg;
  genX64(arg);
  printf("  pop %s\n", reg);
  return arg.args;
}

/// Push args in reverse order.
void reversePushArgs(const(Node)* arg) {
  if (arg == null) return;
  reversePushArgs(arg.args);
  genX64(arg);
}

/// Set args before calling a function.
void setArgs(const(Node)* arg) {
  arg = setArg(arg, "rdi");
  arg = setArg(arg, "rsi");
  arg = setArg(arg, "rdx");
  arg = setArg(arg, "rcx");
  arg = setArg(arg, "r8");
  arg = setArg(arg, "r9");
  reversePushArgs(arg);
}

/// Generate x64 asm in node and put a result in stack top
void genX64(const(Node)* node) {
  if (node == null) return;

  NodeKind k = node.kind;
  if (k == NodeKind.func) {
    printf("// NodeKind.func\n");
    printf(".global %s\n", node.name);
    printf("%s:\n", node.name);

    printf("  push rbp\n");
    printf("  mov rbp, rsp\n");
    printf("  // push args\n");
    if (node.argsLength > 0) {
      printf("  mov QWORD PTR -8[rbp], rdi\n");
    }
    if (node.argsLength > 1) {
      printf("  mov QWORD PTR -16[rbp], rsi\n");
    }
    if (node.argsLength > 2) {
      printf("  mov QWORD PTR -24[rbp], rdx\n");
    }
    if (node.argsLength > 3) {
      printf("  mov QWORD PTR -32[rbp], rcx\n");
    }
    if (node.argsLength > 4) {
      printf("  mov QWORD PTR -40[rbp], r8\n");
    }
    if (node.argsLength > 5) {
      printf("  mov QWORD PTR -48[rbp], r9\n");
    }
    for (long n = 0; n + 5 < node.argsLength; ++n) {
      printf("  mov rax, QWORD PTR %ld[rbp]\n", 16 + n * long.sizeof);
      printf("  mov QWORD PTR -%ld[rbp], rax\n", 56 + n * long.sizeof);
    }
    // alloc local variables
    printf("  sub rsp, %d\n", node.localsLength * long.sizeof);
    for (const(Node)* bd = node.funcBody.next;  bd; bd = bd.next) {
      printf("  // gen body\n");
      genX64(bd);
    }
    return;
  }
  if (k == NodeKind.call) {
    ++numForCall;
    printf("  // NodeKind.call\n");
    // adjust rsp 16-byte aligned
    printf("  mov rax, rsp\n");
    printf("  and rax, 15\n");
    printf("  jnz .L.call8offset.%d\n", numForCall);

    // if 16 byte aligned
    printf("  mov rax, 0\n");
    setArgs(node.args);
    printf("  call %s\n", node.name);
    printf("  jmp .L.callend.%d\n", numForCall);

    // if not 16 byte aligned (but always 8 byte aligned)
    printf(".L.call8offset.%d:\n", numForCall);
    printf("  sub rsp, 8\n");  // adjust
    printf("  mov rax, 0\n");
    setArgs(node.args);
    printf("  call %s\n", node.name);
    printf("  add rsp, 8\n");  // revert

    printf(".L.callend.%d:\n", numForCall);
    // function return value will be stored in rax
    printf("  push rax\n");
    return;
  }
  if (k == NodeKind.compound) {
    for (const(Node)* stmt = node.next; stmt; stmt = stmt.next) {
      genX64(stmt);
      printf("  pop rax\n");
    }
    return;
  }
  if (k == NodeKind.for_) {
    long n = numForBlock;
    ++numForBlock;

    genX64(node.forInit);
    printf(".Lbeginfor%ld:\n", n);
    genX64(node.forCond);
    // rax = forCond
    printf("  pop rax\n");
    printf("  cmp rax, 0\n");
    // jump to end if rax == 0
    printf("  je .Lendfor%ld\n", n);
    genX64(node.forBlock);
    genX64(node.forUpdate);
    // jump to begin
    printf("  jmp .Lbeginfor%ld\n", n);
    printf(".Lendfor%ld:\n", n);
    return;
  }
  if (k == NodeKind.if_) {
    // if (condExpr) ifStatement
    genX64(node.condExpr);
    // rax = condExpr
    printf("  pop rax\n");
    // new ifStatement block
    long n = numIfBlock;
    ++numIfBlock;
    printf("  cmp rax, 0\n");
    if (node.elseStatement) {
      // jump to elseStatement if rax == 0
      printf("  je  .Lelse%ld\n", n);
      genX64(node.ifStatement);
      printf("  je  .Lendif%ld\n", n);
      printf(".Lelse%ld:\n", n);
      genX64(node.elseStatement);
    }
    else {
      // skip ifStatement if rax == 0
      printf("  je  .Lendif%ld\n", n);
      genX64(node.ifStatement);
    }
    printf(".Lendif%ld:\n", n);
    return;
  }
  if (k == NodeKind.return_) {
    genX64(node.lhs);
    // rax = lhs
    printf("  pop rax\n");
    // go back to callee
    printf("  mov rsp, rbp\n");
    printf("  pop rbp\n");
    printf("  ret\n");
    return;
  }
  if (k == NodeKind.integer) {
    printf("  push %ld\n", node.integer);
    return;
  }
  if (k == NodeKind.localVar) {
    raxLocalVarAddress(node);
    // rax = *rax
    printf("  mov rax, [rax]\n");
    // return the deref value
    printf("  push rax\n");
    return;
  }
  if (k == NodeKind.assign) {
    raxLocalVarAddress(node.lhs);
    printf("  push rax\n");
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
