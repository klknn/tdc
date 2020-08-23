module tdc.stdc.ctype;

// for self-host subset libc binding.
extern (C) @nogc nothrow:

int isdigit(int c);
int isspace(int c);
