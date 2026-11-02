module datapath(input  clk, reset,
                input  [1:0]  ResultSrc, 
                input  PCSrc, ALUSrc,
                input  RegWrite,
                input  [1:0]  ImmSrc, 
                input  [2:0]  ALUControl,
                output Zero,
                output [31:0] PCF,
                input  [31:0] InstrF,
                output [31:0] InstrD, InstrE, InstrM, InstrW, ALUResultM, WriteDataM, 
                input  [31:0] ReadDataM,
                output [4:0]  RdM, RdW,
                input  [1:0]  ForwardAE, ForwardBE,
                input  StallF, StallD, FlushE, FlushD);
  
  localparam WIDTH = 32; // Define a local parameter for bus width

  wire [31:0] PCNext, PCPlus4F, PCTargetE;
  wire [31:0] PCD, PCPlus4D; 
  wire [31:0] ImmExtD, RD2D; 
  wire [31:0] RD1D, SrcBE; 
  wire [31:0] SrcAE, WriteDataE, PCE, ImmExtE, PCPlus4E, ALUResultE, RD1E, RD2E;
  wire [31:0] PCPlus4M;
  wire [31:0] ResultW, ALUResultW, ReadDataW, PCPlus4W; 
  wire [4:0]  RdE;

  // next PC logic
  floperc #(WIDTH) pcreg(
    .clk(clk), 
    .reset(reset), 
    .en(~StallF),
    .clear(1'b0),
    .d(PCNext), 
    .q(PCF)
  ); 
  
    // Fetch -> Decode  (32+32+32 = 96)
  floperc #(96) regFD(clk, reset, ~StallD, FlushD,
    {InstrF, PCF, PCPlus4F},
    {InstrD, PCD, PCPlus4D});

  // Decode -> Execute  (32+32+32+5+32+32+32 = 197)
  floperc #(197) regDE(clk, reset, 1'b1, FlushE,
    {RD1D, RD2D, PCD, InstrD[11:7], ImmExtD, PCPlus4D, InstrD},
    {RD1E, RD2E, PCE, RdE,          ImmExtE, PCPlus4E, InstrE});

  // Execute -> Memory  (32+32+5+32+32 = 133)
  flopr #(133) regEM(clk, reset,
    {ALUResultE, WriteDataE, RdE, PCPlus4E, InstrE},
    {ALUResultM, WriteDataM, RdM, PCPlus4M, InstrM});

  // Memory -> Writeback  (32+32+5+32+32 = 133)
  flopr #(133) regMW(clk, reset,
    {ALUResultM, ReadDataM, RdM, PCPlus4M, InstrM},
    {ALUResultW, ReadDataW, RdW, PCPlus4W, InstrW});
  

  adder       pcadd4(
    .a(PCF), 
    .b({WIDTH{1'b0}} + 4), // Using WIDTH parameter for constant 4
    .y(PCPlus4F)
  ); 

  adder       pcaddbranch(
    .a(PCE), 
    .b(ImmExtE), 
    .y(PCTargetE)
  ); 

  mux2 #(WIDTH)  pcmux(
    .d0(PCPlus4F), 
    .d1(PCTargetE), 
    .s(PCSrc), 
    .y(PCNext)
  ); 
 
  // register file logic
  regfile     rf(
    .clk(clk), 
    .we3(RegWrite), 
    .a1(InstrD[19:15]), 
    .a2(InstrD[24:20]), 
    .a3(RdW), 
    .wd3(ResultW), 
    .rd1(RD1D), 
    .rd2(RD2D)
  ); 

  extend      ext(
    .instr(InstrD[31:7]), 
    .immsrc(ImmSrc), 
    .immext(ImmExtD)
  ); 
  
  mux3 #(WIDTH)  srcamuxE(
    .d0(RD1E),
    .d1(ResultW),
    .d2(ALUResultM),
    .s(ForwardAE),
    .y(SrcAE)
  );
  
  mux3 #(WIDTH)  srcbmuxE(
    .d0(RD2E),
    .d1(ResultW),
    .d2(ALUResultM),
    .s(ForwardBE),
    .y(WriteDataE)
  );

  // ALU logic
  mux2 #(WIDTH)  srcbmux(
    .d0(WriteDataE), 
    .d1(ImmExtE), 
    .s(ALUSrc), 
    .y(SrcBE)
  ); 

  alu         alu(
    .a(SrcAE), 
    .b(SrcBE), 
    .alucontrol(ALUControl), 
    .result(ALUResultE), 
    .zero(Zero)
  ); 

  mux3 #(WIDTH)  resultmux(
    .d0(ALUResultW), 
    .d1(ReadDataW), 
    .d2(PCPlus4W), 
    .s(ResultSrc), 
    .y(ResultW)
  ); 
endmodule