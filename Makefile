DC := dmd # ldc2
DFLAGS := -g -i="source/tdc/*.d" -Isource -betterC
OBJ := app.o codegen.o tokenize.o parse.o
.PHONY: clean test

bin/tdc: $(OBJ)
	mkdir -p bin
	gcc -g -static $(OBJ) -o $@ -lc

%.o: source/tdc/%.d
	$(DC) $(DFLAGS) -c $<

app.o: app.d
	$(DC) $(DFLAGS) -c $<

clean:
	rm -rfv *.o *.a tdc tdc-test-library tmp tmp.s bin

test: bin/tdc
	dub test --compiler=$(firstword $(DC))
	./test.sh
