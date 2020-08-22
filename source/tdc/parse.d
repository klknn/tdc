/// Parse module.
module tdc.parse;

import core.stdc.stdlib : calloc;
import tdc.tokenize : consume, expect, expectInteger;

@nogc nothrow:

/// Node kind.
enum NodeKind {
  add,  // +
  sub,  // -
  mul,  // *
  div,  // /
  eq,   // ==
  neq,  // !=
  lt,   // <
  leq,  // <=
  // gt,   // >
  // geq,  // >=
  integer,  // 123
}

/// Node of abstract syntax tree (ast).
struct Node {
  NodeKind kind;
  Node* lhs;
  Node* rhs;
  long integer;
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

/// Create a primary expression.
/// primary := "(" expr ")" | integer
Node* primary() {
  if (consume("(")) {
    Node* node = expr();
    expect(")");
    return node;
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

/// Create an expression.
/// expr := equality
Node* expr() {
  return equality();
}

unittest
{
  import tdc.tokenize;
  const(char)* s = "123 <= 124";

  // const(char)* s = " 123 + 2*(4/5) ";
  tokenize(s);
  Node* n = expr();
  // assert(n.kind == NodeKind.add);
  // assert(n.lhs.kind == NodeKind.integer);
  // assert(n.lhs.integer == 123);
  // assert(n.rhs.kind == NodeKind.mul);
}
