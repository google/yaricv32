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

`include "regs.v"
`include "alu.v"
`include "mem.v"

module cpu(
  input clk,
  output uart_tx_wire);

  localparam WIDTH = 32;
  localparam INSTR_WIDTH = WIDTH;
  localparam REG_COUNT = 32;
  localparam ADDRESS_WIDTH = 12;
  localparam STACK_REG_IDX = 2;
  localparam PC_INC = $clog2(INSTR_WIDTH) - 1;
  localparam STACK_START = (1 << (ADDRESS_WIDTH-1)) - PC_INC;
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
  localparam BTYPE_IMM11 = RD_START;
  localparam BTYPE_IMM1 = RD_START + 1;
  localparam BTYPE_IMM4 = BTYPE_IMM1 + 3;
  localparam BTYPE_IMM5 = RS2_END + 1;
  localparam BTYPE_IMM10 = BTYPE_IMM5 + 5;
  localparam BTYPE_IMM12 = BTYPE_IMM10 + 1;

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

  //Branch instructions
  localparam BRANCH_OPCODE = 7'b1100011;
  localparam BEQ_FUNCT3 = 3'b000;
  localparam BNE_FUNCT3 = 3'b001;
  localparam BLT_FUNCT3 = 3'b100;
  localparam BGE_FUNCT3 = 3'b101;
  localparam BLTU_FUNCT3 = 3'b110;
  localparam BGEU_FUNCT3 = 3'b111;

  //Arithmetic instructions
  localparam IARITH_OPCODE = 7'b0010011;
  localparam ARITH_OPCODE = 7'b0110011;
  localparam ADD_FUNCT3 = 3'b000;
  localparam SLT_FUNCT3 = 3'b010;
  localparam SLTU_FUNCT3 = 3'b011;
  localparam XOR_FUNCT3 = 3'b100;
  localparam OR_FUNCT3 = 3'b110;
  localparam AND_FUNCT3 = 3'b111;
  localparam SL_FUNCT3 = 3'b001;
  localparam SR_FUNCT3 = 3'b101;
  localparam SUB_BIT = 30;
  localparam ARITH_SHIFT_BIT = 30;

  localparam STAGE_T0 = 0;
  localparam STAGE_T1 = 1;
  localparam STAGE_T2 = 2;
  localparam STAGE_T3 = 3;
  localparam STAGE_T4 = 4;
  localparam STAGE_COUNT = STAGE_T4 + 1;
  localparam STAGE_WIDTH = $clog2(STAGE_COUNT);

`ifdef IVERILOG
  localparam rst_size = 3;
`else
  localparam rst_size = 6;
`endif
  localparam rst_max = (1 << rst_size) - 1;

  reg [rst_size : 0] rst_cnt = 0;
  reg rstn = 0;

  reg [WIDTH-1 : 0] ir;               //Instruction register.
  reg [STAGE_WIDTH-1 : 0] stage_reg;  //Keeps track of the current execution stage.
  reg [WIDTH-1 : 0] pc_reg;           //Program counter

  reg regs_wr_enable;
  reg [REG_WIDTH-1 : 0] regs_rs1_offset, regs_rs2_offset, regs_rd_offset;
  reg [WIDTH-1 : 0] regs_rd_in;
  wire [WIDTH-1 : 0] regs_rs1_out, regs_rs2_out;
  registers #(
    .WIDTH(WIDTH),
    .REG_WIDTH(REG_WIDTH),
    .STACK_REG(STACK_REG_IDX),
    .STACK_START(STACK_START)) cpu_regs (
    .rst(!rstn),
    .clk(clk),
    .write_enable(regs_wr_enable),
    .rs1_offset(regs_rs1_offset),
    .rs2_offset(regs_rs2_offset),
    .rd_offset(regs_rd_offset),
    .rd_data_in(regs_rd_in),
    .rs1_data_out(regs_rs1_out),
    .rs2_data_out(regs_rs2_out));

  reg sub_enable, alu_arith_shift;
  reg [2 : 0] alu_op;
  reg [REG_WIDTH-1 : 0] alu_shamt;
  reg [WIDTH-1 : 0] alu_a, alu_b;
  wire [WIDTH-1 : 0] alu_res;
  wire alu_eq, alu_bgeu, alu_bge;
  alu #(
    .WIDTH(WIDTH),
    .ADD_OP(ADD_FUNCT3),
    .SLT_OP(SLT_FUNCT3),
    .SLTU_OP(SLT_FUNCT3),
    .XOR_OP(XOR_FUNCT3),
    .OR_OP(OR_FUNCT3),
    .AND_OP(ADD_FUNCT3),
    .SL_OP(SL_FUNCT3),
    .SR_OP(SR_FUNCT3)) cpu_alu(
    .a(alu_a),
    .b(alu_b),
    .sub_enable(sub_enable),
    .arith_shift(alu_arith_shift),
    .op(alu_op),
    .shamt(alu_shamt),
    .res(alu_res),
    .eq(alu_eq),
    .bgeu(alu_bgeu),
    .bge(alu_bge));

  reg ram_wr_enable = 0;
  reg [ADDRESS_WIDTH-1 : 0] ram_rd_addr, ram_wr_addr;
  reg [WIDTH-1 : 0] ram_data_in;
  wire [WIDTH-1 : 0] ram_data_out;
  ram #(
    .WIDTH(WIDTH),
    .ADDRESS_WIDTH(ADDRESS_WIDTH)) cpu_ram(
    .rst(!rstn),
    .clk(clk),
    .write_enable(ram_wr_enable),
    .read_addr(ram_rd_addr),
    .write_addr(ram_wr_addr),
    .data_in(ram_data_in),
    .data_out(ram_data_out),
    .uart_tx_wire(uart_tx_wire));

  wire [OPCODE_END : 0] opcode;
  wire [FUNCT3_WIDTH : 0] funct3;
  wire [REG_WIDTH-1 : 0] rd;
  wire [REG_WIDTH-1 : 0] rs1;
  wire [REG_WIDTH-1 : 0] rs2;
  wire [WIDTH-1 : 0] itype_imm;
  wire [WIDTH-1 : 0] stype_imm;
  wire [WIDTH-1 : 0] utype_imm;
  wire [WIDTH-1 : 0] jtype_imm;
  wire [WIDTH-1 : 0] btype_imm;

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

  assign itype_imm = {{20{ir[ITYPE_IMM_END]}}, ir[ITYPE_IMM_END : ITYPE_IMM_START]};

  assign stype_imm = {{20{ir[STYPE_IMM2_END]}},
    {ir[STYPE_IMM2_END : STYPE_IMM2_START], ir[STYPE_IMM1_END : STYPE_IMM1_START]}};

  assign utype_imm = {ir[UTYPE_IMM_END : UTYPE_IMM_START], 12'b0};

  assign jtype_imm = {{12{ir[JTYPE_IMM20]}}, {ir[JTYPE_IMM20],
    ir[JTYPE_IMM19 : JTYPE_IMM12], ir[JTYPE_IMM11], ir[JTYPE_IMM10 : JTYPE_IMM1], 1'b0}};

  assign btype_imm = {{20{ir[BTYPE_IMM12]}}, {ir[BTYPE_IMM12],
    ir[BTYPE_IMM11], ir[BTYPE_IMM10 : BTYPE_IMM5], ir[BTYPE_IMM4 : BTYPE_IMM1], 1'b0}};

  always @(posedge clk) begin
    if (rstn) begin
      case (stage_reg)

        STAGE_T0: begin
          ir <= ram_data_out;
          alu_a <= pc_reg;
          alu_b <= PC_INC;
          sub_enable <= 0;
          alu_op <= ADD_FUNCT3;
          regs_wr_enable <= 0;
          ram_wr_enable <= 0;
          stage_reg <= STAGE_T1;
        end

        STAGE_T1: begin
          case (opcode)

            ARITH_OPCODE: begin
              regs_rs1_offset <= rs1;
              regs_rs2_offset <= rs2;
              pc_reg <= alu_res;
              stage_reg <= STAGE_T2;
            end

            IARITH_OPCODE: begin
              regs_rs1_offset <= rs1;
              pc_reg <= alu_res;
              stage_reg <= STAGE_T2;
            end

            BRANCH_OPCODE: begin
              regs_rd_in <= alu_res;
              alu_b <= btype_imm;
              regs_rs1_offset <= rs1;
              regs_rs2_offset <= rs2;
              stage_reg <= STAGE_T2;
            end

            LOAD_OPCODE: begin
              regs_rs1_offset <= rs1;
              pc_reg <= alu_res;
              stage_reg <= STAGE_T2;
            end

            STORE_OPCODE: begin
              regs_rs1_offset <= rs1;
              pc_reg <= alu_res;
              stage_reg <= STAGE_T2;
            end

            LUI_OPCODE: begin
              regs_wr_enable <= 1;
              regs_rd_offset <= rd;
              regs_rd_in <= utype_imm;
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
              regs_rd_offset <= rd;
              regs_rd_in <= alu_res;
              alu_b <= jtype_imm;
              stage_reg <= STAGE_T2;
            end

            JALR_OPCODE: begin
              regs_wr_enable <= 1;
              regs_rd_offset <= rd;
              regs_rd_in <= alu_res;
              regs_rs1_offset <= rs1;
              stage_reg <= STAGE_T2;
            end

            default: begin
`ifdef IVERILOG
              $display("Unsupported opcode: %d!\n", opcode);
`endif
            end

          endcase
        end

        STAGE_T2: begin
          case (opcode)

            ARITH_OPCODE: begin
              alu_a <= regs_rs1_out;
              alu_b <= regs_rs2_out;
              alu_op <= funct3;
              sub_enable <= ir[SUB_BIT];
              alu_arith_shift <= ir[ARITH_SHIFT_BIT];
              alu_shamt <= regs_rs2_out[REG_WIDTH-1 : 0];
              stage_reg <= STAGE_T3;
            end

            IARITH_OPCODE: begin
              alu_a <= regs_rs1_out;
              alu_b <= itype_imm;
              alu_op <= funct3;
              alu_arith_shift <= ir[ARITH_SHIFT_BIT];
              alu_shamt <= rs2;
              stage_reg <= STAGE_T3;
            end

            BRANCH_OPCODE: begin
              ram_data_in <= alu_res;
              alu_a <= regs_rs1_out;
              alu_b <= regs_rs2_out;
              stage_reg <= STAGE_T3;
            end

            LOAD_OPCODE: begin
              alu_a <= regs_rs1_out;
              alu_b <= itype_imm;
              sub_enable <= 0;
              stage_reg <= STAGE_T3;
            end

            STORE_OPCODE: begin
              alu_a <= regs_rs1_out;
              alu_b <= stype_imm;
              sub_enable <= 0;
              stage_reg <= STAGE_T3;
            end

            AUIPC_OPCODE: begin
              pc_reg <= ram_rd_addr;
              regs_wr_enable <= 1;
              regs_rd_offset = rd;
              regs_rd_in <= alu_res;
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
              alu_a <= regs_rs1_out;
              alu_b <= itype_imm;
              stage_reg <= STAGE_T3;
            end

            default: begin
            end

          endcase
        end

        STAGE_T3: begin
          case (opcode)

            ARITH_OPCODE: begin
              regs_wr_enable <= 1;
              regs_rd_in <= alu_res;
              regs_rd_offset <= rd;
              ram_rd_addr <= pc_reg;
              stage_reg <= STAGE_T0;
            end

            IARITH_OPCODE: begin
              regs_wr_enable <= 1;
              regs_rd_in <= alu_res;
              regs_rd_offset <= rd;
              ram_rd_addr <= pc_reg;
              stage_reg <= STAGE_T0;
            end

            BRANCH_OPCODE: begin
              stage_reg <= STAGE_T0;
              case (funct3)

                BEQ_FUNCT3: begin
                  pc_reg <= alu_eq ? ram_data_in : regs_rd_in;
                  ram_rd_addr <= alu_eq ? ram_data_in : regs_rd_in;
                end

                BNE_FUNCT3: begin
                  pc_reg <= !alu_eq ? ram_data_in : regs_rd_in;
                  ram_rd_addr <= !alu_eq ? ram_data_in : regs_rd_in;
                end

                BGE_FUNCT3: begin
                  pc_reg <= alu_bge ? ram_data_in : regs_rd_in;
                  ram_rd_addr <= alu_bge ? ram_data_in : regs_rd_in;
                end

                BGEU_FUNCT3: begin
                  pc_reg <= alu_bgeu ? ram_data_in : regs_rd_in;
                  ram_rd_addr <= alu_bgeu ? ram_data_in : regs_rd_in;
                end

                BLT_FUNCT3: begin
                  pc_reg <= !alu_bge ? ram_data_in : regs_rd_in;
                  ram_rd_addr <= !alu_bge ? ram_data_in : regs_rd_in;
                end

                BLTU_FUNCT3: begin
                  pc_reg <= !alu_bgeu ? ram_data_in : regs_rd_in;
                  ram_rd_addr <= !alu_bgeu ? ram_data_in : regs_rd_in;
                end

                default: begin
`ifdef IVERILOG
                  $display("Unsupported branch function: %d !\n", funct3);
`endif
                end

              endcase
            end

            LOAD_OPCODE: begin
              ram_rd_addr <= alu_res;
              stage_reg <= STAGE_T4;
            end

            STORE_OPCODE: begin
              ram_wr_addr <= alu_res;
              regs_rs2_offset <= rs2;
              stage_reg <= STAGE_T4;
            end

            JALR_OPCODE: begin
              pc_reg <= {alu_res[31:1], 1'b0};
              ram_rd_addr <= {alu_res[31:1], 1'b0};
              stage_reg <= STAGE_T0;
            end

            default: begin
            end

          endcase
        end

        STAGE_T4: begin
          case (opcode)

            LOAD_OPCODE: begin
              regs_rd_offset <= rd;
              regs_wr_enable <= 1;
              ram_rd_addr <= pc_reg;
              stage_reg <= STAGE_T0;
              case (funct3)

                LW_FUNCT3: begin
                  regs_rd_in  <= ram_data_out;
                end

                LB_FUNCT3: begin
                  regs_rd_in <= {{24{ram_data_out[7]}}, ram_data_out[7:0]};
                end

                LH_FUNCT3: begin
                  regs_rd_in <= {{16{ram_data_out[15]}}, ram_data_out[15:0]};
                end

                LBU_FUNCT3: begin
                  regs_rd_in <= {24'b0, (ram_data_out[7:0])};
                end

                LHU_FUNCT3: begin
                  regs_rd_in <= {16'b0, (ram_data_out[15:0])};
                end

                default: begin
`ifdef IVERILOG
                  $display("Unsupported load function: %d !\n", funct3);
`endif
                end

              endcase
            end

            STORE_OPCODE: begin
              ram_wr_enable <= 1;
              ram_rd_addr <= pc_reg;
              stage_reg <= STAGE_T0;
              case (funct3)

                SB_FUNCT3: begin
                  ram_data_in[7:0] <= regs_rs2_out[7:0];
                end

                SH_FUNCT3: begin
                  ram_data_in[15:0] <= regs_rs2_out[15:0];
                end

                SW_FUNCT3: begin
                  ram_data_in <= regs_rs2_out;
                end

                default: begin
`ifdef IVERILOG
                  $display("Unsupported store function: %d !\n", funct3);
`endif
                end

              endcase
            end

          endcase
        end

        default: begin
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
