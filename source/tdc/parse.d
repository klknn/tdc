/// Parse module.
module tdc.parse;

import tdc.stdc.string : strncmp, strncpy;
import tdc.stdc.stdlib : calloc;
import tdc.tokenize : consume, consumeKind, consumeIdentifier,
  expect, expectInteger, isEof, match, Token, TokenKind;

@nogc nothrow:

/// Local variable.
struct LocalVar {
  LocalVar* next;
  const(char)* name;
  long length;  // of name
  long offset;  // from rbp
}

/// Current parsing local variable array.
private LocalVar* currentLocals;
private long currentLocalsLength;

/// Find local variables by name.
private LocalVar* findLocalVar(Token* token) {
  for (LocalVar* l = currentLocals; l; l = l.next) {
    if (l.length == token.length && strncmp(token.str, l.name, l.length) == 0) {
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
  lt,      // <
  leq,     // <=
  integer, // 123
  localVar,  // local var
  compound,  // { ... }
  call,      // identifier()
  func,      // func( ... ) { ... }
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
  LocalVar* var;     // for localVar

  Node* next; // for array of nodes

  // func or call
  const(char)* name;
  // func
  Node* funcBody;

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

/// Copy a new string from token.
const(char)* copyStr(Token* t) {
  char* s = cast(char*) calloc(t.length + 1, char.sizeof);
  return strncpy(s, t.str, t.length);
}

/// Create a primary expression.
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
  Token* t = consumeIdentifier();
  if (t) {
    // call or func
    if (consume("(")) {
      Node* node = newNode(NodeKind.call);
      Node* args = node;
      // parse args
      for (long i = 0; !consume(")"); ++i) {
        if (i != 0) expect(",");
        args.next = expr();
        args = args.next;
      }
      node.name = copyStr(t);
      // call
      if (!match("{")) return node;
      // func
      node.kind = NodeKind.func;
      node.funcBody = statement();
      return node;
    }

    // identifier
    Node* node = newNode(NodeKind.localVar);
    LocalVar* lv = findLocalVar(t);
    if (lv) {
      // TODO: return lv; ?
      node.var = lv;
      return node;
    }
    long offset = 0;
    if (currentLocals) {
      offset = currentLocals.offset + long.sizeof;
    }
    lv = cast(LocalVar*) calloc(1, LocalVar.sizeof);
    lv.next = currentLocals;
    lv.name = t.str;
    lv.length = t.length;
    lv.offset = offset;
    currentLocals = lv;
    currentLocalsLength += 1;
    node.var = lv;
    return node;
  }
  // integer
  Node* node = newNode(NodeKind.integer);
  node.integer = expectInteger();
  return node;
}

/// Create a unary expression.
/// unary := ("+" | "-")? unary | primary
Node* unary() {
  if (consume("+")) {
    return unary();
  }
  else if (consume("-")) {
    // TODO: optimize this in codegen.
    Node* zero = newNode(NodeKind.integer);
    zero.integer = 0;
    return newNodeBinOp(NodeKind.sub, zero, unary());
  }
  return primary();
}

/// Create a mul or div expression.
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

/// Create an arithmetic Node.
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
  }
  assert(false, "unreachable");
}

// relational := arith (("<"|"<="|">"|">=") arith)*
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

/// Create an equality
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

/// assign := equality ("=" assign)?
Node* assign() {
  Node* node = equality();
  if (consume("=")) {
    node = newNodeBinOp(NodeKind.assign, node, assign());
  }
  return node;
}

/// Create an expression.
/// expr := assign
Node* expr() {
  return assign();
}

/// statement = "if" "(" expr ")" statement ("else" statement)?
///           | "while" "(" expr ")" statement
///           | "for" "(" expr? ";" expr? ";" expr? ")" statement
///           | "return"? expr ";"
///           | "{" statement* "}"
///           | identifier "(" identifier* ")" statement
Node* statement() {
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

/// Program with abstract syntax tree and so on.
struct Program {
  Node* node;
  LocalVar* locals;
  long localsLength;
}

/// program := statement*
Program program() {
  Program ret;
  // reset global vars
  currentLocals = null;
  currentLocalsLength = 0;
  int i = 0;
  Node* prev;
  while (!isEof()) {
    Node* node = statement();
    if (ret.node == null) ret.node = node;
    else prev.next = node;
    prev = node;
  }
  ret.locals = currentLocals;
  ret.localsLength = currentLocalsLength;
  return ret;
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "a = 123;";
  tokenize(s);
  Program prog = program();
  Node* stmt = prog.node;
  assert(stmt.kind == NodeKind.assign);
  assert(stmt.lhs.kind == NodeKind.localVar);
  assert(stmt.rhs.kind == NodeKind.integer);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "return 123;";
  tokenize(s);
  Program prog = program();
  Node* stmt = prog.node;
  assert(stmt.kind == NodeKind.return_);
  assert(stmt.rhs == null);
  assert(stmt.lhs.kind == NodeKind.integer);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "if (1) 2; else 3;";
  tokenize(s);
  Program prog = program();
  Node* stmt = prog.node;
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

  const(char)* s = "for (A;A<10;A=A+1) {1;2;3;}";
  tokenize(s);
  Program prog = program();
  Node* stmt = prog.node;
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
  Program prog = program();
  Node* stmt = prog.node;
  assert(stmt.kind == NodeKind.call);
  assert(stmt.name[0..3] == "foo");
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "foo(123);";
  tokenize(s);
  Program prog = program();
  Node* stmt = prog.node;
  assert(stmt.kind == NodeKind.call);
  assert(stmt.name[0..3] == "foo");
  assert(stmt.next.integer == 123);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "foo(a) { return a * 2; }";
  tokenize(s);
  Program prog = program();
  Node* stmt = prog.node;
  assert(stmt.kind == NodeKind.func);
  assert(stmt.name[0..3] == "foo");
  // assert(stmt.next.name[0..1] == "a");
}
