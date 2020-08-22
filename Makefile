DC := ldc2
DFLAGS := -g -betterC -i="source/tdc/*.d" -Isource
OBJ := app.o codegen.o tokenize.o parse.o
.PHONY: clean test

bin/tdc: $(OBJ)
	mkdir -p bin
	gcc -static $(OBJ) -o $@

%.o: source/tdc/%.d
	$(DC) $(DFLAGS) -c $<

app.o: app.d
	$(DC) $(DFLAGS) -c $<

clean:
	rm -rfv *.o *.a tdc tdc-test-library tmp tmp.s

test: bin/tdc
	dub test
	./test.sh
