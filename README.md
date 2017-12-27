# yaricv32

Yet Another RIsCV32 implementation of the [rv32ui][1] ISA. Testing can be done on the Lattice iCE40 family of FPGAs. The specific board used for development is:

* [ICE40 Breakout Board][2]

This particular family of FPGAs is currently supported by a fully open source toolchain.
For anyone interested further information is available at:

* [Yosys][3]
* [arachne-pnr][4]
* [IceStorm][5]

The CPU core will execute the instructions in-order and is able to pass all rv32ui [riscv-tests][6]. It uses 8K of the FPGA static block ram for instructions, data, stack and approx. 2000 logic cells. Currently the included firmware will calculate and output the first twelve Fibonacci numbers via a memory mapped UART transmitter which is connected to the second UART port of the development board.   

## Prerequisites

Ubuntu 17.10 although it should work on 16.04 as well. All necessary tools can be installed via:

```
sudo apt-get install arachne-pnr iverilog autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev gtkwave minicom
```

## Running the simulator test bench

The simulator can be invoked via:

```
make
```

The output should be a 'top_test.vcd' file that can be viewed using GtkWave:

```
gtkwave top_test.vcd
```

## Firmware and tests build prerequisites
The repository containing the tests can be cloned along with the cross toolchain using the included
build script:

```
./build-toolchain.sh
```

## Building and running the RISC-V tests
The tests will be compiled and executed via:

```
make riscv_tests
```

## Building the firmware
The firmware can be built using:

```
make firmware.hex
```

## USB permissions for the FPGA board

Before flashing the FPGA board, the USB access permissions need a minor adjustment that will allow the tools to
write a bitstream on the device. Create a new file at:
```
/etc/udev/rules.d/53-lattice-ftdi.rules
```

Add this line inside:

```
ACTION=="add", ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", MODE:="666"
```

## FPGA synthesis and flashing

Make sure that the breakout board is connected to the host PC and configured for SRAM
programming.
Flashing the bitstream on the FPGA can be done by invoking:

```
make flash
```

## Receiving output

The default program will currently calculate the fibonacci sequence of numbers.
As mentioned before the 'OUT' instruction will transmit the register 'A' contents on the second UART port.
The serial device will usually appear on the host as '/dev/ttyUSB1'. The configuration used right now is:

* baudrate: 19000
* bits: 8
* parity: none
* stop bits: 2
* no hw flow control

The data comes in as binary so for nicer output you can instruct minicom to display in hex mode:

```
minicom -H
```

This is not an official Google product

[1]: https://riscv.org/specifications/
[2]: http://www.latticesemi.com/Products/DevelopmentBoardsAndKits/iCE40HX8KBreakoutBoard.aspx
[3]: http://www.clifford.at/yosys/
[4]: https://github.com/cseed/arachne-pnr
[5]: http://www.clifford.at/icestorm/
[6]: https://github.com/riscv/riscv-tests

