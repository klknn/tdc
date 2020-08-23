module tdc.stdc.ctype;

// for self-host subset libc binding.
extern (C) @nogc nothrow:

pure int isdigit(int c);
pure int isspace(int c);
