/// Parse module.
module tdc.parse;

import tdc.stdc.string : strncmp;
import tdc.stdc.stdlib : calloc;
import tdc.stdc.stdio : fprintf, stderr;
import tdc.tokenize : consume, consumeKind, consumeIdentifier,
  copyStr, expect, expectInteger, isEof, match, printErrorAt, printErrorCurrent,
  Token, TokenKind;
import tdc.type : newType, Type, TypeKind;

@nogc nothrow:

/// Local variable.
struct LocalVar {
  LocalVar* next;
  const(char)* name;
  long length;  // of name
  long offset;  // from rbp
  const(Type)* type;
}

/// Current parsing local variable array.
private LocalVar* currentLocals;
private long currentLocalsLength;
// private LocalVar* currentArgs;
private long currentArgsLength;

/// Find local variables by name.
private const(LocalVar)* findLocalVar(const(Token)* token) {
  for (LocalVar* l = currentLocals; l; l = l.next) {
    if (token.kind == TokenKind.identifier &&
        l.length == token.length &&
        strncmp(token.str, l.name, l.length) == 0) {
      return l;
    }
  }
  return null;
}

/// Node kind.
enum NodeKind {
  assign,  // =
  add,     // +
  sub,     // -
  mul,     // *
  div,     // /
  eq,      // ==
  neq,     // !=
  not,     // !
  lt,      // <
  leq,     // <=
  xor,     // ^
  and,     // &
  and2,    // &&
  or,      // |
  or2,     // ||
  address, // &x
  deref,   // *x
  integer, // 123
  localVar,  // local var
  compound,  // { ... }
  call,      // identifier()
  func,      // func( ... ) { ... }
  defVar,    // int x
  // keywords
  return_,
  if_,
  else_,
  while_,
  for_,
}

/// Node of abstract syntax tree (ast).
struct Node {
  NodeKind kind;
  Node* lhs;
  Node* rhs;
  long integer;      // for integer
  const(LocalVar)* var;     // for localVar

  const(Type)* type;

  Node* next;  // for multiple values

  // for unary ops
  Node* unary;

  // func or call
  const(char)* name;
  // func
  Node* funcBody;
  LocalVar* locals;
  long localsLength;
  Node* args;
  long argsLength;
  Type* returnType;

  // if-else block
  Node* condExpr;
  Node* ifStatement;
  Node* elseStatement;

  // for/while block
  Node* forInit;
  Node* forCond;
  Node* forUpdate;
  Node* forBlock;

  // compound statement
  Node* compound;
}

Node* newNode(NodeKind kind) {
  Node* ret = cast(Node*) calloc(1, Node.sizeof);
  ret.kind = kind;
  return ret;
}

/// Create new Node of lhs and rhs nodes.
Node* newNodeBinOp(NodeKind kind, Node* lhs, Node* rhs) {
  Node* ret = newNode(kind);
  ret.lhs = lhs;
  ret.rhs = rhs;
  return ret;
}

/// primary = "(" expr ")"
///         | identifier
///         | identifier "(" (expr ",")* expr? ")"
///         | identifier "(" (expr ",")* expr? ")" statement
///         | integer
Node* primary() {
  // "(" expr ")"
  if (consume("(")) {
    Node* node = expr();
    expect(")");
    return node;
  }
  // identifier ("(" expr* ")")?
  const(Token)* t = consumeIdentifier();
  if (t) {
    // func call
    if (consume("(")) {
      Node* node = newNode(NodeKind.call);
      Node* iter = node;
      // parse args
      for (long i = 0; !consume(")"); ++i) {
        if (i != 0) expect(",");
        iter.args = expr();
        iter = iter.args;
        ++node.argsLength;
      }
      node.name = copyStr(t);
      return node;
    }

    // identifier
    Node* node = newNode(NodeKind.localVar);
    const(LocalVar)* lv = findLocalVar(t);
    if (lv) {
      node.var = lv;
      return node;
    }
    printErrorAt(t);
    fprintf(stderr, "Variable '%s' not found\n", copyStr(t));
    assert(false, "undefined variable.");
  }
  // integer
  Node* node = newNode(NodeKind.integer);
  node.integer = expectInteger();
  node.type = newType(TypeKind.int_);
  return node;
}

/// Define a new LocalVar
LocalVar* defineVar(const(Token)* t) {
  // push local vars after func args
  long offset = (1 + currentArgsLength) * long.sizeof;
  if (currentLocals) {
    offset = currentLocals.offset + long.sizeof;
  }
  LocalVar* lv = cast(LocalVar*) calloc(1, LocalVar.sizeof);
  lv.next = currentLocals;
  lv.name = t.str;
  lv.length = t.length;
  lv.offset = offset;
  currentLocals = lv;
  currentLocalsLength += 1;
  return lv;
}


/// unary := ("&" | "*" | "!"| "+" | "-")? unary | primary
Node* unary() {
  if (consume("*")) {
    Node* node = newNode(NodeKind.deref);
    node.unary = unary();
    return node;
  }
  if (consume("&")) {
    Node* node = newNode(NodeKind.address);
    node.unary = unary();
    return node;
  }
  if (consume("!")) {
    // (x != 0) ^ 1
    // TODO: optimize this in codegen.
    Node* zero = newNode(NodeKind.integer);
    zero.type = newType(TypeKind.int_);
    zero.integer = 0;
    Node* one = newNode(NodeKind.integer);
    one.type = newType(TypeKind.int_);
    one.integer = 1;
    return newNodeBinOp(
        NodeKind.xor, one, newNodeBinOp(NodeKind.neq, zero, unary()));
  }
  if (consume("+")) {
    return unary();
  }
  if (consume("-")) {
    // TODO: optimize this in codegen.
    Node* zero = newNode(NodeKind.integer);
    zero.integer = 0;
    zero.type = newType(TypeKind.int_);
    return newNodeBinOp(NodeKind.sub, zero, unary());
  }
  return primary();
}

/// mulOrDiv := unary (("*"|"/") unary)*
Node* mulOrDiv() {
  Node* node = unary();
  for (;;) {
    if (consume("*")) {
      node = newNodeBinOp(NodeKind.mul, node, unary());
    }
    else if (consume("/")) {
      node = newNodeBinOp(NodeKind.div, node, unary());
    }
    else {
      return node;
    }
  }
  assert(false, "unreachable");
}

bool isPonter(const(Node)* node) {
  if (node.type && node.type.kind == TypeKind.ptr) return true;
  if (node.var && node.var.type.kind == TypeKind.ptr) return true;
  return false;
}

const(Type)* typeOf(const(Node)* node) {
  if (node.type) return node.type;
  if (node.var.type) return node.var.type;
  return null;
}

/// arith := mulOrDiv (("+"|"-") mulOrDiv)*
Node* arith() {
  Node* node = mulOrDiv();
  for (;;) {
    if (consume("+")) {
      node = newNodeBinOp(NodeKind.add, node, mulOrDiv());
    }
    else if (consume("-")) {
      node = newNodeBinOp(NodeKind.sub, node, mulOrDiv());
    }
    else {
      return node;
    }

    // pointer stride
    if (isPonter(node.lhs)) {
      Node* stride = newNode(NodeKind.integer);
      stride.type = newType(TypeKind.int_);
      stride.integer = 4;  // TODO: implement sizeof
      Node* rhs = newNodeBinOp(NodeKind.mul, stride, node.rhs);
      node = newNodeBinOp(node.kind, node.lhs, rhs);
      node.type = typeOf(node.lhs);
      continue;
    }
    if (isPonter(node.rhs)) {
      Node* stride = newNode(NodeKind.integer);
      stride.type = newType(TypeKind.int_);
      stride.integer = 4;  // TODO: implement sizeof
      Node* lhs = newNodeBinOp(NodeKind.mul, stride, node.lhs);
      node = newNodeBinOp(node.kind, lhs, node.rhs);
      node.type = typeOf(node.rhs);
      continue;
    }
  }
  assert(false, "unreachable");
}

/// relational := arith (("<"|"<="|">"|">=") arith)*
Node* relational() {
  Node* node = arith();
  for (;;) {
    if (consume("<")) {
      node = newNodeBinOp(NodeKind.lt, node, arith());
    }
    else if (consume("<=")) {
      node = newNodeBinOp(NodeKind.leq, node, arith());
    }
    else if (consume(">")) {
      // swap lhs and rhs
      node = newNodeBinOp(NodeKind.lt, arith(), node);
    }
    else if (consume(">=")) {
      // swap lhs and rhs
      node = newNodeBinOp(NodeKind.leq, arith(), node);
    }
    else {
      return node;
    }
  }
  assert(false, "unreachable");
}

/// equality := relational (("=="|"!=") relational)*
Node* equality() {
  Node* node = relational();
  for (;;) {
    if (consume("==")) {
      node = newNodeBinOp(NodeKind.eq, node, relational());
    }
    else if (consume("!=")) {
      node = newNodeBinOp(NodeKind.neq, node, relational());
    }
    else {
      return node;
    }
  }
  assert(false, "unreachable");
}

/// logic := equality (("&&"|"||"|"&"|"|"|"^") logic)*
Node* logic() {
  Node* node = equality();
  for (;;) {
    if (consume("&&")) {
      node = newNodeBinOp(NodeKind.and2, node, logic());
    }
    else if (consume("||")) {
      node = newNodeBinOp(NodeKind.or2, node, logic());
    }
    else if (consume("&")) {
      node = newNodeBinOp(NodeKind.and, node, logic());
    }
    else if (consume("|")) {
      node = newNodeBinOp(NodeKind.or, node, logic());
    }
    else if (consume("^")) {
      node = newNodeBinOp(NodeKind.xor, node, logic());
    }
    else {
      return node;
    }
  }
  assert(false, "unreachable");
}

/// assign := logic ("=" assign)?
Node* assign() {
  Node* node = logic();
  if (consume("=")) {
    // assert(node.kind == NodeKind.localVar);
    node = newNodeBinOp(NodeKind.assign, node, assign());
  }
  return node;
}

/// expr := assign
Node* expr() {
  return assign();
}

/// type = "int" ("*")*
Type* consumeType() {
  if (consumeKind(TokenKind.int_)) {
    Type* ret = newType(TypeKind.int_);
    while (consume("*")) {
      Type* t = newType(TypeKind.ptr);
      t.ptrof = ret;
      ret = t;
    }
    return ret;
  }
  return null;
}

/// Sets args (params) to the function node.
/// params = (type identifier ",")* type identifier
void setParams(Node* node) {
  Node* iter = node;
  for (long i = 0; !consume(")"); ++i) {
    if (i != 0) expect(",");
    Type* type = consumeType();
    if (type == null) {
      printErrorCurrent();
      fprintf(stderr, "Type expected");
      assert(type);
    }

    // define arg var
    const(Token)* atoken = consumeIdentifier();
    Node* anode = newNode(NodeKind.defVar);
    LocalVar* var = defineVar(atoken);
    var.type = type;
    anode.type = type;
    anode.var = var;
    iter.args = anode;
    iter = iter.args;
    ++node.argsLength;
  }
}

/// statement = "if" "(" expr ")" statement ("else" statement)?
///           | "while" "(" expr ")" statement
///           | "for" "(" expr? ";" expr? ";" expr? ")" statement
///           | "return"? expr ";"
///           | "{" statement* "}"
///           | type identifier ";"
///           | type identifier "(" params ")" "{" statement* "}"
Node* statement() {
  // TODO support non-int def, e.g., int*
  Type* type = consumeType();
  if (type) {
    const(Token)* t = consumeIdentifier();
    assert(t, "identifier expected");
    // func def
    if (consume("(")) {
      Node* node = newNode(NodeKind.func);
      node.returnType = type;
      setParams(node);
      node.name = copyStr(t);
      // func
      node.kind = NodeKind.func;
      node.funcBody = statement();
      // reset args
      currentArgsLength = node.argsLength;
      return node;
    }
    // variable def
    Node* node = newNode(NodeKind.defVar);
    assert(findLocalVar(t) == null, "variable already defined.");
    LocalVar* var = defineVar(t);
    var.type = type;
    node.type = type;
    node.var = var;
    expect(";");
    return node;
  }
  // "{" statement* "}"
  if (consume("{")) {
    Node* node = newNode(NodeKind.compound);
    Node* cmpd = node;
    while (!consume("}")) {
      cmpd.next = statement();
      cmpd = cmpd.next;
    }
    return node;
  }
  // "if" "(" expr ")" statement ("else" statement)?
  if (consumeKind(TokenKind.if_)) {
    Node* node = newNode(NodeKind.if_);
    expect("(");
    node.condExpr = expr();
    expect(")");
    node.ifStatement = statement();
    if (consumeKind(TokenKind.else_)) {
      node.elseStatement = statement();
    }
    return node;
  }
  // "for" "(" expr? ";" expr? ";" expr? ")" statement
  if (consumeKind(TokenKind.for_)) {
    Node* node = newNode(NodeKind.for_);
    expect("(");
    if (!consume(";")) {
      node.forInit = expr();
      expect(";");
    }
    if (!consume(";")) {
      node.forCond = expr();
      expect(";");
    }
    if (!consume(")")) {
      node.forUpdate = expr();
      expect(")");
    }
    node.forBlock = statement();
    return node;
  }
  // "while" "(" expr ")" statement
  if (consumeKind(TokenKind.while_)) {
    Node* node = newNode(NodeKind.for_);
    expect("(");
    node.forCond = expr();
    expect(")");
    node.forBlock = statement();
    return node;
  }
  // "return"? expr ";"
  if (consumeKind(TokenKind.return_)) {
    Node* node = newNodeBinOp(NodeKind.return_, expr(), null);
    expect(";");
    return node;
  }
  Node* node = expr();
  if (node.kind != NodeKind.func) expect(";");
  return node;
}

/// program := statement*
Node* func() {
  // reset global vars
  currentLocals = null;
  currentLocalsLength = 0;
  Node* node = statement();
  // assert(node.kind == NodeKind.func, "only function can be top-level");
  node.locals = currentLocals;
  node.localsLength = currentLocalsLength;
  return node;
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "int a; a = 123;";
  tokenize(s);

  Node* stmt = statement();
  assert(stmt.kind == NodeKind.defVar);
  stmt = statement();
  assert(stmt.kind == NodeKind.assign);
  assert(stmt.lhs.kind == NodeKind.localVar);
  assert(stmt.rhs.kind == NodeKind.integer);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "1 == 2 && 1 || 3;";
  tokenize(s);

  Node* stmt = expr();
  assert(stmt.kind == NodeKind.and2);
  assert(stmt.lhs.kind == NodeKind.eq);
  assert(stmt.rhs.kind == NodeKind.or2);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "return 123;";
  tokenize(s);

  Node* stmt = statement();
  assert(stmt.kind == NodeKind.return_);
  assert(stmt.rhs == null);
  assert(stmt.lhs.kind == NodeKind.integer);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "if (1) 2; else 3;";
  tokenize(s);

  Node* stmt = statement();
  assert(stmt.kind == NodeKind.if_);
  assert(stmt.condExpr.kind == NodeKind.integer);
  assert(stmt.condExpr.integer == 1);
  assert(stmt.ifStatement.kind == NodeKind.integer);
  assert(stmt.ifStatement.integer == 2);
  assert(stmt.elseStatement.kind == NodeKind.integer);
  assert(stmt.elseStatement.integer == 3);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "int A; int* B; for (A = 0;A<10;A=A+1) {1;2;3;}";
  tokenize(s);

  Node* declInt = statement();
  assert(declInt.kind == NodeKind.defVar);
  assert(declInt.var.name[0..1] == "A");
  assert(declInt.var.length == 1);
  assert(declInt.type.kind == TypeKind.int_);

  Node* declIntPtr = statement();
  assert(declIntPtr.kind == NodeKind.defVar);
  assert(declIntPtr.var.name[0..1] == "B");
  assert(declIntPtr.var.length == 1);
  assert(declIntPtr.type.kind == TypeKind.ptr);
  assert(declIntPtr.type.ptrof.kind == TypeKind.int_);

  Node* stmt = statement();
  assert(stmt.kind == NodeKind.for_);
  assert(stmt.forBlock.kind == NodeKind.compound);
  assert(stmt.forBlock.next.integer == 1);
  assert(stmt.forBlock.next.next.integer == 2);
  assert(stmt.forBlock.next.next.next.integer == 3);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "foo();";
  tokenize(s);

  Node* stmt = expr();
  assert(stmt.kind == NodeKind.call);
  assert(stmt.name[0..3] == "foo");
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "foo(123);";
  tokenize(s);

  Node* stmt = expr();
  assert(stmt.kind == NodeKind.call);
  assert(stmt.name[0..3] == "foo");
  assert(stmt.args.integer == 123);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "int foo(int a, int* b) { return a; } int main() {}";
  tokenize(s);

  Node* stmt = func();
  assert(stmt.kind == NodeKind.func);
  assert(stmt.name[0..3] == "foo");
  assert(stmt.returnType.kind == TypeKind.int_);
  assert(stmt.args.var.name[0..1] == "a");
  assert(stmt.args.type.kind == TypeKind.int_);
  assert(stmt.args.args.var.name[0..1] == "b");
  assert(stmt.args.args.type.kind == TypeKind.ptr);
  assert(stmt.args.args.type.ptrof.kind == TypeKind.int_);

  Token t;
  t.kind = TokenKind.identifier;
  t.str = "a";
  t.length = 1;
  t.str = "b";
  t.length = 1;
  assert(findLocalVar(&t));
  assert(stmt.argsLength == 2);

  Node* main = func();
  assert(main.kind == NodeKind.func);
  assert(main.name[0..4] == "main");
  assert(main.argsLength == 0);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "int** foo;";
  tokenize(s);

  Node* stmt = statement();
  assert(stmt.kind == NodeKind.defVar);
  assert(stmt.var.name[0..3] == "foo");
  assert(stmt.type.kind == TypeKind.ptr);
  assert(stmt.type.ptrof.kind == TypeKind.ptr);
  assert(stmt.type.ptrof.ptrof.kind == TypeKind.int_);
}
