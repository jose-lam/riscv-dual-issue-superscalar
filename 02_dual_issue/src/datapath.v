module datapath(input  clk, reset,
                // ---- control via 0 / via 1 (desde controller c_0 / c_1) ----
                input  [1:0]  ResultSrc_0, ResultSrc_1,   // etapa W
                input         PCSrc_0, PCSrc_1,           // PCSrc_1 no se usa en E1
                input         ALUSrc_0, ALUSrc_1,
                input         RegWrite_0, RegWrite_1,     // etapa W
                input  [1:0]  ImmSrc_0, ImmSrc_1,
                input  [2:0]  ALUControl_0, ALUControl_1,
                output        Zero_0, Zero_1,
                // ---- fetch ----
                output [31:0] PCF,
                input  [63:0] InstrF,
                output [63:0] InstrD, InstrE, InstrM, InstrW,
                // ---- memoria de datos (1 solo puerto: via 0 en E1) ----
                output [31:0] ALUResultM, WriteDataM,
                input  [31:0] ReadDataM,
                output [4:0]  RdM, RdW,
                // ---- hazard unit (solo via 0 en E1) ----
                input  [1:0]  ForwardAE, ForwardBE,
                input         StallF, StallD, FlushE, FlushD);

  localparam WIDTH = 32;

  localparam FD_W = 32 + 32 + 32;                    // Instr, PC, PC+4              = 96
  localparam DE_W = 32 + 32 + 32 + 5 + 32 + 32 + 32; // RD1,RD2,PC,Rd,Imm,PC+4,Instr = 197
  localparam EM_W = 32 + 32 + 5 + 32 + 32;           // ALURes,WriteData,Rd,PC+4,Instr = 133
  localparam MW_W = 32 + 32 + 5 + 32 + 32;           // ALURes,ReadData,Rd,PC+4,Instr  = 133

  // ---------------- Fetch ----------------
  wire [31:0] PCNext, PCTargetE_0, PCTargetE_1;
  wire [31:0] PCF_1;                  // PC de la instruccion 1 = PCF + 4
  wire [31:0] PCPlusF_0, PCPlusF_1;   // PCPlusF_0 = PCF+4 (link via 0), PCPlusF_1 = PCF+8 (link via 1 y PC secuencial)

  // ---------------- Decode ----------------
  wire [31:0] InstrD_0, InstrD_1;
  wire [31:0] PCD_0, PCD_1, PCPlusD_0, PCPlusD_1;
  wire [31:0] RD1D, RD2D, RD4D, RD5D;   // rf: rd1/rd2 -> via 0, rd4/rd5 -> via 1
  wire [31:0] ImmExtD_0, ImmExtD_1;

  // ---------------- Execute ----------------
  wire [31:0] InstrE_0, InstrE_1;
  wire [31:0] RD1E, RD2E, RD4E, RD5E;
  wire [31:0] PCE_0, PCE_1, PCPlusE_0, PCPlusE_1;
  wire [31:0] ImmExtE_0, ImmExtE_1;
  wire [4:0]  RdE_0, RdE_1;
  wire [31:0] SrcAE_0, SrcAE_1, SrcBE_0, SrcBE_1;
  wire [31:0] WriteDataE_0, WriteDataE_1;
  wire [31:0] ALUResultE_0, ALUResultE_1;

  // Forwarding de la via 1: desactivado en E1 (se implementa en E2)
  wire [1:0]  ForwardAE_1 = 2'b00;
  wire [1:0]  ForwardBE_1 = 2'b00;

  // ---------------- Memory ----------------
  wire [31:0] InstrM_0, InstrM_1;
  wire [31:0] ALUResultM_0, ALUResultM_1, WriteDataM_0, WriteDataM_1;
  wire [31:0] PCPlusM_0, PCPlusM_1;
  wire [4:0]  RdM_0, RdM_1;
  // Un solo puerto de memoria: en E1 solo la via 0 accede. Via 1 recibe 0.
  wire [31:0] ReadDataM_0 = ReadDataM;
  wire [31:0] ReadDataM_1 = 32'b0;

  // ---------------- Writeback ----------------
  wire [31:0] InstrW_0, InstrW_1;
  wire [31:0] ALUResultW_0, ALUResultW_1, ReadDataW_0, ReadDataW_1;
  wire [31:0] PCPlusW_0, PCPlusW_1;
  wire [4:0]  RdW_0, RdW_1;
  wire [31:0] ResultW_0, ResultW_1;

  // ---------------- Salidas hacia riscvsingle ----------------
  assign InstrD     = {InstrD_1, InstrD_0};
  assign InstrE     = {InstrE_1, InstrE_0};
  assign InstrM     = {InstrM_1, InstrM_0};
  assign InstrW     = {InstrW_1, InstrW_0};
  assign ALUResultM = ALUResultM_0;
  assign WriteDataM = WriteDataM_0;
  assign RdM        = RdM_0;
  assign RdW        = RdW_0;

  // ============================================================
  // FETCH: un solo PC
  // ============================================================
  floperc #(WIDTH) pcreg(
    .clk(clk),
    .reset(reset),
    .en(~StallF),
    .clear(1'b0),
    .d(PCNext),
    .q(PCF)
  );

  adder pcadd4(.a(PCF), .b(32'd4), .y(PCPlusF_0));   // PC+4
  adder pcadd8(.a(PCF), .b(32'd8), .y(PCPlusF_1));   // PC+8
  assign PCF_1 = PCPlusF_0;                          // PC de la instruccion 1

  // En E1 solo la via 0 redirige; secuencial = PC+8
  mux2 #(WIDTH) pcmux(
    .d0(PCPlusF_1),
    .d1(PCTargetE_0),
    .s(PCSrc_0),
    .y(PCNext)
  );

  // ============================================================
  // Registros de pipeline (uno por via)
  // ============================================================
  // Fetch -> Decode
  floperc #(FD_W) regFD_0(clk, reset, ~StallD, FlushD,
    {InstrF[31:0],  PCF,   PCPlusF_0},
    {InstrD_0,      PCD_0, PCPlusD_0});

  floperc #(FD_W) regFD_1(clk, reset, ~StallD, FlushD,
    {InstrF[63:32], PCF_1, PCPlusF_1},
    {InstrD_1,      PCD_1, PCPlusD_1});

  // Decode -> Execute
  floperc #(DE_W) regDE_0(clk, reset, 1'b1, FlushE,
    {RD1D, RD2D, PCD_0, InstrD_0[11:7], ImmExtD_0, PCPlusD_0, InstrD_0},
    {RD1E, RD2E, PCE_0, RdE_0,          ImmExtE_0, PCPlusE_0, InstrE_0});

  floperc #(DE_W) regDE_1(clk, reset, 1'b1, FlushE,
    {RD4D, RD5D, PCD_1, InstrD_1[11:7], ImmExtD_1, PCPlusD_1, InstrD_1},
    {RD4E, RD5E, PCE_1, RdE_1,          ImmExtE_1, PCPlusE_1, InstrE_1});

  // Execute -> Memory
  flopr #(EM_W) regEM_0(clk, reset,
    {ALUResultE_0, WriteDataE_0, RdE_0, PCPlusE_0, InstrE_0},
    {ALUResultM_0, WriteDataM_0, RdM_0, PCPlusM_0, InstrM_0});

  flopr #(EM_W) regEM_1(clk, reset,
    {ALUResultE_1, WriteDataE_1, RdE_1, PCPlusE_1, InstrE_1},
    {ALUResultM_1, WriteDataM_1, RdM_1, PCPlusM_1, InstrM_1});

  // Memory -> Writeback
  flopr #(MW_W) regMW_0(clk, reset,
    {ALUResultM_0, ReadDataM_0, RdM_0, PCPlusM_0, InstrM_0},
    {ALUResultW_0, ReadDataW_0, RdW_0, PCPlusW_0, InstrW_0});

  flopr #(MW_W) regMW_1(clk, reset,
    {ALUResultM_1, ReadDataM_1, RdM_1, PCPlusM_1, InstrM_1},
    {ALUResultW_1, ReadDataW_1, RdW_1, PCPlusW_1, InstrW_1});

  // ============================================================
  // DECODE
  // ============================================================
  regfile rf(
    .clk(clk),
    .we3(RegWrite_0), .we6(RegWrite_1),
    .a1(InstrD_0[19:15]), .a2(InstrD_0[24:20]),   // via 0
    .a4(InstrD_1[19:15]), .a5(InstrD_1[24:20]),   // via 1
    .a3(RdW_0),           .a6(RdW_1),
    .wd3(ResultW_0),      .wd6(ResultW_1),
    .rd1(RD1D), .rd2(RD2D),
    .rd4(RD4D), .rd5(RD5D)
  );

  extend ext0(.instr(InstrD_0[31:7]), .immsrc(ImmSrc_0), .immext(ImmExtD_0));
  extend ext1(.instr(InstrD_1[31:7]), .immsrc(ImmSrc_1), .immext(ImmExtD_1));

  // ============================================================
  // EXECUTE
  // ============================================================
  adder pcaddbranch_0(.a(PCE_0), .b(ImmExtE_0), .y(PCTargetE_0));
  adder pcaddbranch_1(.a(PCE_1), .b(ImmExtE_1), .y(PCTargetE_1));  // se usara en E2

  // Forwarding via 0 (hazard unit actual)
  mux3 #(WIDTH) srcamuxE_0(.d0(RD1E), .d1(ResultW_0), .d2(ALUResultM_0), .s(ForwardAE),   .y(SrcAE_0));
  mux3 #(WIDTH) srcbmuxE_0(.d0(RD2E), .d1(ResultW_0), .d2(ALUResultM_0), .s(ForwardBE),   .y(WriteDataE_0));
  // Via 1: seleccion fija en 00 (sin forwarding en E1)
  mux3 #(WIDTH) srcamuxE_1(.d0(RD4E), .d1(ResultW_1), .d2(ALUResultM_1), .s(ForwardAE_1), .y(SrcAE_1));
  mux3 #(WIDTH) srcbmuxE_1(.d0(RD5E), .d1(ResultW_1), .d2(ALUResultM_1), .s(ForwardBE_1), .y(WriteDataE_1));

  mux2 #(WIDTH) srcbmux_0(.d0(WriteDataE_0), .d1(ImmExtE_0), .s(ALUSrc_0), .y(SrcBE_0));
  mux2 #(WIDTH) srcbmux_1(.d0(WriteDataE_1), .d1(ImmExtE_1), .s(ALUSrc_1), .y(SrcBE_1));

  alu alu_0(.a(SrcAE_0), .b(SrcBE_0), .alucontrol(ALUControl_0), .result(ALUResultE_0), .zero(Zero_0));
  alu alu_1(.a(SrcAE_1), .b(SrcBE_1), .alucontrol(ALUControl_1), .result(ALUResultE_1), .zero(Zero_1));

  // ============================================================
  // WRITEBACK
  // ============================================================
  mux3 #(WIDTH) resultmux_0(.d0(ALUResultW_0), .d1(ReadDataW_0), .d2(PCPlusW_0), .s(ResultSrc_0), .y(ResultW_0));
  mux3 #(WIDTH) resultmux_1(.d0(ALUResultW_1), .d1(ReadDataW_1), .d2(PCPlusW_1), .s(ResultSrc_1), .y(ResultW_1));

endmodule