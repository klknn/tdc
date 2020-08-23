/// Parse module.
module tdc.tokenize;

@nogc nothrow:

import tdc.stdc.ctype : isalpha, isdigit, isspace;
import tdc.stdc.stdlib : calloc, strtol;
import tdc.stdc.stdio : fprintf, stderr;
import tdc.stdc.string : strncmp, strlen;

/// Token kinds.
enum TokenKind {
  reserved,
  identifier,
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
  long length;
}


/// Pointer to currently parsing token.
Token* currentToken;
/// Pointer to currently parsing string.
const(char)* currentString;
void printErrorAt(const(char)* s) {
    fprintf(stderr, "%s\n", currentString);
    for (long i = 0; i < s - currentString; ++i) {
      fprintf(stderr, " ");
    }
    fprintf(stderr, "^ HERE\n");
}

/// Check s is match to the current token.
bool match(const(char)* s) {
  if (currentToken.kind != TokenKind.reserved) return false;
  if (strncmp(s, currentToken.str, currentToken.length) != 0) return false;
  if (strlen(s) != currentToken.length) return false;
  return true;
}

unittest {
  const(char)* s = "a = 1";
  Token t = Token(TokenKind.reserved, null, 0, s + 2, 1);
  currentToken = &t;
  assert(match("="));
  assert(!match("=="));
}

/// Updates `currentToken` and returns true if op is valid else false.
bool consume(const(char)* s) {
  if (!match(s)) {
    return false;
  }
  currentToken = currentToken.next;
  return true;
}

/// Check expected string is found.
void expect(const(char)* s) {
  if (match(s)) {
    currentToken = currentToken.next;
    return;
  }
  fprintf(stderr, "ERROR: expected %s\n", s);
  printErrorAt(currentToken.str);
  assert(false);
}

/// Consume a token if it is an indentifier.
Token* consumeIdentifier() {
  if (currentToken.kind != TokenKind.identifier) {
    return null;
  }
  Token* ret = currentToken;
  currentToken = currentToken.next;
  return ret;
}

/// Updates `currentToken` and returns a parsed integer when it is integer.
/// Exits with error 1 otherwise.
long expectInteger() {
  if (currentToken.kind != TokenKind.integer) {
    fprintf(stderr, "ERROR: expected integer\n");
    printErrorAt(currentToken.str);
    assert(false);
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
Token* newToken(TokenKind kind, Token* cur, const(char)* s, long length) {
  Token* tok = cast(Token*) calloc(1, Token.sizeof);
  tok.kind = kind;
  tok.str = s;
  tok.length = length;
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
    // 2-char reserved
    if (strncmp(p, "==", 2) == 0 || strncmp(p, "!=", 2) == 0 ||
        strncmp(p, "<=", 2) == 0 || strncmp(p, ">=", 2) == 0) {
      cur = newToken(TokenKind.reserved, cur, p, 2);
      p += 2;
      continue;
    }
    // 1-char reserved
    if (*p == '+' || *p == '-' || *p == '*' || *p == '/' ||
        *p == '<' || *p == '>' ||
        *p == '(' || *p == ')' ||
        *p == ';' || *p == '=') {
      cur = newToken(TokenKind.reserved, cur, p, 1);
      ++p;
      continue;
    }
    // identifier
    if (isalpha(*p)) {
      cur = newToken(TokenKind.identifier, cur, p, 1);
      ++p;
      continue;
    }
    // literals
    if (isdigit(*p)) {
      cur = newToken(TokenKind.integer, cur, p, 0);
      cur.integer = strtol(p, &p, 10);
      continue;
    }
    fprintf(stderr, "ERROR: cannot tokenize\n");
    printErrorAt(p);
    break;
  }
  newToken(TokenKind.eof, cur, p, 0);
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

unittest {
  const(char)* s = "(123)";
  tokenize(s);

  assert(consume("("));
  assert(expectInteger() == 123);
  assert(consume(")"));
  assert(isEof());
}

unittest {
  const(char)* s = "1 <= 2";
  tokenize(s);
}
