module tdc.stdc.string;

// for self-host subset libc binding.
extern (C) @nogc nothrow:

int strncmp(scope const char* s1, scope const char* s2, size_t n);
size_t strlen(scope const char *s);
char* strncpy(scope char* s1, scope const char* s2, size_t n);
