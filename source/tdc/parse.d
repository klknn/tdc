/// Parse module.
module tdc.parse;

import tdc.stdc.stdlib : calloc;
import tdc.tokenize : consume, consumeIdentifier, expect, expectInteger, isEof,
  Token;

@nogc nothrow:

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
}

/// Node of abstract syntax tree (ast).
struct Node {
  NodeKind kind;
  Node* lhs;
  Node* rhs;
  long integer;  // for integer
  long offset;  // for localVar
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
    // TODO: lookup identifiers
    return newNodeLocalVar(
        (*t.str - 'a' + 1) * long.sizeof);
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

/// statement := expr ";"?
Node* statement() {
  Node* node = expr();
  consume(";");
  return node;
}

/// program := statement*
Node** program(long max) {
  Node** code = cast(Node**) calloc(max, (Node*).sizeof);
  int i = 0;
  while (!isEof()) {
    code[i] = statement();
    ++i;
    assert(i < max);
  }
  code[i] = null;
  return code;
}

unittest
{
  import tdc.tokenize;
  const(char)* s = "a = 123;";

  // const(char)* s = " 123 + 2*(4/5) ";
  tokenize(s);
  assert(currentToken.next.kind == TokenKind.reserved);
  assert(currentToken.next.length == 1);
  assert(currentToken.next.str[0] == '=');

  Node** prog = program(2);
  Node* stmt = prog[0];
  assert(stmt.kind == NodeKind.assign);
  assert(stmt.lhs.kind == NodeKind.localVar);
  assert(stmt.rhs.kind == NodeKind.integer);
  assert(prog[1] == null);
}
