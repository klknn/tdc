module tdc.type;

import tdc.stdc.stdlib : calloc;

@nogc nothrow:

enum TypeKind {
  int_,
  ptr,
}

struct Type {
  TypeKind kind;
  Type* ptrof;
}

Type* newType(TypeKind kind) {
  Type* ret = cast(Type*) calloc(1, Type.sizeof);
  ret.kind = kind;
  return ret;
}
