module tdc.stdc.stdio;

// for self-host subset libc binding.
extern (C) @nogc nothrow:

struct FILE;
int fprintf(FILE* stream, scope const char* format, scope const ...);
int printf(scope const char* format, scope const ...);
extern __gshared FILE* stderr;
