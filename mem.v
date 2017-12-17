/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

`include "uart-tx.v"

module ram(
  input rst,
  input clk,
  input write_enable,
  input [ADDRESS_WIDTH-1 : 0] read_addr,
  input [ADDRESS_WIDTH-1 : 0] write_addr,
  input [WIDTH-1 : 0] data_in,
  output [WIDTH-1 : 0] data_out,
  output uart_tx_wire);

  parameter ADDRESS_WIDTH = 12;
  parameter WIDTH = 32;
  parameter IO_SPACE_WIDTH = 2; //MSB bits for memory mapped IO
  localparam MEMORY_SIZE = 1 << (ADDRESS_WIDTH - IO_SPACE_WIDTH - 1);
  localparam WORD_ALIGNMENT = $clog2(WIDTH / 8);
  localparam ALIGNED_WIDTH = ADDRESS_WIDTH - WORD_ALIGNMENT;
  localparam IO_START = MEMORY_SIZE << IO_SPACE_WIDTH;
  localparam UART_OFFSET = 4;
  // UART TX IO mapping
  // [31 : 16] unused, [15:8] tx data, [7 : 2] unused [1] uart tx ready flag, [0] uart tx start
  localparam UART_BASE = IO_START + UART_OFFSET;
  reg [WIDTH-1 : 0] mem [0 : MEMORY_SIZE-1];
  wire [ALIGNED_WIDTH-1 : 0] read_addr_aligned, write_addr_aligned;
  reg uart_start;
  reg [7 : 0] uart_tx_buffer;
  wire uart_ready;

  initial begin
    $readmemh("firmware.hex", mem);
  end

  uarttx tx(
    .rst(rst),
    .clk(clk),
    .tx_start(uart_start),
    .tx_byte(uart_tx_buffer),
    .tx(uart_tx_wire),
    .tx_ready(uart_ready));

  assign read_addr_aligned = read_addr[ADDRESS_WIDTH-1 : WORD_ALIGNMENT];
  assign write_addr_aligned = write_addr[ADDRESS_WIDTH-1 : WORD_ALIGNMENT];
  assign data_out = (read_addr == UART_BASE) ?
                    {16'b0, uart_tx_buffer, 6'b0, uart_ready, uart_start} : mem[read_addr_aligned];

  always @(posedge clk) begin
    if (rst) begin
      uart_start <= 0;
    end else begin
      if (write_enable) begin
        if (write_addr == UART_BASE) begin
          uart_start <= data_in[0];
          uart_tx_buffer <= data_in[15 : 8];
        end else begin
          mem[write_addr_aligned] <= data_in;
        end
      end
    end
  end

endmodule

