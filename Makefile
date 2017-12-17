RISCV_TOOLS_PREFIX = riscv-toolchain/bin/riscv32-unknown-elf-
RISCV_LIBS_PREFIX = riscv-toolchain/lib/gcc/riscv32-unknown-elf/7.2.0/
CC = $(RISCV_TOOLS_PREFIX)gcc
AS = $(RISCV_TOOLS_PREFIX)as
LD = $(RISCV_TOOLS_PREFIX)ld
OBJCOPY = $(RISCV_TOOLS_PREFIX)objcopy
BIN32HEX = bin32hex.py
MEMSIZE = 8192
MEMWORDCOUNT = $(shell echo $(MEMSIZE) / 4 | bc)
CCFLAGS = -c -Wall -fno-pic -fno-builtin -nostdlib -march=rv32i -mabi=ilp32 -O0\
					-DMEMSIZE=$(MEMSIZE)
ASFLAGS = -fno-pic -march=rv32i -mabi=ilp32
LDFLAGS = -T firmware/firmware.ld
OBJCOPYFLAGS = -O binary

COMP = iverilog
SIM = vvp
SYN = yosys
PNR = arachne-pnr
PACK = icepack
PROG = iceprog

COMP_FLAGS = -Wall -g2005
PCF = top.pcf
TESTS = top_test.vcd
FIRMWARE_SRC = firmware/main.o
FIRMWARE_CRT = firmware/start.o

all: $(TESTS)

%.vcd: %.vvp
	$(SIM) $<

%.blif: %.v
	$(SYN) -q -p "synth_ice40 -blif $@" $<

%.txt: %.blif
	$(PNR) -d 8k -p $(PCF) -o $@ $<

%.bin: %.txt
	$(PACK) $< $@

%.vvp: %.v
	$(COMP) $(COMP_FLAGS) -o $@ $<

flash: cpu.bin
	$(PROG) -S $<$

%.hex: %.dump
	./$(BIN32HEX) $< $@ $(MEMWORDCOUNT)

%.dump: %.elf
	$(OBJCOPY) $(OBJCOPYFLAGS) $< $@

%.elf: $(FIRMWARE_CRT) $(FIRMWARE_SRC)
	$(LD) $(LDFLAGS) -o $@ $^ $(RISCV_LIBS_PREFIX)libgcc.a

%.o: %.c
	$(CC) $(CCFLAGS) -o $@ $<

$(FIRMWARE_CRT).o: %.s
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f *.vvp *.vcd *.blif *.bin *.txt *.dump *.elf firmware/*.elf firmware/*.o

.PHONY: clean
