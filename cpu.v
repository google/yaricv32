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

module registers(
  input clk,
  input write_enable,
  input [REG_WIDTH-1 : 0] read_offset,
  input [REG_WIDTH-1 : 0] write_offset,
  input [WIDTH-1 : 0] data_in,
  output [WIDTH-1 : 0] data_out);

  parameter REG_WIDTH = 5;
  parameter WIDTH = 32;
  parameter STACK_REG_IDX = 2;
  parameter STACK_START = 1 << 12;
  localparam REG_COUNT = 1 << REG_WIDTH;
  reg [WIDTH-1 : 0] regs [0 : REG_COUNT-1];

  initial begin
`ifdef IVERILOG
      regs[STACK_REG_IDX] = STACK_START;
      regs[8] = 104;
      regs[15] = 7;
`endif
  end

  assign data_out = regs[read_offset];

  always @(posedge clk) begin
    if (write_enable && (write_offset != 0)) begin
     regs[write_offset] <= data_in;
    end
  end

endmodule

module ram(
  input clk,
  input write_enable,
  input [ADDRESS_WIDTH-1 : 0] read_addr,
  input [ADDRESS_WIDTH-1 : 0] write_addr,
  input [WIDTH-1 : 0] data_in,
  output [WIDTH-1 : 0] data_out);

  parameter ADDRESS_WIDTH = 12;
  parameter WIDTH = 32;
  localparam MEMORY_SIZE = 1 << ADDRESS_WIDTH;
  reg [WIDTH-1 : 0] mem [0 : MEMORY_SIZE-1];

  initial begin
`ifdef IVERILOG
    mem[0] = 32'h03c000ef;
    mem[4] = 32'h038000ef;
    mem[8] = 32'hfef42623;
    mem[12] = 32'hfec42583;
    mem[60] = 32'h00400137;
    mem[64] = 32'h00008067;
`endif
  end

  assign data_out = mem[read_addr];

  always @(posedge clk) begin
    if (write_enable) begin
      mem[write_addr] <= data_in;
    end
  end

endmodule

module alu(
  input [WIDTH-1 : 0] a,
  input [WIDTH - 1 : 0] b,
  input sub_enable,
  output [WIDTH - 1 : 0] res);

  parameter WIDTH = 32;
  wire [WIDTH - 1 : 0] carry;
  wire [WIDTH - 1 : 0] b_in;

  assign b_in = sub_enable ? ~(b) : b;

  genvar i;
  generate
    for (i = 0; i < WIDTH; i = i + 1) begin
      if (i == 0) begin
        assign res[i] = (a[i] ^ b_in[i]) ^ sub_enable;
        assign carry[i] = ((a[i] ^ b_in[i]) & sub_enable) | (a[i] & b_in[i]);
      end else begin
        assign res[i] = (a[i] ^ b_in[i]) ^ carry[i-1];
        assign carry[i] = ((a[i] ^ b_in[i]) & carry[i-1]) | (a[i] & b_in[i]);
      end
    end
  endgenerate

endmodule
module cpu(
  input clk,
  output uart_tx_wire);

  localparam WIDTH = 32;
  localparam INSTR_WIDTH = WIDTH;
  localparam REG_COUNT = 32;
  localparam RAM_WIDTH = 8;
  localparam MEMORY_SIZE = 1 << RAM_WIDTH; //4k
  localparam STACK_REG_IDX = 2;
  localparam STACK_START = MEMORY_SIZE;
  localparam PC_INC = $clog2(INSTR_WIDTH) - 1;
  localparam REG_WIDTH = $clog2(REG_COUNT);
  localparam OPCODE_START = 0;
  localparam OPCODE_END = 6;
  localparam RD_START = OPCODE_END + 1;
  localparam RD_END = RD_START + REG_WIDTH - 1;
  localparam FUNCT3_START = RD_START + REG_WIDTH;
  localparam FUNCT3_WIDTH = 2;
  localparam FUNCT3_END = FUNCT3_START + FUNCT3_WIDTH;
  localparam RS1_START = FUNCT3_END + 1;
  localparam RS1_END = RS1_START + REG_WIDTH - 1;
  localparam RS2_START = RS1_START + REG_WIDTH;
  localparam RS2_END = RS2_START + REG_WIDTH - 1;
  localparam ITYPE_IMM_START = RS1_END + 1;
  localparam ITYPE_IMM_END = INSTR_WIDTH - 1;
  localparam STYPE_IMM1_START = RD_START;
  localparam STYPE_IMM1_END = RD_END;
  localparam STYPE_IMM2_START = RS2_START + REG_WIDTH;
  localparam STYPE_IMM2_END = ITYPE_IMM_END;
  localparam UTYPE_IMM_START = RD_END + 1;
  localparam UTYPE_IMM_END = INSTR_WIDTH - 1;
  localparam JTYPE_IMM12 = RD_END + 1;
  localparam JTYPE_IMM19 = JTYPE_IMM12 + 7;
  localparam JTYPE_IMM11 = JTYPE_IMM19 + 1;
  localparam JTYPE_IMM1 = JTYPE_IMM11 + 1;
  localparam JTYPE_IMM10 = JTYPE_IMM1 + 9;
  localparam JTYPE_IMM20 = JTYPE_IMM10 + 1;

  //Load instructions
  localparam LOAD_OPCODE = 7'b0000011;
  localparam LB_FUNCT3 = 3'b000;
  localparam LH_FUNCT3 = 3'b001;
  localparam LW_FUNCT3 = 3'b010;
  localparam LBU_FUNCT3 = 3'b100;
  localparam LHU_FUNCT3 = 3'b101;

  //Store instructions
  localparam STORE_OPCODE = 7'b0100011;
  localparam SB_FUNCT3 = 3'b000;
  localparam SH_FUNCT3 = 3'b001;
  localparam SW_FUNCT3 = 3'b010;

  //Load immediate instructions
  localparam LUI_OPCODE = 7'b0110111;
  localparam AUIPC_OPCODE = 7'b0010111;

  //Control tranfer instructions
  localparam JAL_OPCODE = 7'b1101111;
  localparam JALR_OPCODE = 7'b1100111;

  localparam STAGE_T0 = 0;
  localparam STAGE_T1 = 1;
  localparam STAGE_T2 = 2;
  localparam STAGE_T3 = 3;
  localparam STAGE_T4 = 4;
  localparam STAGE_COUNT = STAGE_T4 + 1;
  localparam STAGE_WIDTH = $clog2(STAGE_COUNT);

  localparam rst_size = 5;
  localparam rst_max = (1 << 5) - 1;

  reg [rst_size : 0] rst_cnt = 0;
  reg rstn = 0;

  reg [WIDTH-1 : 0] ir;               //Instruction register.
  reg [STAGE_WIDTH-1 : 0] stage_reg;  //Keeps track of the current execution stage.
  reg [WIDTH-1 : 0] pc_reg;           //Program counter

  reg regs_wr_enable;
  reg [REG_WIDTH-1 : 0] regs_rd_offset, regs_wr_offset;
  reg [WIDTH-1 : 0] regs_data_in;
  wire [WIDTH-1 : 0] regs_data_out;
  registers #(
    .WIDTH(WIDTH),
    .REG_WIDTH(REG_WIDTH),
    .STACK_REG_IDX(STACK_REG_IDX),
    .STACK_START(STACK_START)) cpu_regs (
    .clk(clk),
    .write_enable(regs_wr_enable),
    .read_offset(regs_rd_offset),
    .write_offset(regs_wr_offset),
    .data_in(regs_data_in),
    .data_out(regs_data_out));

  reg alu_op;
  reg [WIDTH-1 : 0] alu_a, alu_b;
  wire [WIDTH-1 : 0] alu_res;
  alu #(.WIDTH(WIDTH)) cpu_alu(
    .a(alu_a),
    .b(alu_b),
    .sub_enable(alu_op),
    .res(alu_res));

  reg ram_wr_enable;
  reg [RAM_WIDTH-1 : 0] ram_rd_addr, ram_wr_addr;
  reg [WIDTH-1 : 0] ram_data_in;
  wire [WIDTH-1 : 0] ram_data_out;
  ram #(.WIDTH(WIDTH), .ADDRESS_WIDTH(RAM_WIDTH)) cpu_ram(
    .clk(clk),
    .write_enable(ram_wr_enable),
    .read_addr(ram_rd_addr),
    .write_addr(ram_wr_addr),
    .data_in(ram_data_in),
    .data_out(ram_data_out));

  wire [OPCODE_END : 0] opcode;
  wire [FUNCT3_WIDTH : 0] funct3;
  wire [REG_WIDTH-1 : 0] rd;
  wire [REG_WIDTH-1 : 0] rs1;
  wire [REG_WIDTH-1 : 0] rs2;
  wire [WIDTH-1 : 0] itype_imm;
  wire [WIDTH-1 : 0] stype_imm;
  wire [WIDTH-1 : 0] utype_imm;
  wire [WIDTH-1 : 0] jtype_imm;

  assign uart_tx_wire = itype_imm[0];

  always @(posedge clk) begin
    if (rst_cnt != rst_max) begin
      rst_cnt <= rst_cnt + 1;
    end else begin
      rstn <= 1;
    end
  end

  assign opcode = ir[OPCODE_END : OPCODE_START];
  assign funct3 = ir[FUNCT3_END : FUNCT3_START];
  assign rd = ir[RD_END : RD_START];
  assign rs1 = ir[RS1_END : RS1_START];
  assign rs2 = ir[RS2_END : RS2_START];

  assign itype_imm = {ir[ITYPE_IMM_END] ? {20{1'b1}} : 20'b0, ir[ITYPE_IMM_END : ITYPE_IMM_START]};

  assign stype_imm = {ir[STYPE_IMM2_END] ? {20{1'b1}} : 20'b0,
    {ir[STYPE_IMM2_END : STYPE_IMM2_START], ir[STYPE_IMM1_END : STYPE_IMM1_START]}};

  assign utype_imm = {ir[UTYPE_IMM_END : UTYPE_IMM_START], 12'b0};

  assign jtype_imm = {ir[JTYPE_IMM20] ? {12{1'b1}} : 12'b0, {ir[JTYPE_IMM20],
    ir[JTYPE_IMM19 : JTYPE_IMM12], ir[JTYPE_IMM11], ir[JTYPE_IMM10 : JTYPE_IMM1], 1'b0}};

  always @(posedge clk) begin
    if (rstn) begin
      case (stage_reg)

        STAGE_T0: begin
          ir <= ram_data_out;
          alu_a <= pc_reg;
          alu_b <= PC_INC;
          alu_op <= 0;
          regs_wr_enable <= 0;
          ram_wr_enable <= 0;
          stage_reg <= STAGE_T1;
        end

        STAGE_T1: begin
          case (opcode)
            LOAD_OPCODE: begin
              regs_rd_offset <= rs1;
              pc_reg <= alu_res;
              stage_reg <= STAGE_T2;
            end

            STORE_OPCODE: begin
              regs_rd_offset <= rs1;
              pc_reg <= alu_res;
              stage_reg <= STAGE_T2;
            end

            LUI_OPCODE: begin
              regs_wr_enable <= 1;
              regs_wr_offset <= rd;
              regs_data_in <= utype_imm;
              pc_reg <= alu_res;
              ram_rd_addr <= alu_res;
              stage_reg <= STAGE_T0;
            end

            AUIPC_OPCODE: begin
              ram_rd_addr <= alu_res;
              alu_b <= utype_imm;
              stage_reg <= STAGE_T2;
            end

            JAL_OPCODE: begin
              regs_wr_enable <= 1;
              regs_wr_offset <= rd;
              regs_data_in <= alu_res;
              alu_b <= jtype_imm;
              stage_reg <= STAGE_T2;
            end

            JALR_OPCODE: begin
              regs_wr_enable <= 1;
              regs_wr_offset <= rd;
              regs_data_in <= alu_res;
              regs_rd_offset <= rs1;
              stage_reg <= STAGE_T2;
            end

            default: begin
`ifdef IVERILOG
              $display("Unsupported opcode!\n");
`endif
            end
          endcase
        end

        STAGE_T2: begin
          case (opcode)

            LOAD_OPCODE: begin
              alu_a <= regs_data_out;
              alu_b <= itype_imm;
              alu_op <= 0;
              stage_reg <= STAGE_T3;
            end

            STORE_OPCODE: begin
              alu_a <= regs_data_out;
              alu_b <= stype_imm;
              alu_op <= 0;
              stage_reg <= STAGE_T3;
            end

            AUIPC_OPCODE: begin
              pc_reg <= ram_rd_addr;
              regs_wr_enable <= 1;
              regs_wr_offset <= rd;
              regs_data_in <= alu_res;
              stage_reg <= STAGE_T0;
            end

            JAL_OPCODE: begin
              pc_reg <= alu_res;
              ram_rd_addr <= alu_res;
              regs_wr_enable <= 0;
              stage_reg <= STAGE_T0;
            end

            JALR_OPCODE: begin
              regs_wr_enable <= 0;
              alu_a <= regs_data_out;
              alu_b <= itype_imm;
              stage_reg <= STAGE_T3;
            end

          endcase
        end

        STAGE_T3: begin
          case (opcode)

            LOAD_OPCODE: begin
              ram_rd_addr <= alu_res;
              stage_reg <= STAGE_T4;
            end

            STORE_OPCODE: begin
              ram_wr_addr <= alu_res;
              regs_rd_offset <= rs2;
              stage_reg <= STAGE_T4;
            end

            JALR_OPCODE: begin
              pc_reg <= {alu_res[31:1], 1'b0};
              ram_rd_addr <= {alu_res[31:1], 1'b0};
              stage_reg <= STAGE_T0;
            end

          endcase
        end

        STAGE_T4: begin
          case (opcode)

            LOAD_OPCODE: begin
              regs_wr_offset <= rd;
              regs_wr_enable <= 1;
              ram_rd_addr <= pc_reg;
              stage_reg <= STAGE_T0;
              case (funct3)

                LB_FUNCT3: begin
                   regs_data_in <= {ram_data_out[7] ? {24{1'b1}} : 24'b0, ram_data_out[7:0]};
                end

                LH_FUNCT3: begin
                  regs_data_in <= {ram_data_out[15] ? {16{1'b1}} : 16'b0, ram_data_out[15:0]};
                end

                LW_FUNCT3: begin
                  regs_data_in <= ram_data_out;
                end

                LBU_FUNCT3: begin
                  regs_data_in <= {24'b0, (ram_data_out[7:0])};
                end

                LHU_FUNCT3: begin
                  regs_data_in <= {16'b0, (ram_data_out[15:0])};
                end

                default: begin
                end

              endcase
            end

            STORE_OPCODE: begin
              ram_wr_enable <= 1;
              ram_rd_addr <= pc_reg;
              stage_reg <= STAGE_T0;
              case (funct3)

                SB_FUNCT3: begin
                  ram_data_in[7:0] <= regs_data_out[7:0];
                end

                SH_FUNCT3: begin
                  ram_data_in[15:0] <= regs_data_out[15:0];
                end

                SW_FUNCT3: begin
                  ram_data_in <= regs_data_out;
                end

                default: begin
                end
              endcase
            end

          endcase
        end

        default: begin
          stage_reg <= STAGE_COUNT;
        end

      endcase
    end else begin
      ir <= 0;
      pc_reg <= 0;
      ram_rd_addr <= 0;
      stage_reg <= STAGE_T0;
    end
  end
endmodule
