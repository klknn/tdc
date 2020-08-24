/// Parse module.
module tdc.tokenize;

@nogc nothrow:

import tdc.stdc.ctype : isalpha, isdigit, isspace;
import tdc.stdc.stdlib : calloc, strtol;
import tdc.stdc.stdio : fprintf, stderr;
import tdc.stdc.string : strncmp, strlen;


/// Token kinds.
enum TokenKind {
  eof,
  reserved,
  identifier,
  integer,
  // keywords
  return_,
  if_,
  else_,
  while_,
  for_,
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
private Token* currentToken;
/// Pointer to currently parsing string.
private const(char)* currentString;
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

bool consumeKind(TokenKind k) {
  if (currentToken.kind != k) return false;
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

bool isIdentifierSuffix(char c) {
  return isalpha(c) || c == '_' || isdigit(c);
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
    // keywords
    if (strncmp(p, "return", 6) == 0 && !isIdentifierSuffix(p[6])) {
      cur = newToken(TokenKind.return_, cur, p, 6);
      p += 6;
      continue;
    }
    if (strncmp(p, "if", 2) == 0 && !isIdentifierSuffix(p[2])) {
      cur = newToken(TokenKind.if_, cur, p, 2);
      p += 2;
      continue;
    }
    if (strncmp(p, "else", 4) == 0 && !isIdentifierSuffix(p[4])) {
      cur = newToken(TokenKind.else_, cur, p, 4);
      p += 4;
      continue;
    }
    if (strncmp(p, "while", 5) == 0 && !isIdentifierSuffix(p[5])) {
      cur = newToken(TokenKind.while_, cur, p, 5);
      p += 5;
      continue;
    }
    if (strncmp(p, "for", 3) == 0 && !isIdentifierSuffix(p[3])) {
      cur = newToken(TokenKind.for_, cur, p, 3);
      p += 3;
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
        *p == '(' || *p == ')' || *p == '{' || *p == '}' ||
        *p == ',' || *p == ';' || *p == '=') {
      cur = newToken(TokenKind.reserved, cur, p, 1);
      ++p;
      continue;
    }
    // identifier
    if (isalpha(*p) || *p == '_') {
      const(char)* s = p;
      ++p;
      while (isIdentifierSuffix(*p)) {
        ++p;
      }
      cur = newToken(TokenKind.identifier, cur, s, p - s);
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
  const(char)* s = "if (1) {} else {} ";
  tokenize(s);
  assert(consumeKind(TokenKind.if_));
  assert(consume("("));
  assert(expectInteger() == 1);
  assert(consume(")"));
  assert(consume("{"));
  assert(consume("}"));
  assert(consumeKind(TokenKind.else_));
  assert(consume("{"));
  assert(consume("}"));
  assert(isEof());
}

unittest {
  const(char)* s = "while (1) {} ";
  tokenize(s);
  assert(consumeKind(TokenKind.while_));
  assert(consume("("));
  assert(expectInteger() == 1);
  assert(consume(")"));
  assert(consume("{"));
  assert(consume("}"));
  assert(isEof());
}

unittest {
  const(char)* s = "for (;;) {} ";
  tokenize(s);
  assert(consumeKind(TokenKind.for_));
  assert(consume("("));
  assert(consume(";"));
  assert(consume(";"));
  assert(consume(")"));
  assert(consume("{"));
  assert(consume("}"));
  assert(isEof());
}

unittest {
  const(char)* s = "return foo + bar";
  tokenize(s);

  assert(consumeKind(TokenKind.return_));
  Token* t = consumeIdentifier();
  assert(t);
  assert(t.str[0 .. t.length] == "foo");
  assert(consume("+"));
  Token* bar = consumeIdentifier();
  assert(bar.str[0..bar.length] == "bar");
  assert(isEof());
}
