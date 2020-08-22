/// Parse module.
module tdc.tokenize;

@nogc nothrow:

import core.stdc.ctype : isdigit, isspace;
import core.stdc.stdlib : calloc, exit, strtol;
import core.stdc.stdio : fprintf, stderr;

/// Token kinds.
enum TokenKind {
  reserved,
  integer,
  eof
}

/// Token aggregates.
struct Token {
  /// Token info.
  TokenKind kind;
  Token* next;
  /// Contents.
  long integer;
  const(char)* str;
}


/// Pointer to currently parsing token.
private Token* currentToken;
/// Pointer to currently parsing string.
private const(char)* currentString;
/// Pointer diff to currently parsing token from the start of currentString.
private long currentLocation() {
  return currentToken.str - currentString;
}
private void printCurrentErrorAt() {
    fprintf(stderr, "%s\n", currentString);
    for (long i = 0; i < currentLocation; ++i) {
      fprintf(stderr, " ");
    }
    fprintf(stderr, "^ HERE\n");
}

/// Updates `currentToken` and returns true if op is valid else false.
bool consume(char op) {
  if (currentToken.kind != TokenKind.reserved || currentToken.str[0] != op) {
    return false;
  }
  currentToken = currentToken.next;
  return true;
}

/// Check expected char is found.
void expectChar(char c) {
  if (currentToken.kind != TokenKind.reserved || currentToken.str[0] != c) {
    fprintf(stderr, "ERROR: expected char\n");
    printCurrentErrorAt();
    exit(1);
  }
  currentToken = currentToken.next;
}

/// Updates `currentToken` and returns a parsed integer when it is integer.
/// Exits with error 1 otherwise.
long expectInteger() {
  if (currentToken.kind != TokenKind.integer) {
    fprintf(stderr, "ERROR: expected integer\n");
    printCurrentErrorAt();
    exit(1);
  }
  long integer = currentToken.integer;
  currentToken = currentToken.next;
  return integer;
}

/// Checks currentToken is eof.
bool isEof() {
  return currentToken.kind == TokenKind.eof;
}

/// Assigns new token to `currentToken.next`.
Token* newToken(TokenKind kind, Token* cur, const(char)* s) {
  Token* tok = cast(Token*) calloc(1, Token.sizeof);
  tok.kind = kind;
  tok.str = s;
  cur.next = tok;
  return tok;
}

/// Tokenizes a string.
void tokenize(const(char)* p) {
  currentString = p;
  Token head;
  head.next = null;
  Token* cur = &head;
  while (*p) {
    // spaces
    if (isspace(*p)) {
      ++p;
      continue;
    }
    // reserved
    if (*p == '+' || *p == '-' || *p == '*' || *p == '/' ||
        *p == '(' || *p == ')') {
      cur = newToken(TokenKind.reserved, cur, p);
      ++p;
      continue;
    }
    // literals
    if (isdigit(*p)) {
      cur = newToken(TokenKind.integer, cur, p);
      cur.integer = strtol(p, &p, 10);
      continue;
    }
    fprintf(stderr, "ERROR: cannot tokenize\n");
    break;
  }
  newToken(TokenKind.eof, cur, p);
  currentToken = head.next;
}

unittest {
  const(char)* s = " 123 + 2*(4/5) ";
  tokenize(s);

  assert(currentToken.integer  == 123);
  long n = 0;
  while (currentToken.kind != TokenKind.eof) {
    ++n;
    currentToken = currentToken.next;
  }
  assert(n == 9);
}
