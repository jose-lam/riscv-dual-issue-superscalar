module riscvsingle(input  clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output MemWrite,
                   output [31:0] DataAdr, 
                   output [31:0] WriteData,
                   input  [31:0] ReadData);
  
  wire [31:0] ALUResult, InstrD, InstrE, InstrM, InstrW; 
  
  wire       ALUSrc, RegWriteW, RegWriteM, Jump, Zero; 
  wire [1:0] ResultSrcW, ResultSrcE, ImmSrc; 
  wire [2:0] ALUControl;
  wire [1:0] ForwardAE, ForwardBE; 
  wire       PCSrc; 
  wire [4:0] RdM, RdW;
  wire       StallF, StallD, FlushE, FlushD;

  // DataAdr is connected to ALUResult
  assign DataAdr = ALUResult;

  controller c(
    .clk(clk), 
    .reset(reset), 
    .op(InstrD[6:0]), 
    .funct3(InstrD[14:12]), 
    .funct7b5(InstrD[30]), 
    .ZeroE(Zero),
    .ResultSrcW(ResultSrcW), 
    .ResultSrcE(ResultSrcE),
    .MemWriteM(MemWrite), 
    .PCSrcE(PCSrc),
    .ALUSrcE(ALUSrc), 
    .RegWriteM(RegWriteM),
    .RegWriteW(RegWriteW), 
    .JumpE(Jump),
    .ImmSrcD(ImmSrc), 
    .ALUControlE(ALUControl),
    .FlushE(FlushE)
  ); 
  
  datapath dp(
    .clk(clk), 
    .reset(reset), 
    .ResultSrc(ResultSrcW), 
    .PCSrc(PCSrc),
    .ALUSrc(ALUSrc), 
    .RegWrite(RegWriteW),
    .ImmSrc(ImmSrc), 
    .ALUControl(ALUControl),
    .Zero(Zero), 
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
    .PCSrcE(PCSrc),
    .ResultSrc(ResultSrcE[0]),
    .RegWriteM(RegWriteM),
    .RegWriteW(RegWriteW)
  );

endmodule