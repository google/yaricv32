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

module alu(
  input [WIDTH-1 : 0] a,
  input [WIDTH - 1 : 0] b,
  input sub_enable,
  input arith_shift,
  input [2 : 0] op,
  input [SHIFT_WIDTH-1 : 0] shamt,
  output [WIDTH - 1 : 0] res,
  output eq,
  output bgeu,
  output bge);

  parameter WIDTH = 32;

  parameter ADD_OP = 3'b000;
  parameter SLT_OP = 3'b010;
  parameter SLTU_OP = 3'b011;
  parameter XOR_OP = 3'b100;
  parameter OR_OP = 3'b110;
  parameter AND_OP = 3'b111;
  parameter SL_OP = 3'b001;
  parameter SR_OP = 3'b101;
  localparam SHIFT_WIDTH = $clog2(WIDTH);

  wire [WIDTH - 1 : 0] carry, b_in, adder;
  wire slt, sltu;

  assign b_in = sub_enable ? ~(b) : b;
  assign eq = a == b;
  assign bgeu = a >= b;
  assign bge = $signed(a) >= $signed(b);
  assign slt = (!bge) ? 1 : 0;
  assign sltu = (!bgeu) ? 1 : 0;

  assign res = (op == ADD_OP) ? adder : (op == OR_OP) ? (a | b) : (op == XOR_OP) ? (a ^ b) :
               (op == SL_OP) ? (a << shamt) : ((op == SR_OP) && (arith_shift)) ? (a >>> shamt) :
               (op == SR_OP) ? (a >> shamt) : (op == SLT_OP) ? slt : (op == SLTU_OP) ? sltu :
               a & b;

  genvar i;
  generate
    for (i = 0; i < WIDTH; i = i + 1) begin
      if (i == 0) begin
        assign adder[i] = (a[i] ^ b_in[i]) ^ sub_enable;
        assign carry[i] = ((a[i] ^ b_in[i]) & sub_enable) | (a[i] & b_in[i]);
      end else begin
        assign adder[i] = (a[i] ^ b_in[i]) ^ carry[i-1];
        assign carry[i] = ((a[i] ^ b_in[i]) & carry[i-1]) | (a[i] & b_in[i]);
      end
    end
  endgenerate

endmodule
