// Nucleo Dual-Issue In-Order (se conserva el nombre del modulo del Single-Issue
// para no cambiar top.v ni los testbenches).
module riscvsingle(input  clk, reset,
                   output [31:0] PC,
                   input  [63:0] Instr,
                   output MemWrite,
                   output [31:0] DataAdr,
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  wire [63:0] InstrD, InstrE, InstrM, InstrW;

  // control por via
  wire       ALUSrc_0, ALUSrc_1;
  wire       RegWriteM_0, RegWriteM_1, RegWriteW_0, RegWriteW_1;
  wire       Zero_0, Zero_1;
  wire       PCSrc_0, PCSrc_1;
  wire       MemWriteM_0, MemWriteM_1;
  wire [1:0] ResultSrcW_0, ResultSrcW_1, ResultSrcE_0, ResultSrcE_1, ResultSrcM_0, ResultSrcM_1;
  wire [1:0] ImmSrc_0, ImmSrc_1;
  wire [2:0] ALUControl_0, ALUControl_1;
  wire       JumpE_0, JumpE_1;

  // hazard / issue
  wire [2:0] ForwardAE_0, ForwardBE_0, ForwardAE_1, ForwardBE_1;
  wire [4:0] RdM_0, RdM_1, RdW_0, RdW_1;
  wire       Issue0, Issue1, Partial;
  wire       StallF, StallD, FlushD, FlushE_0, FlushE_1, FlushM_1;

  // ---------------- Issue Unit (etapa D) ----------------
  issue_unit iu(
    .InstrD_0(InstrD[31:0]),  .InstrD_1(InstrD[63:32]),
    .InstrE_0(InstrE[31:0]),  .InstrE_1(InstrE[63:32]),
    .Issue0(Issue0),          .Issue1(Issue1)
  );

  // ---------------- Controllers (uno por via) ----------------
  controller c_0(
    .clk(clk),
    .reset(reset),
    .op(InstrD[6:0]),
    .funct3(InstrD[14:12]),
    .funct7b5(InstrD[30]),
    .ZeroE(Zero_0),
    .ResultSrcW(ResultSrcW_0),
    .ResultSrcE(ResultSrcE_0),
    .ResultSrcM(ResultSrcM_0),
    .MemWriteM(MemWriteM_0),
    .PCSrcE(PCSrc_0),
    .ALUSrcE(ALUSrc_0),
    .RegWriteM(RegWriteM_0),
    .RegWriteW(RegWriteW_0),
    .JumpE(JumpE_0),
    .ImmSrcD(ImmSrc_0),
    .ALUControlE(ALUControl_0),
    .FlushE(FlushE_0),
    .FlushM(1'b0)
  );

  controller c_1(
    .clk(clk),
    .reset(reset),
    .op(InstrD[38:32]),
    .funct3(InstrD[46:44]),
    .funct7b5(InstrD[62]),
    .ZeroE(Zero_1),
    .ResultSrcW(ResultSrcW_1),
    .ResultSrcE(ResultSrcE_1),
    .ResultSrcM(ResultSrcM_1),
    .MemWriteM(MemWriteM_1),
    .PCSrcE(PCSrc_1),
    .ALUSrcE(ALUSrc_1),
    .RegWriteM(RegWriteM_1),
    .RegWriteW(RegWriteW_1),
    .JumpE(JumpE_1),
    .ImmSrcD(ImmSrc_1),
    .ALUControlE(ALUControl_1),
    .FlushE(FlushE_1),
    .FlushM(FlushM_1)
  );

  // ---------------- Datapath ----------------
  datapath dp(
    .clk(clk),
    .reset(reset),
    .ResultSrcW_0(ResultSrcW_0),
    .ResultSrcW_1(ResultSrcW_1),
    .ResultSrcM_0(ResultSrcM_0),
    .ResultSrcM_1(ResultSrcM_1),
    .MemWriteM_0(MemWriteM_0),
    .MemWriteM_1(MemWriteM_1),
    .PCSrcE_0(PCSrc_0),
    .PCSrcE_1(PCSrc_1),
    .ALUSrcE_0(ALUSrc_0),
    .ALUSrcE_1(ALUSrc_1),
    .RegWriteW_0(RegWriteW_0),
    .RegWriteW_1(RegWriteW_1),
    .ImmSrcD_0(ImmSrc_0),
    .ImmSrcD_1(ImmSrc_1),
    .ALUControlE_0(ALUControl_0),
    .ALUControlE_1(ALUControl_1),
    .Zero_0(Zero_0),
    .Zero_1(Zero_1),
    .PCF(PC),
    .InstrF(Instr),
    .InstrD(InstrD),
    .InstrE(InstrE),
    .InstrM(InstrM),
    .InstrW(InstrW),
    .ALUResultM(DataAdr),
    .WriteDataM(WriteData),
    .MemWrite(MemWrite),
    .ReadDataM(ReadData),
    .RdM_0(RdM_0), .RdM_1(RdM_1),
    .RdW_0(RdW_0), .RdW_1(RdW_1),
    .ForwardAE_0(ForwardAE_0), .ForwardBE_0(ForwardBE_0),
    .ForwardAE_1(ForwardAE_1), .ForwardBE_1(ForwardBE_1),
    .StallF(StallF),
    .StallD(StallD),
    .FlushD(FlushD),
    .FlushE_0(FlushE_0),
    .FlushE_1(FlushE_1),
    .FlushM_1(FlushM_1),
    .Partial(Partial)
  );

  // ---------------- Hazard Unit ----------------
  hazard h(
    .Rs1E_0(InstrE[19:15]), .Rs2E_0(InstrE[24:20]),
    .Rs1E_1(InstrE[51:47]), .Rs2E_1(InstrE[56:52]),
    .RdM_0(RdM_0), .RdM_1(RdM_1),
    .RdW_0(RdW_0), .RdW_1(RdW_1),
    .RegWriteM_0(RegWriteM_0), .RegWriteM_1(RegWriteM_1),
    .RegWriteW_0(RegWriteW_0), .RegWriteW_1(RegWriteW_1),
    .ForwardAE_0(ForwardAE_0), .ForwardBE_0(ForwardBE_0),
    .ForwardAE_1(ForwardAE_1), .ForwardBE_1(ForwardBE_1),
    .Issue0(Issue0), .Issue1(Issue1),
    .PCSrcE_0(PCSrc_0), .PCSrcE_1(PCSrc_1),
    .StallF(StallF),
    .StallD(StallD),
    .FlushD(FlushD),
    .FlushE_0(FlushE_0),
    .FlushE_1(FlushE_1),
    .FlushM_1(FlushM_1),
    .Partial(Partial)
  );

endmodule
