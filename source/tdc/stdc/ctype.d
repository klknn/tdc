module tdc.stdc.ctype;

// for self-host subset libc binding.
extern (C) @nogc nothrow:

int isalpha(int c);
int isdigit(int c);
int isspace(int c);
