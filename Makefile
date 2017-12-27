COMP = iverilog
SIM = vvp
SYN = yosys
PNR = arachne-pnr
PACK = icepack
PROG = iceprog
BIN32HEX = bin32hex.py
RISCV_TOOLS_PREFIX = third_party/riscv-toolchain/bin/riscv32-unknown-elf-
RISCV_GCC_LIB = third_party/riscv-toolchain/lib/gcc/riscv32-unknown-elf/7.2.0/libgcc.a
CC = $(RISCV_TOOLS_PREFIX)gcc
OBJCOPY = $(RISCV_TOOLS_PREFIX)objcopy

RISCV_TESTS_DIR = third_party/riscv-tests/isa/rv32ui
RISCV_TESTS_SRC = $(wildcard $(RISCV_TESTS_DIR)/*.S)
RISCV_TESTS = $(basename $(RISCV_TESTS_SRC))
RISCV_TESTS_ELF = $(addsuffix .elf,$(RISCV_TESTS))
RISCV_TESTS_HEX = $(addsuffix .hex,$(RISCV_TESTS))
RISCV_TEST_RESULT_OBJ = env/riscv_test_result.o
RISCV_TEST_DEFINES = test_defines.v
RISCV_TEST_INC = third_party/riscv-tests/isa/macros/scalar
RISCV_TEST_LINK_SCRIPT = third_party/riscv-tests/env/p/link.ld
RISCV_TEST_BENCH = riscv_test.v
RISCV_TEST_SIM = riscv_test.vvp

MEMSIZE = 8192
MEMWORDCOUNT = $(shell echo $(MEMSIZE) / 4 | bc)
OBJCOPYFLAGS = -O binary
PUTC_OBJ = env/putc.o
INC_DIR = env/inc
CCFLAGS = -Wall -fno-pic -fno-builtin -nostdlib -march=rv32i -mabi=ilp32 -O0 -DMEMSIZE=$(MEMSIZE)
COMP_FLAGS = -Wall -g2005
PCF = top.pcf
TOP_TEST = top_test.vcd
FIRMWARE_NAME = firmware
FIRMWARE_SRC = firmware/start.s firmware/main.o
FIRMWWARE_LINK_SCRIPT = firmware/link.ld

all: $(TOP_TEST)

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

riscv_tests: $(RISCV_TESTS_HEX)
	$(foreach t, $(RISCV_TESTS), $(call run_test, $(t)))

define run_test
	$(file >$(RISCV_TEST_DEFINES),`define TEST_PROG "$(strip $(1)).hex")
	$(file >>$(RISCV_TEST_DEFINES),`define TEST_NAME "$(basename $(notdir $(1)))")
	$(shell $(COMP) $(COMP_FLAGS) -o $(RISCV_TEST_SIM) $(RISCV_TEST_BENCH))
	@echo "$(shell $(SIM) $(RISCV_TEST_SIM))"
endef

%.o: %.c
	$(CC) $(CCFLAGS) -I$(INC_DIR) -c -o $@ $<

%.elf: %.S | $(PUTC_OBJ) $(RISCV_TEST_RESULT_OBJ)
	$(CC) $(CCFLAGS) -I$(INC_DIR) -I$(RISCV_TEST_INC) -T$(RISCV_TEST_LINK_SCRIPT) -o $@ $< \
		$(RISCV_TEST_RESULT_OBJ) $(PUTC_OBJ)

$(FIRMWARE_NAME).elf: $(FIRMWARE_SRC)
	$(CC) $(CCFLAGS) -T$(FIRMWWARE_LINK_SCRIPT) -o $@ $^ $(RISCV_GCC_LIB)

clean:
	rm -f *.vvp *.vcd *.blif *.bin *.txt *.dump *.elf firmware/*.elf firmware/*.o \
		$(RISCV_TEST_DEFINES) $(RISCV_TESTS_HEX)

.SILENT:

.PHONY: clean riscv_tests
