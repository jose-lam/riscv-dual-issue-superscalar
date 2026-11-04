module riscvsingle(input  clk, reset,
                   output [31:0] PC,
                   input  [63:0] Instr,
                   output MemWrite,
                   output [31:0] DataAdr,
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  wire [31:0] ALUResult;
  wire [63:0] InstrD, InstrE, InstrM, InstrW;

  wire       ALUSrc_0, ALUSrc_1;
  wire       RegWriteM_0, RegWriteW_0, RegWriteW_1;
  wire       Zero_0, Zero_1;
  wire       PCSrc_0, PCSrc_1;
  wire       MemWrite_0;
  wire [1:0] ResultSrcW_0, ResultSrcW_1, ResultSrcE_0;
  wire [1:0] ImmSrc_0, ImmSrc_1;
  wire [2:0] ALUControl_0, ALUControl_1;
  wire [1:0] ForwardAE, ForwardBE;
  wire [4:0] RdM, RdW;
  wire       StallF, StallD, FlushE, FlushD;

  assign DataAdr  = ALUResult;
  assign MemWrite = MemWrite_0;

  controller c_0(
    .clk(clk),
    .reset(reset),
    .op(InstrD[6:0]),
    .funct3(InstrD[14:12]),
    .funct7b5(InstrD[30]),
    .ZeroE(Zero_0),
    .ResultSrcW(ResultSrcW_0),
    .ResultSrcE(ResultSrcE_0),
    .MemWriteM(MemWrite_0),
    .PCSrcE(PCSrc_0),
    .ALUSrcE(ALUSrc_0),
    .RegWriteM(RegWriteM_0),
    .RegWriteW(RegWriteW_0),
    .ImmSrcD(ImmSrc_0),
    .ALUControlE(ALUControl_0),
    .FlushE(FlushE)
  );

  controller c_1(
    .clk(clk),
    .reset(reset),
    .op(InstrD[38:32]),
    .funct3(InstrD[46:44]),
    .funct7b5(InstrD[62]),
    .ZeroE(Zero_1),
    .ResultSrcW(ResultSrcW_1),
    .PCSrcE(PCSrc_1),
    .ALUSrcE(ALUSrc_1),
    .RegWriteW(RegWriteW_1),
    .ImmSrcD(ImmSrc_1),
    .ALUControlE(ALUControl_1),
    .FlushE(FlushE)
  );

  datapath dp(
    .clk(clk),
    .reset(reset),
    .ResultSrc_0(ResultSrcW_0),
    .ResultSrc_1(ResultSrcW_1),
    .PCSrc_0(PCSrc_0),
    .PCSrc_1(PCSrc_1),
    .ALUSrc_0(ALUSrc_0),
    .ALUSrc_1(ALUSrc_1),
    .RegWrite_0(RegWriteW_0),
    .RegWrite_1(RegWriteW_1),
    .ImmSrc_0(ImmSrc_0),
    .ImmSrc_1(ImmSrc_1),
    .ALUControl_0(ALUControl_0),
    .ALUControl_1(ALUControl_1),
    .Zero_0(Zero_0),
    .Zero_1(Zero_1),
    .PCF(PC),
    .InstrF(Instr),
    .InstrD(InstrD),
    .InstrE(InstrE),
    .InstrM(InstrM),
    .InstrW(InstrW),
    .ALUResultM(ALUResult),
    .WriteDataM(WriteData),
    .ReadDataM(ReadData),
    .RdM(RdM),
    .RdW(RdW),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .StallF(StallF),
    .StallD(StallD),
    .FlushE(FlushE),
    .FlushD(FlushD)
  );

  hazard h(
    .StallF(StallF),
    .StallD(StallD),
    .FlushD(FlushD),
    .FlushE(FlushE),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .Rs1D(InstrD[19:15]),
    .Rs2D(InstrD[24:20]),
    .RdE(InstrE[11:7]),
    .Rs1E(InstrE[19:15]),
    .Rs2E(InstrE[24:20]),
    .RdM(RdM),
    .RdW(RdW),
    .PCSrcE(PCSrc_0),
    .ResultSrc(ResultSrcE_0[0]),
    .RegWriteM(RegWriteM_0),
    .RegWriteW(RegWriteW_0)
  );

endmodule