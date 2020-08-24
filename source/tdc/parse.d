/// Parse module.
module tdc.parse;

import tdc.stdc.string : strncmp;
import tdc.stdc.stdlib : calloc;
import tdc.tokenize : consume, consumeKind, consumeIdentifier,
  expect, expectInteger, isEof, Token, TokenKind;

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
  long integer;  // for integer
  long offset;  // for localVar
  // for if-else block
  Node* condExpr;
  Node* ifStatement;
  Node* elseStatement;

  // for block
  Node* forInit;
  Node* forCond;
  Node* forUpdate;
  Node* forBlock;
}

/// Create new Node of lhs and rhs nodes.
Node* newNode(NodeKind kind, Node* lhs, Node* rhs) {
  Node* ret = cast(Node*) calloc(1, Node.sizeof);
  ret.kind = kind;
  ret.lhs = lhs;
  ret.rhs = rhs;
  return ret;
}

/// Create a new Node of an integer.
Node* newNodeInteger(long integer) {
  Node* ret = cast(Node*) calloc(1, Node.sizeof);
  ret.kind = NodeKind.integer;
  ret.integer = integer;
  return ret;
}

/// Create a new Node of an localVar.
Node* newNodeLocalVar(long offset) {
  Node* ret = cast(Node*) calloc(1, Node.sizeof);
  ret.kind = NodeKind.localVar;
  ret.offset = offset;
  return ret;
}

/// Create a primary expression.
/// primary := "(" expr ")" | identifier | integer
Node* primary() {
  if (consume("(")) {
    Node* node = expr();
    expect(")");
    return node;
  }
  Token* t = consumeIdentifier();
  if (t) {
    LocalVar* lv = findLocalVar(t);
    if (lv) {
      // TODO: return lv; ?
      return newNodeLocalVar(lv.offset);
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
    return newNodeLocalVar(offset);
  }
  return newNodeInteger(expectInteger());
}

/// Create a unary expression.
/// unary := ("+" | "-")? unary | primary
Node* unary() {
  if (consume("+")) {
    return unary();
  }
  else if (consume("-")) {
    // TODO: optimize this in codegen.
    return newNode(NodeKind.sub, newNodeInteger(0), unary());
  }
  return primary();
}

/// Create a mul or div expression.
/// mulOrDiv := unary (("*"|"/") unary)*
Node* mulOrDiv() {
  Node* node = unary();
  for (;;) {
    if (consume("*")) {
      node = newNode(NodeKind.mul, node, unary());
    }
    else if (consume("/")) {
      node = newNode(NodeKind.div, node, unary());
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
      node = newNode(NodeKind.add, node, mulOrDiv());
    }
    else if (consume("-")) {
      node = newNode(NodeKind.sub, node, mulOrDiv());
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
      node = newNode(NodeKind.lt, node, arith());
    }
    else if (consume("<=")) {
      node = newNode(NodeKind.leq, node, arith());
    }
    else if (consume(">")) {
      // swap lhs and rhs
      node = newNode(NodeKind.lt, arith(), node);
    }
    else if (consume(">=")) {
      // swap lhs and rhs
      node = newNode(NodeKind.leq, arith(), node);
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
      node = newNode(NodeKind.eq, node, relational());
    }
    else if (consume("!=")) {
      node = newNode(NodeKind.neq, node, relational());
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
    node = newNode(NodeKind.assign, node, assign());
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
Node* statement() {
  // "if" "(" expr ")" statement ("else" statement)?
  if (consumeKind(TokenKind.if_)) {
    Node* node = newNode(NodeKind.if_, null, null);
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
    Node* node = newNode(NodeKind.for_, null, null);
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
    Node* node = newNode(NodeKind.for_, null, null);
    expect("(");
    node.forCond = expr();
    expect(")");
    node.forBlock = statement();
    return node;
  }
  // "return"? expr ";"
  if (consumeKind(TokenKind.return_)) {
    Node* node = newNode(NodeKind.return_, expr(), null);
    expect(";");
    return node;
  }
  Node* node = expr();
  expect(";");
  return node;
}

/// Program with abstract syntax tree and so on.
struct Program {
  Node** nodes;
  LocalVar* locals;
  long localsLength;
}

/// program := statement*
Program program(long max) {
  Node** nodes = cast(Node**) calloc(max, (Node*).sizeof);
  // reset global vars
  currentLocals = null;
  currentLocalsLength = 0;
  int i = 0;
  while (!isEof()) {
    nodes[i] = statement();
    ++i;
    assert(i < max);
  }
  nodes[i] = null;

  Program ret;
  ret.nodes = nodes;
  ret.locals = currentLocals;
  ret.localsLength = currentLocalsLength;
  return ret;
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "a = 123;";
  tokenize(s);
  Program prog = program(2);
  Node* stmt = prog.nodes[0];
  assert(stmt.kind == NodeKind.assign);
  assert(stmt.lhs.kind == NodeKind.localVar);
  assert(stmt.rhs.kind == NodeKind.integer);
  assert(prog.nodes[1] == null);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "return 123;";
  tokenize(s);
  Program prog = program(2);
  Node* stmt = prog.nodes[0];
  assert(stmt.kind == NodeKind.return_);
  assert(stmt.rhs == null);
  assert(stmt.lhs.kind == NodeKind.integer);
  assert(prog.nodes[1] == null);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "if (1) 2; else 3;";
  tokenize(s);
  Program prog = program(10);
  Node* stmt = prog.nodes[0];
  assert(stmt.kind == NodeKind.if_);
  assert(stmt.condExpr.kind == NodeKind.integer);
  assert(stmt.condExpr.integer == 1);
  assert(stmt.ifStatement.kind == NodeKind.integer);
  assert(stmt.ifStatement.integer == 2);
  assert(stmt.elseStatement.kind == NodeKind.integer);
  assert(stmt.elseStatement.integer == 3);
  assert(prog.nodes[1] == null);
}

unittest
{
  import tdc.tokenize;

  const(char)* s = "for (A;A<10;A=A+1) 1;";
  tokenize(s);
  Program prog = program(10);
  Node* stmt = prog.nodes[0];
  assert(stmt.kind == NodeKind.for_);
  assert(prog.nodes[1] == null);
}
