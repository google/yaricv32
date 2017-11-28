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

module cpu(
  input clk,
  output uart_tx_wire);

  localparam WIDTH = 32;
  localparam INSTR_WIDTH = WIDTH;
  localparam REG_COUNT = 32;
  localparam MEMORY_SIZE = 1 << 12; //4k
  localparam STACK_REG_IDX = 2;
  localparam STACK_START = MEMORY_SIZE;
  localparam PC_INC = $clog2(INSTR_WIDTH) - 1;
  localparam REG_WIDTH = $clog2(REG_COUNT);
  localparam OPCODE_START = 0;
  localparam OPCODE_END = 6;
  localparam RD_START = OPCODE_END + 1;
  localparam RD_END = RD_START + REG_WIDTH - 1;
  localparam FUNCT3_START = RD_START + REG_WIDTH;
  localparam FUNCT3_END = FUNCT3_START + 2;
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
  reg [WIDTH-1 : 0] regs [REG_COUNT-1 : 0]; //CPU registers
  reg [WIDTH-1 : 0] pc_reg;           //Program counter
  reg [WIDTH-1 : 0] mem [0 : MEMORY_SIZE];
  reg [WIDTH-1 : 0] mem_off;
  wire [REG_WIDTH-1 : 0] rd;
  wire [REG_WIDTH-1 : 0] rs1;
  wire [REG_WIDTH-1 : 0] rs2;
  wire [WIDTH-1 : 0] itype_imm;
  wire [WIDTH-1 : 0] stype_imm;

  assign uart_tx_wire = 1'b1;

  initial begin
`ifdef IVERILOG
    mem[0] = 32'h00400137;
`endif
  end

  always @(posedge clk) begin
    if (rst_cnt != rst_max) begin
      rst_cnt <= rst_cnt + 1;
    end else begin
      rstn <= 1;
    end
  end

  assign rd = ir[RD_END : RD_START];
  assign rs1 = ir[RS1_END : RS1_START];
  assign rs2 = ir[RS2_END : RS2_START];
  assign itype_imm = regs[rs1] + {ir[ITYPE_IMM_END] ? {20{1'b1}} : 20'b0,
                      ir[ITYPE_IMM_END : ITYPE_IMM_START]};
  assign stype_imm = regs[rs1] + {ir[STYPE_IMM2_END] ? {20{1'b1}} : 20'b0,
                       {ir[STYPE_IMM2_END : STYPE_IMM2_START],
                         ir[STYPE_IMM1_END : STYPE_IMM1_START]}};
  integer idx;
  always @(posedge clk) begin
    if (rstn) begin
      case (stage_reg)
        STAGE_T0: begin
          ir <= mem[pc_reg];
          pc_reg <= pc_reg + PC_INC;
          stage_reg <= STAGE_T1;
        end
        STAGE_T1: begin
          case (ir[OPCODE_END : OPCODE_START])
            LOAD_OPCODE: begin
              case (ir[FUNCT3_END : FUNCT3_START])
                LB_FUNCT3: begin
                  regs[rd] <= {mem[itype_imm][7] ? {24{1'b1}} : 24'b0, mem[itype_imm][7:0]};
                end
                LH_FUNCT3: begin
                  regs[rd] <= {mem[itype_imm][15] ? {16{1'b1}} : 16'b0, mem[itype_imm][15:0]};
                end
                LW_FUNCT3: begin
                  regs[rd] <= mem[itype_imm];
                  $display("LW rd: %d imm: %d mem: %d\n", rd, itype_imm, mem[itype_imm]);
                end
                LBU_FUNCT3: begin
                  regs[rd] <= {24'b0, (mem[itype_imm][7:0])};
                end
                LHU_FUNCT3: begin
                  regs[rd] <= {16'b0, (mem[itype_imm][15:0])};
                end
                default: begin
`ifdef IVERILOG
                  $display("Unsupported load function!\n");
`endif
                end
              endcase
              stage_reg <= STAGE_T2;
            end

            STORE_OPCODE: begin
              case (ir[FUNCT3_END : FUNCT3_START])
                SB_FUNCT3: begin
                  mem[stype_imm][7:0] <= regs[rs2][7:0];
                end
                SH_FUNCT3: begin
                  mem[stype_imm][15:0] <= regs[rs2][15:0];
                end
                SW_FUNCT3: begin
                  mem[stype_imm] <= regs[rs2];
                end
                default: begin
`ifdef IVERILOG
                  $display("Unsupported store function!\n");
`endif
                end
              endcase
              stage_reg <= STAGE_T2;
            end

            LUI_OPCODE: begin
              regs[rd] <= {ir[UTYPE_IMM_END : UTYPE_IMM_START], 12'b0};
              stage_reg <= STAGE_T2;
            end

            AUIPC_OPCODE: begin
              regs[rd] <= pc_reg + {ir[UTYPE_IMM_END : UTYPE_IMM_START], 12'b0} - PC_INC;
              stage_reg <= STAGE_T2;
            end

            default: begin
`ifdef IVERILOG
              $display("Unsupported opcode!\n");
`endif
            end
          endcase
          stage_reg <= STAGE_T2;
        end
        STAGE_T2: begin
`ifdef IVERILOG
          $display("rd: %d %d\n", rd, regs[rd]);
`endif
          stage_reg <= STAGE_T0;
        end
        STAGE_T3: begin
        end
        STAGE_T4: begin
        end
        default: begin
          stage_reg <= STAGE_COUNT;
        end
      endcase
    end else begin
      ir <= 0;
      for (idx = 0; idx < REG_COUNT; idx = idx + 1) begin
        regs[idx] <= 0;
      end
      regs[STACK_REG_IDX] <= STACK_START;
      regs[8] <= 64;
      regs[15] <= 7;
      pc_reg <= 0;
      stage_reg <= STAGE_T0;
    end
  end
endmodule
