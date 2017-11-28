COMP = iverilog
SIM = vvp
SYN = yosys
PNR = arachne-pnr
PACK = icepack
PROG = iceprog

PCF = top.pcf
TESTS = top_test.vcd

all: $(TESTS)

%.vcd: %.vvp
	$(SIM) $<

%.blif: %.v
	$(SYN) -q -p "synth_ice40 -blif $@" $<

%.txt: %.blif
	$(PNR) -p $(PCF) -o $@ $<

%.bin: %.txt
	$(PACK) $< $@

%.vvp: %.v
	$(COMP) -Wall -o $@ $<

clean:
	rm -f *.vvp *.vcd *.blif *.bin *.txt

.PHONY: clean
