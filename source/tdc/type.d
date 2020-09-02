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

int sizeOf(const(Type)* type) {
  if (type.kind == TypeKind.int_) {
    return 4;
  }
  if (type.kind == TypeKind.ptr) {
    // TODO: check 32/64bit
    return 8;
  }
  assert(false, "unknown type for .sizeof");
}
