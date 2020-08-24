module tdc.stdc.stdlib;

// for self-host subset libc binding.
extern (C) @nogc nothrow:

void* realloc(void *ptr, size_t size);
void* calloc(size_t nmemb, size_t size);
void exit(int status);
long strtol(scope inout(char)* nptr, scope inout(char)** endptr, int base);
