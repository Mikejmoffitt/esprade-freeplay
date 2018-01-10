AS=asl
P2BIN=p2bin
SRC=patch.s
BSPLIT=bsplit
MAME=mame

ASFLAGS=-i . -n -U

.PHONY: all clean prg.bin

all: prg.bin

prg.orig:
	stat u42.int
	stat u41.int
	$(BSPLIT) c u42.int u41.int prg.orig

prg.o: prg.orig
	$(AS) $(SRC) $(ASFLAGS) -o prg.o

prg.bin: prg.o
	$(P2BIN) $< $@ -r \$$-0xFFFFF
	mkdir -p out/
	$(BSPLIT) s prg.bin out/u42.int out/u41.int

clean:
	@-rm -f prg.*
	@-rm -f out/*
