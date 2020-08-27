module tdc.stdc.stdlib;

// for self-host subset libc binding.
extern (C) @nogc nothrow:

void* calloc(size_t nmemb, size_t size);
long strtol(scope inout(char)* nptr, scope inout(char)** endptr, int base);
